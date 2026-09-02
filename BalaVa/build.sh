#!/bin/sh
# Compila el juego y genera el snapshot .z80 en dist/
set -e
cd "$(dirname "$0")"
mkdir -p build dist
if [ ! -f dist/balava.scr ] || [ tools/pantalla_carga.py -nt dist/balava.scr ]; then
    python3 tools/pantalla_carga.py          # necesita Pillow
fi
pasmo --bin --alocal src/balava.asm build/balava.bin build/balava.sym
python3 tools/make_z80.py build/balava.bin dist/balava.z80 --pantalla dist/balava.scr
