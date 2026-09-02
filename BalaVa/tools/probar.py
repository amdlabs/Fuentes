#!/usr/bin/env python3
"""Pruebas del juego ejecutando el snapshot en un Z80 emulado de verdad.

Requiere:  pip install z80 pillow

    python3 tools/probar.py [--png directorio]

Monta una maquina Z80 con una ROM sintetica (manejador de la IM 1 y un juego
de caracteres 8x8 generado al vuelo en 0x3D00, que es donde lo tiene la ROM
real del Spectrum), carga el binario del juego y comprueba la mecanica:
menu, musica del AY, movimiento, disparos, municion, impactos, cinematica,
funeral y la maquina jugando sola.
"""

import argparse
import importlib.util
import os
import sys

import z80
from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TICKS_FRAME = 69888                     # T-estados de un fotograma del 48K

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


def _modulo_rom():
    ruta = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'rom.py')
    spec = importlib.util.spec_from_file_location('rom', ruta)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


crea_rom = _modulo_rom().crea_rom


class Spectrum(z80.Z80Machine):
    """Un 128K con la ROM sintetica: memoria plana, que el juego no pagina."""

    def __init__(self, binario, pantalla):
        super().__init__()
        self.pulsadas = set()
        self.set_memory_block(0x0000, crea_rom())
        self.set_memory_block(0x4000, open(pantalla, 'rb').read())
        self.set_memory_block(0x8000, open(binario, 'rb').read())
        self.pc = 0x8000
        self.sp = 0xFF00
        self.iy = 0x5C3A
        self.ay = [0] * 16                  # registros del AY
        self.ay_sel = 0
        self.ay_escrituras = []
        self.set_input_callback(self._in)
        self.set_output_callback(self._out)
        self.conmutaciones = 0
        self.ultimo_puerto = 0

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

    def _out(self, addr, valor):
        if addr & 0xFF == 0xFE:
            if (valor ^ self.ultimo_puerto) & 0x10:     # bit del altavoz
                self.conmutaciones += 1
            self.ultimo_puerto = valor
        elif addr == 0xFFFD:
            self.ay_sel = valor & 0x0F
        elif addr == 0xBFFD:
            self.ay[self.ay_sel] = valor
            self.ay_escrituras.append((self.ay_sel, valor))

    def periodo_canal(self, canal):
        """Periodo de tono de un canal del AY (0 = A, 1 = B, 2 = C)."""
        return self.ay[canal * 2] | ((self.ay[canal * 2 + 1] & 0x0F) << 8)

    def frecuencia(self, ms=20):
        """Mide la frecuencia del altavoz durante unos milisegundos."""
        self.conmutaciones = 0
        self.ticks_to_stop = int(3_500_000 * ms / 1000)
        while self.ticks_to_stop > 0:
            self.run()
        return round(self.conmutaciones / 2 / (ms / 1000))

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
        apagado = [(0, 0, 0), (0, 0, 205), (205, 0, 0), (205, 0, 205),
                   (0, 205, 0), (0, 205, 205), (205, 205, 0), (205, 205, 205)]
        brillante = [(0, 0, 0), (0, 0, 255), (255, 0, 0), (255, 0, 255),
                     (0, 255, 0), (0, 255, 255), (255, 255, 0), (255, 255, 255)]
        img = Image.new('RGB', (256, 192))
        px = img.load()
        for y in range(192):
            base = dir_pantalla(y)
            for col in range(32):
                b = self.memory[base + col]
                attr = self.memory[0x5800 + (y // 8) * 32 + col]
                tabla = brillante if attr & 0x40 else apagado
                tinta, papel = tabla[attr & 7], tabla[(attr >> 3) & 7]
                for k in range(8):
                    px[col * 8 + k, y] = tinta if b & (0x80 >> k) else papel
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


def lee_z80(ruta):
    """Lee un .z80 como manda la especificacion, sin dar por bueno como se hizo.

    Cabecera de 30 bytes; si el PC de la v1 es 0 hay cabecera ampliada, cuya
    longitud viene en la palabra de los offsets 30-31 y que ocupa a partir del
    32.  Detras van los bancos, cada uno precedido de su longitud (0xFFFF si
    va sin comprimir) y su numero de pagina.
    """
    d = open(ruta, 'rb').read()
    if d[6] or d[7]:
        return {'amp': 0, 'modo': -1, 'pc': d[6] | (d[7] << 8), 'puerto': -1,
                'ay': False, 'paginas': {}, 'sobran': len(d)}
    largo = d[30] | (d[31] << 8)
    amp = d[32:32 + largo]
    p, paginas = 32 + largo, {}
    while p + 3 <= len(d):
        ln, pag = d[p] | (d[p + 1] << 8), d[p + 2]
        p += 3
        if ln != 0xFFFF:                    # comprimido: aqui no se usa
            break
        paginas[pag] = d[p:p + 16384]
        p += 16384
    return {'amp': largo, 'pc': amp[0] | (amp[1] << 8), 'modo': amp[2],
            'puerto': amp[3], 'ay': bool(amp[5] & 4), 'paginas': paginas,
            'sobran': len(d) - p}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--png', help='directorio donde guardar capturas')
    ap.add_argument('--bin', default=os.path.join(RAIZ, 'build', 'balava.bin'))
    ap.add_argument('--scr', default=os.path.join(RAIZ, 'dist', 'balava.scr'))
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
    m = Spectrum(args.bin, args.scr)
    val = lambda n: m.peek(sim[n])

    COL_P1, COL_P2, ANCHO, ALTO = 1, 28, 3, 32
    BARRIL1_COL, BARRIL2_COL, BARRIL_ALTO = 5, 25, 32
    CACTUS = [(8, 100), (21, 60)]
    NUM_BALAS, MUNICION = 4, 8
    CRE_COL, CRE_ANCHO, CRE_Y, CRE_ALTO = 4, 24, 112, 56
    ATTR_JUEGO = 0x30

    def pixeles(col, y, filas, ancho):
        return sum(bin(m.memory[dir_pantalla(y + f, col + c)]).count('1')
                   for f in range(filas) for c in range(ancho))

    def bala(pool, n, campo):
        return m.peek(sim[pool] + n * 3 + campo)

    def calle_libre():
        """Una altura desde la que el tiro no se topa con nada fijo."""
        ocupado = [(val('barril1_y'), 32), (val('barril2_y'), 32),
                   (100, 32), (60, 32), (132, 58)]
        for y in range(20, 158, 2):
            carril = y + 13
            if all(not (o - 1 <= carril <= o + alto) for o, alto in ocupado):
                return y
        return None

    poli = m.sprite(sim, 'spr_poli', ALTO, ANCHO)
    ladron = m.sprite(sim, 'spr_ladron', ALTO, ANCHO)
    muerto = m.sprite(sim, 'spr_muerto', 16, ANCHO)
    barril = m.sprite(sim, 'spr_barril', 32, 2)

    # ---------------------------------------------------------------
    print('\n1. Pantalla de carga')
    m.frames(60)                                # y las copias desplazadas
    captura(m, '0-carga.png')
    scr = open(os.path.join(RAIZ, 'dist', 'balava.scr'), 'rb').read()
    P.check(bytes(m.memory[0x4000:0x5B00]) == scr,
            'la pantalla de carga es la generada')
    invisibles = [(f, c) for f in range(24) for c in range(32)
                  if scr[6144 + f * 32 + c] & 7 == (scr[6144 + f * 32 + c] >> 3) & 7
                  and any(scr[dir_pantalla(f * 8 + k, c) - 0x4000] for k in range(8))]
    P.check(not invisibles, 'sin celdas invisibles', str(invisibles[:4]))
    snap = lee_z80(os.path.join(RAIZ, 'dist', 'balava.z80'))
    P.check(snap['amp'] == 23 and snap['modo'] == 3,
            'el snapshot es de 128K (cabecera de version 2, modo 3)')
    P.check(snap['pc'] == 0x8000 and snap['puerto'] == 0x10,
            'arranca en 0x8000 con la ROM de 48K paginada (0x7FFD = 0x10)')
    P.check(snap['ay'] and snap['sobran'] == 0,
            'con la marca de sonido por el AY y sin bytes de sobra',
            f'sobran {snap["sobran"]}')
    P.check(sorted(snap['paginas']) == list(range(3, 11)), 'y los ocho bancos de RAM',
            str(sorted(snap['paginas'])))
    P.check(snap['paginas'][8][:6912] == scr, 'la pantalla de carga, en el banco 5')
    binario = open(args.bin, 'rb').read()
    P.check(snap['paginas'][5][:len(binario)] == binario, 'y el codigo, en el banco 2')
    m.frames(10, ['SPACE'])

    # ---------------------------------------------------------------
    print('\n2. Menu')
    m.frames(15)
    captura(m, '1-menu.png')
    P.check(all(m.memory[dir_pantalla(y, c)] == 0xFF for y in (2, 3, 188, 189)
                for c in range(32)), 'marco de la pantalla')
    huecos = sum(bin(m.memory[dir_pantalla(y, c)] ^ 0xFF).count('1')
                 for y in range(33, 47) for c in range(10, 22))
    esperados = 0
    for i in range(6):
        glifo = m.peek(sim['logo_letras'] + i * 2) | (m.peek(sim['logo_letras'] + i * 2 + 1) << 8)
        esperados += sum(bin(m.peek(glifo + n)).count('1') for n in range(28))
    P.check(huecos == esperados, 'el logotipo BALAVA, en hueco', f'{huecos} de {esperados}')
    filas = {y // 8 for y in range(88, 184)
             if any(m.memory[dir_pantalla(y, c)] for c in range(4, 28))}
    P.check(filas == {11, 13, 15, 17, 19, 21}, 'las cuatro opciones y los dos rotulos',
            str(sorted(filas)))

    # ---------------------------------------------------------------
    print('\n3. La musica del AY')
    P.check(m.ay[7] & 0x38 == 0x38 and m.ay[7] & 7 == 0,
            'mezclador: tono en los tres canales y sin ruido', bin(m.ay[7]))
    periodos = set()
    volumenes = set()
    for _ in range(60):
        m.frames(4)
        periodos.add(tuple(m.periodo_canal(c) for c in range(3)))
        volumenes.add(tuple(m.ay[8:11]))
    P.check(len(periodos) > 8, 'los tres canales van cambiando de nota',
            f'{len(periodos)} combinaciones')
    P.check(all(len({p[i] for p in periodos}) >= 2 for i in range(3)),
            'melodia, bajo y acordes se mueven cada uno por su lado',
            str([len({p[i] for p in periodos}) for i in range(3)]))
    P.check(len(volumenes) > 5, 'el volumen decae en cada nota')
    # las notas tienen que estar en la tabla de la cancion
    notas = set()
    p = sim['menu_a']
    while True:
        per = m.peek(p) | (m.peek(p + 1) << 8)
        if per == 0xFFFF:
            break
        notas.add(per)
        p += 3
    tocadas = {t[0] for t in periodos if t[0]}
    P.check(tocadas <= notas | {0}, 'y son las de la partitura',
            f'{len(tocadas & notas)} de {len(tocadas)}')
    # las tres voces se reproducen por separado: si no duran lo mismo, a la
    # segunda vuelta el bajo y el arpegio suenan contra la melodia
    largo = 0
    p = sim['menu_a']
    while (m.peek(p) | (m.peek(p + 1) << 8)) != 0xFFFF:
        largo += m.peek(p + 2)
        p += 3
    antes = tuple(m.ay[0:11])
    m.frames(largo // 2)
    P.check(tuple(m.ay[0:11]) != antes, 'la cancion va cambiando por dentro')
    m.frames(largo - largo // 2)
    P.check(tuple(m.ay[0:11]) == antes,
            'y las tres vuelven a empezar a la vez, sin desfasarse',
            f'{largo} fotogramas')
    P.check(m.ay[8] >= m.ay[9] and m.ay[8] >= m.ay[10],
            'con la melodia por encima del acompanamiento',
            f'volumenes {m.ay[8]}, {m.ay[9]} y {m.ay[10]}')

    # ---------------------------------------------------------------
    print('\n4. Opcion 3: pantalla de controles')
    m.frames(10, ['3'])
    m.frames(5)
    captura(m, '2-controles.png')
    filas = {y // 8 for y in range(8, 184)
             if any(m.memory[dir_pantalla(y, c)] for c in range(4, 28))}
    P.check(filas == {3, 7, 8, 9, 12, 13, 14, 17, 20}, 'textos de la ayuda',
            str(sorted(filas)))
    m.frames(10, ['SPACE'])
    m.frames(5)

    # ---------------------------------------------------------------
    print('\n5. Opcion 4: los creditos')
    m.frames(10, ['4'])
    m.frames(30)
    captura(m, '2b-creditos.png')
    foto = open(os.path.join(RAIZ, 'build', 'foto.bin'), 'rb').read()
    arriba = all(m.memory[dir_pantalla(y, c)] == foto[dir_pantalla(y, c) - 0x4000]
                 for y in range(CRE_Y) for c in range(32))
    P.check(arriba, 'la foto del autor, tramada a un bit')
    P.check(all(m.memory[0x5800 + i] == 0x38 for i in range(768)),
            'en blanco y negro, sin colour clash posible')
    ventana = lambda: bytes(m.memory[dir_pantalla(y, c)]
                            for y in range(CRE_Y, CRE_Y + CRE_ALTO)
                            for c in range(CRE_COL, CRE_COL + CRE_ANCHO))
    v0 = ventana()
    sin_tramar = bytes(foto[dir_pantalla(y, c) - 0x4000]
                       for y in range(CRE_Y, CRE_Y + CRE_ALTO)
                       for c in range(CRE_COL, CRE_COL + CRE_ANCHO))
    P.check(v0 != sin_tramar, 'con la franja del texto oscurecida sobre la foto')
    m.frames(25)
    v1 = ventana()
    distintos = sum(a != b for a, b in zip(v0, v1))
    P.check(distintos > 100, 'y el texto subiendo',          # el fondo no se mueve:
            f'{distintos} bytes de {len(v0)} cambian en medio segundo')  # solo las letras
    letras = sum(bin(a & ~b & 0xFF).count('1') for a, b in zip(sin_tramar, v1))
    P.check(letras > 200, 'con letras en blanco recortadas encima',
            f'{letras} pixeles en hueco')
    periodos = [set(), set(), set()]
    for _ in range(400):
        m.frames(1)
        for c in range(3):
            if m.periodo_canal(c):
                periodos[c].add(m.periodo_canal(c))
    P.check(m.ay[7] & 0b111000 == 0b111000 and not m.ay[7] & 7,
            'tono en los tres canales', bin(m.ay[7]))
    P.check(all(len(p) >= 3 for p in periodos), 'melodia, bajo y arpegio',
            str([len(p) for p in periodos]))
    P.check(min(min(p) for p in periodos[1:2]) > 800,
            'con el bajo donde le toca', f'{sorted(periodos[1])[:3]}')
    m.frames(10, ['SPACE'])
    m.frames(20)
    P.check(m.peek(0x5800) == ATTR_JUEGO, 'y una tecla devuelve al menu')
    P.check(val('musica') == 1, 'con Oh! Susanna sonando otra vez')

    # ---------------------------------------------------------------
    print('\n6. Opcion 2: partida a dos')
    m.frames(10, ['2'])
    m.frames(10)
    captura(m, '3-partida.png')
    P.check(val('modo_ia') == 0, 'a dos jugadores, sin maquina')
    P.check((val('p1_y'), val('p2_y')) == (40, 120), 'pistoleros en su sitio')
    P.check((val('balas1'), val('balas2')) == (MUNICION, MUNICION),
            'ocho balas cada uno')
    P.check(pixeles(0, 8, 8, 8) == 8 * sum(bin(b).count('1')
            for b in m.sprite(sim, 'spr_balita', 8, 1)),
            'y las ocho dibujadas en el marcador')
    sep = abs(val('barril2_y') - val('barril1_y'))
    P.check(sep >= 32, 'los barriles nunca en la misma linea de tiro',
            f'{val("barril1_y")} y {val("barril2_y")}, separados {sep}')
    P.check(m.bloque(BARRIL1_COL, val('barril1_y'), 32, 2) == barril,
            'barril del sheriff dibujado')
    P.check(m.bloque(BARRIL2_COL, val('barril2_y'), 32, 2) == barril,
            'barril del bandido dibujado')
    P.check(val('musica') == 0 and m.ay[8] == 0 and m.ay[9] == 0,
            'y se juega sin musica de fondo')
    notas = set()
    for _ in range(100):
        m.frames(1)
        notas.add(tuple(m.periodo_canal(c) for c in range(2)))
    P.check(len(notas) == 1, 'la cancion no avanza mientras se juega',
            f'{len(notas)} combinacion(es) en dos segundos')


    # ---------------------------------------------------------------
    print('\n7. La carreta sube por el centro')
    y0 = val('carreta_y')
    m.frames(40)
    P.check(val('carreta_y') == y0 - 10, 'un pixel cada cuatro fotogramas',
            f'{y0} -> {val("carreta_y")}')
    n = 0                                   # a que el caracol deje libre la
    while val('caracol_x') // 8 <= 16 and n < 400:    # calle de la carreta
        m.frames(1)
        n += 1
    tramo = range(val('carreta_y') + 28, min(192, val('carreta_y') + 44))
    P.check(len(tramo) > 8 and not any(m.memory[dir_pantalla(y, c)]
                                       for y in tramo for c in range(14, 17)),
            'y no deja rastro por debajo', f'{len(tramo)} filas limpias')

    # ---------------------------------------------------------------
    print('\n8. Varias balas en el aire')
    calle = calle_libre()
    P.check(calle is not None, 'hay alguna calle despejada', str(calle))
    while val('p1_y') > calle:
        m.frames(1, ['Q'])
    while val('p1_y') < calle:
        m.frames(1, ['A'])
    antes = val('balas1')
    m.frames(2, ['Z'])
    P.check(not m.ay[7] & 0b100000 and m.ay[10] > 0,
            'sin musica, pero el disparo si se oye',
            f'mezclador {bin(m.ay[7])}, volumen C {m.ay[10]}')
    m.frames(8)
    for _ in range(2):
        m.frames(2, ['Z'])
        m.frames(8)
    vivas = [n for n in range(NUM_BALAS) if bala('b1', n, 2)]
    P.check(len(vivas) >= 2, 'se puede disparar sin esperar a la anterior',
            f'{len(vivas)} balas en el aire')
    P.check(val('balas1') == antes - 3, 'y cada tiro gasta una bala',
            f'{antes} -> {val("balas1")}')
    xs = sorted(bala('b1', n, 0) for n in vivas)
    P.check(len(set(xs)) == len(xs), 'cada una va por su sitio', str(xs))
    captura(m, '4-balas.png')

    # ---------------------------------------------------------------
    print('\n9. Municion: se acaba')
    for _ in range(12):
        m.frames(2, ['Z'])
        m.frames(6)
    P.check(val('balas1') == 0, 'se queda sin balas', str(val('balas1')))
    P.check(pixeles(0, 8, 8, 8) == 0, 'y el marcador se queda vacio')
    m.frames(60)
    m.frames(2, ['Z'])
    m.frames(10)
    P.check(all(not bala('b1', n, 2) for n in range(NUM_BALAS)),
            'sin balas no sale ningun tiro')

    # ---------------------------------------------------------------
    print('\n10. Los barriles y los cactus se van picando')
    while val('carreta_y') > 40 and val('carreta_y') != 0:
        m.frames(1)                              # que la carreta no estorbe
    antes_barril = pixeles(BARRIL2_COL, val('barril2_y'), 32, 2)
    while val('p2_y') > val('barril2_y') + 6:
        m.frames(1, ['P'])
    while val('p2_y') < val('barril2_y') + 6:
        m.frames(1, ['L'])
    for _ in range(4):
        m.frames(2, ['B'])
        m.frames(30)
    quitados = antes_barril - pixeles(BARRIL2_COL, val('barril2_y'), 32, 2)
    P.check(0 < quitados <= 70, 'cada bala se lleva unos pocos pixeles del barril',
            f'{quitados} en 4 tiros')
    captura(m, '5-barril.png')

    # ---------------------------------------------------------------
    print('\n11. Muerte, cine y funeral')
    m.frames(10, ['1'])                          # en partida, la tecla no hace nada
    m.frames(30)
    P.check(val('modo_ia') == 0, 'seguimos en la partida en curso')
    puntos = (val('puntos1'), val('puntos2'))
    calle = calle_libre()
    while val('p2_y') > calle:
        m.frames(1, ['P'])
    while val('p2_y') < calle:
        m.frames(1, ['L'])
    while val('p1_y') > calle:
        m.frames(1, ['Q'])
    while val('p1_y') < calle:
        m.frames(1, ['A'])
    m.frames(2, ['B'])
    n = 0
    while (val('puntos1'), val('puntos2')) == puntos and n < 400:
        m.frames(1)
        n += 1
    P.check(val('puntos2') == puntos[1] + 1, 'el bandido acierta al sheriff')
    m.frames(10)
    captura(m, '6-caido.png')
    n = 0
    while m.peek(0x5800) == 0x30 and n < 200:    # espera a las barras de cine
        m.frames(1)
        n += 1
    P.check(m.peek(0x5800) == 0 and m.peek(0x5800 + 12 * 32) == 0x30,
            'la cinematica pone las bandas negras de cine')
    P.check(val('musica') == 1, 'con la marcha funebre ya sonando')
    m.frames(60)
    captura(m, '7-cine.png')
    n = 0
    while val('esc_x') == 0 and n < 400:
        m.frames(1)
        n += 1
    m.frames(60)
    captura(m, '8-funeral.png')
    n = 0
    while (val('p1_y') != 40 or val('p2_y') != 120) and n < 900:
        m.frames(1)
        n += 1
    P.check(n < 900, 'y la partida se recompone', f'{n} fotogramas')
    P.check(m.bloque(COL_P1, 40, ALTO, ANCHO) == poli, 'con los dos en su sitio')
    P.check(m.bloque(BARRIL1_COL, val('barril1_y'), 32, 2) == barril,
            'y el barril entero otra vez')
    P.check(val('musica') == 0, 'y se vuelve a jugar en silencio')
    captura(m, '9-vuelta.png')

    # ---------------------------------------------------------------
    print('\n12. La maquina juega sola')
    m = Spectrum(args.bin, args.scr)             # maquina nueva, para volver al menu
    m.frames(60)
    m.frames(10, ['SPACE'])
    m.frames(15)
    m.frames(10, ['1'])                          # opcion 1: contra la maquina
    m.frames(30)
    P.check(val('modo_ia') == 1, 'la maquina lleva al bandido')
    y0, balas0 = val('p2_y'), val('balas2')
    alturas = set()
    for _ in range(30):
        m.frames(20)
        alturas.add(val('p2_y'))
    P.check(len(alturas) > 3, 'se mueve sola buscando el tiro',
            f'{len(alturas)} alturas')
    P.check(val('balas2') < balas0, 'y dispara', f'{balas0} -> {val("balas2")}')
    captura(m, '10-maquina.png')

    print()
    if P.fallos:
        print(f'{P.fallos} comprobacion(es) fallidas')
        return 1
    print('todas las comprobaciones correctas')
    return 0


if __name__ == '__main__':
    sys.exit(main())
