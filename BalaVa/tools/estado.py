#!/usr/bin/env python3
"""Prepara la comparacion entre el emulador de referencia y el de JavaScript.

Escribe build/rom.bin (la ROM sintetica que usan los dos) y un guion en JSON
con las teclas que hay que ir pulsando y, en varios puntos, el estado que deja
el emulador de referencia: la firma de la pantalla y algunas variables del
juego.  tools/probar_web.js repite el guion con el nucleo Z80 en JavaScript y
comprueba que sale exactamente lo mismo.
"""

import hashlib
import importlib.util
import json
import os

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def carga_probar():
    ruta = os.path.join(RAIZ, 'tools', 'probar.py')
    spec = importlib.util.spec_from_file_location('probar', ruta)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# guion: (fotogramas, teclas, comprobar)
GUION = [
    (60, [], 'pantalla'),                      # pantalla de carga (y las copias
                                               # desplazadas, que tardan un poco)
    (8, ['SPACE'], None),
    (40, [], 'pantalla'),                      # menu
    (8, ['3'], None),                          # controles
    (30, [], 'pantalla'),
    (8, ['SPACE'], None),
    (30, [], None),
    (8, ['4'], None),                          # creditos: la foto y el scroll
    (40, [], 'pantalla'),
    (60, [], 'pantalla'),                      # el texto ya subiendo
    (8, ['SPACE'], None),
    (30, [], None),
    (8, ['2'], None),                          # partida a dos
    (30, [], 'todo'),
    (40, ['A'], 'todo'),                       # el sheriff baja
    (40, ['P'], 'todo'),                       # el bandido sube
    (2, ['Z'], None),                          # y disparan los dos
    (2, ['B'], None),
    (40, [], 'todo'),
    (60, [], 'todo'),
    (90, [], 'todo'),                          # caracol y carreta andando
]


def main():
    probar = carga_probar()
    os.makedirs(os.path.join(RAIZ, 'build'), exist_ok=True)
    rom = probar.crea_rom()
    with open(os.path.join(RAIZ, 'build', 'rom.bin'), 'wb') as f:
        f.write(rom)

    sim = probar.lee_simbolos(os.path.join(RAIZ, 'build', 'balava.sym'))
    variables = ['p1_y', 'p2_y', 'puntos1', 'puntos2', 'balas1', 'balas2',
                 'caracol_x', 'caracol_y', 'caracol_dir', 'caracol_paso',
                 'carreta_y', 'barril1_y', 'barril2_y', 'modo_ia', 'semilla']

    m = probar.Spectrum(os.path.join(RAIZ, 'build', 'balava.bin'),
                        os.path.join(RAIZ, 'dist', 'balava.scr'))
    pasos = []
    for frames, teclas, comprobar in GUION:
        m.frames(frames, teclas)
        paso = {'frames': frames, 'teclas': teclas}
        if comprobar:
            datos = {'pantalla': hashlib.sha1(bytes(m.memory[0x4000:0x5b00])).hexdigest()}
            if comprobar == 'todo':
                datos['vars'] = {str(sim[v]): m.peek(sim[v]) for v in variables}
            paso['comprobar'] = datos
        pasos.append(paso)

    ruta = os.path.join(RAIZ, 'build', 'guion.json')
    with open(ruta, 'w') as f:
        json.dump({'pasos': pasos}, f, indent=1)
    total = sum(p['frames'] for p in pasos)
    print(f'{ruta}: {len(pasos)} pasos, {total} fotogramas, '
          f'{sum(1 for p in pasos if "comprobar" in p)} puntos de control')


if __name__ == '__main__':
    main()
