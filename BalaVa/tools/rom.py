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


def crea_rom():
    """ROM minima: DI en 0x0000, EI/RET en 0x0038 y un font 8x8 en 0x3D00."""
    rom = bytearray(0x4000)
    rom[0x0000] = 0xF3
    rom[0x0038] = 0xFB
    rom[0x0039] = 0xC9
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
