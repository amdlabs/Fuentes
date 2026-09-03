#!/usr/bin/env python3
"""Arma un .asm suelto, que se ensambla sin nada mas alrededor.

El fuente de trabajo se apoya en dos ficheros que generan los scripts: la foto
de los creditos (INCBIN) y la pantalla de carga (que el snapshot deja ya
dibujada en la memoria de video).  Aqui se meten los dos dentro del propio
ensamblador, en DEFB, y se anade el volcado de la pantalla de carga al arrancar.
Asi el fichero se puede ensamblar en el propio emulador, sin Python ni build.sh.

    python3 tools/asm_suelto.py [salida.asm]
"""

import os
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def defb(datos, sangria='            '):
    lineas = []
    for i in range(0, len(datos), 16):
        trozo = ', '.join(str(b) for b in datos[i:i + 16])
        lineas.append(f'{sangria}DEFB    {trozo}')
    return '\n'.join(lineas)


def main():
    salida = sys.argv[1] if len(sys.argv) > 1 else os.path.join(RAIZ, 'dist', 'balava.asm')
    fuente = open(os.path.join(RAIZ, 'src', 'balava.asm'), encoding='utf-8').read()
    foto = open(os.path.join(RAIZ, 'build', 'foto.bin'), 'rb').read()
    carga = open(os.path.join(RAIZ, 'dist', 'balava.scr'), 'rb').read()

    # 1. la foto, dentro del propio ensamblador
    viejo = '            INCBIN  "build/foto.bin"'
    if viejo not in fuente:
        sys.exit('no encuentro el INCBIN de la foto')
    fuente = fuente.replace(viejo, defb(foto), 1)

    # 2. la pantalla de carga se dibuja al arrancar, que aqui no hay snapshot
    viejo = """            ; la pantalla de carga ya viene dibujada en el snapshot: se
            ; queda a la vista hasta que el jugador pulse una tecla
            xor     a"""
    nuevo = """            ld      hl,pantalla_carga       ; aqui no hay snapshot que la
            ld      de,SCREEN               ; traiga puesta: se vuelca y se
            ld      bc,6912                 ; queda a la vista hasta que el
            ldir                            ; jugador pulse una tecla
            xor     a"""
    if viejo not in fuente:
        sys.exit('no encuentro el arranque')
    fuente = fuente.replace(viejo, nuevo, 1)

    # 3. y sus 6912 bytes, al final del todo
    viejo = '\nfin_codigo:\n            END inicio'
    nuevo = ('\n;---------------------------------------------------------------------\n'
             '; la pantalla de carga, 6912 bytes tal cual van a la memoria de video\n'
             ';---------------------------------------------------------------------\n'
             'pantalla_carga:\n' + defb(carga) +
             '\n\nfin_codigo:\n            END inicio')
    if viejo not in fuente:
        sys.exit('no encuentro el final')
    fuente = fuente.replace(viejo, nuevo, 1)

    cabecera = """; BalaVa - (C) 2026 Kbza Soft - Alejandro Martinez
;
; Version suelta: se ensambla tal cual, sin nada mas alrededor.  Lleva dentro
; la foto de los creditos y la pantalla de carga, que en el proyecto salen de
; dos scripts.  Con pasmo:
;
;     pasmo --tapbas balava.asm balava.tap
;     pasmo --bin balava.asm balava.bin        (ORG 0x8000, se salta a 32768)
;
; Es un juego de 128K: hace falta el AY para la musica.
;
"""
    open(salida, 'w', encoding='utf-8').write(cabecera + fuente)
    print(f'{salida}: {len(fuente.splitlines())} lineas, '
          f'{os.path.getsize(salida) // 1024} KB')


if __name__ == '__main__':
    main()
