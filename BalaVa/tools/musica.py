#!/usr/bin/env python3
"""Rehace el acompanamiento de las canciones a partir de su melodia.

Las tres voces de una cancion se reproducen cada una por su lado y vuelven a
empezar al llegar al final, asi que si no duran exactamente lo mismo se van
desfasando y, a la segunda vuelta, el bajo y los acordes suenan contra la
melodia. Aqui se generan el bajo y el arpegio nota a nota desde la melodia, de
modo que la duracion cuadra por construccion.

    python3 tools/musica.py [--comprobar]
"""

import argparse
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FUENTE = os.path.join(RAIZ, 'src', 'balava.asm')
RELOJ = 1773400 / 16.0
CROMA = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']


def periodo(nota):
    """Periodo del AY de una nota tipo 'D#4'; 0 es el silencio."""
    if nota is None or nota == 'silencio':
        return 0
    grado = CROMA.index(nota[:-1])
    octava = int(nota[-1])
    f = 440.0 * 2 ** ((octava * 12 + grado - (4 * 12 + 9)) / 12.0)
    return round(RELOJ / f)


def clase(per):
    """Nombre de la clase de altura de un periodo (para mirar la melodia)."""
    import math
    n = round(12 * math.log2((RELOJ / per) / 440.0)) + 57
    return CROMA[n % 12]


# Cada cancion: en que tono esta, que acorde le toca a cada nota de la melodia,
# y con que notas se tocan el bajo y el arpegio.
CANCIONES = {
    'menu': {                                   # Oh! Susanna, en do mayor
        'acordes': {'C': 'C', 'D': 'G', 'E': 'C', 'F': 'F', 'G': 'C',
                    'A': 'F', 'B': 'G'},
        'bajo': {'C': 'C3', 'F': 'F2', 'G': 'G2'},
        'arpegio': {'C': ['C4', 'E4', 'G4', 'E4'],
                    'F': ['C4', 'F4', 'A4', 'F4'],
                    'G': ['D4', 'G4', 'B4', 'G4']},
        'paso': 12, 'pulso': 25,
    },
    'cre': {                                    # creditos: original, lenta y lugubre
        'melodia': [
            ('D4', 75), ('A4', 75), ('F4', 50), ('E4', 25), ('D4', 100), (None, 25),
            ('D4', 75), ('A#4', 75), ('A4', 50), ('G4', 25), ('F4', 100), (None, 25),
            ('A4', 75), ('D5', 75), ('C5', 50), ('A#4', 25), ('A4', 100), (None, 25),
            ('F4', 50), ('G4', 50), ('A4', 75), ('F4', 25), ('E4', 50),
            ('D4', 150), (None, 50),
        ],
        'plan': [                               # la armonia, en re menor
            ('Dm', 200), ('A', 25), ('Dm', 125),
            ('Dm', 75), ('Bb', 75), ('Dm', 50), ('Gm', 25), ('F', 125),
            ('Dm', 150), ('F', 50), ('Bb', 25), ('A', 125),
            ('Dm', 50), ('Gm', 50), ('A', 75), ('Dm', 25), ('A', 50), ('Dm', 200),
        ],
        'bajo': {'Dm': 'D2', 'Gm': 'G2', 'A': 'A2', 'Bb': 'A#2', 'F': 'F2'},
        'arpegio': {'Dm': ['D3', 'F3', 'A3', 'F3'],
                    'Gm': ['G3', 'A#3', 'D4', 'A#3'],
                    'A': ['E3', 'A3', 'C#4', 'A3'],
                    'Bb': ['D3', 'F3', 'A#3', 'F3'],
                    'F': ['F3', 'A3', 'C4', 'A3']},
        'paso': 50, 'pulso': 100,
    },
    'fune': {                                   # marcha funebre, en do menor
        'acordes': {'C': 'Cm', 'D': 'G', 'D#': 'Cm', 'F': 'Fm', 'G': 'Cm',
                    'G#': 'Ab', 'A#': 'Eb', 'B': 'G', 'E': 'Cm', 'A': 'Fm'},
        'bajo': {'Cm': 'C2', 'Fm': 'F2', 'G': 'G2', 'Ab': 'G#2', 'Eb': 'D#2'},
        'arpegio': {'Cm': ['C3', 'D#3', 'G3', 'D#3'],
                    'Fm': ['C3', 'F3', 'G#3', 'F3'],
                    'G': ['D3', 'G3', 'B3', 'G3'],
                    'Ab': ['C3', 'D#3', 'G#3', 'D#3'],
                    'Eb': ['D#3', 'G3', 'A#3', 'G3']},
        'paso': 25, 'pulso': 50,
    },
}


def lee_canal(texto, etiqueta):
    ini = texto.index('\n' + etiqueta + ':')
    fin = texto.index('DEFW    0xFFFF', ini)
    cuerpo = texto[ini:fin]
    per = [int(m.group(1)) for m in re.finditer(r'DEFW\s+(\d+)\s*\n', cuerpo)]
    dur = [int(m.group(1)) for m in re.finditer(r'DEFB\s+(\d+)', cuerpo)]
    if len(per) != len(dur):
        sys.exit(f'{etiqueta}: {len(per)} periodos y {len(dur)} duraciones')
    return list(zip(per, dur))


def tramos(melodia, mapa):
    """Acorde de cada trozo de melodia, juntando los que se repiten."""
    salida, ultimo = [], None
    for per, dur in melodia:
        ac = ultimo if per == 0 else mapa[clase(per)]
        if ac is None:                          # silencio de arranque
            ac = next(mapa[clase(p)] for p, _ in melodia if p)
        if salida and salida[-1][0] == ac:
            salida[-1][1] += dur
        else:
            salida.append([ac, dur])
        ultimo = ac
    return salida


def haz_bajo(tramitos, raices, pulso):
    """La raiz del acorde, repicada cada 'pulso' fotogramas."""
    notas = []
    for acorde, dura in tramitos:
        queda = dura
        while queda:
            d = pulso if queda - pulso >= pulso // 2 else queda
            notas.append((raices[acorde], d))
            queda -= d
    return notas


def haz_arpegio(tramitos, acordes, paso):
    """Las notas del acorde en rueda, llenando el tramo justo."""
    notas, k = [], 0
    for acorde, dura in tramitos:
        tonos, queda, i = acordes[acorde], dura, 0
        while queda:
            d = paso + (k % 2)                  # 12, 13, 12, 13...
            if queda - d < paso:
                d = queda
            notas.append((tonos[i % len(tonos)], d))
            queda -= d
            i += 1
            k += 1
    return notas


def bloque(etiqueta, comentario, notas):
    lineas = [f'{etiqueta}:{" " * max(1, 21 - len(etiqueta))}; {comentario}']
    for nota, dur in notas:
        lineas.append(f'            DEFW    {periodo(nota):5d}')
        lineas.append(f'            DEFB    {dur:2d}                  ; {nota}')
    lineas.append('            DEFW    0xFFFF')
    return '\n'.join(lineas) + '\n'


def sustituye(texto, etiqueta, nuevo):
    ini = texto.index('\n' + etiqueta + ':') + 1
    fin = texto.index('DEFW    0xFFFF', ini) + len('DEFW    0xFFFF\n')
    return texto[:ini] + nuevo + texto[fin:]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--comprobar', action='store_true',
                    help='solo mira que las tres voces duren lo mismo')
    args = ap.parse_args()

    texto = open(FUENTE, encoding='utf-8').read()
    mal = 0
    for nombre, receta in CANCIONES.items():
        if 'melodia' in receta:               # cancion propia: tambien la melodia
            melodia = [(periodo(n) if n else 0, d) for n, d in receta['melodia']]
        else:
            melodia = lee_canal(texto, nombre + '_a')
        total = sum(d for _, d in melodia)
        if 'plan' in receta:
            piezas = [list(p) for p in receta['plan']]
            plan = sum(d for _, d in piezas)
            if plan != total:
                sys.exit(f'{nombre}: la armonia dura {plan} y la melodia {total}')
        else:
            piezas = tramos(melodia, receta['acordes'])
        bajo = haz_bajo(piezas, receta['bajo'], receta['pulso'])
        arpegio = haz_arpegio(piezas, receta['arpegio'], receta['paso'])
        if args.comprobar:
            for canal in 'abc':
                dura = sum(d for _, d in lee_canal(texto, f'{nombre}_{canal}'))
                if dura != total:
                    print(f'{nombre}_{canal}: {dura} fotogramas, '
                          f'la melodia dura {total}')
                    mal += 1
            continue
        if 'melodia' in receta:
            texto = sustituye(texto, nombre + '_a',
                              bloque(nombre + '_a', 'la melodia',
                                     [(n or 'silencio', d)
                                      for n, d in receta['melodia']]))
        texto = sustituye(texto, nombre + '_b',
                          bloque(nombre + '_b', 'el bajo', bajo))
        texto = sustituye(texto, nombre + '_c',
                          bloque(nombre + '_c', 'el arpegio', arpegio))
        print(f'{nombre}: {total} fotogramas, {len(piezas)} acordes, '
              f'{len(bajo)} notas de bajo y {len(arpegio)} de arpegio')
    if args.comprobar:
        if mal:
            sys.exit(f'{mal} voz(ces) descuadrada(s)')
        print('las tres voces de cada cancion duran lo mismo')
        return
    open(FUENTE, 'w', encoding='utf-8').write(texto)


if __name__ == '__main__':
    main()
