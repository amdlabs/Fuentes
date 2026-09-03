# BalaVa — ZX Spectrum 128K

Duelo en el oeste en ensamblador Z80. El sheriff (izquierda) y el bandido
(derecha) se disparan de un lado a otro de la pantalla: solo pueden moverse
**arriba y abajo** para esquivar las balas del contrario. Se juega **de uno o de
dos**: en la partida a uno, el bandido lo lleva la máquina.

Cada pistolero entra con **ocho balas en el cinto**, dibujadas arriba en el
marcador, y puede tener **hasta cuatro en el aire a la vez**: disparar no borra
la anterior. Cuando a los dos se les acaba la munición se termina la partida y
solo queda esquivar hasta entonces.

Entre medias hay un **barril de whisky** delante de cada uno (a una altura
distinta cada partida, nunca en la misma línea de tiro), dos cactus y una
**carreta que sube por el centro** hasta perderse por arriba. Todo eso para las
balas, y cada bala **arranca unos pocos píxeles** de lo que toca: a base de tiros
se van abriendo troneras por donde luego pasan los disparos, y una bala nunca
atraviesa dos cosas.

Y por abajo anda **un caballo suelto**, que no es decorado: camina, se para a
pastar, se **encabrita** al oír un tiro y, si le entra una bala, o **embiste al
que le disparó** —y al que no se aparta a tiempo se lo lleva por delante— o sale
de estampida. De las dos maneras se pierde de vista hasta la partida siguiente.

Al que le dan **se dobla, cae al suelo** y arranca la **cinemática**: pantalla
completa, bandas negras de cine, la bala a cámara lenta, primer plano del
alcanzado, fogonazo y desplome. Después el **funeral**, con la marcha fúnebre y
la carreta llevándose el ataúd. Luego se repone el decorado —con los agujeros
que ya tuviera— y sigue la partida. Fondo amarillo, sprites en negro. Gana el
primero que consiga 5 impactos.

    dist/balava.z80        <- snapshot listo para cargar en un emulador
    dist/balava.scr        <- la pantalla de carga suelta (SCREEN$ de 6912 bytes)
    dist/balava-web.html   <- pagina autocontenida: el juego con su emulador dentro
    dist/balava.asm        <- el fuente en un solo fichero, para ensamblar a mano

## Jugar en el navegador

`dist/balava-web.html` es una sola pagina, sin descargas ni dependencias: lleva
dentro un **nucleo Z80 escrito en JavaScript** (`web/z80.js`), el binario del
juego, la pantalla de carga y el juego de caracteres, todo en base64. Se abre y
se juega. El boton **SONIDO** enciende la sintesis del AY: se leen los registros
del chip una vez por fotograma y se genera el bloque de 882 muestras que toca,
tres canales de tono mas el ruido, con la Web Audio API.

Como todo el guion de la pagina vive en un solo ambito, `tools/web.py` aborta la
compilacion si dos declaraciones comparten nombre: la segunda gana en silencio y
las dos acaban siendo la misma variable.

La ROM es **sintetica**: el juego no llama a ninguna rutina del sistema, asi que
basta con un manejador minimo de la interrupcion en `0x0038` y un juego de
caracteres 8x8 en `0x3D00`; no hace falta ninguna imagen de ROM con derechos.

Que el emulador de JavaScript se porta igual que el de referencia no es una
suposicion: `tools/estado.py` guarda el guion de teclas y, en once puntos, la
firma SHA-1 de la pantalla y las variables del juego que deja el emulador de
referencia; `node tools/probar_web.js build/guion.json` repite el mismo guion
con el nucleo de JavaScript y compara. Ahora mismo: **642 fotogramas sin una
sola diferencia**.

## Grabar una partida

`tools/grabar.py` juega una partida guionizada y saca un MP4 con imagen y el
sonido del AY sintetizado (necesita `imageio-ffmpeg`):

    python3 tools/grabar.py --salida dist/balava.mp4

## Pantalla de carga

Al arrancar sale una pantalla de carga al estilo de las de 1987: estallido de
rayos amarillos y rojos, el título en rojo, la silueta de un **pueblo fantasma**
en el horizonte —fachadas falsas, el campanario de la iglesia y el depósito de
agua—, los dos pistoleros **batiéndose en duelo** y, en medio, el **caballo
relinchando de pie sobre las patas traseras**. Con sus bandas negras arriba y
abajo, y se queda a la vista hasta que se pulse una tecla.

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
escala al doble; el pueblo lo dibuja él con fachadas, tejados y ventanas
recortadas.

## Menú

Arranca en un menú de la época: recuadro de pantalla, banda negra con el
logotipo **BALAVA** en hueco, los dos pistoleros apuntándose entre los cactus y
tres opciones.

    1  UN JUGADOR
    2  DOS JUGADORES
    3  CONTROLES
    4  CREDITOS

El aviso `PULSA 1, 2, 3 O 4` parpadea usando el bit FLASH de los atributos, que
lo hace la propia ULA sin gastar un solo ciclo de CPU. De fondo suena **Oh!
Susanna** (Stephen Foster, 1848, de dominio público) por el AY, a tres voces. Al
terminar una partida, cualquier tecla devuelve al menú.

## Créditos

La opción 4 abre los créditos: la **foto del autor digitalizada a un bit**
ocupando la pantalla entera y, por encima, los rótulos subiendo al píxel con una
marcha lenta en re menor sonando por el AY —treinta segundos de notas largas,
bajo pedal y un arpegio que dobla despacio—, y los rótulos pasando en una
**marquesina** al pie, para no taparle la cara.

La foto la prepara `tools/foto.py`: recorta a 4:3 sobre la cara, abre las sombras
con una gamma de 0,72 —si no, los ojos se cierran en dos manchas negras—, realza
los bordes con una máscara de enfoque y trama con el algoritmo de **Atkinson**,
el de los digitalizadores de la época, que reparte solo seis octavos del error y
sale más contrastado y con menos ruido que Floyd-Steinberg. Salen 6144 bytes ya
en el orden de la memoria de vídeo, así que pintarla es un `LDIR`. 

La marquesina no puede borrar y volver a pintar, porque debajo está la foto. El
texto se guarda aparte, en 16 filas de 32 bytes (`BUF_TEXTO`), y cada fotograma
se corre **un píxel a la izquierda con `RL`**, de derecha a izquierda, metiendo
por la derecha la columna que toca del carácter que entra —el juego de
caracteres de la ROM, a doble alto—. Después la franja se compone sobre una
copia de la foto ya oscurecida con una trama del 87 % (`BUF_VENTANA`):
`pantalla = ventana AND NO texto`, o sea letras en blanco recortadas sobre la
foto. El texto se lee con `POP`, que trae dos bytes en 10 T-estados, así que hay
que apagar las interrupciones mientras dura: con `SP` apuntando al búfer, una
`RST 38` escribiría justo ahí.

Los atributos van todos a `PAPER 6 / INK 0`, la misma paleta que el resto del
juego: monocromo de verdad, sin *colour clash* posible.

## Controles

| | Arriba | Abajo | Disparo |
|---|---|---|---|
| Jugador 1 — Sheriff (izquierda) | `Q` | `A` | `Z` |
| Jugador 2 — Bandido (derecha) | `P` | `L` | `B` |

## Cómo jugarlo

Carga `dist/balava.z80` en cualquier emulador de Spectrum (Fuse, ZEsarUX,
Spectaculator, SpecEmu, JSSpeccy…). Es un snapshot de **128K** —hace falta el
AY para la música—, así que arranca directamente en el juego, sin BASIC de por
medio.

## Ensamblarlo a mano, sin nada mas

`dist/balava.asm` es el juego **en un solo fichero**: lleva dentro la foto de los
créditos y la pantalla de carga (que en el proyecto salen de dos scripts), y se
dibuja la pantalla de carga él solo al arrancar. Se ensambla tal cual, con pasmo
o con el ensamblador que traiga el emulador:

    pasmo --tapbas dist/balava.asm balava.tap     <- cinta que arranca sola
    pasmo --bin    dist/balava.asm balava.bin     <- binario en ORG 0x8000

Es un juego de **128K**: hace falta el AY para la música.

## Cómo compilarlo

Hace falta [pasmo](https://pasmo.speccy.org/) y Python 3:

    sudo apt-get install pasmo
    ./build.sh

`build.sh` genera la pantalla de carga, ensambla `src/balava.asm` a un binario
con ORG `0x8000` y `tools/make_z80.py` lo envuelve en un snapshot `.z80` de
**versión 2 de 128K**: palabra de longitud en los offsets 30-31 y detrás los 23
bytes de cabecera ampliada (offsets 32 a 54, con el modo hardware 3, la ROM de
48K paginada por `0x7FFD = 0x10` y la marca de sonido por el AY), así que el
primer banco arranca en el offset 55; los ocho van sin comprimir. Va
con `PC=0x8000`, `SP=0xFF00`, `IM 1` e interrupciones activas. La pantalla de
carga va precargada en la memoria de vídeo del propio snapshot (`--pantalla`),
así que no ocupa ni un byte de código ni hace falta descomprimir nada al
arrancar.

## Pruebas

`tools/probar.py` ejecuta el snapshot en un Z80 emulado de verdad y comprueba el
juego entero: pantalla de carga y el snapshot de 128K —que se relee siguiendo la
especificación, sin dar por bueno cómo se generó, y se comprueba que los bancos
salen donde toca y no sobra ni un byte—, menú, logotipo,
la música del AY —leyendo los registros del chip y comparando las notas con la
partitura—, pantalla de controles, los créditos —foto, atributos, la marquesina corriendo y
las tres voces—, el caballo suelto —que camina, mueve las patas y se para a
pastar—, colocación de los barriles, la carreta
subiendo, varias balas en el aire a la vez, el marcador de munición hasta
agotarse, el picado de barriles y cactus, la muerte con su cinemática y su
funeral, y la máquina jugando sola:

    pip install z80 pillow
    ./build.sh
    python3 tools/probar.py --png capturas

Monta una ROM sintética con un manejador mínimo de la `IM 1` y un juego de
caracteres 8x8 en `0x3D00`, que es donde lo tiene la ROM real, de modo que no
hace falta ninguna imagen de ROM con derechos.

## El campo de juego

- **Todo se rompe**: no hay tabla de obstáculos ni estados de daño. Antes de
  dibujarse, cada bala mira los píxeles que tiene delante; si hay algo, se queda
  ahí y arranca un boquete de 6x4 píxeles. Así la carreta, los cactus y los
  barriles se van perforando poco a poco, y una bala nunca atraviesa dos cosas:
  se para en la primera.
- **Barriles de whisky**: uno delante de cada pistolero. Sirven de parapeto,
  pero también tapan los propios disparos, así que abrirse una tronera cuesta
  munición. La altura sale a suertes en cada partida, con al menos 64 píxeles
  entre uno y otro para que nunca tapen el mismo pasillo de tiro.
- **Munición**: ocho balas cada uno, dibujadas arriba a los lados del marcador.
  Cada disparo borra una del cinto. Sin balas solo queda esquivar, y cuando los
  dos están secos y no queda nada volando, la partida acaba en empate.
- **Carreta**: asoma por abajo en el centro, sube al píxel (uno cada cuatro
  fotogramas), se recorta contra el borde superior hasta desaparecer, espera un
  rato y vuelve a asomar.
- **Caballo suelto**: pasea por la parte baja con tres posturas del paso
  —cuatro pisadas por ciclo—, entra por un lado y sale por el otro sin parar, y
  de vez en cuando se planta a **pastar**. Al oír un tiro, una de cada cuatro
  veces se **encabrita** sobre las patas traseras. Y si le entra una bala, o
  **embiste** al que le disparó —al que no se aparta a tiempo se lo lleva por
  delante— o sale de estampida: de las dos maneras se pierde de vista y no
  vuelve hasta la partida siguiente.
- **Balas cruzadas**: dos balas que se encuentran de frente se anulan.

## La máquina

En la partida a uno, `actualiza_ia` lleva al bandido. Cada fotograma repasa las
balas que vuelan hacia él y se queda con **la más adelantada de las que le vienen
al cuerpo**: esa es la que hay que esquivar, y se aparta por el lado del que
salga antes —arriba si le apunta a los pies, abajo si le apunta a la cabeza—
salvo que ese lado sea el tope del campo, en cuyo caso tira para el otro. Si está
despejado se pone a la altura del revólver del sheriff, pero antes comprueba que
**su propio barril no le tape la línea de tiro**: si se la tapa, se mueve hasta
rebasarlo en vez de gastar balas contra su parapeto. Para que no sea infalible,
el retardo entre tiros y el punto al que apunta salen del generador
pseudoaleatorio.

## La muerte

Cuando una bala alcanza a un pistolero, **se dobla** en el sitio, **cae al
suelo** y se queda a la vista un momento, para que se entienda de qué murió.
Entonces se para la jugada y entra la cinemática, en pantalla completa y con
bandas negras arriba y abajo:

1. la bala cruzando la pantalla a cámara lenta,
2. corte seco y **primer plano** del alcanzado (48x48 píxeles duplicados a
   96x96) y la bala **atravesándole la cabeza**: entra por un lado, va abriendo
   un boquete de catorce filas y sale por el otro, y del agujero de salida
   saltan las esquirlas del cráneo en abanico,
3. fogonazo —tres inversiones de toda el área de atributos— y
4. el desplome, en dos planos.

Después el **funeral**: suena la **marcha fúnebre** de Chopin (1839, dominio
público) mientras la carreta entra por la izquierda, se detiene junto al cuerpo,
carga el ataúd y se lo lleva fuera de la pantalla. Son unos cinco segundos. Al volver a
la partida los dos recargan el cinto: **ocho balas otra vez** para cada uno, y
las recámaras se vacían: si no, las balas que quedaran volando seguirían su
camino al reanudar y matarían otra vez nada más empezar.

El decorado no se pierde: antes de despejar la pantalla se guardan los trozos de
memoria de vídeo del decorado y los barriles, y al acabar se reponen **con los
agujeros que ya tuvieran**.

## Cómo funciona

- **Pantalla**: `scr_addr` traduce (y, columna) a la dirección de la memoria de
  vídeo (`010 Y7Y6 Y2Y1Y0 : Y5Y4Y3 X4X3X2X1X0`) y `down_hl` baja una línea de
  píxeles, que es el bucle interno de todo el dibujado.
- **Logotipo**: banda negra de 32 píxeles de alto sobre la que las letras
  (16x14 píxeles, tabla `logo_letras`) se dibujan con XOR, así que quedan en
  hueco en amarillo sin necesidad de una segunda imagen.
- **Sprites**: los pistoleros miden 24x32 píxeles (3 columnas de caracteres por
  32 filas) y se vuelcan con `dibuja_bloque`, una rutina genérica que sirve
  igual para el decorado (cactus de 16x32, carreta de 24x28, barril de 16x32).
  Al moverse se redibujan y se borra solo la fila que dejan libre, así que no
  parpadean ni hace falta doble búfer. `dibuja_doble` es la misma idea con cada
  bit repetido, y es la que pinta los planos de la cinemática al doble de
  tamaño.
- **Movimiento fino**: todo se mueve a nivel de píxel, nunca a saltos de
  carácter. En vertical basta con cambiar la fila de arranque (un píxel por
  fotograma). En horizontal hace falta desplazar los bytes: al arrancar,
  `genera_desplazados` construye en RAM las **ocho copias** de la
  carreta, el ataúd y la bala del primer plano (una por cada desplazamiento de 0
  a 7 píxeles) rotando los bytes de cada fila con `srl`/`rr`, y luego mover un
  píxel es solo elegir la copia que toca. El sprite lleva un byte en blanco a
  cada lado, así que la columna que abandona queda borrada sola y no deja
  rastro. Las balas usan la misma idea en pequeño: el patrón de 4 píxeles se
  desplaza dentro de una pareja de bytes.
- **Choques**: no hay tablas de rectángulos. `mira_bala` lee los píxeles de la
  memoria de vídeo donde va a caer la bala y, si hay algo, `abre_agujero` los
  borra con un AND: un puñado de bytes que valen igual para el decorado, los
  barriles y el caballo, y que hacen que todo se perfore poco a poco. Lo único
  que se mira aparte es si la bala se paró dentro del recuadro del caballo, para
  que el animal reaccione.
- **Balas**: cada jugador tiene un juego de cuatro ranuras (x, y, activa);
  disparar busca la primera libre, así que se puede tirar sin esperar a la
  anterior. Son bloques de 4x2 píxeles que avanzan 3 píxeles por fotograma y se
  dibujan con XOR, por lo que se borran solas. Cada fotograma se borran todas
  antes de mover a los pistoleros —si no, una bala se vería a sí misma al mirar
  los píxeles de delante— y se vuelven a pintar al final.
- **El funeral por dentro**: `guarda_decorado` copia a un buffer los trozos de
  memoria de vídeo del decorado y los barriles, `limpia_campo` despeja el
  terreno, la escena se anima al ritmo de la música y `restaura_decorado` lo
  repone todo con sus agujeros.
- **Colores**: toda el área de atributos a `PAPER 6 / INK 0` (`0x30`) y borde
  amarillo, así que no hay *attribute clash* posible. El fogonazo de la
  cinemática invierte tinta y papel de todas las celdas y las deja como estaban.
- **Teclado**: lectura directa del puerto `0xFE` por semifilas; el menú lee las
  ocho a la vez con el byte alto a 0 para el «pulsa cualquier tecla».
- **Música**: la lleva el **AY-3-8912** del 128K, por los puertos `0xFFFD`
  (registro) y `0xBFFD` (dato). El reproductor, `ay_tick`, se llama una vez por
  fotograma y no bloquea nada, así que la música suena mientras se juega. Cada
  canción son **tres voces**: melodía en el canal A, bajo en el B y acordes en
  el C, cada una una lista de (periodo, duración) que se recorre en bucle. El
  periodo sale de `1773400 / (16*f)` y el volumen decae en cada nota, que da el
  punteo. Los efectos —disparo, rebote, rotura, impacto— se quedan con el canal
  C: le meten ruido y un volumen que cae, y al terminar devuelven los acordes.
  Hay tres canciones y cada una suena en su sitio: **Oh! Susanna** en el menú,
  la **marcha fúnebre** de Chopin desde el momento en que a alguien le dan hasta
  que la carreta se lleva el ataúd, y una **marcha lenta en re menor**, escrita
  para los créditos, mientras sube el texto. **Durante la partida no hay música**:
  solo se oyen los disparos, los rebotes y los impactos, que se cuelan por el
  canal C sin pasar por el reproductor. Al volver al menú, Oh! Susanna otra vez.

  La melodía entra a volumen 15 y el acompañamiento a 13 y 11, para que no la
  tape, y cada canción dice cuánto tarda una nota en apagarse: el menú a 2
  fotogramas por escalón de volumen, muy punteado, y los créditos a 5, para que
  las notas largas se sostengan.

  Cada voz se reproduce por su lado y vuelve a empezar al llegar a su final, así
  que **las tres tienen que durar exactamente lo mismo**: si no, a la segunda
  vuelta el bajo y el arpegio suenan contra la melodía. Por eso el bajo y el
  arpegio no se escriben a mano, los saca `tools/musica.py` de la propia melodía:
  le asigna un acorde a cada nota, junta los que se repiten y rellena cada tramo
  con la raíz y con las notas del acorde en rueda. De la de los créditos, que es
  original, lleva también la melodía y la lista de acordes escritas a mano. `build.sh` no compila si las
  tres voces de una canción no cuadran, y las pruebas comprueban además que al
  cabo de una vuelta entera el AY vuelve al mismo estado.
- **Ritmo**: `HALT` en el bucle principal sincroniza el juego a los 50 Hz de la
  interrupción, y los textos se imprimen con el juego de caracteres de la ROM
  (`0x3C00 + código*8`) sin depender de las rutinas de canales del BASIC.

## Ficheros

    src/balava.asm          codigo fuente Z80 (pasmo)
    .claude/skills/zx-spectrum/  lo aprendido aqui, para el proximo juego
    web/z80.js              nucleo Z80 + ULA + AY en JavaScript
    web/balava.html         plantilla de la pagina del emulador
    arte/autor.png          la foto del autor, para los creditos
    tools/pantalla_carga.py compone la pantalla de carga sin colour clash
    tools/foto.py           trama la foto a un bit para la pantalla de creditos
    tools/musica.py         saca el bajo y el arpegio de cada melodia
    tools/rom.py            la ROM sintetica (interrupcion y juego de caracteres)
    tools/make_z80.py       genera el snapshot .z80 de 128K a partir del binario
    tools/web.py            arma dist/balava-web.html con todo dentro
    tools/probar.py         pruebas sobre el Z80 de referencia
    tools/estado.py         guion y estado esperado para comparar emuladores
    tools/probar_web.js     repite el guion con el nucleo de JavaScript
    tools/grabar.py         graba un video de una partida
    build.sh                ensambla y genera todo lo de dist/
    dist/                   snapshot, pantalla de carga y pagina web

---

(C) 2026 **Kbza Soft** — Alejandro Martinez
