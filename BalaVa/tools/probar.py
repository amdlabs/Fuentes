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
    CAJA1_COL, CAJA2_COL, CAJA_Y, CAJA_ALTO = 5, 25, 80, 32
    CALLE = 40                                  # la altura desde la que hay tiro limpio
    ESCENARIO = [('spr_carreta', 14, 20, 28, 3),        # nombre, col, y, filas, ancho
                 ('spr_cactus', 8, 100, 32, 2),
                 ('spr_cactus', 21, 60, 32, 2)]
    COLS_OCUPADAS = set(range(COL_P1, COL_P1 + ANCHO)) | set(range(COL_P2, COL_P2 + ANCHO))
    COLS_OCUPADAS |= {CAJA1_COL, CAJA1_COL + 1, CAJA2_COL, CAJA2_COL + 1}
    for _, col, _, _, ancho in ESCENARIO:
        COLS_OCUPADAS |= set(range(col, col + ancho))
    COLS_LIBRES = [c for c in range(32) if c not in COLS_OCUPADAS]

    def pixeles(col, y, filas, ancho):
        return sum(bin(m.memory[dir_pantalla(y + f, col + c)]).count('1')
                   for f in range(filas) for c in range(ancho))

    poli = m.sprite(sim, 'spr_poli', ALTO, ANCHO)
    ladron = m.sprite(sim, 'spr_ladron', ALTO, ANCHO)
    muerto = m.sprite(sim, 'spr_muerto', 16, ANCHO)
    caja = m.sprite(sim, 'spr_caja', 8, 2)

    # ---------------------------------------------------------------
    print('\n1. Pantalla de carga')
    m.frames(50)                                # deja tiempo a las copias desplazadas
    captura(m, '0-carga.png')
    scr = open(os.path.join(RAIZ, 'dist', 'balava.scr'), 'rb').read()
    P.check(bytes(m.memory[0x4000:0x5B00]) == scr,
            'la pantalla de carga del snapshot es la generada')
    invisibles = [(f, c) for f in range(24) for c in range(32)
                  if scr[6144 + f * 32 + c] & 7 == (scr[6144 + f * 32 + c] >> 3) & 7
                  and any(scr[dir_pantalla(f * 8 + k, c) - 0x4000] for k in range(8))]
    P.check(not invisibles, 'ninguna celda dibujada tiene tinta y papel iguales',
            str(invisibles[:4]))
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
    P.check(huecos == esperados, 'el logotipo BALAVA aparece en hueco sobre la banda',
            f'{huecos} de {esperados} pixeles')
    P.check(all(m.peek(0x5800 + 19 * 32 + c) == 0xB0 for c in range(10, 21)),
            'el aviso PULSA 1 O 2 usa el bit FLASH')

    # ---------------------------------------------------------------
    print('\n3. La musica del menu')
    esperadas = []
    p = sim['musica']
    while len(esperadas) < 10:
        per, _, ticks = (m.peek(p), m.peek(p + 1), m.peek(p + 2))
        if per == 0xFF:
            break
        f = round(3_500_000 / (32 * per + 60)) if per else 0
        if esperadas and esperadas[-1][0] == f:
            esperadas[-1][1] += ticks
        else:
            esperadas.append([f, ticks])
        p += 3
    sonadas = []
    for _ in range(120):
        f = m.frecuencia(20)
        if sonadas and abs(sonadas[-1][0] - f) < 40:
            sonadas[-1][1] += 1
        else:
            sonadas.append([f, 1])
    P.check(len(sonadas) >= 6, 'la melodia va cambiando de nota',
            ' '.join(f'{f}Hz' for f, _ in sonadas[:8]))
    def encaje(salto):
        return sum(1 for (fe, _), (fs, _) in zip(esperadas[salto:], sonadas)
                   if fe and abs(fs - fe) <= max(40, fe * 0.06))
    P.check(max(encaje(k) for k in range(5)) >= 5,
            'las notas coinciden con la melodia guardada')

    # ---------------------------------------------------------------
    print('\n4. Opcion 2: pantalla de controles')
    m.frames(10, ['2'])
    m.frames(5)
    captura(m, '2-controles.png')
    filas = {y // 8 for y in range(8, 184)
             if any(m.memory[dir_pantalla(y, c)] for c in range(4, 28))}
    P.check(filas == {3, 7, 8, 9, 12, 13, 14, 17, 20}, 'textos de la ayuda',
            str(sorted(filas)))
    m.frames(10, ['SPACE'])
    m.frames(5)

    # ---------------------------------------------------------------
    print('\n5. Opcion 1: empieza la partida')
    m.frames(10, ['1'])
    m.frames(10)
    captura(m, '3-partida.png')
    P.check((val('p1_y'), val('p2_y')) == (40, 120), 'pistoleros en su sitio',
            f"{val('p1_y')},{val('p2_y')}")
    P.check(m.bloque(COL_P1, 40, ALTO, ANCHO) == poli, 'sheriff a la izquierda')
    P.check(m.bloque(COL_P2, 120, ALTO, ANCHO) == ladron, 'bandido a la derecha')
    for nombre, col, y, filas_, ancho in ESCENARIO:
        P.check(m.bloque(col, y, filas_, ancho) == m.sprite(sim, nombre, filas_, ancho),
                f'decorado: {nombre[4:]} en la columna {col}')
    P.check(all(m.bloque(c, CAJA_Y + t * 8, 8, 2) == caja
                for c in (CAJA1_COL, CAJA2_COL) for t in range(4)),
            'las dos cajas, enteras')

    # ---------------------------------------------------------------
    print('\n6. Movimiento suave')
    antes = val('p1_y')
    m.frames(10, ['Q'])
    P.check(val('p1_y') == antes - 10, 'Q sube un pixel por fotograma',
            f"{antes} -> {val('p1_y')}")
    m.frames(10, ['A'])
    P.check(val('p1_y') == antes, 'A baja un pixel por fotograma')
    m.frames(200, ['Q'])
    P.check(val('p1_y') == 16, 'tope superior', str(val('p1_y')))
    m.frames(200, ['A'])
    P.check(val('p1_y') == 160, 'tope inferior', str(val('p1_y')))
    P.check(m.bloque(COL_P1, 160, ALTO, ANCHO) == poli and
            not any(m.bloque(COL_P1, 16, 144, ANCHO)),
            'al moverse no deja rastro en su columna')

    # ---------------------------------------------------------------
    print('\n7. El caracol pasea')
    x0, y0 = val('caracol_x'), val('caracol_y')
    posiciones = set()
    alturas = set()
    for _ in range(40):
        m.frames(15)
        posiciones.add(val('caracol_x'))
        alturas.add(val('caracol_y'))
    P.check(len(posiciones) > 20, 'se mueve a lo ancho', f'{len(posiciones)} posiciones')
    P.check(len(alturas) > 3, 'y tambien cambia de altura', f'{len(alturas)} alturas')
    P.check(132 <= val('caracol_y') <= 164, 'sin salirse de su banda', str(val('caracol_y')))
    caracol = [m.peek(sim['spr_caracol_d'] + i) for i in range(6 * 26)]
    esperado = sum(bin(b).count('1') for b in caracol)
    real = pixeles(val('caracol_x') >> 3, val('caracol_y'), 26, 6)
    P.check(real == esperado, 'se dibuja entero en cualquier pixel',
            f'{real} de {esperado}')

    # ---------------------------------------------------------------
    print('\n8. Las balas van picando lo que tocan')
    while val('p1_y') > CAJA_Y:
        m.frames(1, ['Q'])
    while val('p1_y') < CAJA_Y:
        m.frames(1, ['A'])
    antes_caja = pixeles(CAJA1_COL, CAJA_Y, CAJA_ALTO, 2)
    alcances = []
    for _ in range(4):
        m.frames(2, ['Z'])
        m.frames(35)
        alcances.append(val('b1_x'))
    despues_caja = pixeles(CAJA1_COL, CAJA_Y, CAJA_ALTO, 2)
    captura(m, '4-caja.png')
    quitados = antes_caja - despues_caja
    P.check(0 < quitados <= 60, 'cada bala se lleva solo unos pixeles de la caja',
            f'{quitados} pixeles en 4 tiros')
    P.check(alcances[-1] > alcances[0], 'la bala llega mas lejos segun se abre el hueco',
            str(alcances))
    P.check(val('puntos1') == 0, 'picar la caja no puntua')
    for nombre, col, y, filas_, ancho in ESCENARIO:
        if col == 8:
            continue                            # el cactus de abajo aun no se toca
        P.check(m.bloque(col, y, filas_, ancho) == m.sprite(sim, nombre, filas_, ancho),
                f'el resto del decorado sigue intacto: columna {col}')

    # ---------------------------------------------------------------
    print('\n9. El cactus tambien se perfora')
    while val('p1_y') < 100:
        m.frames(1, ['A'])
    antes_cactus = pixeles(8, 100, 32, 2)
    for _ in range(3):
        m.frames(2, ['Z'])
        m.frames(40)
    despues_cactus = pixeles(8, 100, 32, 2)
    P.check(0 < antes_cactus - despues_cactus <= 60,
            'el cactus se va rompiendo poco a poco',
            f'{antes_cactus - despues_cactus} pixeles en 3 tiros')

    # ---------------------------------------------------------------
    print('\n10. Impacto, caido y funeral')
    dano_caja = pixeles(CAJA1_COL, CAJA_Y, CAJA_ALTO, 2)
    while val('p1_y') > CALLE:
        m.frames(1, ['Q'])
    while val('p2_y') > CALLE:
        m.frames(1, ['P'])
    P.check(val('p1_y') == val('p2_y') == CALLE, 'los dos en la calle libre de arriba')
    m.frames(2, ['Z'])
    while val('puntos1') == 0:
        m.frames(1)
    P.check(True, 'el disparo alcanza al bandido')
    m.frames(20)
    captura(m, '5-caido.png')
    P.check(m.bloque(COL_P2, CALLE + ALTO - 16, 16, ANCHO) == muerto,
            'el bandido se queda tumbado donde le dieron')
    n = 0
    while val('esc_x') == 0:
        m.frames(1)
        n += 1
    P.check(40 <= n <= 90, 'el caido se ve un momento antes del funeral',
            f'{n / 50:.1f} s')
    m.frames(40)
    captura(m, '6-funeral.png')
    filas = {y // 8 for y in range(16, 60)
             if any(m.memory[dir_pantalla(y, c)] for c in range(32))}
    P.check(5 in filas, 'el funeral saca su rotulo', str(sorted(filas)))
    inicio = n
    while val('esc_x') < 216:
        m.frames(1)
        n += 1
    P.check(4.0 <= (n - inicio) / 50 <= 6.5, 'la escena dura unos cinco segundos',
            f'{(n - inicio) / 50:.1f} s')
    captura(m, '7-carreta.png')
    while val('p1_y') != 40 or val('p2_y') != 120:
        m.frames(1)
    m.frames(5)
    P.check(m.bloque(COL_P1, 40, ALTO, ANCHO) == poli and
            m.bloque(COL_P2, 120, ALTO, ANCHO) == ladron,
            'tras el funeral los dos vuelven a su sitio')
    P.check(pixeles(CAJA1_COL, CAJA_Y, CAJA_ALTO, 2) == dano_caja,
            'la caja conserva los agujeros de antes del funeral')
    P.check(m.bloque(21, 60, 32, 2) == m.sprite(sim, 'spr_cactus', 32, 2),
            'y el decorado vuelve tal cual estaba')

    # ---------------------------------------------------------------
    print('\n11. Balas que se cruzan')
    while val('p1_y') > CALLE:
        m.frames(1, ['Q'])
    while val('p2_y') > CALLE:
        m.frames(1, ['P'])
    antes = (val('puntos1'), val('puntos2'))
    m.frames(2, ['Z', 'B'])
    m.frames(30)
    captura(m, '8-cruce.png')
    P.check(val('b1_act') == 0 and val('b2_act') == 0,
            'dos balas de frente se anulan')
    P.check((val('puntos1'), val('puntos2')) == antes, 'y no puntuan')
    sucio = sum(1 for y in list(range(16, 40)) + list(range(48, 60))
                for c in COLS_LIBRES if m.memory[dir_pantalla(y, c)])
    P.check(sucio == 0, 'sin rastro de las balas', f'{sucio} bytes')

    # ---------------------------------------------------------------
    print('\n12. Fin de partida')
    for _ in range(14):
        if val('puntos1') >= 5:
            break
        while val('p1_y') > CALLE:
            m.frames(1, ['Q'])
        while val('p1_y') < CALLE:
            m.frames(1, ['A'])
        while val('p2_y') > CALLE:
            m.frames(1, ['P'])
        while val('p2_y') < CALLE:
            m.frames(1, ['L'])
        m.frames(2, ['Z'])
        m.frames(500)
    P.check(val('puntos1') == 5, 'la partida llega a 5 impactos', str(val('puntos1')))
    m.frames(30)
    captura(m, '9-ganador.png')
    filas = {y // 8 for y in range(192)
             if any(m.memory[dir_pantalla(y, c)] for c in range(32))}
    P.check(filas == {9, 12, 16}, 'pantalla de ganador', str(sorted(filas)))
    m.frames(10, ['SPACE'])
    m.frames(10)
    P.check(all(m.memory[dir_pantalla(24, c)] == 0xFF for c in range(1, 10)),
            'al acabar se vuelve al menu')

    print()
    if P.fallos:
        print(f'{P.fallos} comprobacion(es) fallidas')
        return 1
    print('todas las comprobaciones correctas')
    return 0


if __name__ == '__main__':
    sys.exit(main())
