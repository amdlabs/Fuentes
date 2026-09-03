#!/usr/bin/env python3
"""Arma la pagina web autocontenida del emulador (dist/balava-web.html).

Mete dentro del HTML el nucleo Z80 (web/z80.js) y, en base64, el juego de
caracteres de la ROM sintetica, la pantalla de carga y el binario del juego.
No queda ninguna descarga externa: el artefacto no puede hacer peticiones.
"""

import base64
import importlib.util
import json
import re
import sys
import os

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def carga_rom():
    spec = importlib.util.spec_from_file_location(
        'rom', os.path.join(RAIZ, 'tools', 'rom.py'))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def revisa_nombres(pagina):
    """Aborta si dos declaraciones del ambito del script comparten nombre.

    En JavaScript la segunda gana en silencio y las dos acaban siendo la misma
    variable; asi se quedo mudo el AY una temporada, porque el contador de
    fotogramas y el de los canales de sonido se llamaban igual.
    """
    ini = pagina.rindex('<script>')             # el bloque propio de la pagina,
    cuerpo = pagina[ini:pagina.index('</script>', ini)]   # no el del nucleo Z80
    vistos, repes = set(), set()
    for linea in cuerpo.split('\n'):
        if linea.startswith('  function '):
            nombres = [re.match(r'  function (\w+)', linea).group(1)]
        elif linea.startswith('  var '):
            nombres = [n for n in map(nombre, declarados(linea[6:])) if n]
        else:
            continue
        for n in nombres:
            if n in vistos:
                repes.add(n)
            vistos.add(n)
    if repes:
        sys.exit(f'declarados dos veces en el ambito del script: {sorted(repes)}')


def declarados(decl):
    """Nombres de un 'var a = 1, b = [2, 3], c;' - las comas de dentro no cuentan."""
    hondo, trozo = 0, ''
    for ch in decl:
        if ch in '([{':
            hondo += 1
        elif ch in ')]}':
            hondo -= 1
        if ch == ',' and not hondo:
            yield trozo
            trozo = ''
        else:
            trozo += ch
    yield trozo


def nombre(trozo):
    m = re.match(r'\s*([A-Za-z_$][\w$]*)', trozo)
    return m.group(1) if m else None


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
    revisa_nombres(plantilla)
    ruta = os.path.join(RAIZ, 'dist', 'balava-web.html')
    with open(ruta, 'w') as f:
        f.write(salida)
    print(f'{ruta}: {len(salida) / 1024:.0f} KB')


if __name__ == '__main__':
    main()
