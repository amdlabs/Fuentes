#!/usr/bin/env python3
"""Genera un snapshot .z80 de ZX Spectrum 128K (version 2, sin comprimir).

Hace falta el 128K porque la musica va por el AY.  El juego usa el mapa de
memoria de siempre (la ROM de 48K paginada), asi que por dentro no cambia
nada.  Se carga en Fuse, ZEsarUX, Spectaculator, SpecEmu, JSSpeccy, etc.

    python3 tools/make_z80.py build/juego.bin dist/policia_ladron.z80
"""

import argparse
import sys

RAM_INI = 0x4000
RAM_FIN = 0x10000
RAM_LEN = RAM_FIN - RAM_INI          # 49152


def entero(texto):
    return int(texto, 0)


def construir(binario, org, pc, sp, borde, iy, pantalla=None):
    """Snapshot .z80 de version 2 para un Spectrum 128K.

    El AY vive en el 128K, asi que el juego se entrega como snapshot de 128K
    con la ROM de 48K paginada (puerto 0x7FFD = 0x10): el mapa de memoria
    queda igual que en un 48K -- banco 5 en 0x4000, banco 2 en 0x8000 y
    banco 0 en 0xC000 -- y ademas hay AY.
    """
    if not RAM_INI <= org < RAM_FIN:
        sys.exit(f"ORG {org:#06x} fuera de la RAM")
    if org + len(binario) > 0xC000:
        sys.exit("el binario se sale del banco 2")

    bancos = [bytearray(0x4000) for _ in range(8)]
    if pantalla is not None:
        if len(pantalla) != 6912:
            sys.exit(f"la pantalla mide {len(pantalla)} bytes y tiene que medir 6912")
        bancos[5][0:6912] = pantalla                  # 0x4000, banco 5
    bancos[2][org - 0x8000:org - 0x8000 + len(binario)] = binario   # 0x8000, banco 2

    cab = bytearray(30)
    cab[6], cab[7] = 0, 0              # PC = 0: hay cabecera ampliada
    cab[8], cab[9] = sp & 0xFF, sp >> 8
    cab[10] = 0x3F                     # I
    cab[12] = (borde & 7) << 1
    cab[23], cab[24] = iy & 0xFF, iy >> 8
    cab[27] = 0x01                     # IFF1: interrupciones activadas
    cab[28] = 0x01                     # IFF2
    cab[29] = 0x01                     # bits 0-1: modo de interrupcion = IM 1

    ext = bytearray(23)
    ext[0], ext[1] = 23, 0             # longitud de la cabecera ampliada
    ext[2], ext[3] = pc & 0xFF, pc >> 8
    ext[4] = 3                         # modo de maquina: 128K
    ext[5] = 0x10                      # ultimo OUT a 0x7FFD: ROM 48K, banco 0
    ext[6] = 0                         # sin Interface I
    ext[7] = 0
    ext[8] = 0                         # ultimo OUT a 0xFFFD
    # ext[9..24]: los 16 registros del AY, a cero

    bloques = bytearray()
    for banco, datos in enumerate(bancos):
        bloques += bytes([0xFF, 0xFF, banco + 3])     # sin comprimir
        bloques += datos

    return bytes(cab) + bytes(ext) + bytes(bloques)


def main():
    ap = argparse.ArgumentParser(description="crea un .z80 de 48K a partir de un binario")
    ap.add_argument("binario", help="binario ensamblado")
    ap.add_argument("salida", help="fichero .z80 de salida")
    ap.add_argument("--org", type=entero, default=0x8000, help="direccion de carga (0x8000)")
    ap.add_argument("--pc", type=entero, default=None, help="PC inicial (por omision, ORG)")
    ap.add_argument("--sp", type=entero, default=0xFF00, help="puntero de pila")
    ap.add_argument("--borde", type=entero, default=6, help="color del borde (6 = amarillo)")
    ap.add_argument("--iy", type=entero, default=0x5C3A, help="IY (lo usa la RST 38 de la ROM)")
    ap.add_argument("--pantalla", help="SCREEN$ de 6912 bytes para la pantalla de carga")
    args = ap.parse_args()

    with open(args.binario, "rb") as f:
        binario = f.read()

    pc = args.org if args.pc is None else args.pc
    if pc == 0:
        sys.exit("PC no puede ser 0 en un .z80 de version 1")

    pantalla = None
    if args.pantalla:
        with open(args.pantalla, "rb") as f:
            pantalla = f.read()

    datos = construir(binario, args.org, pc, args.sp, args.borde, args.iy, pantalla)
    with open(args.salida, "wb") as f:
        f.write(datos)

    print(f"{args.salida}: {len(datos)} bytes, snapshot de 128K "
          f"(codigo {len(binario)} bytes en {args.org:#06x}, PC={pc:#06x}, SP={args.sp:#06x}"
          f"{', con pantalla de carga' if pantalla else ''})")


if __name__ == "__main__":
    main()
