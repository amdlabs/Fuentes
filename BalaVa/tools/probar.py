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

    def bloque(self, col, y, filas, ancho):
        """Bytes de un bloque rectangular de pantalla, fila a fila."""
        return [self.memory[dir_pantalla(y + f, col + c)]
                for f in range(filas) for c in range(ancho)]

    def sprite(self, simbolos, nombre, filas, ancho):
        """Los bytes de un sprite tal y como estan en el codigo."""
        return [self.peek(simbolos[nombre] + i) for i in range(filas * ancho)]

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
    ap.add_argument('--z80', default=os.path.join(RAIZ, 'dist', 'balava.z80'))
    ap.add_argument('--sym', default=os.path.join(RAIZ, 'build', 'balava.sym'))
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

    COL_P1, COL_P2, ANCHO, ALTO = 1, 28, 3, 32
    ESCENARIO = [('spr_carreta', 14, 20, 28, 3),        # nombre, col, y, filas, ancho
                 ('spr_cactus', 8, 100, 32, 2),
                 ('spr_cactus', 21, 60, 32, 2)]
    COLS_OCUPADAS = set(range(COL_P1, COL_P1 + ANCHO)) | set(range(COL_P2, COL_P2 + ANCHO))
    for _, col, _, _, ancho in ESCENARIO:
        COLS_OCUPADAS |= set(range(col, col + ancho))

    poli = m.sprite(sim, 'spr_poli', ALTO, ANCHO)
    ladron = m.sprite(sim, 'spr_ladron', ALTO, ANCHO)
    cactus = m.sprite(sim, 'spr_cactus', 32, 2)

    # ---------------------------------------------------------------
    print('\n1. Menu')
    m.frames(10)
    captura(m, '1-menu.png')
    P.check(all(m.memory[dir_pantalla(y, c)] == 0xFF for y in (2, 3, 188, 189)
                for c in range(32)), 'marco: lineas de arriba y abajo')
    P.check(all(m.memory[dir_pantalla(y, 0)] & 0x30 == 0x30 and
                m.memory[dir_pantalla(y, 31)] & 0x0C == 0x0C for y in range(4, 188)),
            'marco: lineas de los lados')
    P.check(all(m.memory[dir_pantalla(y, c)] == 0xFF for y in range(24, 56)
                for c in range(1, 30) if not 10 <= c <= 21),
            'banda negra del logotipo')
    huecos = sum(bin(m.memory[dir_pantalla(y, c)] ^ 0xFF).count('1')
                 for y in range(33, 47) for c in range(10, 22))
    esperados = 0                              # pixeles de las seis letras
    for i in range(6):
        glifo = m.peek(sim['logo_letras'] + i * 2) | (m.peek(sim['logo_letras'] + i * 2 + 1) << 8)
        esperados += sum(bin(m.peek(glifo + n)).count('1') for n in range(28))
    P.check(huecos == esperados, 'el logotipo BALAVA aparece en hueco sobre la banda',
            f'{huecos} de {esperados} pixeles')
    P.check(m.bloque(3, 64, ALTO, ANCHO) == poli and m.bloque(25, 64, ALTO, ANCHO) == ladron,
            'los dos pistoleros se apuntan bajo el logotipo')
    P.check(m.bloque(10, 72, 24, 2) == cactus[:48] and m.bloque(19, 72, 24, 2) == cactus[:48],
            'los cactus del menu')
    P.check(all(m.peek(0x5800 + 19 * 32 + c) == 0xB0 for c in range(10, 21)),
            'el aviso PULSA 1 O 2 usa el bit FLASH')

    # ---------------------------------------------------------------
    print('\n2. Opcion 2: pantalla de controles')
    m.frames(3, ['2'])
    m.frames(5)
    captura(m, '2-controles.png')
    filas = {y // 8 for y in range(8, 184)
             if any(m.memory[dir_pantalla(y, c)] for c in range(4, 28))}
    P.check(filas == {3, 7, 8, 9, 12, 13, 14, 17, 20}, 'textos de la ayuda',
            str(sorted(filas)))
    m.frames(3, ['SPACE'])
    m.frames(5)
    P.check(all(m.memory[dir_pantalla(24, c)] == 0xFF for c in range(1, 10)),
            'cualquier tecla devuelve al menu')

    # ---------------------------------------------------------------
    print('\n3. Opcion 1: empieza la partida')
    m.frames(3, ['1'])
    m.frames(5)
    captura(m, '3-partida.png')
    P.check((val('p1_y'), val('p2_y')) == (40, 120), 'pistoleros en su posicion de salida',
            f"{val('p1_y')},{val('p2_y')}")
    P.check(val('puntos1') == 0 and val('puntos2') == 0, 'marcador a cero')
    P.check(m.bloque(COL_P1, 40, ALTO, ANCHO) == poli, 'sheriff dibujado a la izquierda')
    P.check(m.bloque(COL_P2, 120, ALTO, ANCHO) == ladron, 'bandido dibujado a la derecha')
    for nombre, col, y, filas, ancho in ESCENARIO:
        P.check(m.bloque(col, y, filas, ancho) == m.sprite(sim, nombre, filas, ancho),
                f'decorado: {nombre[4:]} en la columna {col}')
    P.check(all(m.memory[dir_pantalla(13, c)] == 0xFF for c in range(32)),
            'linea separadora del marcador')

    # ---------------------------------------------------------------
    print('\n4. Movimiento y limites')
    m.frames(10, ['Q'])
    P.check(val('p1_y') == 20, 'Q sube 2 pixeles por fotograma', str(val('p1_y')))
    m.frames(10, ['A'])
    P.check(val('p1_y') == 40, 'A baja 2 pixeles por fotograma', str(val('p1_y')))
    m.frames(10, ['P'])
    P.check(val('p2_y') == 100, 'P sube al bandido', str(val('p2_y')))
    m.frames(10, ['L'])
    P.check(val('p2_y') == 120, 'L baja al bandido', str(val('p2_y')))
    m.frames(120, ['Q'])
    P.check(val('p1_y') == 16, 'tope superior', str(val('p1_y')))
    m.frames(120, ['A'])
    P.check(val('p1_y') == 160, 'tope inferior', str(val('p1_y')))
    P.check(m.bloque(COL_P1, 160, ALTO, ANCHO) == poli and
            not any(m.bloque(COL_P1, 16, 144, ANCHO)),
            'al moverse no deja rastro en su columna')

    # ---------------------------------------------------------------
    print('\n5. El decorado para las balas')
    while val('p1_y') > 16:
        m.frames(1, ['Q'])                       # arriba del todo: la carreta tapa
    puntos = (val('puntos1'), val('puntos2'))
    m.frames(2, ['V'])
    m.frames(15)
    captura(m, '4-bala.png')
    P.check(val('b1_act') == 1 and val('b1_y') == val('p1_y') + 13,
            'la bala sale a la altura del revolver')
    m.frames(30)
    P.check(val('b1_act') == 0, 'la carreta para la bala', f"x={val('b1_x')}")
    P.check(val('b1_x') == 112, 'la bala se queda en el borde de la carreta',
            str(val('b1_x')))
    P.check((val('puntos1'), val('puntos2')) == puntos, 'una bala parada no puntua')
    for nombre, col, y, filas, ancho in ESCENARIO:
        P.check(m.bloque(col, y, filas, ancho) == m.sprite(sim, nombre, filas, ancho),
                f'el decorado sigue intacto: {nombre[4:]} en la columna {col}')

    # ---------------------------------------------------------------
    print('\n6. Disparo que falla')
    while val('p1_y') < 160:
        m.frames(1, ['A'])                       # abajo del todo: linea libre
    m.frames(2, ['V'])
    m.frames(60)
    P.check(val('b1_act') == 0 and val('puntos1') == 0, 'sin alineacion no hay impacto')

    # ---------------------------------------------------------------
    print('\n7. Impactos')
    while val('p2_y') < 160:
        m.frames(1, ['L'])                       # los dos abajo, sin nada en medio
    P.check(val('p1_y') == val('p2_y') == 160, 'los dos en la calle libre de abajo')
    m.frames(2, ['V'])
    m.frames(80)
    captura(m, '5-impacto.png')
    P.check(val('puntos1') == 1, 'el sheriff acierta al bandido',
            f"{val('puntos1')}-{val('puntos2')}")
    P.check((val('p1_y'), val('p2_y')) == (40, 120), 'la ronda recoloca a los dos')
    while val('p1_y') < 160:
        m.frames(1, ['A'])
    while val('p2_y') < 160:
        m.frames(1, ['L'])
    m.frames(2, ['SPACE'])
    m.frames(80)
    P.check(val('puntos2') == 1, 'el bandido acierta al sheriff',
            f"{val('puntos1')}-{val('puntos2')}")

    # ---------------------------------------------------------------
    print('\n8. Esquiva y balas cruzadas')
    while val('p1_y') < 160:
        m.frames(1, ['A'])
    while val('p2_y') < 160:
        m.frames(1, ['L'])
    antes = (val('puntos1'), val('puntos2'))
    m.frames(2, ['V'])
    m.frames(40, ['P'])                          # el bandido se aparta
    m.frames(40)
    P.check((val('puntos1'), val('puntos2')) == antes, 'moverse a tiempo esquiva la bala')
    while val('p2_y') < 160:
        m.frames(1, ['L'])
    m.frames(2, ['V', 'SPACE'])
    m.frames(20)
    captura(m, '6-cruce.png')
    P.check(val('b1_act') == 1 and val('b2_act') == 1, 'las dos balas conviven')
    m.frames(80)
    sucio = sum(1 for y in range(16, 192) for c in range(32)
                if c not in COLS_OCUPADAS and m.memory[dir_pantalla(y, c)])
    P.check(sucio == 0, 'las balas no dejan rastro al cruzarse', f'{sucio} bytes')

    # ---------------------------------------------------------------
    print('\n9. Fin de partida')
    for _ in range(14):
        if val('puntos1') >= 5:
            break
        while val('p1_y') < 160:
            m.frames(1, ['A'])
        while val('p2_y') < 160:
            m.frames(1, ['L'])
        m.frames(2, ['V'])
        m.frames(100)
    P.check(val('puntos1') == 5, 'la partida llega a 5 impactos', str(val('puntos1')))
    m.frames(20)
    captura(m, '7-ganador.png')
    filas = {y // 8 for y in range(192)
             if any(m.memory[dir_pantalla(y, c)] for c in range(32))}
    P.check(filas == {9, 12, 16}, 'pantalla de ganador (texto + resultado)', str(sorted(filas)))
    m.frames(3, ['SPACE'])
    m.frames(10)
    captura(m, '8-vuelta.png')
    P.check(all(m.memory[dir_pantalla(24, c)] == 0xFF for c in range(1, 10)),
            'al acabar se vuelve al menu')
    m.frames(3, ['1'])
    m.frames(10)
    P.check((val('p1_y'), val('p2_y'), val('puntos1')) == (40, 120, 0),
            'la partida nueva parte de cero')

    print()
    if P.fallos:
        print(f'{P.fallos} comprobacion(es) fallidas')
        return 1
    print('todas las comprobaciones correctas')
    return 0


if __name__ == '__main__':
    sys.exit(main())
