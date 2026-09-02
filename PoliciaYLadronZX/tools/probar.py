#!/usr/bin/env python3
"""Pruebas del juego ejecutando el snapshot en un Z80 emulado de verdad.

Requiere:  pip install z80 pillow

    python3 tools/probar.py [--png directorio]

Monta una maquina Z80 con una ROM sintetica (manejador de la IM 1 y un juego
de caracteres 8x8 generado al vuelo en 0x3D00, que es donde lo tiene la ROM
real del Spectrum), carga dist/policia_ladron.z80 y comprueba la mecanica:
movimiento, limites, disparos, impactos, esquivas, marcador y fin de partida.
"""

import argparse
import os
import sys

import z80
from PIL import Image, ImageDraw, ImageFont

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TICKS_FRAME = 69888                     # T-estados de un fotograma del 48K
TTF = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'

FILAS_TECLADO = {                       # semi-fila -> teclas (bit 0 .. bit 4)
    0xFE: ['CAPS', 'Z', 'X', 'C', 'V'],
    0xFD: ['A', 'S', 'D', 'F', 'G'],
    0xFB: ['Q', 'W', 'E', 'R', 'T'],
    0xF7: ['1', '2', '3', '4', '5'],
    0xEF: ['0', '9', '8', '7', '6'],
    0xDF: ['P', 'O', 'I', 'U', 'Y'],
    0xBF: ['ENTER', 'L', 'K', 'J', 'H'],
    0x7F: ['SPACE', 'SYM', 'M', 'N', 'B'],
}


def dir_pantalla(y, col=0):
    return 0x4000 | ((y & 0xC0) << 5) | ((y & 0x07) << 8) | ((y & 0x38) << 2) | col


def crea_rom():
    """ROM minima: DI en 0x0000, EI/RET en 0x0038 y un font 8x8 en 0x3D00."""
    rom = bytearray(0x4000)
    rom[0x0000] = 0xF3
    rom[0x0038] = 0xFB
    rom[0x0039] = 0xC9
    fuente = ImageFont.truetype(TTF, 9)
    for c in range(32, 128):
        img = Image.new('1', (8, 8), 0)
        ImageDraw.Draw(img).text((-1, -1), chr(c), font=fuente, fill=1)
        for fila in range(8):
            b = 0
            for col in range(8):
                if img.getpixel((col, fila)):
                    b |= 0x80 >> col
            rom[0x3C00 + c * 8 + fila] = b
    return bytes(rom)


class Spectrum(z80.Z80Machine):
    def __init__(self, snapshot):
        super().__init__()
        self.pulsadas = set()
        self.set_memory_block(0x0000, crea_rom())
        datos = open(snapshot, 'rb').read()
        cab, ram = datos[:30], datos[30:]
        assert len(ram) == 49152, f'RAM de {len(ram)} bytes'
        assert cab[12] & 0x20 == 0, 'el .z80 esta comprimido'
        assert cab[29] & 3 == 1, 'el .z80 no usa IM 1'
        self.set_memory_block(0x4000, ram)
        self.pc = cab[6] | (cab[7] << 8)
        self.sp = cab[8] | (cab[9] << 8)
        self.iy = cab[23] | (cab[24] << 8)
        self.set_input_callback(self._in)

    def _in(self, addr):
        if addr & 0xFF != 0xFE:
            return 0xFF
        alto = (addr >> 8) & 0xFF
        res = 0xFF
        for fila, teclas in FILAS_TECLADO.items():
            if alto & ((~fila) & 0xFF):
                continue                                # semi-fila no seleccionada
            for n, tecla in enumerate(teclas):
                if tecla in self.pulsadas:
                    res &= ~(1 << n) & 0xFF
            return res
        return res

    def frames(self, n, teclas=()):
        self.pulsadas = set(teclas)
        for _ in range(n):
            self.ticks_to_stop = TICKS_FRAME
            while self.ticks_to_stop > 0:
                self.run()
            self.on_handle_active_int()

    def peek(self, addr):
        return self.memory[addr]

    def columna(self, col, y0=0, y1=192):
        """Bytes de una columna de caracteres entre dos filas de pixeles."""
        return [self.memory[dir_pantalla(y, col)] for y in range(y0, y1)]

    def png(self, ruta):
        img = Image.new('RGB', (256, 192))
        px = img.load()
        for y in range(192):
            base = dir_pantalla(y)
            for col in range(32):
                b = self.memory[base + col]
                for k in range(8):
                    px[col * 8 + k, y] = (0, 0, 0) if b & (0x80 >> k) else (255, 255, 0)
        img.resize((512, 384), Image.NEAREST).save(ruta)


def lee_simbolos(ruta):
    simbolos = {}
    for linea in open(ruta):
        partes = linea.split()
        if len(partes) == 3 and partes[1].upper() == 'EQU':
            simbolos[partes[0]] = int(partes[2].rstrip('Hh'), 16)
    return simbolos


class Pruebas:
    def __init__(self):
        self.fallos = 0

    def check(self, cond, texto, detalle=''):
        marca = 'OK  ' if cond else 'FALLA'
        if not cond:
            self.fallos += 1
        print(f'  [{marca}] {texto}{(" -> " + detalle) if detalle else ""}')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--png', help='directorio donde guardar capturas')
    ap.add_argument('--z80', default=os.path.join(RAIZ, 'dist', 'policia_ladron.z80'))
    ap.add_argument('--sym', default=os.path.join(RAIZ, 'build', 'juego.sym'))
    args = ap.parse_args()

    if args.png:
        os.makedirs(args.png, exist_ok=True)

    def captura(m, nombre):
        if args.png:
            m.png(os.path.join(args.png, nombre))

    sim = lee_simbolos(args.sym)
    P = Pruebas()
    m = Spectrum(args.z80)
    val = lambda n: m.peek(sim[n])

    # ---------------------------------------------------------------
    print('\n1. Pantalla de presentacion')
    m.frames(10)
    captura(m, '1-titulo.png')
    poli = [m.peek(sim['spr_poli'] + i) for i in range(16)]
    ladron = [m.peek(sim['spr_ladron'] + i) for i in range(16)]
    P.check(m.columna(2, 16, 32) == poli, 'el policia aparece junto al titulo')
    P.check(m.columna(29, 16, 32) == ladron, 'el ladron aparece junto al titulo')
    filas_texto = {y // 8 for y in range(192)
                   if any(m.memory[dir_pantalla(y, c)] for c in range(32))}
    P.check(filas_texto == {2, 3, 6, 7, 8, 11, 12, 13, 16, 19},
            'los textos caen en las filas previstas', str(sorted(filas_texto)))
    P.check(all(m.memory[dir_pantalla(y, 0)] == 0 for y in range(48, 192)),
            'ningun texto se desborda a la columna 0')

    # ---------------------------------------------------------------
    print('\n2. Comienzo de la partida (ENTER)')
    m.frames(3, ['ENTER'])
    m.frames(5)
    captura(m, '2-partida.png')
    P.check((val('p1_y'), val('p2_y')) == (48, 128), 'jugadores en su posicion de salida',
            f"{val('p1_y')},{val('p2_y')}")
    P.check(val('puntos1') == 0 and val('puntos2') == 0, 'marcador a cero')
    P.check(m.columna(2, 48, 64) == poli, 'sprite del policia dibujado en la columna 2')
    P.check(m.columna(29, 128, 144) == ladron, 'sprite del ladron dibujado en la columna 29')
    P.check(all(m.memory[dir_pantalla(13, c)] == 0xFF for c in range(32)),
            'linea separadora del marcador')

    # ---------------------------------------------------------------
    print('\n3. Movimiento y limites')
    m.frames(10, ['Q'])
    P.check(val('p1_y') == 28, 'Q sube 2 pixeles por fotograma', str(val('p1_y')))
    m.frames(10, ['A'])
    P.check(val('p1_y') == 48, 'A baja 2 pixeles por fotograma', str(val('p1_y')))
    m.frames(10, ['P'])
    P.check(val('p2_y') == 108, 'P sube al ladron', str(val('p2_y')))
    m.frames(10, ['L'])
    P.check(val('p2_y') == 128, 'L baja al ladron', str(val('p2_y')))
    m.frames(120, ['Q'])
    P.check(val('p1_y') == 16, 'tope superior', str(val('p1_y')))
    m.frames(120, ['A'])
    P.check(val('p1_y') == 176, 'tope inferior', str(val('p1_y')))
    P.check(m.columna(2, 176, 192) == poli and not any(m.columna(2, 16, 176)),
            'al moverse no deja rastro en su columna')

    # ---------------------------------------------------------------
    print('\n4. Disparo que falla')
    m.frames(120, ['Q'])                                    # policia arriba, ladron abajo
    m.frames(2, ['V'])
    P.check(val('b1_act') == 1 and val('b1_y') == val('p1_y') + 7,
            'la bala sale a la altura del brazo')
    m.frames(15)
    captura(m, '3-bala.png')
    P.check(val('b1_x') > 24 and val('b1_act') == 1, 'la bala avanza', f"x={val('b1_x')}")
    m.frames(60)
    P.check(val('b1_act') == 0 and val('puntos1') == 0, 'sin alineacion no hay impacto')

    # ---------------------------------------------------------------
    print('\n5. Impactos')
    while val('p1_y') != val('p2_y'):
        m.frames(1, ['A'] if val('p1_y') < val('p2_y') else ['Q'])
    m.frames(2, ['V'])
    m.frames(80)
    captura(m, '4-impacto.png')
    P.check(val('puntos1') == 1, 'el policia acierta al ladron', f"{val('puntos1')}-{val('puntos2')}")
    P.check((val('p1_y'), val('p2_y')) == (48, 128), 'la ronda recoloca a los dos')
    while val('p1_y') != val('p2_y'):
        m.frames(1, ['A'] if val('p1_y') < val('p2_y') else ['Q'])
    m.frames(2, ['SPACE'])
    m.frames(80)
    P.check(val('puntos2') == 1, 'el ladron acierta al policia', f"{val('puntos1')}-{val('puntos2')}")

    # ---------------------------------------------------------------
    print('\n6. Esquiva y balas cruzadas')
    while val('p1_y') != val('p2_y'):
        m.frames(1, ['A'] if val('p1_y') < val('p2_y') else ['Q'])
    antes = (val('puntos1'), val('puntos2'))
    m.frames(2, ['V'])
    m.frames(40, ['P'])                                     # el ladron se aparta
    m.frames(40)
    P.check((val('puntos1'), val('puntos2')) == antes, 'moverse a tiempo esquiva la bala')
    m.frames(2, ['V', 'SPACE'])
    m.frames(26)
    captura(m, '5-cruce.png')
    P.check(val('b1_act') == 1 and val('b2_act') == 1, 'las dos balas conviven')
    m.frames(80)
    sucio = sum(1 for y in range(16, 192) for c in range(32)
                if c not in (2, 29) and m.memory[dir_pantalla(y, c)])
    P.check(sucio == 0, 'las balas no dejan rastro al cruzarse', f'{sucio} bytes')

    # ---------------------------------------------------------------
    print('\n7. Fin de partida')
    for _ in range(12):
        if val('puntos1') >= 5:
            break
        while val('p1_y') != val('p2_y'):
            m.frames(1, ['A'] if val('p1_y') < val('p2_y') else ['Q'])
        m.frames(2, ['V'])
        m.frames(100)
    P.check(val('puntos1') == 5, 'la partida llega a 5 impactos', str(val('puntos1')))
    m.frames(20)
    captura(m, '6-ganador.png')
    filas = {y // 8 for y in range(192)
             if any(m.memory[dir_pantalla(y, c)] for c in range(32))}
    P.check(filas == {9, 12, 16}, 'pantalla de ganador (texto + resultado)', str(sorted(filas)))
    m.frames(3, ['ENTER'])
    m.frames(10)
    captura(m, '7-vuelta.png')
    P.check(m.columna(2, 16, 32) == poli, 'ENTER devuelve a la presentacion')
    m.frames(3, ['ENTER'])
    m.frames(10)
    P.check((val('p1_y'), val('p2_y'), val('puntos1')) == (48, 128, 0),
            'la partida nueva parte de cero')

    print()
    if P.fallos:
        print(f'{P.fallos} comprobacion(es) fallidas')
        return 1
    print('todas las comprobaciones correctas')
    return 0


if __name__ == '__main__':
    sys.exit(main())
