#!/usr/bin/env python3
"""Graba un video de una partida de BalaVa emulando el snapshot.

Reutiliza la maquina Z80 de tools/probar.py, va soltando pulsaciones segun un
guion, y saca los fotogramas y el sonido del altavoz a un MP4.

    pip install z80 pillow imageio-ffmpeg
    python3 tools/grabar.py --salida balava.mp4
"""

import argparse
import importlib.util
import os
import struct
import subprocess
import sys
import wave

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TICKS_FRAME = 69888
MUESTREO = 44100

APAGADO = [(0, 0, 0), (0, 0, 205), (205, 0, 0), (205, 0, 205),
           (0, 205, 0), (0, 205, 205), (205, 205, 0), (205, 205, 205)]
BRILLANTE = [(0, 0, 0), (0, 0, 255), (255, 0, 0), (255, 0, 255),
             (0, 255, 0), (0, 255, 255), (255, 255, 0), (255, 255, 255)]


def carga_probar():
    ruta = os.path.join(RAIZ, 'tools', 'probar.py')
    spec = importlib.util.spec_from_file_location('probar', ruta)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


VOLUMEN = [0, 0.006, 0.008, 0.011, 0.016, 0.022, 0.032, 0.045,
           0.063, 0.089, 0.126, 0.178, 0.251, 0.355, 0.501, 0.708]
PASO_AY = (1773400 / 16) / MUESTREO          # ticks del AY por muestra


class Grabadora:
    def __init__(self, probar, binario, pantalla, sym):
        self.probar = probar
        self.m = probar.Spectrum(binario, pantalla)
        self.sim = probar.lee_simbolos(sym)
        self.fotogramas = []
        self.audio = bytearray()
        self.n = 0
        self.cuenta = [0.0, 0.0, 0.0]           # estado del AY para el sonido
        self.nivel = [1, 1, 1]
        self.cuenta_ruido = 0.0
        self.lfsr = 1
        self.nivel_ruido = 1
        self.continua = [0.0, 0.0]

    def val(self, nombre):
        return self.m.peek(self.sim[nombre])

    # --- un fotograma: emula, pinta y genera su trozo de sonido -------
    def frame(self, teclas=()):
        self.m.pulsadas = set(teclas)
        self.m.ticks_to_stop = TICKS_FRAME
        while self.m.ticks_to_stop > 0:
            self.m.run()
        self.m.on_handle_active_int()
        self.fotogramas.append(self._pinta())
        self._sonido()
        self.n += 1

    def frames(self, n, teclas=()):
        for _ in range(n):
            self.frame(teclas)

    def hasta(self, condicion, teclas=(), limite=400):
        """Mantiene unas teclas hasta que se cumpla algo (o se acabe el limite)."""
        for _ in range(limite):
            if condicion():
                return
            self.frame(teclas)

    def _pinta(self):
        mem = self.m.memory
        destello = (self.n // 16) % 2          # el FLASH de la ULA
        fila = bytearray(256 * 192 * 3)
        for y in range(192):
            base = 0x4000 | ((y & 0xC0) << 5) | ((y & 0x07) << 8) | ((y & 0x38) << 2)
            attr_base = 0x5800 + (y // 8) * 32
            for col in range(32):
                b = mem[base + col]
                a = mem[attr_base + col]
                tabla = BRILLANTE if a & 0x40 else APAGADO
                tinta, papel = a & 7, (a >> 3) & 7
                if a & 0x80 and destello:
                    tinta, papel = papel, tinta
                ct, cp = tabla[tinta], tabla[papel]
                for k in range(8):
                    x = col * 8 + k
                    c = ct if b & (0x80 >> k) else cp
                    p = (y * 256 + x) * 3
                    fila[p:p + 3] = bytes(c)
        return bytes(fila)

    def _sonido(self):
        """Sintetiza los tres canales del AY con los registros del fotograma."""
        ay = self.m.ay
        per = [ay[0] | ((ay[1] & 15) << 8), ay[2] | ((ay[3] & 15) << 8),
               ay[4] | ((ay[5] & 15) << 8)]
        per_ruido = (ay[6] & 31) or 1
        mezcla = ay[7]
        vol = [ay[8] & 15, ay[9] & 15, ay[10] & 15]
        muestras = bytearray()
        for _ in range(MUESTREO // 50):
            self.cuenta_ruido -= PASO_AY
            while self.cuenta_ruido <= 0:
                self.cuenta_ruido += per_ruido * 2
                bit = (self.lfsr ^ (self.lfsr >> 3)) & 1
                self.lfsr = (self.lfsr >> 1) | (bit << 16)
                self.nivel_ruido = self.lfsr & 1
            v = 0.0
            for c in range(3):
                p = per[c] or 1
                self.cuenta[c] -= PASO_AY
                while self.cuenta[c] <= 0:
                    self.cuenta[c] += p
                    self.nivel[c] ^= 1
                con_tono = not ((mezcla >> c) & 1)
                con_ruido = not ((mezcla >> (c + 3)) & 1)
                if (self.nivel[c] if con_tono else 1) & (self.nivel_ruido if con_ruido else 1):
                    v += VOLUMEN[vol[c]]
            salida = v - self.continua[0] + 0.995 * self.continua[1]
            self.continua = [v, salida]
            muestras += struct.pack('<h', max(-32000, min(32000, int(salida * 24000))))
        self.audio += muestras


def guion(g):
    """La partida que se graba."""
    v = g.val
    g.frames(150)                                     # pantalla de carga
    g.frames(8, ['SPACE'])
    g.frames(320)                                     # menu, con la musica del AY
    g.frames(8, ['3'])                                # los controles
    g.frames(130)
    g.frames(8, ['SPACE'])
    g.frames(90)
    g.frames(8, ['2'])                                # partida a dos
    g.frames(40)

    def calle():
        ocupado = [(v('barril1_y'), 32), (v('barril2_y'), 32),
                   (100, 32), (60, 32), (132, 58)]
        for y in range(20, 158, 2):
            if all(not (o - 1 <= y + 13 <= o + alto) for o, alto in ocupado):
                return y
        return 40

    # el sheriff vacia medio cargador contra su barril: se va perforando
    g.hasta(lambda: v('p1_y') >= v('barril1_y') + 8, ['A'])
    g.hasta(lambda: v('p1_y') <= v('barril1_y') + 8, ['Q'])
    for _ in range(4):
        g.frames(3, ['Z'])
        g.frames(22)
    g.frames(30)

    # tres tiros seguidos por la calle libre, sin esperar a que lleguen
    objetivo = calle()
    g.hasta(lambda: v('p1_y') <= objetivo, ['Q'])
    g.hasta(lambda: v('p1_y') >= objetivo, ['A'])
    for _ in range(3):
        g.frames(3, ['Z'])
        g.frames(10)
    g.frames(60)

    # el bandido responde y mata al sheriff: cine y funeral
    g.hasta(lambda: v('p2_y') <= objetivo, ['P'])
    g.hasta(lambda: v('p2_y') >= objetivo, ['L'])
    g.frames(15)
    g.frames(3, ['B'])
    g.hasta(lambda: v('puntos2') > 0, [], limite=250)
    g.hasta(lambda: v('p1_y') == 40 and v('p2_y') == 120, [], limite=900)
    g.frames(80)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--salida', default=os.path.join(RAIZ, 'dist', 'balava.mp4'))
    ap.add_argument('--bin', default=os.path.join(RAIZ, 'build', 'balava.bin'))
    ap.add_argument('--scr', default=os.path.join(RAIZ, 'dist', 'balava.scr'))
    ap.add_argument('--sym', default=os.path.join(RAIZ, 'build', 'balava.sym'))
    ap.add_argument('--escala', type=int, default=3)
    args = ap.parse_args()

    import imageio_ffmpeg
    probar = carga_probar()
    g = Grabadora(probar, args.bin, args.scr, args.sym)
    guion(g)
    print(f'{g.n} fotogramas ({g.n / 50:.1f} s)')

    tmp_wav = args.salida + '.wav'
    with wave.open(tmp_wav, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(MUESTREO)
        w.writeframes(bytes(g.audio))

    ancho, alto = 256 * args.escala, 192 * args.escala
    orden = [imageio_ffmpeg.get_ffmpeg_exe(), '-y', '-loglevel', 'error',
             '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', '256x192', '-r', '50', '-i', '-',
             '-i', tmp_wav,
             '-vf', f'scale={ancho}:{alto}:flags=neighbor',
             '-c:v', 'libx264', '-preset', 'medium', '-crf', '20', '-pix_fmt', 'yuv420p',
             '-c:a', 'aac', '-b:a', '96k', '-shortest', args.salida]
    p = subprocess.Popen(orden, stdin=subprocess.PIPE)
    for f in g.fotogramas:
        p.stdin.write(f)
    p.stdin.close()
    if p.wait() != 0:
        sys.exit('ffmpeg fallo')
    os.remove(tmp_wav)
    print(f'{args.salida}: {os.path.getsize(args.salida) / 1024:.0f} KB')


if __name__ == '__main__':
    main()
