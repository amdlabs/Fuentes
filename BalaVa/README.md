# BalaVa — ZX Spectrum 48K

Duelo en el oeste para dos jugadores, en ensamblador Z80 para ZX Spectrum 48K.
El sheriff (izquierda) y el bandido (derecha) se disparan de un lado a otro de
la pantalla: solo pueden moverse **arriba y abajo** para esquivar las balas del
contrario. En medio hay una carreta y dos cactus que **paran los disparos**, un
**caracol gigante** que cruza el campo despacio y va tapando calles a su paso, y
delante de cada pistolero una **caja** tras la que parapetarse, que se va
rompiendo a tiros tramo a tramo. Fondo amarillo, sprites en negro. Gana el
primero que consiga 5 impactos.

    dist/balava.z80    <- snapshot listo para cargar en un emulador
    dist/balava.scr    <- la pantalla de carga suelta (SCREEN$ de 6912 bytes)

## Pantalla de carga

Al arrancar sale una pantalla de carga al estilo de las de 1987: estallido de
rayos amarillos y rojos, el título en rojo, los dos pistoleros recortados en
negro, la carreta, los cactus y el caracol, y las bandas negras de arriba y
abajo. Se queda a la vista hasta que se pulse una tecla.

**Sin colour clash**: en el Spectrum cada celda de 8x8 admite una sola tinta y
un solo papel, así que la pantalla se compone *a nivel de celda*. El fondo se
pinta por celdas enteras (los rayos son cuñas cuyo color se decide por el
ángulo de la celda, no del píxel) y cada dibujo declara con qué tinta entra; si
dos dibujos de tintas distintas cayeran en la misma celda, `tools/pantalla_carga.py`
lo detecta, lo dice y no escribe nada. Por construcción no puede haber choque
de atributos, y como `build.sh` genera la pantalla en cada compilación, un
descuido de composición rompe la compilación en vez de colarse en el juego.

El dibujo no está duplicado: el generador lee los sprites del propio
`src/balava.asm`, de los comentarios en ASCII que acompañan a cada `DEFB`, y los
escala al doble.

## Menú

Arranca en un menú de la época: recuadro de pantalla, banda negra con el
logotipo **BALAVA** en hueco, los dos pistoleros apuntándose entre los cactus y
dos opciones.

    1  JUGAR
    2  CONTROLES

El aviso `PULSA 1 O 2` parpadea usando el bit FLASH de los atributos, que lo
hace la propia ULA sin gastar un solo ciclo de CPU. De fondo suena **Oh! Susanna**
(Stephen Foster, 1848, de dominio público) por el altavoz. Al terminar una
partida, cualquier tecla devuelve al menú.

## Controles

| | Arriba | Abajo | Disparo |
|---|---|---|---|
| Jugador 1 — Sheriff (izquierda) | `Q` | `A` | `Z` |
| Jugador 2 — Bandido (derecha) | `P` | `L` | `B` |

Cada jugador solo puede tener una bala en el aire: hasta que la suya no llega
al otro lado, no puede volver a disparar.

## Cómo jugarlo

Carga `dist/balava.z80` en cualquier emulador de Spectrum (Fuse, ZEsarUX,
Spectaculator, SpecEmu, JSSpeccy…). Es un snapshot de 48K, así que arranca
directamente en el juego, sin BASIC de por medio.

## Cómo compilarlo

Hace falta [pasmo](https://pasmo.speccy.org/) y Python 3:

    sudo apt-get install pasmo
    ./build.sh

`build.sh` genera la pantalla de carga, ensambla `src/balava.asm` a un binario
con ORG `0x8000` y `tools/make_z80.py` lo envuelve en un snapshot `.z80` de
versión 1 sin comprimir (30 bytes de cabecera + los 49152 de RAM), con
`PC=0x8000`, `SP=0xFF00`, `IM 1` e interrupciones activas. La pantalla de carga
va precargada en la memoria de vídeo del propio snapshot (`--pantalla`), así que
no ocupa ni un byte de código ni hace falta descomprimir nada al arrancar.

## Pruebas

`tools/probar.py` ejecuta el snapshot en un Z80 emulado de verdad y comprueba
el juego entero (menú, logotipo, música —midiendo las frecuencias que salen por
el altavoz y comparándolas con la melodía guardada—, pantalla de controles,
movimiento fino, topes, disparos, impactos, esquivas, caracol, rotura de las
cajas, marcador, fin de partida y que no queden restos de píxeles en pantalla):

    pip install z80 pillow
    ./build.sh
    python3 tools/probar.py --png capturas

Monta una ROM sintética con un manejador mínimo de la `IM 1` y un juego de
caracteres 8x8 en `0x3D00`, que es donde lo tiene la ROM real, de modo que no
hace falta ninguna imagen de ROM con derechos.

## El campo de juego

- **Carreta y cactus**: fijos, paran las balas.
- **Caracol gigante**: cruza el campo de lado a lado a un píxel cada tres
  fotogramas (unos 15 segundos por travesía, más o menos media jugada), da la
  vuelta al llegar al final y también para las balas. Como se mueve, la calle
  que tapa va cambiando.
- **Cajas**: una delante de cada pistolero, de cuatro tramos. Cada impacto se
  lleva un tramo por delante; por el hueco que queda ya pasan las balas. Sirven
  de parapeto, pero también tapan los propios disparos, así que abrirse una
  tronera cuesta munición.

## Cómo funciona

- **Pantalla**: `scr_addr` traduce (y, columna) a la dirección de la memoria de
  vídeo (`010 Y7Y6 Y2Y1Y0 : Y5Y4Y3 X4X3X2X1X0`) y `down_hl` baja una línea de
  píxeles, que es el bucle interno de todo el dibujado.
- **Logotipo**: banda negra de 32 píxeles de alto sobre la que las letras
  (16x14 píxeles, tabla `logo_letras`) se dibujan con XOR, así que quedan en
  hueco en amarillo sin necesidad de una segunda imagen.
- **Sprites**: los pistoleros miden 24x32 píxeles (3 columnas de caracteres por
  32 filas) y se vuelcan con `dibuja_bloque`, una rutina genérica que sirve
  igual para el decorado (cactus de 16x32 y carreta de 24x28). Al moverse se
  redibujan y se borran solo la fila que dejan libre, así que no parpadean ni
  hace falta doble búfer.
- **Movimiento fino**: todo se mueve a nivel de píxel, nunca a saltos de
  carácter. En vertical basta con cambiar la fila de arranque (un píxel por
  fotograma). En horizontal hace falta desplazar los bytes: al arrancar,
  `genera_desplazados` construye en RAM las **ocho copias** del caracol (una por
  cada desplazamiento de 0 a 7 píxeles) rotando los bytes de cada fila con
  `srl`/`rr`, y luego mover un píxel es solo elegir la copia que toca. El sprite
  lleva un byte en blanco a cada lado, así que la columna que abandona queda
  borrada sola y no deja rastro. Las balas usan la misma idea en pequeño: el
  patrón de 4 píxeles se desplaza dentro de una pareja de bytes.
- **Decorado**: la carreta y los dos cactus son obstáculos de verdad. La tabla
  `obstaculos` guarda un rectángulo (x0, x1, y0, y1) por pieza y `choca_obstaculo`
  comprueba cada bala contra ella **antes** de dibujarla, así que la bala se
  detiene en el borde sin llegar a pisar el decorado (que se dibuja una sola vez
  al empezar la partida y nunca hay que repintarlo).
- **Balas**: bloques de 4x2 píxeles que avanzan 4 píxeles por fotograma y se
  dibujan con XOR, por lo que se borran solas y pueden cruzarse sin estropear
  el fondo. Cuando una bala llega a la columna del rival se comprueba si su
  altura cae dentro de los 32 píxeles del sprite.
- **Colores**: toda el área de atributos a `PAPER 6 / INK 0` (`0x30`) y borde
  amarillo, así que no hay *attribute clash* posible.
- **Teclado**: lectura directa del puerto `0xFE` por semifilas; el menú lee las
  ocho a la vez con el byte alto a 0 para el «pulsa cualquier tecla».
- **Música**: el altavoz se conmuta con un bucle de retardo, así que un periodo
  completo son `32*C + 60` T-estados y la nota sale a `3.500.000 / (32*C + 60)`
  Hz. La melodía se guarda como (periodo, ciclos por tick, ticks) y suena en
  trozos de 60 ms para que el menú pueda mirar el teclado entre uno y otro. Las
  interrupciones se desactivan mientras suena, que si no la RST 38 desafina las
  notas.
- **Ritmo**: `HALT` en el bucle principal sincroniza el juego a los 50 Hz de la
  interrupción, y los textos se imprimen con el juego de caracteres de la ROM
  (`0x3C00 + código*8`) sin depender de las rutinas de canales del BASIC.

## Ficheros

    src/balava.asm         codigo fuente Z80 (pasmo)
    tools/pantalla_carga.py compone la pantalla de carga sin colour clash
    tools/make_z80.py      genera el snapshot .z80 de 48K a partir del binario
    tools/probar.py        pruebas sobre un Z80 emulado
    build.sh               ensambla y genera dist/balava.z80
    dist/                  snapshot y pantalla de carga listos para usar
