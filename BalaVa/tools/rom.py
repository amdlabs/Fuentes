#!/usr/bin/env python3
"""La ROM sintetica que usan el banco de pruebas y el emulador web.

No hace falta ninguna imagen de ROM con derechos: el juego solo necesita un
manejador de la interrupcion en 0x0038 y un juego de caracteres 8x8 donde lo
tiene la ROM real (0x3C00 + codigo*8).
"""

from PIL import Image, ImageDraw, ImageFont

TTF = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'

# unas cuantas letras salen mal al reducir la tipografia a 8x8, asi que van
# dibujadas a mano (bit 7 = pixel de la izquierda)
RETOQUES = {
    'Q': [0x3C, 0x42, 0x42, 0x42, 0x4A, 0x44, 0x3A, 0x00],
    'V': [0x42, 0x42, 0x42, 0x42, 0x24, 0x24, 0x18, 0x00],
    'W': [0x42, 0x42, 0x42, 0x5A, 0x5A, 0x66, 0x42, 0x00],
    'J': [0x1E, 0x04, 0x04, 0x04, 0x44, 0x44, 0x38, 0x00],
    'M': [0x42, 0x66, 0x5A, 0x5A, 0x42, 0x42, 0x42, 0x00],
}


# El manejador de la interrupcion imita lo que hace el de la ROM de verdad:
# apila cuatro parejas de registros, lleva la cuenta de FRAMES y escribe
# LAST-K y KSTATE0 *a traves de IY*, que es como los toca la ROM.  Asi, si el
# juego se llevara IY por delante o dejara el SP donde no debe, se nota aqui en
# vez de solo en una maquina real.
MANEJADOR = bytes([
    0xF5, 0xE5, 0xC5, 0xD5,             # push af / hl / bc / de
    0x2A, 0x78, 0x5C,                   # ld hl,(FRAMES)
    0x23,                               # inc hl
    0x22, 0x78, 0x5C,                   # ld (FRAMES),hl
    0xFD, 0x36, 0x08, 0x20,             # ld (iy+0x08),' '   LAST-K
    0xFD, 0x36, 0x00, 0xFF,             # ld (iy+0x00),0xFF  KSTATE0
    0xD1, 0xC1, 0xE1, 0xF1,             # pop de / bc / hl / af
    0xFB, 0xC9,                         # ei / ret
])


def crea_rom():
    """ROM minima: DI en 0x0000, el manejador en 0x0038 y un font en 0x3D00."""
    rom = bytearray(0x4000)
    rom[0x0000] = 0xF3
    rom[0x0038:0x0038 + len(MANEJADOR)] = MANEJADOR
    fuente = ImageFont.truetype(TTF, 9)
    for c in range(32, 128):
        img = Image.new('1', (8, 8), 0)
        ImageDraw.Draw(img).text((-1, -1), chr(c), font=fuente, fill=1)
        for fila in range(8):
            b = 0
            for col in range(8):
                if img.getpixel((col, fila)):
                    b |= 0x80 >> col
            rom[0x3C00 + c * 8 + fila] = b
    for letra, filas in RETOQUES.items():
        rom[0x3C00 + ord(letra) * 8:0x3C00 + ord(letra) * 8 + 8] = bytes(filas)
    return bytes(rom)
