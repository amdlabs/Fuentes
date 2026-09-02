#!/usr/bin/env python3
"""Arma la pagina web autocontenida del emulador (dist/balava-web.html).

Mete dentro del HTML el nucleo Z80 (web/z80.js) y, en base64, el juego de
caracteres de la ROM sintetica, la pantalla de carga y el binario del juego.
No queda ninguna descarga externa: el artefacto no puede hacer peticiones.
"""

import base64
import importlib.util
import json
import os

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def carga_rom():
    spec = importlib.util.spec_from_file_location(
        'rom', os.path.join(RAIZ, 'tools', 'rom.py'))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main():
    plantilla = open(os.path.join(RAIZ, 'web', 'balava.html')).read()
    z80 = open(os.path.join(RAIZ, 'web', 'z80.js')).read()
    rom = carga_rom().crea_rom()
    datos = {
        'fuente': base64.b64encode(rom[0x3D00:0x4000]).decode(),
        'pantalla': base64.b64encode(open(os.path.join(RAIZ, 'dist', 'balava.scr'), 'rb').read()).decode(),
        'codigo': base64.b64encode(open(os.path.join(RAIZ, 'build', 'balava.bin'), 'rb').read()).decode(),
    }
    salida = plantilla.replace('/*@z80@*/', z80).replace('/*@datos@*/', json.dumps(datos))
    ruta = os.path.join(RAIZ, 'dist', 'balava-web.html')
    with open(ruta, 'w') as f:
        f.write(salida)
    print(f'{ruta}: {len(salida) / 1024:.0f} KB')


if __name__ == '__main__':
    main()
