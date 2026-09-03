#!/usr/bin/env python3
"""Genera la pantalla de carga (SCREEN$ de 6912 bytes) de BalaVa.

El color del Spectrum va por celdas de 8x8: cada celda solo admite una tinta
y un papel.  Para que no haya *colour clash* la pantalla se compone a nivel de
celda: el fondo se pinta por celdas enteras y cada dibujo declara con que
tinta entra, de modo que si dos dibujos con tintas distintas cayeran en la
misma celda el generador lo canta y no escribe nada.

    python3 tools/pantalla_carga.py [--png preview.png]

Los dibujos (logotipo, pistoleros, caballo, cactus) se leen del propio
src/balava.asm, de los comentarios en ASCII que acompañan a cada DEFB, para
no tener el arte duplicado en dos sitios.
"""

import argparse
import math
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASM = os.path.join(RAIZ, 'src', 'balava.asm')
TTF = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf'

NEGRO, AZUL, ROJO, MAGENTA, VERDE, CIAN, AMARILLO, BLANCO = range(8)


def lee_arte(nombre):
    """Saca el dibujo en ASCII de los comentarios de un bloque DEFB del .asm."""
    filas = []
    dentro = False
    for linea in open(ASM):
        if linea.startswith(nombre + ':'):
            dentro = True
            continue
        if dentro:
            m = re.search(r';\s*([.#]+)\s*$', linea)
            if m:
                filas.append(m.group(1))
            elif filas:
                break
    if not filas:
        sys.exit(f'no encuentro el dibujo {nombre} en {ASM}')
    return filas


def escala(arte, n):
    return [''.join(c * n for c in fila) for fila in arte for _ in range(n)]


def recorta(arte):
    """Quita las columnas y filas vacias de los bordes."""
    cols = [i for i in range(len(arte[0])) if any(f[i] == '#' for f in arte)]
    filas = [f for f in arte if '#' in f]
    return [''.join(f[i] for i in range(cols[0], cols[-1] + 1)) for f in filas]


class Pantalla:
    def __init__(self):
        self.pix = [[0] * 256 for _ in range(192)]
        self.papel = [[AMARILLO] * 32 for _ in range(24)]
        self.tinta = [[NEGRO] * 32 for _ in range(24)]
        self.brillo = [[0] * 32 for _ in range(24)]
        self.tinta_usada = {}                  # celda -> tinta ya comprometida
        self.choques = []

    # --- color, siempre por celdas enteras ---------------------------
    def papel_celdas(self, c0, f0, c1, f1, color, brillo=1):
        for f in range(f0, f1 + 1):
            for c in range(c0, c1 + 1):
                self.papel[f][c] = color
                self.brillo[f][c] = brillo

    # --- dibujo, declarando con que tinta entra ----------------------
    def dibuja(self, arte, x, y, tinta=NEGRO):
        for dy, fila in enumerate(arte):
            for dx, ch in enumerate(fila):
                if ch != '#':
                    continue
                px, py = x + dx, y + dy
                if not (0 <= px < 256 and 0 <= py < 192):
                    continue
                celda = (py // 8, px // 8)
                previa = self.tinta_usada.get(celda)
                if previa is not None and previa != tinta:
                    self.choques.append(celda)
                self.tinta_usada[celda] = tinta
                self.tinta[celda[0]][celda[1]] = tinta
                self.pix[py][px] = 1

    def texto(self, cadena, x, y, tinta=BLANCO, tam=11):
        from PIL import Image, ImageDraw, ImageFont
        fuente = ImageFont.truetype(TTF, tam)
        ancho = 8 * len(cadena) + 8
        img = Image.new('1', (ancho, 12), 0)
        ImageDraw.Draw(img).text((0, 0), cadena, font=fuente, fill=1)
        arte = [''.join('#' if img.getpixel((cx, cy)) else '.' for cx in range(ancho))
                for cy in range(12)]
        arte = [f for f in arte if '#' in f]        # recorta arriba y abajo
        self.dibuja(arte, x, y, tinta)

    # --- salida ------------------------------------------------------
    def scr(self):
        datos = bytearray(6912)
        for y in range(192):
            base = ((y & 0xC0) << 5) | ((y & 0x07) << 8) | ((y & 0x38) << 2)
            for c in range(32):
                b = 0
                for k in range(8):
                    if self.pix[y][c * 8 + k]:
                        b |= 0x80 >> k
                datos[base + c] = b
        for f in range(24):
            for c in range(32):
                datos[6144 + f * 32 + c] = (self.brillo[f][c] << 6 |
                                            self.papel[f][c] << 3 | self.tinta[f][c])
        return bytes(datos)

    def png(self, ruta, escala_px=2):
        from PIL import Image
        rgb = [(0, 0, 0), (0, 0, 205), (205, 0, 0), (205, 0, 205),
               (0, 205, 0), (0, 205, 205), (205, 205, 0), (205, 205, 205)]
        rgbb = [(0, 0, 0), (0, 0, 255), (255, 0, 0), (255, 0, 255),
                (0, 255, 0), (0, 255, 255), (255, 255, 0), (255, 255, 255)]
        img = Image.new('RGB', (256, 192))
        px = img.load()
        for y in range(192):
            for x in range(256):
                f, c = y // 8, x // 8
                tabla = rgbb if self.brillo[f][c] else rgb
                px[x, y] = tabla[self.tinta[f][c] if self.pix[y][x] else self.papel[f][c]]
        img.resize((256 * escala_px, 192 * escala_px), Image.NEAREST).save(ruta)


def pueblo():
    """Silueta de un pueblo del oeste abandonado: fachadas falsas, un
    campanario y el deposito de agua, con los huecos de puertas y ventanas."""
    an, al = 256, 44
    g = [['.'] * an for _ in range(al)]

    def bloque(x0, y0, x1, y1, ch='#'):
        for y in range(max(0, y0), min(al, y1 + 1)):
            for x in range(max(0, x0), min(an, x1 + 1)):
                g[y][x] = ch

    def tejado(x0, x1, y, alto):
        for i in range(alto):
            bloque(x0 + i * (x1 - x0) // (2 * alto), y - i,
                   x1 - i * (x1 - x0) // (2 * alto), y - i)

    def casa(x0, x1, alto, falso=False, ventanas=2):
        cima = al - alto
        bloque(x0, cima, x1, al - 1)
        if falso:                                   # fachada recta, mas alta
            bloque(x0 + 2, cima - 4, x1 - 2, cima)
        else:
            tejado(x0 - 2, x1 + 2, cima, 4)
        ancho = (x1 - x0) // (ventanas + 1)
        for k in range(ventanas):                   # ventanas vacias
            vx = x0 + ancho * (k + 1) - 2
            bloque(vx, cima + 6, vx + 4, cima + 11, '.')
        bloque((x0 + x1) // 2 - 3, al - 10, (x0 + x1) // 2 + 3, al - 1, '.')

    casa(2, 40, 26, ventanas=2)
    casa(46, 92, 34, falso=True, ventanas=3)        # el saloon
    casa(160, 200, 28, ventanas=2)
    casa(206, 252, 24, falso=True, ventanas=2)

    # el campanario de la iglesia
    bloque(106, al - 30, 132, al - 1)
    tejado(104, 134, al - 30, 5)
    bloque(114, al - 44, 124, al - 30)
    tejado(112, 126, al - 44, 6)
    bloque(117, al - 50, 120, al - 44)              # la cruz
    bloque(114, al - 48, 123, al - 47)
    bloque(116, al - 22, 122, al - 15, '.')

    # el deposito de agua, sobre sus patas
    bloque(138, al - 40, 156, al - 28)
    tejado(136, 158, al - 40, 3)
    for x in (140, 146, 153):
        bloque(x, al - 28, x + 1, al - 1)
    bloque(139, al - 20, 155, al - 19)

    return [''.join(f) for f in g]


def compon():
    p = Pantalla()

    # ---- cielo: estrella de rayos amarillos y rojos desde el titulo ---
    cx, cy = 16.0, 4.0                          # centro del estallido, en celdas
    for f in range(2, 15):
        for c in range(32):
            ang = math.degrees(math.atan2(f - cy, (c - cx) * 0.6)) % 360
            dist = math.hypot((c - cx) * 0.6, f - cy)
            amarillo = dist < 3.2 or int(ang // 15) % 2 == 0
            p.papel_celdas(c, f, c, f, AMARILLO if amarillo else ROJO, 1)

    # ---- bandas de arriba y de abajo ---------------------------------
    p.papel_celdas(0, 0, 31, 1, NEGRO, 0)
    p.papel_celdas(0, 23, 31, 23, NEGRO, 0)

    # ---- suelo del desierto ------------------------------------------
    p.papel_celdas(0, 15, 31, 22, AMARILLO, 0)   # el suelo, desde la fila 15

    # ---- el titulo, sobre una franja amarilla limpia -------------------
    p.papel_celdas(0, 2, 31, 6, AMARILLO, 1)
    letras = [recorta(escala(lee_arte('logo_' + n), 2)) for n in 'balava']
    x = 128 - sum(len(l[0]) + 6 for l in letras) // 2
    for letra in letras:
        p.dibuja(letra, x, 20, ROJO)
        x += len(letra[0]) + 6

    # ---- el pueblo fantasma, recortado en el horizonte ----------------
    p.dibuja(pueblo(), 0, 76, NEGRO)

    # ---- los dos pistoleros, batiendose en duelo ----------------------
    sheriff = escala(lee_arte('spr_poli'), 2)
    bandido = escala(lee_arte('spr_ladron'), 2)
    p.dibuja(sheriff, 4, 119, NEGRO)            # los pies en el suelo
    p.dibuja(bandido, 204, 119, NEGRO)

    # ---- y el caballo, relinchando de pie sobre las patas traseras ----
    caballo = escala(recorta(lee_arte('spr_caballo_alza')), 2)
    p.dibuja(caballo, 96, 119, NEGRO)

    # ---- textos ------------------------------------------------------
    p.texto('ZX SPECTRUM 128K', 8, 4, BLANCO)
    p.texto('KBZA SOFT 2026', 144, 4, BLANCO)
    p.texto('1 O 2 JUGADORES - PULSA UNA TECLA', 24, 185, BLANCO, tam=9)
    return p


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--scr', default=os.path.join(RAIZ, 'dist', 'balava.scr'))
    ap.add_argument('--png', help='guarda ademas una vista previa')
    args = ap.parse_args()

    p = compon()
    if p.choques:
        celdas = sorted(set(p.choques))
        sys.exit(f'colour clash en {len(celdas)} celdas: {celdas[:8]}')

    os.makedirs(os.path.dirname(args.scr), exist_ok=True)
    with open(args.scr, 'wb') as f:
        f.write(p.scr())
    usadas = len(p.tinta_usada)
    print(f'{args.scr}: 6912 bytes, {usadas} celdas con dibujo, sin colour clash')
    if args.png:
        p.png(args.png)


if __name__ == '__main__':
    main()
