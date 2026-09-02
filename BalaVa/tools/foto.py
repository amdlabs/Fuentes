#!/usr/bin/env python3
"""Pasa la foto del autor a un bitmap de ZX Spectrum: 256x192 a un solo bit.

Sale en el orden de la memoria de video (6144 bytes), asi que dibujarla en
pantalla es un LDIR y, en la ventana del scroll de los creditos, el byte de la
foto esta siempre a la misma distancia del byte de pantalla.

    python3 tools/foto.py [--png vista.png]
"""

import argparse
import os
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANCHO, ALTO = 256, 192


def dir_pantalla(y, col=0):
    return ((y & 0xC0) << 5) | ((y & 0x07) << 8) | ((y & 0x38) << 2) | col


def prepara(ruta):
    """Recorta a 4:3 sobre la cara, levanta las sombras y realza el detalle.

    Con un solo bit por pixel las medias tintas se van en el tramado, asi que
    antes hay que abrir las sombras -los ojos se cerraban en dos manchas
    negras- y marcar los bordes con una mascara de enfoque.
    """
    from PIL import Image, ImageEnhance, ImageFilter, ImageOps
    im = Image.open(ruta).convert('L')
    an, al = im.size
    im = im.crop((int(an * 0.02), int(al * 0.05),      # cabeza y hombros, 4:3
                  int(an * 0.98), int(al * 0.77)))
    im = im.resize((ANCHO, ALTO), Image.LANCZOS)
    im = ImageOps.autocontrast(im, cutoff=1)
    im = im.point(lambda v: int(255 * ((v / 255.0) ** 0.72)))     # abre sombras
    im = im.filter(ImageFilter.UnsharpMask(radius=6, percent=90, threshold=3))
    return ImageEnhance.Contrast(im).enhance(1.05)


def trama(im):
    """Tramado de Atkinson, el de los digitalizadores de la epoca.

    Solo reparte seis octavos del error, asi que sale mas contrastado y con
    menos ruido que Floyd-Steinberg: justo lo que le va a una cara.
    """
    px = [[float(im.getpixel((x, y))) for x in range(ANCHO)] for y in range(ALTO)]
    bits = [[0] * ANCHO for _ in range(ALTO)]
    for y in range(ALTO):
        for x in range(ANCHO):
            v = px[y][x]
            nuevo = 255.0 if v >= 128 else 0.0
            bits[y][x] = 0 if nuevo else 1          # 1 = tinta (negro)
            e = (v - nuevo) / 8.0
            for dx, dy in ((1, 0), (2, 0), (-1, 1), (0, 1), (1, 1), (0, 2)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < ANCHO and 0 <= ny < ALTO:
                    px[ny][nx] += e
    return bits


def a_pantalla(bits):
    datos = bytearray(6144)
    for y in range(ALTO):
        base = dir_pantalla(y)
        for c in range(32):
            b = 0
            for k in range(8):
                if bits[y][c * 8 + k]:
                    b |= 0x80 >> k
            datos[base + c] = b
    return bytes(datos)


def vista(bits, ruta, escala=2):
    from PIL import Image
    im = Image.new('RGB', (ANCHO * escala, ALTO * escala))
    px = im.load()
    for y in range(ALTO):
        for x in range(ANCHO):
            col = (0, 0, 0) if bits[y][x] else (255, 255, 255)
            for dy in range(escala):
                for dx in range(escala):
                    px[x * escala + dx, y * escala + dy] = col
    im.save(ruta)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--foto', default=os.path.join(RAIZ, 'arte', 'autor.png'))
    ap.add_argument('--salida', default=os.path.join(RAIZ, 'build', 'foto.bin'))
    ap.add_argument('--png', help='guarda ademas una vista previa')
    args = ap.parse_args()

    if not os.path.exists(args.foto):
        sys.exit(f'no encuentro la foto: {args.foto}')
    bits = trama(prepara(args.foto))
    datos = a_pantalla(bits)
    os.makedirs(os.path.dirname(args.salida), exist_ok=True)
    open(args.salida, 'wb').write(datos)
    tinta = sum(sum(f) for f in bits)
    print(f'{args.salida}: {len(datos)} bytes, {tinta * 100 // (ANCHO * ALTO)}% de tinta')
    if args.png:
        vista(bits, args.png)


if __name__ == '__main__':
    main()
