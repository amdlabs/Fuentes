#!/usr/bin/env python3
"""Genera un snapshot .z80 de ZX Spectrum 48K (version 1, sin comprimir).

El fichero resultante son 30 bytes de cabecera seguidos de los 49152 bytes
de RAM ($4000-$FFFF).  Se carga en Fuse, ZEsarUX, Spectaculator, SpecEmu,
JSSpeccy, etc.

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
    if not RAM_INI <= org < RAM_FIN:
        sys.exit(f"ORG {org:#06x} fuera de la RAM de un 48K")
    if org + len(binario) > RAM_FIN:
        sys.exit("el binario no cabe en la RAM a partir de ORG")

    ram = bytearray(RAM_LEN)
    if pantalla is not None:
        if len(pantalla) != 6912:
            sys.exit(f'la pantalla mide {len(pantalla)} bytes y tiene que medir 6912')
        ram[0:6912] = pantalla          # 0x4000: pixeles y atributos
    ram[org - RAM_INI:org - RAM_INI + len(binario)] = binario

    cab = bytearray(30)
    cab[0] = 0x00                      # A
    cab[1] = 0x00                      # F
    cab[2], cab[3] = 0x00, 0x00        # C, B
    cab[4], cab[5] = 0x00, 0x00        # L, H
    cab[6], cab[7] = pc & 0xFF, pc >> 8
    cab[8], cab[9] = sp & 0xFF, sp >> 8
    cab[10] = 0x3F                     # I (valor habitual en un 48K)
    cab[11] = 0x00                     # R
    cab[12] = (borde & 7) << 1         # bit5=0 -> bloque sin comprimir
    cab[13], cab[14] = 0x00, 0x00      # E, D
    cab[15], cab[16] = 0x00, 0x00      # C', B'
    cab[17], cab[18] = 0x00, 0x00      # E', D'
    cab[19], cab[20] = 0x00, 0x00      # L', H'
    cab[21] = 0x00                     # A'
    cab[22] = 0x00                     # F'
    cab[23], cab[24] = iy & 0xFF, iy >> 8
    cab[25], cab[26] = 0x00, 0x00      # IX
    cab[27] = 0x01                     # IFF1: interrupciones activadas
    cab[28] = 0x01                     # IFF2
    cab[29] = 0x01                     # bits 0-1: modo de interrupcion = IM 1

    return bytes(cab) + bytes(ram)


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

    print(f"{args.salida}: {len(datos)} bytes "
          f"(codigo {len(binario)} bytes en {args.org:#06x}, PC={pc:#06x}, SP={args.sp:#06x}"
          f"{', con pantalla de carga' if pantalla else ''})")


if __name__ == "__main__":
    main()
