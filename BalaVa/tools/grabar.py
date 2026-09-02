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


class Grabadora:
    def __init__(self, probar, z80, sym):
        self.probar = probar
        self.m = probar.Spectrum(z80)
        self.sim = probar.lee_simbolos(sym)
        self.fotogramas = []
        self.audio = bytearray()
        self.n = 0
        self.altavoz = 0
        self.cambios = []                       # (posicion en el frame, nivel)
        self.m.set_output_callback(self._out)

    def _out(self, addr, valor):
        if addr & 0xFF == 0xFE:
            nivel = 1 if valor & 0x10 else 0
            if nivel != self.altavoz:
                self.altavoz = nivel
                pos = TICKS_FRAME - max(0, self.m.ticks_to_stop)
                self.cambios.append((pos, nivel))

    def val(self, nombre):
        return self.m.peek(self.sim[nombre])

    # --- un fotograma: emula, pinta y genera su trozo de sonido -------
    def frame(self, teclas=()):
        self.m.pulsadas = set(teclas)
        self.cambios = []
        nivel_ini = self.altavoz
        self.m.ticks_to_stop = TICKS_FRAME
        while self.m.ticks_to_stop > 0:
            self.m.run()
        self.m.on_handle_active_int()
        self.fotogramas.append(self._pinta())
        self._sonido(nivel_ini)
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

    def _sonido(self, nivel_ini):
        n = MUESTREO // 50                      # muestras por fotograma
        nivel = nivel_ini
        idx = 0
        muestras = bytearray()
        for i in range(n):
            limite = (i + 1) * TICKS_FRAME // n
            while idx < len(self.cambios) and self.cambios[idx][0] <= limite:
                nivel = self.cambios[idx][1]
                idx += 1
            muestras += struct.pack('<h', 7000 if nivel else -7000)
        self.audio += muestras


def guion(g):
    """La partida que se graba."""
    v = g.val
    g.frames(130)                                     # pantalla de carga
    g.frames(8, ['SPACE'])
    g.frames(300)                                     # menu, con musica
    g.frames(8, ['2'])                                # los controles
    g.frames(140)
    g.frames(8, ['SPACE'])
    g.frames(100)                                     # otra vez el menu
    g.frames(8, ['1'])                                # a jugar
    g.frames(40)

    # el sheriff baja hasta su caja y le abre una tronera a tiros
    g.hasta(lambda: v('p1_y') >= 80, ['A'])
    g.frames(15)
    for _ in range(3):
        g.frames(2, ['Z'])
        g.frames(40)
    g.frames(25)

    # un tiro contra el caracol, que anda por abajo
    g.hasta(lambda: v('p1_y') >= 135, ['A'])
    g.frames(2, ['Z'])
    g.frames(70)

    # los dos a la calle libre de arriba: duelo de verdad
    g.hasta(lambda: v('p1_y') <= 40, ['Q'])
    g.hasta(lambda: v('p2_y') <= 60, ['P'])
    g.frames(2, ['Z'])
    g.frames(30)
    g.hasta(lambda: v('p2_y') >= 90, ['L'])           # el bandido esquiva
    g.frames(50)

    # y ahora si: impacto, caido y funeral entero
    g.hasta(lambda: v('p2_y') <= 40, ['P'])
    g.hasta(lambda: v('p1_y') <= 40, ['Q'])
    g.frames(20)
    g.frames(2, ['Z'])
    g.hasta(lambda: v('puntos1') > 0, [], limite=200)
    g.frames(60)                                      # el caido, a la vista
    g.hasta(lambda: v('esc_x') >= 216, [], limite=400) # el funeral entero
    g.frames(120)                                     # vuelta al juego


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--salida', default=os.path.join(RAIZ, 'dist', 'balava.mp4'))
    ap.add_argument('--z80', default=os.path.join(RAIZ, 'dist', 'balava.z80'))
    ap.add_argument('--sym', default=os.path.join(RAIZ, 'build', 'balava.sym'))
    ap.add_argument('--escala', type=int, default=3)
    args = ap.parse_args()

    import imageio_ffmpeg
    probar = carga_probar()
    g = Grabadora(probar, args.z80, args.sym)
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
