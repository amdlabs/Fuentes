#!/bin/sh
# Compila el juego y genera el snapshot .z80 en dist/
set -e
cd "$(dirname "$0")"
mkdir -p build dist
pasmo --bin --alocal src/juego.asm build/juego.bin build/juego.sym
python3 tools/make_z80.py build/juego.bin dist/policia_ladron.z80
