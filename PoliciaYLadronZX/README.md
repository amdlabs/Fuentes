# Policia y Ladron — ZX Spectrum 48K

Juego de dos jugadores en ensamblador Z80 para ZX Spectrum 48K. El policía
(izquierda) y el ladrón (derecha) se disparan de un lado a otro de la pantalla:
solo pueden moverse **arriba y abajo** para esquivar las balas del contrario.
Fondo amarillo, sprites en negro. Gana el primero que consiga 5 impactos.

    dist/policia_ladron.z80    <- snapshot listo para cargar en un emulador

## Controles

| | Arriba | Abajo | Disparo |
|---|---|---|---|
| Jugador 1 — Policía (izquierda) | `Q` | `A` | `V` |
| Jugador 2 — Ladrón (derecha) | `P` | `L` | `ESPACIO` |

`ENTER` empieza la partida y reinicia al terminar. Cada jugador solo puede
tener una bala en el aire: hasta que la suya no llega al otro lado, no puede
volver a disparar.

## Cómo jugarlo

Carga `dist/policia_ladron.z80` en cualquier emulador de Spectrum (Fuse,
ZEsarUX, Spectaculator, SpecEmu, JSSpeccy…). Es un snapshot de 48K, así que
arranca directamente en el juego, sin BASIC de por medio.

## Cómo compilarlo

Hace falta [pasmo](https://pasmo.speccy.org/) y Python 3:

    sudo apt-get install pasmo
    ./build.sh

`build.sh` ensambla `src/juego.asm` a un binario con ORG `0x8000` y
`tools/make_z80.py` lo envuelve en un snapshot `.z80` de versión 1 sin
comprimir (30 bytes de cabecera + los 49152 de RAM), con `PC=0x8000`,
`SP=0xFF00`, borde amarillo, `IM 1` e interrupciones activas.

## Pruebas

`tools/probar.py` ejecuta el snapshot en un Z80 emulado de verdad y comprueba
la mecánica completa (movimiento, topes, disparos, impactos, esquivas,
marcador, fin de partida y que no queden restos de píxeles en pantalla):

    pip install z80 pillow
    ./build.sh
    python3 tools/probar.py --png capturas

Monta una ROM sintética con un manejador mínimo de la `IM 1` y un juego de
caracteres 8x8 en `0x3D00`, que es donde lo tiene la ROM real, de modo que no
hace falta ninguna imagen de ROM con derechos.

## Cómo funciona

- **Pantalla**: `scr_addr` traduce (y, columna) a la dirección de la memoria de
  vídeo (`010 Y7Y6 Y2Y1Y0 : Y5Y4Y3 X4X3X2X1X0`) y `down_hl` baja una línea de
  píxeles, que es el bucle interno de todo el dibujado.
- **Sprites**: 8x16 píxeles, uno por columna de caracteres (2 y 29). Al moverse
  se redibujan y se borran solo las 2 filas que dejan libres, así que no
  parpadean ni hace falta doble búfer.
- **Balas**: bloques de 4x2 píxeles que avanzan 4 píxeles por fotograma y se
  dibujan con XOR, por lo que se borran solas y pueden cruzarse sin estropear
  el fondo. Cuando una bala llega a la columna del rival se comprueba si su
  altura cae dentro de los 16 píxeles del sprite.
- **Colores**: toda el área de atributos a `PAPER 6 / INK 0` (`0x30`) y borde
  amarillo, así que no hay *attribute clash* posible.
- **Ritmo**: `HALT` en el bucle principal sincroniza el juego a los 50 Hz de la
  interrupción, y los textos se imprimen con el juego de caracteres de la ROM
  (`0x3C00 + código*8`) sin depender de las rutinas de canales del BASIC.

## Ficheros

    src/juego.asm        codigo fuente Z80 (pasmo)
    tools/make_z80.py    genera el snapshot .z80 de 48K a partir del binario
    tools/probar.py      pruebas sobre un Z80 emulado
    build.sh             ensambla y genera dist/policia_ladron.z80
    dist/                snapshot listo para usar
