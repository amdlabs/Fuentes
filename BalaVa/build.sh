#!/bin/sh
# Compila el juego y genera el snapshot .z80 en dist/
set -e
cd "$(dirname "$0")"
mkdir -p build dist
pasmo --bin --alocal src/balava.asm build/balava.bin build/balava.sym
python3 tools/make_z80.py build/balava.bin dist/balava.z80
