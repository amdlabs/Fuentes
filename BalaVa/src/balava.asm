;=====================================================================
;  B A L A V A   -  ZX Spectrum 128K  -  1 o 2 jugadores
;---------------------------------------------------------------------
;  Duelo en el oeste: el sheriff (izquierda) y el bandido (derecha) se
;  disparan de lado a lado.  Solo pueden moverse arriba y abajo para
;  esquivar las balas, y la carreta, los cactus, los barriles de whisky
;  y el caballo suelto paran los disparos: hay que buscar el hueco.
;  Ocho balas cada uno, hasta cuatro en el aire a la vez; cuando los dos
;  se quedan secos se acaba la partida.  A un jugador, el bandido lo
;  lleva la maquina.  La musica va por el AY, a tres voces.
;  Fondo amarillo (PAPER 6), sprites en negro (INK 0).
;
;  Controles:
;     Jugador 1 - SHERIFF : Q = arriba   A = abajo   Z = disparo
;     Jugador 2 - BANDIDO : P = arriba   L = abajo   B = disparo
;
;  Ensamblar con:  pasmo --bin src/balava.asm build/balava.bin
;=====================================================================

SCREEN      EQU 0x4000              ; memoria de pantalla
ATTRS       EQU 0x5800              ; area de atributos
FONT        EQU 0x3C00              ; juego de caracteres de la ROM

PAPEL       EQU 6                   ; amarillo
TINTA       EQU 0                   ; negro
ATTR_JUEGO  EQU (PAPEL*8)+TINTA     ; = 0x30

COL_P1      EQU 1                   ; primera columna del sheriff (x = 8)
COL_P2      EQU 28                  ; primera columna del bandido (x = 224)
ANCHO_JUG   EQU 3                   ; 24 pixeles de ancho
ALTO_SPR    EQU 32                  ; 32 pixeles de alto

MIN_Y       EQU 18                  ; limite superior del campo de juego
MAX_Y       EQU 160                 ; limite inferior (160 + 31 = 191)
VEL_JUG     EQU 1                   ; pixeles por fotograma (movimiento fino)

P1_INI_Y    EQU 40
P2_INI_Y    EQU 120

VEL_BALA    EQU 3                   ; pixeles por fotograma
NUM_BALAS   EQU 4                   ; balas de cada uno en el aire a la vez
MUNICION    EQU 8                   ; y cuantas lleva en el cinto
BALA_DY     EQU 13                  ; altura del revolver dentro del sprite
BAL_INI_1   EQU 32                  ; x de salida de la bala del sheriff
BAL_FIN_1   EQU 224                 ; x donde alcanza al bandido
BAL_INI_2   EQU 220                 ; x de salida de la bala del bandido
BAL_FIN_2   EQU 28                  ; x donde alcanza al sheriff

; --- decorado (tambien para la tabla de obstaculos) -------------------
CARRETA_COL EQU 14                  ; x = 112 .. 135, sube por el centro
CARRETA_ALTO EQU 28
CARRETA_ABAJO EQU 163               ; por donde asoma
CARRETA_LENTO EQU 4                 ; un pixel cada 4 fotogramas
CACTUS_ALTO EQU 32
CACTUS1_COL EQU 8                   ; x =  64 ..  79
CACTUS1_Y   EQU 100                 ; y = 100 .. 131
CACTUS2_COL EQU 21                  ; x = 168 .. 183
CACTUS2_Y   EQU 60                  ; y =  60 ..  91

; --- barriles de whisky (uno delante de cada pistolero) ---------------
CAJA1_COL   EQU 5                   ; x =  40 ..  55
CAJA2_COL   EQU 25                  ; x = 200 .. 215
CAJA_ALTO   EQU 32                  ; su altura sale a suertes cada partida

; --- el caballo suelto ----------------------------------------------
CAB_ANCHO   EQU 7                   ; 56 pixeles: 40 de caballo y un byte
CAB_ALTO    EQU 32                  ; en blanco a cada lado
CAB_BYTES   EQU CAB_ANCHO*CAB_ALTO
CAB_PASOS   EQU 3                   ; posturas del paso
CAB_RITMO   EQU 6                   ; fotogramas por pisada
CAB_Y       EQU 158                 ; pisando el suelo
CAB_MAX     EQU 200                 ; 256 - 56
CAB_CUERPO  EQU 40                  ; lo que ocupa de verdad
CAB_MORRO   EQU 48
CAB_PASEA   EQU 0                   ; sus estados
CAB_EMBISTE EQU 1
CAB_HUYE    EQU 2
CAB_PASTA   EQU 3
CAB_ALZA    EQU 4
CAB_IDO     EQU 5

; --- la escena del funeral -------------------------------------------
CARRETA_ANCHO EQU 5                 ; la carreta con margenes, 40 pixeles
CARRETA_BYTES EQU CARRETA_ANCHO*CARRETA_ALTO
ATAUD_ALTO  EQU 16
ATAUD_ANCHO EQU 5
ATAUD_BYTES EQU ATAUD_ANCHO*ATAUD_ALTO
ESC_CARRETA_Y EQU 108               ; la carreta cruza por aqui
ESC_ATAUD_Y EQU 92                  ; el ataud va encima de ella
ESC_CUERPO_Y EQU 120                ; el caido espera en el suelo
ESC_CUERPO_COL EQU 17
ESC_PASO    EQU 1                   ; pixeles por fotograma
ESC_PARADA  EQU 104                 ; donde recoge el ataud
ESC_FIN     EQU 216                 ; y por donde se va

; --- la pantalla de creditos -----------------------------------------
MQ_Y        EQU 168                 ; la marquesina, al pie de la foto
MQ_ALTO     EQU 16                  ; dos filas: el juego de caracteres, doble

; --- memoria de trabajo (fuera del binario) --------------------------
BUF_TEXTO   EQU 0xC000              ; la marquesina, 16 filas de 32 bytes
BUF_VENTANA EQU 0xC200              ; y la franja de foto de debajo, otro tanto
BUF_CABALLO EQU 0xC400              ; el caballo: tres posturas del paso, cada
BUF_QUIETO  EQU BUF_CABALLO+CAB_BYTES*8*CAB_PASOS   ; una en ocho desplazamientos
BUF_ESPEJO  EQU BUF_QUIETO+CAB_BYTES                ; (por encima de los creditos:
BUF_CARRETA EQU 0xE000              ; nada de compartir sitio con nadie)
BUF_ATAUD   EQU BUF_CARRETA+CARRETA_BYTES*8
BALAZO_ANCHO EQU 5                  ; la bala en primer plano, con margenes
BALAZO_ALTO EQU 8
BALAZO_BYTES EQU BALAZO_ANCHO*BALAZO_ALTO
BUF_BALAZO  EQU BUF_ATAUD+ATAUD_BYTES*8
BUF_DECORADO EQU BUF_BALAZO+BALAZO_BYTES*8        ; copia del decorado
CARA_ANCHO  EQU 6                   ; el primer plano, 48x48

PUNTOS_WIN  EQU 5                   ; impactos para ganar la partida

            ORG 0x8000

;=====================================================================
; ARRANQUE
;=====================================================================
inicio:
            di
            ld      sp,0xFF00
            ld      iy,0x5C3A               ; la RST 38 de la ROM usa IY
            call    init_sysvars
            ld      a,CARRETA_ANCHO
            ld      (gen_ancho),a
            ld      a,CARRETA_ALTO
            ld      (gen_alto),a
            ld      hl,spr_carreta_m
            ld      de,BUF_CARRETA
            call    genera_desplazados
            ld      a,ATAUD_ANCHO
            ld      (gen_ancho),a
            ld      a,ATAUD_ALTO
            ld      (gen_alto),a
            ld      hl,spr_ataud_m
            ld      de,BUF_ATAUD
            call    genera_desplazados
            ld      a,BALAZO_ANCHO
            ld      (gen_ancho),a
            ld      a,BALAZO_ALTO
            ld      (gen_alto),a
            ld      hl,spr_balazo_m
            ld      de,BUF_BALAZO
            call    genera_desplazados
            call    ay_init
            im      1
            ei
            ; la pantalla de carga ya viene dibujada en el snapshot: se
            ; queda a la vista hasta que el jugador pulse una tecla
            xor     a
            out     (0xFE),a                ; borde negro, a juego con ella
            call    espera_tecla

main:
            call    menu
            call    partida
            jr      main

;---------------------------------------------------------------------
; Deja las variables del sistema que toca la interrupcion de la ROM
; en un estado valido (el snapshot arranca con la RAM a cero).
;---------------------------------------------------------------------
init_sysvars:
            ld      a,0xFF
            ld      (0x5C00),a              ; KSTATE 0 = libre
            ld      (0x5C04),a              ; KSTATE 4 = libre
            xor     a
            ld      (0x5C3B),a              ; FLAGS
            ld      (0x5C41),a              ; MODE
            ld      a,35
            ld      (0x5C09),a              ; REPDEL
            ld      a,5
            ld      (0x5C0A),a              ; REPPER
            ret

;=====================================================================
; PARTIDA
;=====================================================================
partida:
            xor     a
            ld      (puntos1),a
            ld      (puntos2),a

            call    prepara_caballo         ; cada partida, un caballo nuevo
            call    coloca_barriles         ; y los barriles en otro sitio
            ld      a,MUNICION
            ld      (balas1),a
            ld      (balas2),a
            ld      a,CARRETA_ABAJO
            ld      (carreta_y),a
            call    calla_musica            ; se juega sin musica de fondo
            call    limpia_balas
            call    limpia_pantalla
            call    dibuja_marcador
            call    dibuja_escenario
            call    dibuja_cajas
            call    dibuja_caballo
            call    dibuja_carreta
            call    hud_puntos
            call    hud_municion
            call    coloca_jugadores

bucle:
            halt                            ; sincroniza a 50 Hz
            call    ay_tick                 ; un fotograma de musica
            call    borra_balas             ; primero se quitan todas de en
            call    actualiza_p1            ; medio (asi no se estorban al
            ld      a,(modo_ia)             ; mirar los pixeles), luego se
            or      a
            call    z,actualiza_p2
            ld      a,(modo_ia)
            or      a
            call    nz,actualiza_ia
            call    mueve_balas             ; mueven y al final se pintan
            call    pinta_balas             ; las que sigan vivas
            call    actualiza_caballo
            call    actualiza_carreta

            ld      a,(puntos1)
            cp      PUNTOS_WIN              ; NC, no Z: si por lo que sea se
            jr      nc,gana_poli            ; salta un tanto, tambien acaba
            ld      a,(puntos2)
            cp      PUNTOS_WIN
            jp      nc,gana_ladron
            call    quedan_balas            ; ¿se acabo la municion?
            jr      nz,bucle
            ld      a,(puntos1)
            ld      hl,puntos2
            cp      (hl)
            jr      c,gana_ladron
            jp      z,fin_empate
gana_poli:

            ld      hl,txt_gana_poli
            ld      c,8
            jr      fin_partida
fin_empate:
            ld      hl,txt_empate
            ld      c,10
            jr      fin_partida
gana_ladron:
            ld      hl,txt_gana_ladron
            ld      c,8
fin_partida:
            push    hl
            push    bc
            call    calla_musica            ; que no se quede el AY zumbando
            call    limpia_pantalla
            pop     bc
            pop     hl
            ld      b,9
            call    print_str               ; "GANA EL ..."
            ld      hl,txt_final
            ld      b,12
            ld      c,10
            call    print_str               ; "RESULTADO"
            ld      a,(puntos1)
            add     a,'0'
            ld      b,12
            ld      c,20
            call    print_char
            ld      a,'-'
            ld      b,12
            ld      c,21
            call    print_char
            ld      a,(puntos2)
            add     a,'0'
            ld      b,12
            ld      c,22
            call    print_char
            ld      hl,txt_tecla
            ld      b,16
            ld      c,5
            call    print_str
            call    espera_tecla
            ret

;---------------------------------------------------------------------
; Coloca a los dos jugadores en su posicion de salida y los dibuja
;---------------------------------------------------------------------
coloca_jugadores:
            ld      a,P1_INI_Y
            ld      (p1_y),a
            ld      c,COL_P1
            ld      de,spr_poli
            call    dibuja_jugador
            ld      a,P2_INI_Y
            ld      (p2_y),a
            ld      c,COL_P2
            ld      de,spr_ladron
            jp      dibuja_jugador

;=====================================================================
; JUGADOR 1 - SHERIFF   (Q arriba / A abajo / Z dispara)
;=====================================================================
actualiza_p1:
            ld      bc,0xFBFE               ; fila Q W E R T
            in      a,(c)
            and     %00000001               ; Q
            jr      nz,ap1_no_sube
            ld      a,(p1_y)
            ld      c,COL_P1
            ld      de,spr_poli
            call    sube
            ld      (p1_y),a
            jr      ap1_tiro
ap1_suelta:
            xor     a
            ld      (tecla1),a
            ret

ap1_no_sube:
            ld      bc,0xFDFE               ; fila A S D F G
            in      a,(c)
            and     %00000001               ; A
            jr      nz,ap1_tiro
            ld      a,(p1_y)
            ld      c,COL_P1
            ld      de,spr_poli
            call    baja
            ld      (p1_y),a
ap1_tiro:
            ld      bc,0xFEFE               ; fila CAPS Z X C V
            in      a,(c)
            and     %00000010               ; Z
            jr      nz,ap1_suelta
            ld      a,(tecla1)              ; un tiro por pulsacion
            or      a
            ret     nz
            ld      a,1
            ld      (tecla1),a
            jp      dispara1

;=====================================================================
; JUGADOR 2 - BANDIDO   (P arriba / L abajo / B dispara)
;=====================================================================
actualiza_p2:
            ld      bc,0xDFFE               ; fila P O I U Y
            in      a,(c)
            and     %00000001               ; P
            jr      nz,ap2_no_sube
            ld      a,(p2_y)
            ld      c,COL_P2
            ld      de,spr_ladron
            call    sube
            ld      (p2_y),a
            jr      ap2_tiro
ap2_no_sube:
            ld      bc,0xBFFE               ; fila ENTER L K J H
            in      a,(c)
            and     %00000010               ; L
            jr      nz,ap2_tiro
            ld      a,(p2_y)
            ld      c,COL_P2
            ld      de,spr_ladron
            call    baja
            ld      (p2_y),a
ap2_tiro:
            ld      bc,0x7FFE               ; fila SPACE SYM M N B
            in      a,(c)
            and     %00010000               ; B
            jr      nz,ap2_suelta
            ld      a,(tecla2)
            or      a
            ret     nz
            ld      a,1
            ld      (tecla2),a
            jp      dispara2
ap2_suelta:
            xor     a
            ld      (tecla2),a
            ret

;=====================================================================
; LAS BALAS
;   Cada jugador lleva NUM_BALAS ranuras (x, y, activa) y MUNICION tiros
;   en el cinto.  Se puede disparar con otras balas en el aire: ninguna
;   pisa a la anterior.  El ciclo va en tres pasadas para que al mirar
;   los pixeles no se vean unas balas a otras.
;=====================================================================
limpia_balas:
            ld      hl,b1
            ld      de,b1+1
            ld      bc,NUM_BALAS*3*2-1
            ld      (hl),0
            ldir
            ret

;---------------------------------------------------------------------
; dispara1 / dispara2 - saca una bala si queda hueco y municion
;---------------------------------------------------------------------
dispara1:
            ld      a,(balas1)
            or      a
            ret     z                       ; sin municion, a esquivar
            ld      hl,b1
            call    busca_hueco
            ret     c                       ; las cuatro en el aire
            ld      a,BAL_INI_1
            ld      (hl),a
            inc     hl
            ld      a,(p1_y)
            add     a,BALA_DY
            ld      (hl),a
            inc     hl
            ld      (hl),1
            ld      hl,balas1
            dec     (hl)
            call    hud_municion
            call    caballo_oye_tiro
            jp      sonido_tiro

dispara2:
            ld      a,(balas2)
            or      a
            ret     z
            ld      hl,b2
            call    busca_hueco
            ret     c
            ld      a,BAL_INI_2
            ld      (hl),a
            inc     hl
            ld      a,(p2_y)
            add     a,BALA_DY
            ld      (hl),a
            inc     hl
            ld      (hl),1
            ld      hl,balas2
            dec     (hl)
            call    hud_municion
            call    caballo_oye_tiro
            jp      sonido_tiro

;---------------------------------------------------------------------
; busca_hueco - HL = primera ranura libre;  carry = no queda ninguna
;---------------------------------------------------------------------
busca_hueco:
            ld      b,NUM_BALAS
bh_ranura:
            inc     hl
            inc     hl
            ld      a,(hl)
            dec     hl
            dec     hl
            or      a
            ret     z
            ld      de,3
            add     hl,de
            djnz    bh_ranura
            scf
            ret

;---------------------------------------------------------------------
; quedan_balas - Z si no queda municion ni balas en el aire
;---------------------------------------------------------------------
quedan_balas:
            ld      a,(balas1)
            ld      hl,balas2
            or      (hl)
            ret     nz
            ld      hl,b1                   ; ¿y en el aire?
            call    qb_pool
            ret     nz
            ld      hl,b2
qb_pool:
            ld      b,NUM_BALAS
qb_ranura:
            inc     hl
            inc     hl
            ld      a,(hl)
            or      a
            ret     nz
            inc     hl
            djnz    qb_ranura
            ret                             ; Z: ninguna viva

;---------------------------------------------------------------------
; borra_balas / pinta_balas - las quita o las pone todas
;---------------------------------------------------------------------
borra_balas:
pinta_balas:
            ld      hl,b1
            call    bp_pool
            ld      hl,b2
bp_pool:
            ld      b,NUM_BALAS
bp_ranura:
            push    bc
            push    hl
            inc     hl
            inc     hl
            ld      a,(hl)
            or      a
            jr      z,bp_sig
            dec     hl
            ld      b,(hl)                  ; y
            dec     hl
            ld      a,(hl)                  ; x
            call    bala_xor
bp_sig:
            pop     hl
            ld      de,3
            add     hl,de
            pop     bc
            djnz    bp_ranura
            ret

;---------------------------------------------------------------------
; mueve_balas - avanza cada bala y mira contra que choca
;---------------------------------------------------------------------
mueve_balas:
            ld      a,1                     ; las del sheriff, a la derecha
            ld      (bal_sent),a
            ld      hl,b1
            call    mb_pool
            xor     a                       ; las del bandido, a la izquierda
            ld      (bal_sent),a
            ld      hl,b2
mb_pool:
            ld      b,NUM_BALAS
mb_ranura:
            push    bc
            push    hl
            inc     hl
            inc     hl
            ld      a,(hl)
            or      a
            jr      z,mb_sig
            pop     hl
            push    hl
            call    mueve_una
mb_sig:
            pop     hl
            ld      de,3
            add     hl,de
            pop     bc
            djnz    mb_ranura
            ret

;---------------------------------------------------------------------
; mueve_una - una bala:  HL = ranura (x, y, activa)
;---------------------------------------------------------------------
mueve_una:
            ld      (bal_ranura),hl
            ld      a,(bal_sent)
            or      a
            jr      z,mu_izquierda
            ld      a,(hl)                  ; hacia la derecha
            add     a,VEL_BALA
            ld      (hl),a
            cp      BAL_FIN_1
            jr      c,mu_sigue
            ld      hl,p2_y                 ; ha llegado al bandido
            jr      mu_llega
mu_izquierda:
            ld      a,(hl)
            sub     VEL_BALA
            ld      (hl),a
            cp      BAL_FIN_2+1
            jr      nc,mu_sigue
            ld      hl,p1_y                 ; ha llegado al sheriff
mu_llega:
            ld      c,(hl)                  ; C = y del rival
            call    mu_apaga
            ld      hl,(bal_ranura)
            inc     hl
            ld      a,(hl)                  ; y de la bala
            inc     a
            sub     c
            ret     c                       ; le pasa por encima
            cp      ALTO_SPR+1
            ret     nc                      ; o por debajo
            ld      a,(bal_sent)
            or      a
            jp      nz,impacto_ladron
            jp      impacto_poli
mu_sigue:
            ld      hl,(bal_ranura)
            inc     hl
            ld      b,(hl)                  ; y
            dec     hl
            ld      a,(hl)                  ; x
            call    mira_bala               ; ¿hay algo delante?
            ret     nc
            ld      hl,(bal_ranura)
            inc     hl
            ld      b,(hl)
            dec     hl
            ld      a,(hl)
            call    abre_agujero            ; le arranca unos pixeles
            ld      hl,(bal_ranura)
            inc     hl
            ld      b,(hl)
            dec     hl
            ld      a,(hl)
            call    mira_caballo            ; ¿le ha dado al caballo?
            call    mu_apaga
            jp      sonido_rebote

mu_apaga:
            ld      hl,(bal_ranura)
            inc     hl
            inc     hl
            ld      (hl),0
            ret

;=====================================================================
; IMPACTOS
;=====================================================================
impacto_ladron:                             ; cae el bandido
            ld      hl,puntos1
            inc     (hl)
            ld      a,(p2_y)
            ld      c,COL_P2
            jr      impacto_comun
impacto_poli:                               ; cae el sheriff
            ld      hl,puntos2
            inc     (hl)
            ld      a,(p1_y)
            ld      c,COL_P1
impacto_comun:                              ; A = y del caido, C = su columna
            ld      (caido_y),a
            ld      a,c
            ld      (caido_col),a
            call    hud_puntos              ; el tanteo sube al momento
            call    sonido_impacto
            ld      a,(caido_col)           ; se cae redondo donde estaba
            ld      c,a
            ld      a,(caido_y)
            ld      b,ALTO_SPR
            call    borra_jugador
            ld      a,ANCHO_JUG
            ld      (ancho_bloque),a
            ld      a,(caido_col)           ; primero se dobla
            ld      c,a
            ld      a,(caido_y)
            ld      de,spr_cayendo
            ld      b,ALTO_SPR
            call    dibuja_bloque
            ld      b,20
ic_dobla:
            halt
            call    ay_tick
            djnz    ic_dobla
            ld      a,(caido_col)           ; y da con los huesos en el suelo
            ld      c,a
            ld      a,(caido_y)
            ld      b,ALTO_SPR
            call    borra_jugador
            ld      a,ANCHO_JUG
            ld      (ancho_bloque),a
            ld      a,(caido_col)
            ld      c,a
            ld      a,(caido_y)
            add     a,ALTO_SPR-16
            ld      de,spr_muerto
            ld      b,16
            call    dibuja_bloque
            ld      b,30
ic_ve:
            halt
            call    ay_tick
            djnz    ic_ve
            call    borra_balas             ; las que quedaran en el aire, fuera
            call    limpia_balas            ; y las dos recamaras, a cero: si no,
ic_funeral:                                 ; al volver siguen volando y matan
            call    guarda_decorado         ; con los agujeros de ahora
            ld      hl,cancion_funeral      ; la marcha entra ya con el cine
            call    pon_cancion
            call    cinematica              ; la muerte, en pantalla grande
            call    funeral
            call    calla_musica            ; y se sigue jugando en silencio
            ld      a,MUNICION              ; con el cinto lleno otra vez
            ld      (balas1),a
            ld      (balas2),a
            call    limpia_pantalla
            call    dibuja_marcador
            call    hud_puntos
            call    hud_municion
            call    restaura_decorado
            call    dibuja_carreta
            call    coloca_jugadores
            call    prepara_caballo         ; y vuelve a asomar el caballo
            call    dibuja_caballo
            ld      b,25
ic_pausa:
            halt
            call    ay_tick
            djnz    ic_pausa
            ret

;=====================================================================
; EL FUNERAL
;=====================================================================
;---------------------------------------------------------------------
; funeral - se para la jugada: suena la marcha funebre mientras la
;   carreta entra, carga el ataud y se lo lleva fuera de la pantalla.
;   Son unos cinco segundos.  El decorado se guarda antes y se repone
;   despues, con los agujeros que ya tuviera.
;---------------------------------------------------------------------
funeral:
            call    limpia_todo
            call    dibuja_marcador
            ld      hl,txt_rip
            ld      b,5
            ld      c,8
            call    print_str
            ld      a,ANCHO_JUG             ; el caido, en el suelo
            ld      (ancho_bloque),a
            ld      a,ESC_CUERPO_Y
            ld      c,ESC_CUERPO_COL
            ld      de,spr_muerto
            ld      b,16
            call    dibuja_bloque
            xor     a
            ld      (esc_x),a
fun_ida:                                    ; la carreta entra por la izquierda
            halt
            call    ay_tick
            call    dibuja_carreta_esc
            ld      a,(esc_x)
            add     a,ESC_PASO
            ld      (esc_x),a
            cp      ESC_PARADA
            jr      c,fun_ida
            ld      b,40                    ; se para a cargar
fun_carga:
            push    bc
            halt
            call    ay_tick
            pop     bc
            djnz    fun_carga
            ld      a,ANCHO_JUG
            ld      (ancho_bloque),a
            ld      a,ESC_CUERPO_Y
            ld      c,ESC_CUERPO_COL
            ld      b,16
            call    borra_bloque            ; ya va dentro del ataud
fun_vuelta:                                 ; y se lo lleva
            halt
            call    ay_tick
            call    dibuja_carreta_esc
            call    dibuja_ataud_esc
            ld      a,(esc_x)
            add     a,ESC_PASO
            ld      (esc_x),a
            cp      ESC_FIN
            jr      c,fun_vuelta
            jp      limpia_todo

dibuja_carreta_esc:
            ld      a,(esc_x)
            ld      (mov_x),a
            ld      a,ESC_CARRETA_Y
            ld      (mov_y),a
            ld      a,CARRETA_ANCHO
            ld      (ancho_bloque),a
            ld      a,CARRETA_ALTO
            ld      (mov_alto),a
            ld      hl,BUF_CARRETA
            ld      de,CARRETA_BYTES
            jp      dibuja_movil

dibuja_ataud_esc:
            ld      a,(esc_x)
            ld      (mov_x),a
            ld      a,ESC_ATAUD_Y
            ld      (mov_y),a
            ld      a,ATAUD_ANCHO
            ld      (ancho_bloque),a
            ld      a,ATAUD_ALTO
            ld      (mov_alto),a
            ld      hl,BUF_ATAUD
            ld      de,ATAUD_BYTES
            jp      dibuja_movil

;---------------------------------------------------------------------
; limpia_campo - borra el terreno de juego y deja el marcador
;---------------------------------------------------------------------
limpia_campo:
            ld      a,MIN_Y
            ld      c,0
            call    scr_addr
            ld      b,192-MIN_Y
lcampo_fila:
            push    bc
            push    hl
            ld      b,32
lcampo_col:
            ld      (hl),0
            inc     l
            djnz    lcampo_col
            pop     hl
            call    down_hl
            pop     bc
            djnz    lcampo_fila
            ret

;---------------------------------------------------------------------
; guarda_decorado / restaura_decorado - copian los trozos de pantalla
;   del decorado a un buffer y al reves, para que el funeral no borre
;   los agujeros que las balas le hayan hecho
;---------------------------------------------------------------------
guarda_decorado:
            ld      a,1
            jr      copia_decorado
restaura_decorado:
            xor     a
copia_decorado:                             ; A = 1 guardar, 0 restaurar
            ld      (dec_modo),a
            ld      hl,decorado
            ld      (dec_tabla),hl
            ld      hl,BUF_DECORADO
            ld      (dec_buf),hl
cd_pieza:
            ld      hl,(dec_tabla)
            ld      a,(hl)
            or      a
            ret     z                       ; fin de la tabla
            ld      c,(hl)                  ; columna
            inc     hl
            ld      d,(hl)                  ; y
            inc     hl
            ld      b,(hl)                  ; filas
            inc     hl
            ld      a,(hl)                  ; ancho
            ld      (dec_ancho),a
            inc     hl
            ld      (dec_tabla),hl
            ld      a,d
            call    scr_addr
cd_fila:
            push    bc
            ld      a,(dec_ancho)
            ld      b,a
            ld      de,(dec_buf)
cd_byte:
            ld      a,(dec_modo)
            or      a
            jr      z,cd_repone
            ld      a,(hl)                  ; guardar
            ld      (de),a
            jr      cd_sigue
cd_repone:
            ld      a,(de)                  ; reponer
            ld      (hl),a
cd_sigue:
            inc     de
            inc     l
            djnz    cd_byte
            ld      (dec_buf),de
            ld      a,(dec_ancho)           ; al principio de la fila
            ld      e,a
            ld      a,l
            sub     e
            ld      l,a
            call    down_hl
            pop     bc
            djnz    cd_fila
            jr      cd_pieza

;=====================================================================
; MOVIMIENTO DE UN JUGADOR;=====================================================================
; MOVIMIENTO DE UN JUGADOR
;   entrada: A = y actual, C = columna, DE = sprite
;   salida : A = y nueva
;=====================================================================
sube:
            cp      MIN_Y+VEL_JUG
            ret     c                       ; ya esta arriba del todo
            sub     VEL_JUG
            push    af
            call    dibuja_jugador
            pop     af
            push    af
            add     a,ALTO_SPR              ; borra las filas que deja libres
            ld      b,VEL_JUG
            call    borra_jugador
            pop     af
            ret

baja:
            cp      MAX_Y
            ret     nc                      ; ya esta abajo del todo
            add     a,VEL_JUG
            push    af
            call    dibuja_jugador
            pop     af
            push    af
            sub     VEL_JUG
            ld      b,VEL_JUG
            call    borra_jugador
            pop     af
            ret

;=====================================================================
; LA MUERTE, EN PANTALLA COMPLETA
;   Cortes secos como en las del oeste: la bala a camara lenta, el
;   primer plano del que la recibe, el fogonazo y la caida.
;=====================================================================
cinematica:
            call    limpia_todo
            call    barras_cine
            xor     a                       ; --- plano 1: la bala, despacio
            ld      (esc_x),a
cine_uno:
            halt
            call    ay_tick
            call    pinta_balazo
            ld      a,(esc_x)
            add     a,2
            ld      (esc_x),a
            cp      196
            jr      c,cine_uno
            call    limpia_todo             ; corte
            call    barras_cine
            ld      b,8
cine_corte:
            halt
            call    ay_tick
            djnz    cine_corte
            ld      a,CARA_ANCHO            ; --- plano 2: primer plano
            ld      (ancho_bloque),a
            ld      a,48
            ld      c,5
            ld      de,spr_cara
            ld      b,48
            call    dibuja_doble            ; sale a 96x96
            ld      b,40
cine_dos:
            halt
            call    ay_tick
            djnz    cine_dos
            xor     a                       ; --- la bala atraviesa la cabeza
            ld      (esc_x),a
cine_tres:
            halt
            call    ay_tick
            call    abre_canal              ; se lleva por delante el hueso
            call    pinta_balazo            ; y deja el agujero de lado a lado
            ld      a,(esc_x)
            add     a,2                     ; a camara lenta
            ld      (esc_x),a
            cp      150
            jr      c,cine_tres
            call    sonido_impacto
            call    esquirlas               ; y el craneo suelta pedazos
            ld      b,3                     ; --- fogonazo
cine_flash:
            push    bc
            call    invierte_atributos
            ld      b,4
cine_f1:
            halt
            call    ay_tick
            djnz    cine_f1
            call    invierte_atributos
            ld      b,4
cine_f2:
            halt
            call    ay_tick
            djnz    cine_f2
            pop     bc
            djnz    cine_flash
            call    limpia_todo             ; --- plano 3: se desploma
            call    barras_cine
            ld      a,ANCHO_JUG
            ld      (ancho_bloque),a
            ld      a,40
            ld      c,10
            ld      de,spr_cayendo
            ld      b,ALTO_SPR
            call    dibuja_doble
            ld      b,25
cine_cae:
            halt
            call    ay_tick
            djnz    cine_cae
            call    limpia_todo
            call    barras_cine
            ld      a,ANCHO_JUG
            ld      (ancho_bloque),a
            ld      a,104
            ld      c,10
            ld      de,spr_muerto
            ld      b,16
            call    dibuja_doble
            ld      b,35
cine_fin:
            halt
            call    ay_tick
            djnz    cine_fin
            ret

;---------------------------------------------------------------------
; abre_canal - por donde pasa la bala no queda nada: catorce filas
;   limpias, que es el boquete que va dejando al atravesar la cabeza
;---------------------------------------------------------------------
abre_canal:
            ld      a,(esc_x)
            rrca
            rrca
            rrca
            and     %00011111
            ld      c,a
            ld      a,BALAZO_ANCHO
            ld      (ancho_bloque),a
            ld      b,14
            ld      a,90
            jp      borra_bloque

;---------------------------------------------------------------------
; esquirlas - por donde sale la bala, el craneo salta en pedazos: unos
;   cuantos trozos que se van abriendo en abanico hacia delante
;---------------------------------------------------------------------
NUM_ESQ     EQU 6

esquirlas:
            ld      hl,esq_est              ; todos salen del mismo agujero
            ld      b,NUM_ESQ
esq_pon:
            ld      (hl),140                ; x
            inc     hl
            ld      (hl),96                 ; y
            inc     hl
            djnz    esq_pon
            ld      c,20
esq_frame:
            push    bc
            call    esq_pinta
            halt
            call    ay_tick
            call    esq_pinta               ; XOR: se borran solas
            call    esq_mueve
            pop     bc
            dec     c
            jr      nz,esq_frame
            ret

esq_pinta:
            ld      hl,esq_est
            ld      b,NUM_ESQ
esq_una:
            push    bc
            push    hl
            ld      a,(hl)
            inc     hl
            ld      b,(hl)
            call    bala_xor
            pop     hl
            inc     hl
            inc     hl
            pop     bc
            djnz    esq_una
            ret

esq_mueve:
            ld      hl,esq_est
            ld      de,esq_vel
            ld      b,NUM_ESQ
esq_paso:
            ld      a,(de)                  ; hacia delante
            add     a,(hl)
            ld      (hl),a
            inc     hl
            inc     de
            ld      a,(de)                  ; y abriendose, con signo
            add     a,(hl)
            ld      (hl),a
            inc     hl
            inc     de
            djnz    esq_paso
            ret

esq_vel:         DEFB 4,-3, 5,-2, 5,0, 4,2, 3,3, 5,-1
esq_est:         DEFS NUM_ESQ*2

;---------------------------------------------------------------------
; pinta_balazo - la bala en primer plano, al pixel
;---------------------------------------------------------------------
pinta_balazo:
            ld      a,(esc_x)
            ld      (mov_x),a
            ld      a,96
            ld      (mov_y),a
            ld      a,BALAZO_ANCHO
            ld      (ancho_bloque),a
            ld      a,BALAZO_ALTO
            ld      (mov_alto),a
            ld      hl,BUF_BALAZO
            ld      de,BALAZO_BYTES
            jp      dibuja_movil

;---------------------------------------------------------------------
; limpia_todo - la pantalla entera, marcador incluido
;---------------------------------------------------------------------
limpia_todo:
            ld      hl,SCREEN
            ld      de,SCREEN+1
            ld      bc,6144-1
            ld      (hl),0
            ldir
            ret

;---------------------------------------------------------------------
; barras_cine - las bandas negras de arriba y abajo, formato de cine
;---------------------------------------------------------------------
barras_cine:
            ld      hl,ATTRS
            ld      de,ATTRS+1
            ld      bc,768-1
            ld      (hl),ATTR_JUEGO
            ldir
            ld      hl,ATTRS                ; tres filas arriba
            ld      de,ATTRS+1
            ld      bc,3*32-1
            ld      (hl),0
            ldir
            ld      hl,ATTRS+21*32          ; y tres abajo
            ld      de,ATTRS+21*32+1
            ld      bc,3*32-1
            ld      (hl),0
            ldir
            ret

;---------------------------------------------------------------------
; invierte_atributos - fogonazo: cambia tinta y papel del centro
;---------------------------------------------------------------------
invierte_atributos:
            ld      hl,ATTRS+3*32
            ld      b,18*32/8
inv_grupo:
            push    bc
            ld      b,8
inv_celda:
            ld      a,(hl)
            xor     %00110110               ; 0x30 <-> 0x06
            ld      (hl),a
            inc     hl
            djnz    inv_celda
            pop     bc
            djnz    inv_grupo
            ret

;---------------------------------------------------------------------
; dibuja_doble - vuelca un sprite al doble de tamano
;   entrada: A = y, C = columna, DE = sprite, B = filas,
;            (ancho_bloque) = ancho del original en bytes
;---------------------------------------------------------------------
dibuja_doble:
            call    scr_addr
dd_fila:
            push    bc
            push    de
            push    hl
            ld      a,(ancho_bloque)
            ld      b,a
            ld      hl,dd_buf
dd_exp:
            ld      a,(de)
            inc     de
            push    bc
            push    de
            push    hl
            call    expande                 ; A -> DE, cada bit repetido
            pop     hl
            ld      (hl),d
            inc     hl
            ld      (hl),e
            inc     hl
            pop     de
            pop     bc
            djnz    dd_exp
            pop     hl
            call    dd_vuelca               ; la fila va dos veces
            call    down_hl
            call    dd_vuelca
            call    down_hl
            pop     de
            ld      a,(ancho_bloque)
            add     a,e
            ld      e,a
            jr      nc,dd_sig
            inc     d
dd_sig:
            pop     bc
            djnz    dd_fila
            ret

dd_vuelca:
            push    hl
            push    bc
            ld      a,(ancho_bloque)
            add     a,a
            ld      b,a
            ld      de,dd_buf
dv_byte:
            ld      a,(de)
            ld      (hl),a
            inc     de
            inc     l
            djnz    dv_byte
            pop     bc
            pop     hl
            ret

expande:                                    ; A -> DE con cada bit repetido
            ld      hl,0
            ld      b,8
exp_bit:
            rla
            push    af
            adc     hl,hl
            pop     af
            push    af
            adc     hl,hl
            pop     af
            djnz    exp_bit
            ex      de,hl
            ret

;=====================================================================
; EL BANDIDO JUGADO POR LA MAQUINA
;   Cada fotograma mira las balas que vuelan hacia el y se queda con la
;   mas adelantada de las que le vienen al cuerpo: esa es la que hay que
;   esquivar, y se aparta por el lado que tenga mas cerca, salvo que ese
;   lado sea el tope del campo.  Si esta despejado se pone a la altura
;   del sheriff y dispara, pero antes comprueba que su propio barril no
;   le tape la linea de tiro: si se la tapa, se mueve hasta rebasarlo.
;=====================================================================
actualiza_ia:
            xor     a
            ld      (ia_peor_x),a           ; de momento no le viene ninguna
            ld      hl,b1
            ld      b,NUM_BALAS
ia_bala:
            push    bc
            push    hl
            inc     hl
            inc     hl
            ld      a,(hl)                  ; ¿esta viva?
            or      a
            jr      z,ia_sig
            dec     hl
            ld      c,(hl)                  ; C = y de la bala
            dec     hl
            ld      b,(hl)                  ; B = x de la bala
            ld      a,c
            ld      hl,p2_y
            sub     (hl)
            jr      c,ia_sig                ; le pasa por encima
            cp      ALTO_SPR
            jr      nc,ia_sig               ; o por debajo
            ld      a,(ia_peor_x)           ; ¿mas cerca que la que ya tenia?
            cp      b
            jr      nc,ia_sig
            ld      a,b
            ld      (ia_peor_x),a
            ld      a,c
            ld      (ia_peor_y),a
ia_sig:
            pop     hl
            ld      de,3
            add     hl,de
            pop     bc
            djnz    ia_bala

            ld      a,(ia_peor_x)
            or      a
            jr      z,ia_apunta             ; nada que esquivar

            ld      a,(ia_peor_y)           ; ¿por donde sale antes?
            ld      hl,p2_y
            sub     (hl)
            cp      ALTO_SPR/2
            jr      c,ia_baja_tope          ; le viene a la cabeza: agacharse
            jr      ia_sube_tope            ; a los pies: levantarse

ia_apunta:
            ld      a,(p1_y)                ; despejado: a la altura del otro
            ld      hl,ia_mira              ; cada tiro va a otro punto, asi
            add     a,(hl)                  ; acaba encontrando el hueco
            sub     BALA_DY
            ld      c,a
            ld      a,(p2_y)
            cp      c
            jr      c,ia_baja
            jr      nz,ia_sube
            ld      a,(p2_y)                ; ya esta a tiro: ¿le tapa su
            add     a,BALA_DY               ; propio barril?
            ld      hl,barril2_y
            sub     (hl)
            jr      c,ia_tira               ; la bala sale por encima
            cp      CAJA_ALTO
            jr      nc,ia_tira              ; o por debajo
            call    azar                    ; tapado: mejor probar otra altura
            and     %00011000
            ld      (ia_mira),a
            ret
ia_tira:
            ld      hl,ia_espera
            dec     (hl)
            ret     nz
            call    azar
            and     %00001111
            add     a,12                    ; que no sea infalible
            ld      (ia_espera),a
            call    azar
            and     %00011000               ; 0, 8, 16 o 24
            ld      (ia_mira),a
            jp      dispara2

ia_sube_tope:                               ; subir, si no esta ya arriba
            ld      a,(p2_y)
            cp      MIN_Y+2
            jr      c,ia_baja
            jr      ia_sube
ia_baja_tope:                               ; bajar, si no esta ya abajo
            ld      a,(p2_y)
            cp      MAX_Y-2
            jr      nc,ia_sube
            jr      ia_baja

ia_sube:
            ld      a,(p2_y)
            ld      c,COL_P2
            ld      de,spr_ladron
            call    sube
            ld      (p2_y),a
            ret
ia_baja:
            ld      a,(p2_y)
            ld      c,COL_P2
            ld      de,spr_ladron
            call    baja
            ld      (p2_y),a
            ret

;=====================================================================
; RUTINAS GRAFICAS
;=====================================================================

;---------------------------------------------------------------------
; scr_addr - direccion de pantalla de una fila de pixeles
;   entrada: A = y (0-191)   C = columna (0-31)
;   salida : HL = direccion  (A destruido, BC/DE intactos)
;   HL = 010 Y7Y6 Y2Y1Y0 : Y5Y4Y3 X4X3X2X1X0
;---------------------------------------------------------------------
scr_addr:
            ld      h,a
            and     %00000111
            ld      l,a
            ld      a,h
            and     %11000000
            rrca
            rrca
            rrca
            or      l
            or      %01000000
            ld      l,h
            ld      h,a
            ld      a,l
            and     %00111000
            rlca
            rlca
            or      c
            ld      l,a
            ret

;---------------------------------------------------------------------
; down_hl - baja HL una linea de pixeles (solo destruye A)
;---------------------------------------------------------------------
down_hl:
            inc     h
            ld      a,h
            and     %00000111
            ret     nz
            ld      a,l
            add     a,32
            ld      l,a
            ret     c
            ld      a,h
            sub     8
            ld      h,a
            ret

;---------------------------------------------------------------------
; dibuja_bloque - vuelca un bloque de bytes en pantalla
;   entrada: A = y, C = columna, DE = datos, B = filas,
;            (ancho_bloque) = bytes por fila
;---------------------------------------------------------------------
dibuja_bloque:
            call    scr_addr
dbl_fila:
            push    bc
            push    hl
            ld      a,(ancho_bloque)
            ld      b,a
dbl_col:
            ld      a,(de)
            ld      (hl),a
            inc     de
            inc     l
            djnz    dbl_col
            pop     hl
            call    down_hl
            pop     bc
            djnz    dbl_fila
            ret

;---------------------------------------------------------------------
; borra_bloque - pone a 0 B filas del ancho indicado
;   entrada: A = y, C = columna, B = filas, (ancho_bloque) = ancho
;---------------------------------------------------------------------
borra_bloque:
            call    scr_addr
bbl_fila:
            push    bc
            push    hl
            ld      a,(ancho_bloque)
            ld      b,a
bbl_col:
            ld      (hl),0
            inc     l
            djnz    bbl_col
            pop     hl
            call    down_hl
            pop     bc
            djnz    bbl_fila
            ret

;---------------------------------------------------------------------
; dibuja_jugador / borra_jugador - bloques de 24 pixeles de ancho
;   entrada: A = y, C = columna, DE = sprite (y B = filas al borrar)
;---------------------------------------------------------------------
dibuja_jugador:
            call    ancho_jugador
            ld      b,ALTO_SPR
            jp      dibuja_bloque

borra_jugador:
            call    ancho_jugador
            jp      borra_bloque

ancho_jugador:
            push    af
            ld      a,ANCHO_JUG
            ld      (ancho_bloque),a
            pop     af
            ret

;---------------------------------------------------------------------
; dibuja_escenario - la carreta y los dos cactus del centro
;---------------------------------------------------------------------
dibuja_escenario:
            ld      a,2                     ; los cactus miden 16
            ld      (ancho_bloque),a
            ld      a,CACTUS1_Y
            ld      c,CACTUS1_COL
            ld      de,spr_cactus
            ld      b,CACTUS_ALTO
            call    dibuja_bloque
            ld      a,CACTUS2_Y
            ld      c,CACTUS2_COL
            ld      de,spr_cactus
            ld      b,CACTUS_ALTO
            jp      dibuja_bloque

;---------------------------------------------------------------------
; genera_desplazados - crea las ocho copias de un sprite, una por cada
;   desplazamiento de 0 a 7 pixeles, para poder moverlo pixel a pixel.
;   El sprite lleva un byte en blanco a cada lado, asi que al desplazar
;   no se pierde nada y la columna que abandona ya queda a cero.
;   entrada: HL = sprite original, DE = destino (8 copias seguidas)
;---------------------------------------------------------------------
genera_desplazados:
            xor     a
            ld      (gen_n),a
gd_copia:
            call    gd_una
            ld      a,(gen_n)
            inc     a
            ld      (gen_n),a
            cp      8
            jr      c,gd_copia
            ret

;---------------------------------------------------------------------
; gd_una - una sola copia, la del desplazamiento que haya en gen_n
;---------------------------------------------------------------------
gd_una:
            push    hl
            ld      a,(gen_alto)
            ld      (gen_filas),a
gd_fila:
            xor     a
            ld      (gen_resto),a
            ld      a,(gen_ancho)
            ld      (gen_bytes),a
gd_byte:
            ld      a,(gen_n)
            or      a
            jr      z,gd_sin_desp
            ld      b,a
            ld      a,(hl)
            ld      c,0                     ; C recoge lo que se sale
gd_desp:
            srl     a
            rr      c
            djnz    gd_desp
            jr      gd_junta
gd_sin_desp:
            ld      a,(hl)
            ld      c,0
gd_junta:
            inc     hl
            push    hl
            ld      hl,gen_resto
            or      (hl)                    ; pega lo que sobro del byte anterior
            ld      (hl),c
            pop     hl
            ld      (de),a
            inc     de
            ld      a,(gen_bytes)
            dec     a
            ld      (gen_bytes),a
            jr      nz,gd_byte
            ld      a,(gen_filas)
            dec     a
            ld      (gen_filas),a
            jr      nz,gd_fila
            pop     hl                      ; otra vez al principio del sprite
            ret

;---------------------------------------------------------------------
; azar - numerito pseudoaleatorio (registro de desplazamiento realimentado)
;---------------------------------------------------------------------
azar:
            ld      a,(semilla)
            add     a,a
            jr      nc,az_ok
            xor     %00011101
az_ok:
            or      a
            jr      nz,az_guarda
            ld      a,%01010011             ; que no se quede clavado en cero
az_guarda:
            ld      (semilla),a
            ret

;=====================================================================
; EL CABALLO SUELTO
;   Cruza el campo por abajo con tres posturas del paso, se para a
;   pastar, se encabrita al oir un tiro -no siempre- y, si le dan, o
;   embiste al que le disparo o sale de estampida; de las dos maneras
;   acaba perdiendose de vista y no vuelve hasta la partida siguiente.
;   Al que embiste lo pisa si no se ha apartado a tiempo.
;
;   Las tres posturas del paso se dejan desplazadas al pixel en RAM al
;   empezar la partida (por eso el caballo mira siempre al mismo lado en
;   una misma partida: espejarlas y volver a desplazarlas cuesta un
;   quinto de segundo).  Las dos posturas quietas no se mueven del
;   sitio, asi que basta con desplazar una sola copia al entrar en ellas.
;=====================================================================
prepara_caballo:
            call    azar                    ; a que lado mira esta partida
            and     1
            ld      (cab_dir),a
            ld      hl,cab_x
            or      a
            jr      z,pcab_der
            ld      (hl),CAB_MAX            ; entra por la derecha
            jr      pcab_sigue
pcab_der:
            ld      (hl),0
pcab_sigue:
            xor     a
            ld      (cab_estado),a          ; paseando
            ld      (cab_paso),a
            ld      (cab_t),a
            ld      a,CAB_ANCHO
            ld      (gen_ancho),a
            ld      a,CAB_ALTO
            ld      (gen_alto),a
            ld      hl,spr_caballo0
            ld      de,BUF_CABALLO
            ld      b,CAB_PASOS
pcab_paso:
            push    bc
            push    hl
            call    cab_fuente              ; espejada, si mira a la izquierda
            call    genera_desplazados      ; deja DE tras las ocho copias
            pop     hl
            ld      bc,CAB_BYTES
            add     hl,bc
            pop     bc
            djnz    pcab_paso
            ret

;---------------------------------------------------------------------
; cab_fuente - HL = la postura tal cual, o su espejo si el caballo mira
;   a la izquierda (cada fila al reves, y cada byte con los bits dados
;   la vuelta)
;---------------------------------------------------------------------
cab_fuente:
            ld      a,(cab_dir)
            or      a
            ret     z
            push    de
            ld      de,BUF_ESPEJO
            ld      c,CAB_ALTO
cfu_fila:
            push    de
            ld      a,CAB_ANCHO-1           ; DE, al ultimo byte de la fila
            add     a,e
            ld      e,a
            jr      nc,cfu_ok
            inc     d
cfu_ok:
            ld      b,CAB_ANCHO
cfu_byte:
            ld      a,(hl)
            inc     hl
            call    invierte_bits
            ld      (de),a
            dec     de
            djnz    cfu_byte
            pop     de
            ld      a,CAB_ANCHO             ; y a la fila siguiente
            add     a,e
            ld      e,a
            jr      nc,cfu_sig
            inc     d
cfu_sig:
            dec     c
            jr      nz,cfu_fila
            pop     de
            ld      hl,BUF_ESPEJO
            ret

;   Guarda BC: quien llama lleva ahi los contadores de fila y de byte, y
;   este bucle usa las dos mitades.
invierte_bits:
            push    bc
            ld      b,8
            ld      c,0
ib_bit:
            rra                             ; sale por abajo
            rl      c                       ; y entra por arriba
            djnz    ib_bit
            ld      a,c
            pop     bc
            ret

;---------------------------------------------------------------------
; actualiza_caballo - un fotograma de caballo
;---------------------------------------------------------------------
actualiza_caballo:
            ld      a,(cab_estado)
            cp      CAB_IDO
            ret     z
            cp      CAB_PASTA
            jr      nc,acab_quieto          ; pastando o encabritado
            ld      c,1                     ; al paso
            or      a
            jr      z,acab_anda
            ld      c,3                     ; embistiendo o de estampida
acab_anda:
            ld      a,(cab_dir)
            or      a
            ld      a,(cab_x)
            jr      nz,acab_izq
            add     a,c                     ; hacia la derecha
            jr      c,acab_sale
            cp      CAB_MAX+1
            jr      nc,acab_sale
            jr      acab_pon
acab_izq:
            sub     c                       ; hacia la izquierda
            jr      c,acab_sale
acab_pon:
            ld      (cab_x),a
            ld      hl,cab_t                ; el ciclo del paso
            inc     (hl)
            ld      a,(hl)
            cp      CAB_RITMO
            jr      c,acab_pisa
            ld      (hl),0
            ld      hl,cab_paso
            inc     (hl)
            ld      a,(hl)
            cp      4
            jr      c,acab_pisa
            ld      (hl),0
acab_pisa:
            call    caballo_pisa            ; ¿se lleva a alguien por delante?
            jr      c,acab_atropella
            call    dibuja_caballo
            ld      a,(cab_estado)          ; solo paseando se le ocurren cosas
            or      a
            ret     nz
            call    azar
            cp      2                       ; de vez en cuando, a pastar
            ret     nc
            ld      a,CAB_PASTA
            jp      cab_quieta

acab_atropella:                             ; lo ha pisado: como aqui se entro
            ld      a,(cab_dir)             ; con un CALL desde el bucle, basta
            or      a                       ; con saltar, que el RET del impacto
            jp      z,impacto_ladron        ; devuelve al bucle
            jp      impacto_poli

acab_sale:                                  ; se sale por un lado
            call    borra_caballo
            ld      a,(cab_estado)
            or      a
            jr      nz,acab_ido             ; si iba lanzado, ya no vuelve
            ld      a,(cab_dir)             ; paseando, reaparece por el otro
            or      a
            ld      a,CAB_MAX
            jr      nz,acab_borde
            xor     a
acab_borde:
            ld      (cab_x),a
            ret
acab_ido:
            ld      a,CAB_IDO
            ld      (cab_estado),a
            ret

acab_quieto:
            ld      hl,cab_t
            dec     (hl)
            jr      nz,acab_sigue_quieto
            xor     a                       ; se le pasa y vuelve a andar
            ld      (cab_estado),a
            ld      (cab_t),a
            ret
acab_sigue_quieto:
            jp      dibuja_caballo

;---------------------------------------------------------------------
; cab_quieta - se planta: A = estado (pastando o encabritado).  Como no
;   se mueve del sitio basta con desplazar una copia de la postura
;---------------------------------------------------------------------
cab_quieta:
            ld      (cab_estado),a
            cp      CAB_PASTA
            ld      hl,spr_caballo_pasta
            ld      b,150                   ; lo que dura pastando
            jr      z,cq_pon
            ld      hl,spr_caballo_alza
            ld      b,45
cq_pon:
            ld      a,b
            ld      (cab_t),a
            push    hl
            ld      a,CAB_ANCHO
            ld      (gen_ancho),a
            ld      a,CAB_ALTO
            ld      (gen_alto),a
            pop     hl
            call    cab_fuente
            ld      a,(cab_x)
            and     %00000111
            ld      (gen_n),a               ; solo el desplazamiento que toca
            ld      de,BUF_QUIETO
            call    gd_una
            ret

;---------------------------------------------------------------------
; caballo_oye_tiro - cada disparo le puede asustar, pero no siempre
;---------------------------------------------------------------------
caballo_oye_tiro:
            ld      a,(cab_estado)
            cp      CAB_ALZA
            ret     nc                      ; ya esta a lo suyo
            call    azar
            and     %00000011
            ret     nz                      ; una de cada cuatro
            ld      a,CAB_ALZA
            jp      cab_quieta

;---------------------------------------------------------------------
; caballo_tocado - le ha dado una bala: o embiste al que le disparo o
;   sale de estampida, segun le de.  En los dos casos se va.
;   entrada: A = 0 si la bala venia del bandido, 1 si del sheriff
;---------------------------------------------------------------------
caballo_tocado:
            ld      c,a
            ld      a,(cab_estado)
            cp      CAB_EMBISTE             ; si ya va lanzado, ni se entera
            ret     z
            cp      CAB_HUYE
            ret     z
            cp      CAB_IDO
            ret     z
            call    azar
            and     %00000001
            jr      z,cab_estampida
            ld      a,c                     ; embiste hacia quien le tiro
            ld      (cab_dir),a
            ld      a,CAB_EMBISTE
            ld      (cab_estado),a
            ret
cab_estampida:
            ld      a,CAB_HUYE
            ld      (cab_estado),a
            ret

;---------------------------------------------------------------------
; caballo_pisa - si embiste y alcanza a un pistolero que no se ha
;   apartado a tiempo, se lo lleva por delante.
;   salida: acarreo puesto = lo ha pisado
;---------------------------------------------------------------------
caballo_pisa:
            ld      a,(cab_estado)
            cp      CAB_EMBISTE
            jr      z,cpisa_lanzado
cpisa_no:
            or      a                       ; sin acarreo: no ha pisado a nadie
            ret
cpisa_lanzado:
            ld      a,(cab_dir)
            or      a
            jr      nz,cpisa_izq
            ld      a,(cab_x)               ; embiste hacia el bandido
            add     a,CAB_MORRO
            cp      COL_P2*8
            jr      c,cpisa_no              ; todavia no ha llegado
            ld      a,(p2_y)
            add     a,ALTO_SPR-1
            cp      CAB_Y
            jr      c,cpisa_no              ; se ha apartado a tiempo
            scf
            ret
cpisa_izq:
            ld      a,(cab_x)               ; embiste hacia el sheriff
            add     a,8
            cp      COL_P1*8+ANCHO_JUG*8
            jr      nc,cpisa_no
            ld      a,(p1_y)
            add     a,ALTO_SPR-1
            cp      CAB_Y
            jr      c,cpisa_no
            scf
            ret

;---------------------------------------------------------------------
; dibuja_caballo / borra_caballo
;---------------------------------------------------------------------
dibuja_caballo:
            ld      a,(cab_estado)
            cp      CAB_IDO
            ret     z
            ld      a,(cab_x)
            ld      (mov_x),a
            ld      a,CAB_Y
            ld      (mov_y),a
            ld      a,CAB_ANCHO
            ld      (ancho_bloque),a
            ld      a,CAB_ALTO
            ld      (mov_alto),a
            ld      a,(cab_estado)
            cp      CAB_PASTA
            jr      nc,dcab_quieto
            ld      a,(cab_paso)            ; que postura del ciclo toca
            ld      e,a
            ld      d,0
            ld      hl,cab_ciclo
            add     hl,de
            ld      l,(hl)
            ld      h,0
            ld      de,CAB_BYTES*8          ; y en que copia esta
            call    cab_mul
            ld      de,BUF_CABALLO
            add     hl,de
            ld      de,CAB_BYTES
            jp      dibuja_movil
dcab_quieto:
            ld      a,(cab_x)               ; la copia ya esta desplazada
            rrca
            rrca
            rrca
            and     %00011111
            ld      c,a
            ld      de,BUF_QUIETO
            ld      b,CAB_ALTO
            ld      a,CAB_Y
            jp      dibuja_bloque

cab_mul:                                    ; HL = HL * DE (HL vale 0, 1 o 2)
            ld      a,l
            ld      hl,0
            or      a
            ret     z
            ld      b,a
cmul_suma:
            add     hl,de
            djnz    cmul_suma
            ret

borra_caballo:
            ld      a,(cab_x)
            rrca
            rrca
            rrca
            and     %00011111
            ld      c,a
            ld      a,CAB_ANCHO
            ld      (ancho_bloque),a
            ld      b,CAB_ALTO
            ld      a,CAB_Y
            jp      borra_bloque

cab_ciclo:       DEFB 0, 1, 2, 1            ; las cuatro pisadas del ciclo
cab_x:           DEFB 0
cab_dir:         DEFB 0                     ; 0 a la derecha, 1 a la izquierda
cab_estado:      DEFB CAB_IDO
cab_paso:        DEFB 0
cab_t:           DEFB 0

;---------------------------------------------------------------------
; mira_caballo - ¿la bala que acaba de chocar era contra el caballo?
;   entrada: A = x de la bala, B = y
;---------------------------------------------------------------------
mira_caballo:
            ld      c,a
            ld      a,(cab_estado)
            cp      CAB_IDO
            ret     z
            ld      a,b
            cp      CAB_Y
            ret     c
            cp      CAB_Y+CAB_ALTO
            ret     nc
            ld      a,c                     ; la bala se para justo delante
            ld      hl,cab_x                ; de la tinta, asi que la caja va
            sub     (hl)                    ; de punta a punta del recuadro
            ret     c                       ; por delante del caballo
            cp      CAB_MORRO+4
            ret     nc                      ; o por detras
            ld      a,(bal_sent)            ; embiste hacia quien le tiro
            or      a
            ld      a,0
            jr      z,mcab_va
            ld      a,1
mcab_va:
            jp      caballo_tocado

;---------------------------------------------------------------------
; dibuja_movil - vuelca un sprite pre-desplazado en cualquier pixel
;   entrada: HL = base de las 8 copias, DE = bytes por copia,
;            (mov_x), (mov_y), (ancho_bloque), (mov_alto)
;---------------------------------------------------------------------
dibuja_movil:
            ld      a,(mov_x)
            and     %00000111               ; la copia = desplazamiento
            jr      z,dm_base
            ld      b,a
dm_suma:
            add     hl,de
            djnz    dm_suma
dm_base:
            ex      de,hl                   ; DE = datos ya desplazados
            ld      a,(mov_x)
            rrca
            rrca
            rrca
            and     %00011111
            ld      c,a
            ld      a,(mov_alto)
            ld      b,a
            ld      a,(mov_y)
            jp      dibuja_bloque

;---------------------------------------------------------------------
; coloca_barriles - a cada partida les toca otra altura, y nunca a la
;   misma para que no se tapen el mismo pasillo de tiro
;---------------------------------------------------------------------
coloca_barriles:
            call    azar
            and     %00000011
            add     a,a
            add     a,a
            add     a,a
            add     a,a                     ; 0, 16, 32 o 48
            add     a,MIN_Y+6
            ld      (barril1_y),a
            ld      (barril1_tab+1),a
            ld      c,a
            call    azar
            and     %00000001
            add     a,a
            add     a,a
            add     a,a
            add     a,a
            add     a,64                    ; al menos 64 pixeles mas abajo
            add     a,c
            ld      (barril2_y),a
            ld      (barril2_tab+1),a
            ret

;---------------------------------------------------------------------
; dibuja_cajas - los dos barriles de whisky
;---------------------------------------------------------------------
dibuja_cajas:
            ld      a,2
            ld      (ancho_bloque),a
            ld      a,(barril1_y)
            ld      c,CAJA1_COL
            ld      de,spr_barril
            ld      b,CAJA_ALTO
            call    dibuja_bloque
            ld      a,(barril2_y)
            ld      c,CAJA2_COL
            ld      de,spr_barril
            ld      b,CAJA_ALTO
            jp      dibuja_bloque

;---------------------------------------------------------------------
; actualiza_carreta - asoma por abajo, sube por el centro y se pierde
;   por arriba; luego espera un rato y vuelve a asomar
;---------------------------------------------------------------------
actualiza_carreta:
            ld      a,(carreta_t)
            inc     a
            cp      CARRETA_LENTO
            jr      nc,acar_mueve
            ld      (carreta_t),a
            ret
acar_mueve:
            xor     a
            ld      (carreta_t),a
            ld      a,(carreta_y)
            or      a
            jr      nz,acar_sube
            ld      hl,carreta_espera       ; esta fuera, esperando turno
            dec     (hl)
            ret     nz
            ld      a,CARRETA_ABAJO
            ld      (carreta_y),a
            ret
acar_sube:
            dec     a
            ld      (carreta_y),a
            or      a
            jr      z,acar_fuera
            call    dibuja_carreta
            ld      a,(carreta_y)           ; borra la fila que deja libre
            add     a,CARRETA_ALTO
            cp      192
            ret     nc
            ld      c,CARRETA_COL
            ld      b,1
            ld      a,ANCHO_JUG
            ld      (ancho_bloque),a
            ld      a,(carreta_y)
            add     a,CARRETA_ALTO
            jp      borra_bloque
acar_fuera:
            ld      a,ANCHO_JUG             ; se fue: limpia lo que quede
            ld      (ancho_bloque),a
            ld      a,MIN_Y
            ld      c,CARRETA_COL
            ld      b,CARRETA_ALTO
            call    borra_bloque
            ld      a,80
            ld      (carreta_espera),a
            ret

;---------------------------------------------------------------------
; dibuja_carreta - con recorte por arriba, para que se meta bajo el
;   marcador en vez de pisarlo
;---------------------------------------------------------------------
dibuja_carreta:
            ld      a,ANCHO_JUG
            ld      (ancho_bloque),a
            ld      de,spr_carreta
            ld      b,CARRETA_ALTO
            ld      a,(carreta_y)
            cp      MIN_Y
            jr      nc,dcar_entera
            ld      c,a                     ; le faltan (MIN_Y - y) filas
            ld      a,MIN_Y
            sub     c
            ld      c,a
            ld      a,CARRETA_ALTO
            sub     c
            ret     c                       ; ya no se ve nada
            ret     z
            ld      b,a                     ; filas que quedan
            push    bc
            ld      hl,3
dcar_salta:
            ex      de,hl
            add     hl,de
            ex      de,hl
            dec     c
            jr      nz,dcar_salta
            pop     bc
            ld      a,MIN_Y
dcar_entera:
            ld      c,CARRETA_COL
            jp      dibuja_bloque

;---------------------------------------------------------------------
; mira_bala - ¿hay algo dibujado donde va a caer la bala?
;   Con esto una bala choca con lo primero que se cruza, sea el
;   decorado, un barril o el caballo, sin tablas ni estados aparte.
;   entrada: A = x, B = y
;   salida : carry = 1 si hay algo
;---------------------------------------------------------------------
mira_bala:
            call    patron_bala             ; DE = patron, HL = pantalla
            ld      a,(hl)
            and     d
            jr      nz,mb_choca
            inc     l
            ld      a,(hl)
            dec     l
            and     e
            jr      nz,mb_choca
            call    down_hl
            ld      a,(hl)
            and     d
            jr      nz,mb_choca
            inc     l
            ld      a,(hl)
            dec     l
            and     e
            jr      nz,mb_choca
            or      a                       ; carry a cero: via libre
            ret
mb_choca:
            scf
            ret

;---------------------------------------------------------------------
; abre_agujero - la bala se lleva por delante unos pocos pixeles
;   (6 de ancho por 4 de alto) del objeto contra el que choca
;   entrada: A = x, B = y
;---------------------------------------------------------------------
abre_agujero:
            dec     b                       ; una fila por encima
            call    patron_ancho            ; DE = patron de 6 pixeles
            ld      b,4
ag_fila:
            ld      a,d
            cpl
            and     (hl)
            ld      (hl),a
            inc     l
            ld      a,e
            cpl
            and     (hl)
            ld      (hl),a
            dec     l
            call    down_hl
            djnz    ag_fila
            ret

;---------------------------------------------------------------------
; patron_bala / patron_ancho - patron desplazado al pixel exacto y
;   direccion de pantalla.  entrada: A = x, B = y
;   salida: D y E = las dos mitades del patron, HL = pantalla
;---------------------------------------------------------------------
patron_bala:
            ld      hl,0xF000               ; 4 pixeles
            jr      patron
patron_ancho:
            ld      hl,0xFC00               ; 6 pixeles
patron:
            ld      c,a
            and     %00000111
            jr      z,pat_listo
            ld      d,a
pat_desp:
            srl     h
            rr      l
            dec     d
            jr      nz,pat_desp
pat_listo:
            ld      a,c
            rrca
            rrca
            rrca
            and     %00011111
            ld      c,a
            ld      a,b
            push    hl
            call    scr_addr
            pop     de                      ; D y E = patron
            ret

;---------------------------------------------------------------------
; bala_xor - dibuja/borra una bala (4x2 pixeles) en modo XOR
;   La bala puede estar en cualquier x: el patron de 4 pixeles se
;   desplaza dentro de una pareja de bytes, asi que se mueve pixel a
;   pixel y no a saltos de caracter.
;   entrada: A = x en pixeles, B = y
;---------------------------------------------------------------------
bala_xor:
            call    patron_bala             ; DE = patron, HL = pantalla
            call    bx_fila
            call    down_hl
bx_fila:
            ld      a,(hl)
            xor     d
            ld      (hl),a
            inc     l
            ld      a,(hl)
            xor     e
            ld      (hl),a
            dec     l
            ret

;---------------------------------------------------------------------
; limpia_pantalla - borra los pixeles y pinta todo de amarillo
;---------------------------------------------------------------------
limpia_pantalla:
            ld      hl,SCREEN
            ld      de,SCREEN+1
            ld      bc,6144-1
            ld      (hl),0
            ldir
            ld      hl,ATTRS
            ld      de,ATTRS+1
            ld      bc,768-1
            ld      (hl),ATTR_JUEGO
            ldir
            ld      a,PAPEL
            out     (0xFE),a                ; borde amarillo
            ret

;---------------------------------------------------------------------
; print_char - imprime un caracter con el juego de la ROM
;   entrada: A = codigo (32-127), B = fila (0-23), C = columna (0-31)
;---------------------------------------------------------------------
print_char:
            push    bc
            push    de
            ld      l,a
            ld      h,0
            add     hl,hl
            add     hl,hl
            add     hl,hl                   ; HL = codigo * 8
            ld      de,FONT
            add     hl,de
            ex      de,hl                   ; DE = origen en la ROM
            ld      a,b
            add     a,a
            add     a,a
            add     a,a                     ; A = fila * 8 = y
            call    scr_addr
            ld      b,8
pc_bucle:
            ld      a,(de)
            ld      (hl),a
            inc     de
            inc     h                       ; dentro de la celda: +256
            djnz    pc_bucle
            pop     de
            pop     bc
            ret

;---------------------------------------------------------------------
; print_str - imprime una cadena terminada en 0
;   entrada: HL = cadena, B = fila, C = columna
;---------------------------------------------------------------------
print_str:
            ld      a,c
            cp      32
            ret     nc                      ; no escribe fuera de la pantalla
            ld      a,(hl)
            or      a
            ret     z
            push    hl
            call    print_char
            pop     hl
            inc     hl
            inc     c
            jr      print_str

;---------------------------------------------------------------------
; dibuja_marcador - etiquetas fijas y linea separadora
;---------------------------------------------------------------------
dibuja_marcador:
            ld      hl,txt_poli
            ld      b,0
            ld      c,0
            call    print_str
            ld      hl,txt_ladron
            ld      b,0
            ld      c,22
            call    print_str
            ld      hl,txt_juego
            ld      b,0
            ld      c,13
            call    print_str
            ld      a,16                    ; linea horizontal bajo el marcador
            jp      linea_horizontal

;---------------------------------------------------------------------
; hud_municion - las balas que le quedan a cada uno, dibujadas
;---------------------------------------------------------------------
hud_municion:
            ld      a,8                     ; se limpia la fila entera
            ld      c,0
            call    scr_addr
            ld      b,8
hm_limpia:
            push    bc
            push    hl
            ld      b,32
hm_col:
            ld      (hl),0
            inc     l
            djnz    hm_col
            pop     hl
            call    down_hl
            pop     bc
            djnz    hm_limpia
            ld      a,1
            ld      (ancho_bloque),a
            ld      a,(balas1)
            or      a
            jr      z,hm_otro
            ld      b,a
            ld      c,0
hm_uno:
            push    bc
            ld      a,8
            ld      de,spr_balita
            ld      b,8
            call    dibuja_bloque
            pop     bc
            inc     c
            djnz    hm_uno
hm_otro:
            ld      a,(balas2)
            or      a
            ret     z
            ld      b,a
            ld      c,32
hm_dos:
            dec     c
            push    bc
            ld      a,8
            ld      de,spr_balita
            ld      b,8
            call    dibuja_bloque
            pop     bc
            djnz    hm_dos
            ret

;---------------------------------------------------------------------
; linea_horizontal - linea de 256 pixeles de ancho
;   entrada: A = y
;---------------------------------------------------------------------
linea_horizontal:
            ld      c,0
            call    scr_addr
            ld      b,32
lh_bucle:
            ld      (hl),0xFF
            inc     l
            djnz    lh_bucle
            ret

;---------------------------------------------------------------------
; hud_puntos - refresca los dos digitos del marcador
;---------------------------------------------------------------------
hud_puntos:
            ld      a,(puntos1)
            add     a,'0'
            ld      b,0
            ld      c,8
            call    print_char
            ld      a,(puntos2)
            add     a,'0'
            ld      b,0
            ld      c,30
            jp      print_char

;=====================================================================
; PANTALLA DE PRESENTACION
;=====================================================================
menu:
            call    limpia_pantalla
            call    dibuja_marco
            call    dibuja_logo
            ; los dos pistoleros apuntandose bajo el logotipo
            ld      a,64
            ld      c,3
            ld      de,spr_poli
            call    dibuja_jugador
            ld      a,64
            ld      c,25
            ld      de,spr_ladron
            call    dibuja_jugador
            ld      a,2                     ; un cactus a cada lado
            ld      (ancho_bloque),a
            ld      a,72
            ld      c,10
            ld      de,spr_cactus
            ld      b,24
            call    dibuja_bloque
            ld      a,72
            ld      c,19
            ld      de,spr_cactus
            ld      b,24
            call    dibuja_bloque
            ld      b,77                    ; y de la bala entre los dos
            ld      a,128                   ; x de la bala
            call    bala_xor
            ; opciones
            ld      hl,txt_op1
            ld      b,11
            ld      c,10
            call    print_str
            ld      hl,txt_op2
            ld      b,13
            ld      c,10
            call    print_str
            ld      hl,txt_op3
            ld      b,15
            ld      c,10
            call    print_str
            ld      hl,txt_op4
            ld      b,17
            ld      c,10
            call    print_str
            ld      hl,txt_pulsa
            ld      b,19
            ld      c,7
            call    print_str
            ld      hl,txt_autor
            ld      b,21
            ld      c,3
            call    print_str
            ; el aviso parpadea con el bit FLASH de los atributos
            ld      hl,ATTRS+(19*32)+7
            ld      b,17
menu_flash:
            ld      (hl),0x80+ATTR_JUEGO
            inc     hl
            djnz    menu_flash
            call    espera_libre
            ld      hl,cancion_menu
            call    pon_cancion
menu_espera:
            halt
            call    ay_tick
            ld      bc,0xF7FE               ; fila 1 2 3 4 5
            in      a,(c)
            ld      b,a
            and     %00000001               ; 1 = contra la maquina
            jr      nz,menu_dos
            ld      a,1
            ld      (modo_ia),a
            ret
menu_dos:
            ld      a,b
            and     %00000010               ; 2 = dos jugadores
            jr      nz,menu_tres
            xor     a
            ld      (modo_ia),a
            ret
menu_tres:
            ld      a,b
            and     %00000100               ; 3 = controles
            jr      nz,menu_cuatro
            call    pantalla_controles
            jp      menu                    ; el menu queda fuera del alcance de JR
menu_cuatro:
            ld      a,b
            and     %00001000               ; 4 = creditos
            jr      nz,menu_espera
            call    creditos
            jp      menu

;---------------------------------------------------------------------
; pantalla_controles - la ayuda del menu
;---------------------------------------------------------------------
pantalla_controles:
            call    calla_musica            ; aqui no hay quien mueva la musica
            call    limpia_pantalla
            call    dibuja_marco
            ld      hl,txt_controles
            ld      b,3
            ld      c,11
            call    print_str
            ld      hl,txt_j1
            ld      b,7
            ld      c,6
            call    print_str
            ld      hl,txt_j1b
            ld      b,8
            ld      c,6
            call    print_str
            ld      hl,txt_j1c
            ld      b,9
            ld      c,6
            call    print_str
            ld      hl,txt_j2
            ld      b,12
            ld      c,6
            call    print_str
            ld      hl,txt_j2b
            ld      b,13
            ld      c,6
            call    print_str
            ld      hl,txt_j2c
            ld      b,14
            ld      c,6
            call    print_str
            ld      hl,txt_reglas
            ld      b,17
            ld      c,5
            call    print_str
            ld      hl,txt_tecla
            ld      b,20
            ld      c,5
            call    print_str
            jp      espera_tecla

;=====================================================================
; LOS CREDITOS
;   La foto del autor, digitalizada a un bit, ocupa la pantalla entera, y
;   los rotulos pasan en una marquesina al pie, para no taparle la cara.
;   El texto no se puede borrar y repintar, porque debajo esta la foto:
;   se guarda aparte (BUF_TEXTO, 16 filas de 32 bytes) y cada fotograma se
;   corre un pixel a la izquierda con RL, metiendo por la derecha la
;   columna que toca del caracter que entra.  Luego la franja se compone
;   sobre una copia de la foto ya oscurecida: ventana AND NO texto.
;=====================================================================
creditos:
            call    pinta_foto
            call    arma_ventana
            call    mq_arranca
            ld      hl,cancion_creditos
            call    pon_cancion
            call    espera_libre
cre_bucle:
            halt
            call    ay_tick
            call    mq_corre
            call    mq_pinta
            ld      bc,0x00FE               ; cualquier tecla y fuera
            in      a,(c)
            and     %00011111
            cp      %00011111
            jr      z,cre_bucle
            jp      calla_musica

;---------------------------------------------------------------------
; pinta_foto - vuelca los 6144 bytes de la foto.  Tramada a un bit, pero
;   con la paleta del juego: papel amarillo y tinta negra, como todo lo
;   demas, que el blanco se sale del juego de colores
;---------------------------------------------------------------------
pinta_foto:
            ld      hl,foto
            ld      de,SCREEN
            ld      bc,6144
            ldir
            ld      hl,ATTRS
            ld      de,ATTRS+1
            ld      bc,768-1
            ld      (hl),ATTR_JUEGO
            ldir
            ld      a,PAPEL
            out     (0xFE),a                ; borde amarillo
            ret

;---------------------------------------------------------------------
; arma_ventana - copia la franja de foto que tapa la marquesina y la
;   oscurece con una trama del 87%, para que las letras en blanco se
;   lean encima sin perder del todo la imagen
;---------------------------------------------------------------------
arma_ventana:
            ld      de,BUF_VENTANA
            ld      a,MQ_Y
            ld      b,MQ_ALTO
av_fila:
            push    bc
            push    af
            ld      c,0
            call    scr_addr                ; HL = pantalla(y, 0)
            ld      bc,foto-SCREEN
            add     hl,bc                   ; y por tanto HL = foto
            pop     af
            push    af
            and     1
            ld      c,%11111110
            jr      z,av_par
            ld      c,%01111111
av_par:
            ld      b,32
av_byte:
            ld      a,(hl)
            or      c
            ld      (de),a
            inc     hl
            inc     de                      ; 32 bytes: justo la fila siguiente
            djnz    av_byte
            pop     af
            inc     a
            pop     bc
            djnz    av_fila
            ret

;---------------------------------------------------------------------
; mq_arranca - la marquesina empieza vacia y por el primer caracter
;---------------------------------------------------------------------
mq_arranca:
            ld      hl,BUF_TEXTO
            ld      de,BUF_TEXTO+1
            ld      bc,MQ_ALTO*32-1
            ld      (hl),0
            ldir
            xor     a
            ld      (mq_car),a
            ld      a,%10000000             ; por la columna de mas a la izquierda
            ld      (mq_mascara),a
            ret

;---------------------------------------------------------------------
; mq_corre - un pixel a la izquierda.  Cada fila del texto es un numero
;   de 32 bytes que se desplaza con RL de derecha a izquierda; el bit que
;   entra sale de la columna que toque del caracter siguiente.
;---------------------------------------------------------------------
mq_corre:
            call    mq_glifo                ; HL = las 8 filas del caracter
            ld      de,mq_col               ; el bit que entra por cada fila
            ld      a,(mq_mascara)
            ld      c,a
            ld      b,8
mq_expande:
            ld      a,(hl)
            and     c
            jr      z,mq_apagado
            ld      a,1
mq_apagado:
            ld      (de),a                  ; a doble alto: dos filas por fila
            inc     de                      ; del juego de caracteres
            ld      (de),a
            inc     de
            inc     hl
            djnz    mq_expande

            ld      hl,BUF_TEXTO+31         ; el byte de mas a la derecha
            ld      de,mq_col
            ld      c,MQ_ALTO
mq_fila:
            ld      a,(de)
            inc     de
            or      a
            jr      z,mq_sin_bit
            scf
            jr      mq_rota
mq_sin_bit:
            or      a                       ; sin acarreo: entra un cero
mq_rota:
            ld      b,32
mq_byte:
            rl      (hl)
            dec     hl
            djnz    mq_byte
            ld      a,l                     ; a la fila siguiente
            add     a,64
            ld      l,a
            jr      nc,mq_sigue
            inc     h
mq_sigue:
            dec     c
            jr      nz,mq_fila

            ld      a,(mq_mascara)          ; la columna siguiente
            rrca
            ld      (mq_mascara),a
            cp      %10000000
            ret     nz
            ld      hl,mq_car               ; y, cada ocho, el caracter siguiente
            inc     (hl)
            ld      e,(hl)
            ld      d,0
            ld      hl,txt_marquesina
            add     hl,de
            ld      a,(hl)
            or      a
            ret     nz
            xor     a                       ; se acabo el rotulo: otra vuelta
            ld      (mq_car),a
            ret

;---------------------------------------------------------------------
; mq_glifo - HL = el caracter que esta entrando, en el juego de la ROM
;---------------------------------------------------------------------
mq_glifo:
            ld      a,(mq_car)
            ld      e,a
            ld      d,0
            ld      hl,txt_marquesina
            add     hl,de
            ld      l,(hl)
            ld      h,0
            add     hl,hl
            add     hl,hl
            add     hl,hl
            ld      de,FONT
            add     hl,de
            ret

;---------------------------------------------------------------------
; mq_pinta - compone la franja: ventana AND NO texto.  El texto se lee
;   con SP, que trae dos bytes de golpe, asi que hay que quitar las
;   interrupciones: una RST 38 escribiria justo ahi.
;---------------------------------------------------------------------
mq_pinta:
            di
            ld      hl,BUF_VENTANA
            ld      (mq_ven),hl
            ld      hl,BUF_TEXTO
            ld      (mq_tex),hl
            ld      a,MQ_Y
            ld      b,MQ_ALTO
mqp_fila:
            push    bc
            push    af
            ld      c,0
            call    scr_addr
            ex      de,hl                   ; DE = pantalla
            ld      hl,(mq_ven)             ; HL = ventana
            ld      (mq_sp),sp
            ld      sp,(mq_tex)             ; SP = texto
            REPT    16
            pop     bc
            ld      a,c
            cpl
            and     (hl)
            ld      (de),a
            inc     l
            inc     e
            ld      a,b
            cpl
            and     (hl)
            ld      (de),a
            inc     l
            inc     e
            ENDM
            ld      (mq_tex),sp             ; ya en la fila siguiente
            ld      sp,(mq_sp)
            ld      hl,(mq_ven)             ; la ventana, de 32 en 32 (el INC L
            ld      bc,32                   ; de arriba no cruza de pagina)
            add     hl,bc
            ld      (mq_ven),hl
            pop     af
            inc     a
            pop     bc
            dec     b                       ; el bucle no cabe en un DJNZ
            jp      nz,mqp_fila
            ei
            ret

mq_car:          DEFB 0                     ; por que caracter va
mq_mascara:      DEFB %10000000             ; y por que columna suya
mq_ven:          DEFW 0
mq_tex:          DEFW 0
mq_sp:           DEFW 0
mq_col:          DEFS MQ_ALTO               ; el bit que entra por cada fila

;---------------------------------------------------------------------
; dibuja_marco - recuadro de 2 pixeles alrededor de la pantalla
;---------------------------------------------------------------------
dibuja_marco:
            ld      a,2
            call    linea_horizontal
            ld      a,3
            call    linea_horizontal
            ld      a,188
            call    linea_horizontal
            ld      a,189
            call    linea_horizontal
            ld      a,4
            ld      c,0
            call    scr_addr
            ld      b,184                   ; y = 4 .. 187
dmarco_bucle:
            ld      a,(hl)
            or      %00110000               ; x = 2 y 3
            ld      (hl),a
            ld      a,l
            add     a,31                    ; misma fila, columna 31
            ld      l,a
            ld      a,(hl)
            or      %00001100               ; x = 252 y 253
            ld      (hl),a
            ld      a,l
            sub     31
            ld      l,a
            call    down_hl
            djnz    dmarco_bucle
            ret

;---------------------------------------------------------------------
; dibuja_logo - banda negra con BALAVA en hueco
;---------------------------------------------------------------------
dibuja_logo:
            ld      a,24                    ; banda de y=24 a y=55
            ld      c,1
            call    scr_addr
            ld      b,32
dlogo_fila:
            push    bc
            push    hl
            ld      b,30                    ; columnas 1 a 30
dlogo_col:
            ld      (hl),0xFF
            inc     l
            djnz    dlogo_col
            pop     hl
            call    down_hl
            pop     bc
            djnz    dlogo_fila
            ld      hl,logo_letras          ; las letras, en hueco
            ld      b,6
            ld      c,10                    ; primera columna del logotipo
dlogo_letra:
            push    bc
            ld      e,(hl)
            inc     hl
            ld      d,(hl)
            inc     hl
            push    hl
            ld      a,33                    ; y de las letras
            call    dibuja_letra
            pop     hl
            pop     bc
            inc     c
            inc     c
            djnz    dlogo_letra
            ret

;---------------------------------------------------------------------
; dibuja_letra - letra del logotipo (16x14) en XOR
;   entrada: A = y, C = columna, DE = datos de la letra
;---------------------------------------------------------------------
dibuja_letra:
            call    scr_addr
            ld      b,14
dletra_fila:
            ld      a,(de)
            xor     (hl)
            ld      (hl),a
            inc     de
            inc     l
            ld      a,(de)
            xor     (hl)
            ld      (hl),a
            inc     de
            dec     l
            call    down_hl
            djnz    dletra_fila
            ret

;---------------------------------------------------------------------
; espera_tecla - espera a que se suelte todo y se pulse cualquier tecla
;   (con el byte alto a 0 se leen las ocho semifilas a la vez)
;---------------------------------------------------------------------
espera_tecla:
            call    espera_libre
et_pulsar:
            ld      bc,0x00FE
            in      a,(c)
            and     %00011111
            cp      %00011111
            jr      z,et_pulsar
            ret

;---------------------------------------------------------------------
; espera_libre - espera a que no quede ninguna tecla pulsada
;---------------------------------------------------------------------
espera_libre:
            ld      bc,0x00FE
            in      a,(c)
            and     %00011111
            cp      %00011111
            jr      nz,espera_libre
            ret

;=====================================================================
; MUSICA Y SONIDO POR EL AY
;   El 128K lleva un AY-3-8912 de tres canales.  El reproductor se llama
;   una vez por fotograma y no bloquea nada, asi que la musica suena
;   mientras se juega.  Los canales A y B llevan melodia y bajo, y el C
;   los acordes o, si hay disparo o impacto, el ruido del efecto.
;=====================================================================
AY_SEL      EQU 0xFFFD
AY_DAT      EQU 0xBFFD

;---------------------------------------------------------------------
; ay_reg - escribe el registro A con el valor E
;---------------------------------------------------------------------
ay_reg:
            push    bc
            ld      bc,AY_SEL
            out     (c),a
            ld      bc,AY_DAT
            out     (c),e
            pop     bc
            ret

;---------------------------------------------------------------------
; ay_init - los tres canales en tono y a volumen cero
;---------------------------------------------------------------------
ay_init:
            ld      a,7
            ld      e,%00111000             ; tono en A, B y C; sin ruido
            call    ay_reg
            ld      b,3
            ld      c,8
ai_vol:
            ld      a,c
            ld      e,0
            push    bc
            call    ay_reg
            pop     bc
            inc     c
            djnz    ai_vol
            xor     a
            ld      (fx_t),a
            ret

;---------------------------------------------------------------------
; pon_cancion - HL = tabla con los punteros de los tres canales
;---------------------------------------------------------------------
pon_cancion:
            ld      a,1
            ld      (musica),a
            ld      (pc_tabla),hl
            ld      hl,ay_est_a
            ld      b,3
pc_canal:
            push    bc
            push    hl
            ld      hl,(pc_tabla)
            ld      e,(hl)
            inc     hl
            ld      d,(hl)
            inc     hl
            ld      (pc_tabla),hl
            pop     hl
            ld      (hl),e                  ; por donde va
            inc     hl
            ld      (hl),d
            inc     hl
            ld      (hl),e                  ; y por donde empezaba
            inc     hl
            ld      (hl),d
            inc     hl
            ld      (hl),1                  ; nota nueva ya
            inc     hl
            ld      (hl),0                  ; volumen
            inc     hl
            pop     bc
            djnz    pc_canal
            ld      hl,(pc_tabla)           ; detras de los tres punteros va lo
            ld      a,(hl)                  ; que tarda en apagarse cada nota
            ld      (vel_decae),a
            xor     a
            ld      (ay_par),a
            ret

;---------------------------------------------------------------------
; calla_musica - se acaba la cancion y los tres canales a cero.  Durante
;   la partida no suena mas que el AY de los disparos, que se cuela por
;   el canal C sin pasar por el reproductor.
;---------------------------------------------------------------------
calla_musica:
            xor     a
            ld      (musica),a
            ld      (fx_t),a
            ld      b,3
            ld      c,8
cmus_canal:
            ld      a,c
            ld      e,0
            push    bc
            call    ay_reg
            pop     bc
            inc     c
            djnz    cmus_canal
            ld      a,7
            ld      e,%00111000             ; tono en los tres, sin ruido
            jp      ay_reg

;---------------------------------------------------------------------
; ay_solo_fx - sin cancion: solo se atiende al efecto que haya
;---------------------------------------------------------------------
ay_solo_fx:
            ld      a,(fx_t)
            or      a
            ret     z
            jp      fx_tick

;---------------------------------------------------------------------
; ay_tick - un fotograma de musica
;---------------------------------------------------------------------
ay_tick:
            ld      a,(ay_par)              ; cuenta hasta lo que dure la nota
            inc     a                       ; en apagarse, segun la cancion
            ld      hl,vel_decae
            cp      (hl)
            jr      c,at_cuenta
            xor     a
at_cuenta:
            ld      (ay_par),a
            ld      a,(musica)
            or      a
            jr      z,ay_solo_fx            ; en la partida solo suenan los tiros
            ld      hl,ay_est_a
            xor     a
            call    ay_canal
            ld      hl,ay_est_b
            ld      a,1
            call    ay_canal
            ld      a,(fx_t)                ; el canal C lo puede ocupar
            or      a                       ; un disparo o un impacto
            jp      nz,fx_tick
            ld      hl,ay_est_c
            ld      a,2
            ; cae en ay_canal

;---------------------------------------------------------------------
; ay_canal - HL = estado del canal, A = numero de canal
;---------------------------------------------------------------------
ay_canal:
            ld      (ay_num),a
            ld      (ay_est),hl
            ld      de,4
            add     hl,de
            ld      a,(hl)
            dec     a
            ld      (hl),a
            jr      nz,ay_vol
            ld      hl,(ay_est)             ; toca nota nueva
            ld      e,(hl)
            inc     hl
            ld      d,(hl)
            ld      a,(de)
            inc     de
            ld      c,a
            ld      a,(de)
            inc     de
            ld      b,a                     ; BC = periodo
            ld      a,b
            and     c
            inc     a
            jr      nz,ay_pon
            ld      hl,(ay_est)             ; se acabo: vuelta al principio
            inc     hl
            inc     hl
            ld      e,(hl)
            inc     hl
            ld      d,(hl)
            ld      a,(de)
            inc     de
            ld      c,a
            ld      a,(de)
            inc     de
            ld      b,a
ay_pon:
            ld      a,(de)                  ; duracion
            inc     de
            ld      hl,(ay_est)
            ld      (hl),e
            inc     hl
            ld      (hl),d
            inc     hl
            inc     hl
            inc     hl
            ld      (hl),a
            inc     hl
            ld      a,b
            or      c
            jr      z,ay_calla
            ld      a,(ay_num)              ; la melodia por encima del
            add     a,a                     ; acompanamiento: 15, 13 y 11
            push    bc
            ld      c,a
            ld      a,15
            sub     c
            pop     bc
            jr      ay_vol_ini
ay_calla:
            xor     a                       ; silencio
ay_vol_ini:
            ld      (hl),a
            ld      a,(ay_num)              ; el periodo, a sus dos registros
            add     a,a
            ld      e,c
            call    ay_reg
            ld      a,(ay_num)
            add     a,a
            inc     a
            ld      e,b
            call    ay_reg
ay_vol:
            ld      hl,(ay_est)
            ld      de,5
            add     hl,de
            ld      a,(ay_par)              ; el volumen decae, para que las
            or      a                       ; notas suenen pulsadas
            jr      nz,ay_pon_vol
            ld      a,(hl)
            or      a
            jr      z,ay_pon_vol
            dec     a
            ld      (hl),a
ay_pon_vol:
            ld      e,(hl)
            ld      a,(ay_num)
            add     a,8
            jp      ay_reg

;---------------------------------------------------------------------
; efectos - ocupan el canal C con ruido mientras duran
;---------------------------------------------------------------------
sonido_tiro:
            ld      e,3                     ; chasquido corto
            ld      c,8
            jr      fx_ruido
sonido_rebote:
            ld      e,8
            ld      c,6
            jr      fx_ruido
sonido_rotura:
            ld      e,12
            ld      c,10
            jr      fx_ruido
sonido_impacto:
            ld      e,24                    ; ruido grave y largo
            ld      c,30
fx_ruido:
            ld      a,6                     ; periodo del ruido
            call    ay_reg
            ld      a,c
            ld      (fx_t),a
            ld      a,15
            ld      (fx_vol),a
            ld      a,7                     ; ruido en C, tono en A y B
            ld      e,%00011100
            jp      ay_reg

fx_tick:
            ld      hl,fx_t
            dec     (hl)
            jr      nz,fx_sigue
            ld      a,7                     ; se acabo: vuelve el tono
            ld      e,%00111000
            call    ay_reg
            ld      e,0
            ld      a,10
            jp      ay_reg
fx_sigue:
            ld      hl,fx_vol
            ld      a,(hl)
            or      a
            jr      z,fx_pon_vol
            dec     a
            ld      (hl),a
fx_pon_vol:
            ld      e,a
            ld      a,10
            jp      ay_reg

;=====================================================================
; DATOS
;=====================================================================
; ---- sprites de 8x16, el bit a 1 se pinta en negro ------------------
spr_poli:                ; el sheriff, 24x32, mira a la derecha
            DEFB    %00000000, %00000000, %00000000   ; ........................
            DEFB    %00000011, %11111100, %00000000   ; ......########..........
            DEFB    %00000111, %11111110, %00000000   ; .....##########.........
            DEFB    %00001111, %11111111, %00000000   ; ....############........
            DEFB    %00011111, %11111111, %10000000   ; ...##############.......
            DEFB    %00000011, %11110000, %00000000   ; ......######............
            DEFB    %00000011, %11110000, %00000000   ; ......######............
            DEFB    %00000011, %11111000, %00000000   ; ......#######...........
            DEFB    %00000111, %11111000, %00000000   ; .....########...........
            DEFB    %00001111, %11111100, %00000000   ; ....##########..........
            DEFB    %00001111, %11111110, %00000000   ; ....###########.........
            DEFB    %00001111, %11111111, %00000000   ; ....############........
            DEFB    %00001111, %11111111, %10000000   ; ....#############.......
            DEFB    %00001111, %11111111, %11110000   ; ....################....
            DEFB    %00001111, %11111111, %11110000   ; ....################....
            DEFB    %00001111, %11111111, %11000000   ; ....##############......
            DEFB    %00001111, %11111110, %00000000   ; ....###########.........
            DEFB    %00001111, %11111100, %00000000   ; ....##########..........
            DEFB    %00001111, %11111100, %00000000   ; ....##########..........
            DEFB    %00001111, %11111100, %00000000   ; ....##########..........
            DEFB    %00011111, %11111110, %00000000   ; ...############.........
            DEFB    %00011111, %00111110, %00000000   ; ...#####..#####.........
            DEFB    %00011110, %00011110, %00000000   ; ...####....####.........
            DEFB    %00111110, %00011111, %00000000   ; ..#####....#####........
            DEFB    %00111100, %00001111, %00000000   ; ..####......####........
            DEFB    %00111100, %00001111, %10000000   ; ..####......#####.......
            DEFB    %01111100, %00000111, %10000000   ; .#####.......####.......
            DEFB    %01111000, %00000111, %10000000   ; .####........####.......
            DEFB    %01111000, %00000111, %11000000   ; .####........#####......
            DEFB    %01111000, %00000011, %11000000   ; .####.........####......
            DEFB    %11110000, %00000011, %11100000   ; ####..........#####.....
            DEFB    %11111000, %00000011, %11110000   ; #####.........######....

spr_ladron:              ; el bandido, 24x32, mira a la izquierda
            DEFB    %00000000, %00000000, %00000000   ; ........................
            DEFB    %00000000, %00111111, %00000000   ; ..........######........
            DEFB    %00000000, %01111111, %10000000   ; .........########.......
            DEFB    %00000000, %11111111, %11000000   ; ........##########......
            DEFB    %00000111, %11111111, %10000000   ; .....############.......
            DEFB    %00000000, %00001111, %11000000   ; ............######......
            DEFB    %00000000, %00011111, %11000000   ; ...........#######......
            DEFB    %00000000, %00111111, %11000000   ; ..........########......
            DEFB    %00000000, %00111111, %11000000   ; ..........########......
            DEFB    %00000000, %01111111, %11000000   ; .........#########......
            DEFB    %00000000, %11111111, %11000000   ; ........##########......
            DEFB    %00000001, %11111111, %11000000   ; .......###########......
            DEFB    %00000011, %11111111, %11000000   ; ......############......
            DEFB    %00001111, %11111111, %11110000   ; ....################....
            DEFB    %00001111, %11111111, %11110000   ; ....################....
            DEFB    %00000011, %11111111, %11110000   ; ......##############....
            DEFB    %00000000, %01111111, %11110000   ; .........###########....
            DEFB    %00000000, %00111111, %11110000   ; ..........##########....
            DEFB    %00000000, %00111111, %11110000   ; ..........##########....
            DEFB    %00000000, %00111111, %11110000   ; ..........##########....
            DEFB    %00000000, %01111111, %11111000   ; .........############...
            DEFB    %00000000, %01111100, %11111000   ; .........#####..#####...
            DEFB    %00000000, %01111000, %01111000   ; .........####....####...
            DEFB    %00000000, %11111000, %01111100   ; ........#####....#####..
            DEFB    %00000000, %11110000, %00111100   ; ........####......####..
            DEFB    %00000001, %11110000, %00111100   ; .......#####......####..
            DEFB    %00000001, %11100000, %00111110   ; .......####.......#####.
            DEFB    %00000001, %11100000, %00011110   ; .......####........####.
            DEFB    %00000011, %11100000, %00011110   ; ......#####........####.
            DEFB    %00000011, %11000000, %00011110   ; ......####.........####.
            DEFB    %00000111, %11000000, %00001111   ; .....#####..........####
            DEFB    %00001111, %11000000, %00011111   ; ....######.........#####

spr_cactus:              ; cactus, 16x32
            DEFB    %00000011, %11000000   ; ......####......
            DEFB    %00110011, %11001100   ; ..##..####..##..
            DEFB    %00110011, %11001100   ; ..##..####..##..
            DEFB    %00110011, %11001100   ; ..##..####..##..
            DEFB    %00110011, %11001100   ; ..##..####..##..
            DEFB    %00110011, %11001100   ; ..##..####..##..
            DEFB    %00111111, %11101100   ; ..#########.##..
            DEFB    %00111111, %11101100   ; ..#########.##..
            DEFB    %00000011, %11111000   ; ......#######...
            DEFB    %00000011, %11111000   ; ......#######...
            DEFB    %00000011, %11000000   ; ......####......
            DEFB    %00000011, %11000000   ; ......####......
            DEFB    %00000111, %11100000   ; .....######.....
            DEFB    %00000011, %11000000   ; ......####......
            DEFB    %00000011, %11000000   ; ......####......
            DEFB    %00000011, %11000000   ; ......####......
            DEFB    %00000111, %11100000   ; .....######.....
            DEFB    %00000011, %11000000   ; ......####......
            DEFB    %00000011, %11000000   ; ......####......
            DEFB    %00000011, %11000000   ; ......####......
            DEFB    %00000011, %11000000   ; ......####......
            DEFB    %00000111, %11100000   ; .....######.....
            DEFB    %00000011, %11000000   ; ......####......
            DEFB    %00000011, %11000000   ; ......####......
            DEFB    %00000011, %11000000   ; ......####......
            DEFB    %00000011, %11000000   ; ......####......
            DEFB    %00000011, %11000000   ; ......####......
            DEFB    %00000011, %11000000   ; ......####......
            DEFB    %00000011, %11000000   ; ......####......
            DEFB    %00000011, %11000000   ; ......####......
            DEFB    %00000011, %11000000   ; ......####......
            DEFB    %00000011, %11000000   ; ......####......

spr_carreta:             ; carreta, 24x28
            DEFB    %00000001, %11111111, %10000000   ; .......##########.......
            DEFB    %00000111, %11111111, %11100000   ; .....##############.....
            DEFB    %00001111, %11111111, %11110000   ; ....################....
            DEFB    %00011111, %11111111, %11111000   ; ...##################...
            DEFB    %00011111, %10000001, %11111000   ; ...######......######...
            DEFB    %00011111, %10000001, %11111000   ; ...######......######...
            DEFB    %00011111, %00000000, %11111000   ; ...#####........#####...
            DEFB    %00011111, %00000000, %11111000   ; ...#####........#####...
            DEFB    %00011111, %00000000, %11111000   ; ...#####........#####...
            DEFB    %00011111, %10000001, %11111000   ; ...######......######...
            DEFB    %00011111, %10000001, %11111000   ; ...######......######...
            DEFB    %00011111, %11000011, %11111000   ; ...#######....#######...
            DEFB    %00011111, %11000011, %11111000   ; ...#######....#######...
            DEFB    %00011111, %11000011, %11111000   ; ...#######....#######...
            DEFB    %00011111, %11000011, %11111000   ; ...#######....#######...
            DEFB    %00011111, %11000011, %11111000   ; ...#######....#######...
            DEFB    %00111111, %11111111, %11111100   ; ..####################..
            DEFB    %11111111, %11111111, %11111111   ; ########################
            DEFB    %11111111, %11111111, %11111111   ; ########################
            DEFB    %00000111, %10000001, %11100000   ; .....####......####.....
            DEFB    %00001111, %11000011, %11110000   ; ....######....######....
            DEFB    %00011000, %01100110, %00011000   ; ...##....##..##....##...
            DEFB    %00011000, %01100110, %00011000   ; ...##....##..##....##...
            DEFB    %00011000, %01100110, %00011000   ; ...##....##..##....##...
            DEFB    %00011000, %01100110, %00011000   ; ...##....##..##....##...
            DEFB    %00001111, %11000011, %11110000   ; ....######....######....
            DEFB    %00000111, %10000001, %11100000   ; .....####......####.....
            DEFB    %00000000, %00000000, %00000000   ; ........................

spr_cayendo:             ; el pistolero doblandose, 24x32
            DEFB    %00000000, %00000000, %00000000   ; ........................
            DEFB    %00000000, %00000000, %00000000   ; ........................
            DEFB    %00000000, %00111111, %11000000   ; ..........########......
            DEFB    %00000000, %01111111, %11100000   ; .........##########.....
            DEFB    %00000000, %11111111, %11110000   ; ........############....
            DEFB    %00000000, %00111111, %00000000   ; ..........######........
            DEFB    %00000000, %00100100, %00000000   ; ..........#..#..........
            DEFB    %00000000, %01111111, %10000000   ; .........########.......
            DEFB    %00000000, %11111111, %11000000   ; ........##########......
            DEFB    %00000001, %11111111, %11100000   ; .......############.....
            DEFB    %00000011, %11111111, %11110000   ; ......##############....
            DEFB    %00000111, %11111111, %11111000   ; .....################...
            DEFB    %00001111, %11111100, %00000000   ; ....##########..........
            DEFB    %00011111, %11110000, %00000000   ; ...#########............
            DEFB    %00011111, %11100000, %00000000   ; ...########.............
            DEFB    %00011111, %11100000, %00000000   ; ...########.............
            DEFB    %00011111, %11110000, %00000000   ; ...#########............
            DEFB    %00011111, %11111000, %00000000   ; ...##########...........
            DEFB    %00011111, %11111100, %00000000   ; ...###########..........
            DEFB    %00001111, %11111100, %00000000   ; ....##########..........
            DEFB    %00001111, %11111000, %00000000   ; ....#########...........
            DEFB    %00001111, %10111100, %00000000   ; ....#####.####..........
            DEFB    %00011111, %00011110, %00000000   ; ...#####...####.........
            DEFB    %00011110, %00001111, %00000000   ; ...####.....####........
            DEFB    %00111100, %00000111, %10000000   ; ..####.......####.......
            DEFB    %00111100, %00000011, %11000000   ; ..####........####......
            DEFB    %01111000, %00000011, %11000000   ; .####.........####......
            DEFB    %01111000, %00000001, %11100000   ; .####..........####.....
            DEFB    %11110000, %00000001, %11100000   ; ####...........####.....
            DEFB    %11110000, %00000000, %11110000   ; ####............####....
            DEFB    %11100000, %00000000, %11111000   ; ###.............#####...
            DEFB    %11000000, %00000000, %01111000   ; ##...............####...

spr_balazo_m:            ; la bala en primer plano con margenes, 40x8
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000000   ; ........................................
            DEFB    %00000000, %00100011, %11101111, %11111111, %00000000   ; ..........#...#####.############........
            DEFB    %00000000, %01001111, %11111110, %11111111, %00000000   ; .........#..###########.########........
            DEFB    %00000000, %10011111, %11111111, %11111111, %00000000   ; ........#..#####################........
            DEFB    %00000000, %10011111, %11111111, %11111111, %00000000   ; ........#..#####################........
            DEFB    %00000000, %01001111, %11111110, %11111111, %00000000   ; .........#..###########.########........
            DEFB    %00000000, %00100011, %11101111, %11111111, %00000000   ; ..........#...#####.############........
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000000   ; ........................................

spr_cara:                ; primer plano, 48x48
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000000, %00000000   ; ................................................
            DEFB    %00000000, %01111111, %11111111, %11111111, %10000000, %00000000   ; .........########################...............
            DEFB    %00000011, %11111111, %11111111, %11111111, %11110000, %00000000   ; ......##############################............
            DEFB    %00001111, %11111111, %11111111, %11111111, %11111100, %00000000   ; ....##################################..........
            DEFB    %00011111, %11111111, %11111111, %11111111, %11111110, %00000000   ; ...####################################.........
            DEFB    %00111111, %11111111, %11111111, %11111111, %11111111, %00000000   ; ..######################################........
            DEFB    %01111111, %11111111, %11111111, %11111111, %11111111, %10000000   ; .########################################.......
            DEFB    %11111111, %11111111, %11111111, %11111111, %11111111, %11000000   ; ##########################################......
            DEFB    %11111111, %11111111, %11111111, %11111111, %11111111, %11100000   ; ###########################################.....
            DEFB    %11111111, %11111111, %11111111, %11111111, %11111111, %11110000   ; ############################################....
            DEFB    %11111111, %11111111, %11111111, %11111111, %11111111, %11111000   ; #############################################...
            DEFB    %00111111, %11111111, %11111111, %11111111, %11111111, %11111000   ; ..###########################################...
            DEFB    %00001111, %11111111, %11111111, %11111111, %11111111, %11110000   ; ....########################################....
            DEFB    %00000011, %11111111, %11111111, %11111111, %11111111, %10000000   ; ......###################################.......
            DEFB    %00000000, %01111111, %11111111, %11111111, %11111000, %00000000   ; .........############################...........
            DEFB    %00000000, %00011111, %11111111, %11111111, %11100000, %00000000   ; ...........########################.............
            DEFB    %00000000, %00111111, %11111111, %11111111, %11110000, %00000000   ; ..........##########################............
            DEFB    %00000000, %01111111, %11111111, %11111111, %11111000, %00000000   ; .........############################...........
            DEFB    %00000000, %11111111, %11111111, %11111111, %11111100, %00000000   ; ........##############################..........
            DEFB    %00000000, %11110000, %00000000, %00000000, %11110000, %00000000   ; ........####....................####............
            DEFB    %00000000, %11100000, %00000000, %00000000, %01110000, %00000000   ; ........###......................###............
            DEFB    %00000000, %11000111, %10000000, %00011110, %00110000, %00000000   ; ........##...####..........####...##............
            DEFB    %00000000, %11001111, %11000000, %00111111, %00110000, %00000000   ; ........##..######........######..##............
            DEFB    %00000000, %11001100, %11000000, %00110011, %00110000, %00000000   ; ........##..##..##........##..##..##............
            DEFB    %00000000, %11001111, %11000000, %00111111, %00110000, %00000000   ; ........##..######........######..##............
            DEFB    %00000000, %11000111, %10000000, %00011110, %00110000, %00000000   ; ........##...####..........####...##............
            DEFB    %00000000, %11000000, %00000000, %00000000, %00110000, %00000000   ; ........##........................##............
            DEFB    %00000000, %11000000, %00000110, %00000000, %00110000, %00000000   ; ........##...........##...........##............
            DEFB    %00000000, %11000000, %00001111, %00000000, %00110000, %00000000   ; ........##..........####..........##............
            DEFB    %00000000, %11000000, %00011111, %10000000, %00110000, %00000000   ; ........##.........######.........##............
            DEFB    %00000000, %11000000, %00011111, %10000000, %00110000, %00000000   ; ........##.........######.........##............
            DEFB    %00000000, %11000000, %00001111, %00000000, %00110000, %00000000   ; ........##..........####..........##............
            DEFB    %00000000, %11100000, %00000000, %00000000, %00110000, %00000000   ; ........###.......................##............
            DEFB    %00000000, %11110000, %00000000, %00000000, %01110000, %00000000   ; ........####.....................###............
            DEFB    %00000000, %11111000, %00000000, %00000000, %11110000, %00000000   ; ........#####...................####............
            DEFB    %00000000, %01111000, %00000000, %00000000, %11110000, %00000000   ; .........####...................####............
            DEFB    %00000000, %01111001, %11111111, %11111111, %00111000, %00000000   ; .........####..#################..###...........
            DEFB    %00000000, %01111001, %10000000, %00001100, %11111000, %00000000   ; .........####..##...........##..#####...........
            DEFB    %00000000, %01111100, %11111111, %11111001, %11111000, %00000000   ; .........#####..#############..######...........
            DEFB    %00000000, %00111110, %00000000, %00000011, %11111000, %00000000   ; ..........#####...............#######...........
            DEFB    %00000000, %00111111, %00000000, %00000111, %11111000, %00000000   ; ..........######.............########...........
            DEFB    %00000000, %00111111, %10000000, %00001111, %11111000, %00000000   ; ..........#######...........#########...........
            DEFB    %00000000, %00011111, %11111111, %11111111, %11111100, %00000000   ; ...........###########################..........
            DEFB    %00000000, %00011111, %11111111, %11111111, %11111000, %00000000   ; ...........##########################...........
            DEFB    %00000000, %00001111, %11111111, %11111111, %11110000, %00000000   ; ............########################............
            DEFB    %00000000, %00000011, %11111111, %11111111, %11000000, %00000000   ; ..............####################..............
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000000, %00000000   ; ................................................
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000000, %00000000   ; ................................................

spr_balazo:              ; la bala en primer plano, 24x8; la punta a la derecha
            DEFB    %00000000, %00000000, %00000000   ; ........................
            DEFB    %11111111, %11110111, %11000100   ; ############.#####...#..
            DEFB    %11111111, %01111111, %11110010   ; ########.###########..#.
            DEFB    %11111111, %11111111, %11111001   ; #####################..#
            DEFB    %11111111, %11111111, %11111001   ; #####################..#
            DEFB    %11111111, %01111111, %11110010   ; ########.###########..#.
            DEFB    %11111111, %11110111, %11000100   ; ############.#####...#..
            DEFB    %00000000, %00000000, %00000000   ; ........................

spr_caballo0:      ; caballo al paso 1
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000001, %11111000, %00000000   ; .......................................######...........
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000001, %11111100, %00000000   ; .......................................#######..........
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000011, %11111110, %00000000   ; ......................................#########.........
            DEFB    %00000000, %00000000, %00000000, %00000000, %00001111, %11111111, %00000000   ; ....................................############........
            DEFB    %00000000, %00000000, %00000000, %00000000, %00011111, %11111111, %10000000   ; ...................................##############.......
            DEFB    %00000000, %00000000, %00000000, %00000000, %00111111, %11111111, %00000000   ; ..................................##############........
            DEFB    %00000000, %00111000, %01000000, %00000000, %11111111, %10010010, %00000000   ; ..........###....#..............#########..#..#.........
            DEFB    %00000000, %00111011, %11111000, %01000111, %11111111, %00000000, %00000000   ; ..........###.#######....#...###########................
            DEFB    %00000000, %01111111, %11111111, %11111111, %11111110, %00000000, %00000000   ; .........##############################.................
            DEFB    %00000000, %01111111, %11111111, %11111111, %11111100, %00000000, %00000000   ; .........#############################..................
            DEFB    %00000000, %01111111, %11111111, %11111111, %11111000, %00000000, %00000000   ; .........############################...................
            DEFB    %00000000, %11111111, %11111111, %11111111, %11111100, %00000000, %00000000   ; ........##############################..................
            DEFB    %00000000, %11111111, %11111111, %11111111, %11111000, %00000000, %00000000   ; ........#############################...................
            DEFB    %00000000, %11101111, %11111111, %11111111, %11111000, %00000000, %00000000   ; ........###.#########################...................
            DEFB    %00000000, %11100111, %11111111, %11111111, %11111000, %00000000, %00000000   ; ........###..########################...................
            DEFB    %00000000, %11100011, %11111111, %11111111, %11110000, %00000000, %00000000   ; ........###...######################....................
            DEFB    %00000000, %01110001, %11111111, %11111111, %11100000, %00000000, %00000000   ; .........###...####################.....................
            DEFB    %00000000, %01110011, %11111000, %01000011, %11110000, %00000000, %00000000   ; .........###..#######....#....######....................
            DEFB    %00000000, %01110011, %11111000, %00000011, %11110000, %00000000, %00000000   ; .........###..#######.........######....................
            DEFB    %00000000, %00100011, %10111000, %00000011, %11110000, %00000000, %00000000   ; ..........#...###.###.........######....................
            DEFB    %00000000, %00000011, %10111000, %00000011, %11110000, %00000000, %00000000   ; ..............###.###.........######....................
            DEFB    %00000000, %00000011, %10111000, %00000011, %11110000, %00000000, %00000000   ; ..............###.###.........######....................
            DEFB    %00000000, %00000111, %10010000, %00000001, %01111000, %00000000, %00000000   ; .............####..#...........#.####...................
            DEFB    %00000000, %00000111, %00001000, %00000010, %00111000, %00000000, %00000000   ; .............###....#.........#...###...................
            DEFB    %00000000, %00001111, %00001000, %00000010, %00111100, %00000000, %00000000   ; ............####....#.........#...####..................
            DEFB    %00000000, %00001110, %00001000, %00000010, %00011100, %00000000, %00000000   ; ............###.....#.........#....###..................
            DEFB    %00000000, %00011110, %00001111, %00001111, %00011111, %00000000, %00000000   ; ...........####.....####....####...#####................
            DEFB    %00000000, %00111111, %00011111, %10011111, %10011111, %10000000, %00000000   ; ..........######...######..######..######...............
            DEFB    %00000000, %00011110, %00001111, %00001111, %00001111, %00000000, %00000000   ; ...........####.....####....####....####................
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000   ; ........................................................
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000   ; ........................................................
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000   ; ........................................................

spr_caballo1:      ; caballo al paso 2
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000001, %11111000, %00000000   ; .......................................######...........
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000001, %11111100, %00000000   ; .......................................#######..........
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000011, %11111110, %00000000   ; ......................................#########.........
            DEFB    %00000000, %00000000, %00000000, %00000000, %00001111, %11111111, %00000000   ; ....................................############........
            DEFB    %00000000, %00000000, %00000000, %00000000, %00011111, %11111111, %10000000   ; ...................................##############.......
            DEFB    %00000000, %00000000, %00000000, %00000000, %00111111, %11111111, %00000000   ; ..................................##############........
            DEFB    %00000000, %00111000, %01000000, %00000000, %11111111, %10010010, %00000000   ; ..........###....#..............#########..#..#.........
            DEFB    %00000000, %00111011, %11111000, %01000111, %11111111, %00000000, %00000000   ; ..........###.#######....#...###########................
            DEFB    %00000000, %01111111, %11111111, %11111111, %11111110, %00000000, %00000000   ; .........##############################.................
            DEFB    %00000000, %01111111, %11111111, %11111111, %11111100, %00000000, %00000000   ; .........#############################..................
            DEFB    %00000000, %01111111, %11111111, %11111111, %11111000, %00000000, %00000000   ; .........############################...................
            DEFB    %00000000, %11111111, %11111111, %11111111, %11111100, %00000000, %00000000   ; ........##############################..................
            DEFB    %00000000, %11111111, %11111111, %11111111, %11111000, %00000000, %00000000   ; ........#############################...................
            DEFB    %00000000, %11101111, %11111111, %11111111, %11111000, %00000000, %00000000   ; ........###.#########################...................
            DEFB    %00000000, %11100111, %11111111, %11111111, %11111000, %00000000, %00000000   ; ........###..########################...................
            DEFB    %00000000, %11100011, %11111111, %11111111, %11110000, %00000000, %00000000   ; ........###...######################....................
            DEFB    %00000000, %01110001, %11111111, %11111111, %11100000, %00000000, %00000000   ; .........###...####################.....................
            DEFB    %00000000, %01110011, %11111000, %01000011, %11110000, %00000000, %00000000   ; .........###..#######....#....######....................
            DEFB    %00000000, %01110011, %11111000, %00000011, %11110000, %00000000, %00000000   ; .........###..#######.........######....................
            DEFB    %00000000, %00100011, %11111000, %00000011, %11110000, %00000000, %00000000   ; ..........#...#######.........######....................
            DEFB    %00000000, %00000011, %10111000, %00000011, %11110000, %00000000, %00000000   ; ..............###.###.........######....................
            DEFB    %00000000, %00000011, %10111000, %00000011, %11110000, %00000000, %00000000   ; ..............###.###.........######....................
            DEFB    %00000000, %00000011, %10111000, %00000011, %11110000, %00000000, %00000000   ; ..............###.###.........######....................
            DEFB    %00000000, %00000011, %10010000, %00000001, %01110000, %00000000, %00000000   ; ..............###..#...........#.###....................
            DEFB    %00000000, %00000011, %10010000, %00000001, %01110000, %00000000, %00000000   ; ..............###..#...........#.###....................
            DEFB    %00000000, %00000111, %00010000, %00000001, %00111000, %00000000, %00000000   ; .............###...#...........#..###...................
            DEFB    %00000000, %00000111, %10111100, %00000011, %11111100, %00000000, %00000000   ; .............####.####........########..................
            DEFB    %00000000, %00001111, %11111110, %00000111, %11111110, %00000000, %00000000   ; ............###########......##########.................
            DEFB    %00000000, %00000111, %10111100, %00000011, %11111100, %00000000, %00000000   ; .............####.####........########..................
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000   ; ........................................................
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000   ; ........................................................
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000   ; ........................................................

spr_caballo2:      ; caballo al paso 3
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000001, %11111000, %00000000   ; .......................................######...........
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000001, %11111100, %00000000   ; .......................................#######..........
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000011, %11111110, %00000000   ; ......................................#########.........
            DEFB    %00000000, %00000000, %00000000, %00000000, %00001111, %11111111, %00000000   ; ....................................############........
            DEFB    %00000000, %00000000, %00000000, %00000000, %00011111, %11111111, %10000000   ; ...................................##############.......
            DEFB    %00000000, %00000000, %00000000, %00000000, %00111111, %11111111, %00000000   ; ..................................##############........
            DEFB    %00000000, %00111000, %01000000, %00000000, %11111111, %10010010, %00000000   ; ..........###....#..............#########..#..#.........
            DEFB    %00000000, %00111011, %11111000, %01000111, %11111111, %00000000, %00000000   ; ..........###.#######....#...###########................
            DEFB    %00000000, %01111111, %11111111, %11111111, %11111110, %00000000, %00000000   ; .........##############################.................
            DEFB    %00000000, %01111111, %11111111, %11111111, %11111100, %00000000, %00000000   ; .........#############################..................
            DEFB    %00000000, %01111111, %11111111, %11111111, %11111000, %00000000, %00000000   ; .........############################...................
            DEFB    %00000000, %11111111, %11111111, %11111111, %11111100, %00000000, %00000000   ; ........##############################..................
            DEFB    %00000000, %11111111, %11111111, %11111111, %11111000, %00000000, %00000000   ; ........#############################...................
            DEFB    %00000000, %11101111, %11111111, %11111111, %11111000, %00000000, %00000000   ; ........###.#########################...................
            DEFB    %00000000, %11100111, %11111111, %11111111, %11111000, %00000000, %00000000   ; ........###..########################...................
            DEFB    %00000000, %11100011, %11111111, %11111111, %11110000, %00000000, %00000000   ; ........###...######################....................
            DEFB    %00000000, %01110001, %11111111, %11111111, %11100000, %00000000, %00000000   ; .........###...####################.....................
            DEFB    %00000000, %01110011, %11111000, %01000011, %11110000, %00000000, %00000000   ; .........###..#######....#....######....................
            DEFB    %00000000, %01110011, %11111000, %00000011, %11110000, %00000000, %00000000   ; .........###..#######.........######....................
            DEFB    %00000000, %00100011, %10111000, %00000011, %11110000, %00000000, %00000000   ; ..........#...###.###.........######....................
            DEFB    %00000000, %00000011, %10111000, %00000011, %11110000, %00000000, %00000000   ; ..............###.###.........######....................
            DEFB    %00000000, %00000011, %10111000, %00000011, %11110000, %00000000, %00000000   ; ..............###.###.........######....................
            DEFB    %00000000, %00000011, %11010000, %00000001, %11110000, %00000000, %00000000   ; ..............####.#...........#####....................
            DEFB    %00000000, %00000001, %11100000, %00000000, %11100000, %00000000, %00000000   ; ...............####.............###.....................
            DEFB    %00000000, %00000001, %11100000, %00000001, %11100000, %00000000, %00000000   ; ...............####............####.....................
            DEFB    %00000000, %00000000, %11100000, %00000001, %11000000, %00000000, %00000000   ; ................###............###......................
            DEFB    %00000000, %00000000, %11111000, %00000011, %11110000, %00000000, %00000000   ; ................#####.........######....................
            DEFB    %00000000, %00000001, %11111100, %00000111, %11111000, %00000000, %00000000   ; ...............#######.......########...................
            DEFB    %00000000, %00000000, %11111000, %00000011, %11110000, %00000000, %00000000   ; ................#####.........######....................
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000   ; ........................................................
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000   ; ........................................................
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000   ; ........................................................

spr_caballo_pasta: ; caballo pastando
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000   ; ........................................................
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000   ; ........................................................
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000   ; ........................................................
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000   ; ........................................................
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000   ; ........................................................
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000   ; ........................................................
            DEFB    %00000000, %00111000, %01000000, %00000000, %10000000, %00000000, %00000000   ; ..........###....#..............#.......................
            DEFB    %00000000, %00111011, %11111000, %01000111, %11110000, %00000000, %00000000   ; ..........###.#######....#...#######....................
            DEFB    %00000000, %01111111, %11111111, %11111111, %11111000, %00000000, %00000000   ; .........############################...................
            DEFB    %00000000, %01111111, %11111111, %11111111, %11111000, %00000000, %00000000   ; .........############################...................
            DEFB    %00000000, %01111111, %11111111, %11111111, %11111000, %00000000, %00000000   ; .........############################...................
            DEFB    %00000000, %11111111, %11111111, %11111111, %11111100, %00000000, %00000000   ; ........##############################..................
            DEFB    %00000000, %11111111, %11111111, %11111111, %11111110, %00000000, %00000000   ; ........###############################.................
            DEFB    %00000000, %11101111, %11111111, %11111111, %11111111, %00000000, %00000000   ; ........###.############################................
            DEFB    %00000000, %11100111, %11111111, %11111111, %11111111, %10000000, %00000000   ; ........###..############################...............
            DEFB    %00000000, %11100011, %11111111, %11111111, %11111111, %10000000, %00000000   ; ........###...###########################...............
            DEFB    %00000000, %01110001, %11111111, %11111111, %11111111, %11000000, %00000000   ; .........###...###########################..............
            DEFB    %00000000, %01110011, %11111000, %01000011, %11111111, %11100000, %00000000   ; .........###..#######....#....#############.............
            DEFB    %00000000, %01110011, %11111000, %00000011, %11110111, %11110000, %00000000   ; .........###..#######.........######.#######............
            DEFB    %00000000, %00100011, %11111000, %00000011, %11110011, %11111100, %00000000   ; ..........#...#######.........######..########..........
            DEFB    %00000000, %00000011, %10111000, %00000011, %11110001, %11111110, %00000000   ; ..............###.###.........######...########.........
            DEFB    %00000000, %00000011, %10111000, %00000011, %11110001, %11111111, %00000000   ; ..............###.###.........######...#########........
            DEFB    %00000000, %00000011, %10111000, %00000011, %11110000, %11111110, %00000000   ; ..............###.###.........######....#######.........
            DEFB    %00000000, %00000011, %10010000, %00000001, %01110000, %01111111, %00000000   ; ..............###..#...........#.###.....#######........
            DEFB    %00000000, %00000011, %10010000, %00000001, %01110000, %00011110, %00000000   ; ..............###..#...........#.###.......####.........
            DEFB    %00000000, %00000111, %00010000, %00000001, %00111000, %00000100, %00000000   ; .............###...#...........#..###........#..........
            DEFB    %00000000, %00000111, %10111100, %00000011, %11111100, %00000000, %00000000   ; .............####.####........########..................
            DEFB    %00000000, %00001111, %11111110, %00000111, %11111110, %00000000, %00000000   ; ............###########......##########.................
            DEFB    %00000000, %00000111, %10111100, %00000011, %11111100, %00000000, %00000000   ; .............####.####........########..................
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000   ; ........................................................
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000   ; ........................................................
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000   ; ........................................................

spr_caballo_alza:  ; caballo encabritado
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000001, %11111100, %00000000   ; .......................................#######..........
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000011, %11111110, %00000000   ; ......................................#########.........
            DEFB    %00000000, %00000000, %00000000, %00000000, %00001111, %11111111, %00000000   ; ....................................############........
            DEFB    %00000000, %00000000, %00000000, %00000000, %10011111, %11111111, %10000000   ; ................................#..##############.......
            DEFB    %00000000, %00000000, %00000000, %00000111, %11111111, %11111111, %00000000   ; .............................###################........
            DEFB    %00000000, %00000000, %00000000, %00001111, %11111111, %00010010, %00000000   ; ............................############...#..#.........
            DEFB    %00000000, %00000000, %00000000, %00111111, %11111110, %00000000, %00000000   ; ..........................#############.................
            DEFB    %00000000, %00000000, %00000000, %01111111, %11111000, %00000000, %00000000   ; .........................############...................
            DEFB    %00000000, %00000000, %00000000, %11111111, %11111100, %00000000, %00000000   ; ........................##############..................
            DEFB    %00000000, %00000000, %00000001, %11111111, %11111000, %00000000, %00000000   ; .......................##############...................
            DEFB    %00000000, %00000000, %00000011, %11111111, %11111000, %00000000, %00000000   ; ......................###############...................
            DEFB    %00000000, %00000000, %00000111, %11111111, %11111000, %00000000, %00000000   ; .....................################...................
            DEFB    %00000000, %00000000, %00001111, %11111111, %11111110, %00000000, %00000000   ; ....................###################.................
            DEFB    %00000000, %00000000, %00011111, %11111111, %11111111, %10000000, %00000000   ; ...................######################...............
            DEFB    %00000000, %00000000, %00111111, %11111111, %11111111, %11000000, %00000000   ; ..................########################..............
            DEFB    %00000000, %00000000, %01111111, %11111111, %11111111, %11000000, %00000000   ; .................#########################..............
            DEFB    %00000000, %00000000, %11111111, %11111110, %11111011, %11000000, %00000000   ; ................###############.#####.####..............
            DEFB    %00000000, %00000001, %11111111, %11111100, %01111111, %10000000, %00000000   ; ...............###############...########...............
            DEFB    %00000000, %00001111, %11111111, %11111000, %00011111, %00000000, %00000000   ; ............#################......#####................
            DEFB    %00000000, %00011111, %11111111, %11110000, %00011111, %10000000, %00000000   ; ...........#################.......######...............
            DEFB    %00000000, %00111111, %11111111, %11100000, %01111111, %00000000, %00000000   ; ..........#################......#######................
            DEFB    %00000000, %01111111, %11111111, %11000000, %11111100, %00000000, %00000000   ; .........#################......######..................
            DEFB    %00000000, %01111111, %11111111, %10000000, %01111000, %00000000, %00000000   ; .........################........####...................
            DEFB    %00000000, %11111111, %11111111, %00000000, %00000000, %00000000, %00000000   ; ........################................................
            DEFB    %00000000, %11110111, %11111111, %00000000, %00000000, %00000000, %00000000   ; ........####.###########................................
            DEFB    %00000000, %11100111, %11111111, %00000000, %00000000, %00000000, %00000000   ; ........###..###########................................
            DEFB    %00000000, %11100011, %11111110, %00000000, %00000000, %00000000, %00000000   ; ........###...#########.................................
            DEFB    %00000000, %11100001, %11111110, %00000000, %00000000, %00000000, %00000000   ; ........###....########.................................
            DEFB    %00000000, %11100011, %11111100, %00000000, %00000000, %00000000, %00000000   ; ........###...########..................................
            DEFB    %00000000, %11100011, %11011100, %00000000, %00000000, %00000000, %00000000   ; ........###...####.###..................................
            DEFB    %00000000, %11100011, %11111111, %10000000, %00000000, %00000000, %00000000   ; ........###...###########...............................
            DEFB    %00000000, %01000001, %11111111, %11000000, %00000000, %00000000, %00000000   ; .........#.....###########..............................

; ---- letras del logotipo (16x14 pixeles) ----------------------------
logo_letras:
            DEFW    logo_b, logo_a, logo_l, logo_a, logo_v, logo_a

logo_a:                                 ; letra A del logotipo
            DEFB    %00001111,%10000000   ; ....#####.......
            DEFB    %00011111,%11000000   ; ...#######......
            DEFB    %00111000,%11100000   ; ..###...###.....
            DEFB    %01110000,%01110000   ; .###.....###....
            DEFB    %11100000,%00111000   ; ###.......###...
            DEFB    %11100000,%00111000   ; ###.......###...
            DEFB    %11100000,%00111000   ; ###.......###...
            DEFB    %11111111,%11111000   ; #############...
            DEFB    %11111111,%11111000   ; #############...
            DEFB    %11100000,%00111000   ; ###.......###...
            DEFB    %11100000,%00111000   ; ###.......###...
            DEFB    %11100000,%00111000   ; ###.......###...
            DEFB    %11100000,%00111000   ; ###.......###...
            DEFB    %11100000,%00111000   ; ###.......###...

logo_b:                                 ; letra B del logotipo
            DEFB    %11111111,%11000000   ; ##########......
            DEFB    %11111111,%11100000   ; ###########.....
            DEFB    %11100000,%11110000   ; ###.....####....
            DEFB    %11100000,%01110000   ; ###......###....
            DEFB    %11100000,%11110000   ; ###.....####....
            DEFB    %11111111,%11100000   ; ###########.....
            DEFB    %11111111,%11000000   ; ##########......
            DEFB    %11111111,%11100000   ; ###########.....
            DEFB    %11100000,%11110000   ; ###.....####....
            DEFB    %11100000,%01110000   ; ###......###....
            DEFB    %11100000,%01110000   ; ###......###....
            DEFB    %11100000,%11110000   ; ###.....####....
            DEFB    %11111111,%11100000   ; ###########.....
            DEFB    %11111111,%11000000   ; ##########......

logo_l:                                 ; letra L del logotipo
            DEFB    %11100000,%00000000   ; ###.............
            DEFB    %11100000,%00000000   ; ###.............
            DEFB    %11100000,%00000000   ; ###.............
            DEFB    %11100000,%00000000   ; ###.............
            DEFB    %11100000,%00000000   ; ###.............
            DEFB    %11100000,%00000000   ; ###.............
            DEFB    %11100000,%00000000   ; ###.............
            DEFB    %11100000,%00000000   ; ###.............
            DEFB    %11100000,%00000000   ; ###.............
            DEFB    %11100000,%00000000   ; ###.............
            DEFB    %11100000,%00000000   ; ###.............
            DEFB    %11100000,%00000000   ; ###.............
            DEFB    %11111111,%11111000   ; #############...
            DEFB    %11111111,%11111000   ; #############...

logo_v:                                 ; letra V del logotipo
            DEFB    %11100000,%00111000   ; ###.......###...
            DEFB    %11100000,%00111000   ; ###.......###...
            DEFB    %11100000,%00111000   ; ###.......###...
            DEFB    %11100000,%00111000   ; ###.......###...
            DEFB    %11100000,%00111000   ; ###.......###...
            DEFB    %01110000,%01110000   ; .###.....###....
            DEFB    %01110000,%01110000   ; .###.....###....
            DEFB    %00111000,%11100000   ; ..###...###.....
            DEFB    %00111000,%11100000   ; ..###...###.....
            DEFB    %00011101,%11000000   ; ...###.###......
            DEFB    %00011101,%11000000   ; ...###.###......
            DEFB    %00001111,%10000000   ; ....#####.......
            DEFB    %00001111,%10000000   ; ....#####.......
            DEFB    %00000111,%00000000   ; .....###........

; ---- textos ---------------------------------------------------------
txt_poli:        DEFB "SHERIFF:",0
txt_ladron:      DEFB "BANDIDO:",0
txt_juego:       DEFB "BALAVA",0
txt_op1:         DEFB "1  UN JUGADOR",0
txt_op2:         DEFB "2  DOS JUGADORES",0
txt_op3:         DEFB "3  CONTROLES",0
txt_op4:         DEFB "4  CREDITOS",0
txt_pulsa:       DEFB "PULSA 1, 2, 3 O 4",0
txt_autor:       DEFB "(C) 2026 KBZA SOFT",0
txt_controles:   DEFB "CONTROLES",0
txt_j1:          DEFB "JUGADOR 1 - SHERIFF",0
txt_j1b:         DEFB "Q=ARRIBA  A=ABAJO",0
txt_j1c:         DEFB "Z=DISPARO",0
txt_j2:          DEFB "JUGADOR 2 - BANDIDO",0
txt_j2b:         DEFB "P=ARRIBA  L=ABAJO",0
txt_j2c:         DEFB "B=DISPARO",0
txt_reglas:      DEFB "5 IMPACTOS PARA GANAR",0
txt_tecla:       DEFB "PULSA CUALQUIER TECLA",0
txt_rip:         DEFB "DESCANSE EN PAZ",0
txt_gana_poli:   DEFB "GANA EL SHERIFF",0
txt_gana_ladron: DEFB "GANA EL BANDIDO",0
txt_final:       DEFB "RESULTADO",0
txt_empate:      DEFB "SIN BALAS: EMPATE",0
txt_marquesina:  DEFB "BALAVA   ***   UN JUEGO DE KBZA SOFT   ***   DESARROLLADO POR ALEJANDRO MARTINEZ   ***   MUSICA: ALEJANDRO MARTINEZ   ***   (C) 2026 KBZA SOFT   ***   ZX SPECTRUM 128K   ***   PULSA UNA TECLA PARA VOLVER   ***   ",0

spr_muerto:              ; el pistolero abatido, 24x16
            DEFB    %00000000, %00000000, %00000000   ; ........................
            DEFB    %00111000, %00000000, %00000000   ; ..###...................
            DEFB    %01111100, %00000000, %00000000   ; .#####..................
            DEFB    %00111000, %00000000, %00000000   ; ..###...................
            DEFB    %00000000, %00000000, %00000000   ; ........................
            DEFB    %00001111, %00000000, %00000000   ; ....####................
            DEFB    %00011111, %10000000, %00000000   ; ...######...............
            DEFB    %00011111, %10000000, %00000000   ; ...######...............
            DEFB    %00001111, %00000000, %00000000   ; ....####................
            DEFB    %00000011, %11111111, %11111111   ; ......##################
            DEFB    %00000111, %11111111, %11111111   ; .....###################
            DEFB    %00000011, %11111111, %11111111   ; ......##################
            DEFB    %00000000, %00111100, %00011110   ; ..........####.....####.
            DEFB    %00000000, %00111100, %00001111   ; ..........####......####
            DEFB    %00000000, %00011100, %00000111   ; ...........###.......###
            DEFB    %00000000, %00000000, %00000000   ; ........................

spr_carreta_m:           ; carreta con margenes, 40x28, para moverla
            DEFB    %00000000, %00000001, %11111111, %10000000, %00000000   ; ...............##########...............
            DEFB    %00000000, %00000111, %11111111, %11100000, %00000000   ; .............##############.............
            DEFB    %00000000, %00001111, %11111111, %11110000, %00000000   ; ............################............
            DEFB    %00000000, %00011111, %11111111, %11111000, %00000000   ; ...........##################...........
            DEFB    %00000000, %00011111, %10000001, %11111000, %00000000   ; ...........######......######...........
            DEFB    %00000000, %00011111, %10000001, %11111000, %00000000   ; ...........######......######...........
            DEFB    %00000000, %00011111, %00000000, %11111000, %00000000   ; ...........#####........#####...........
            DEFB    %00000000, %00011111, %00000000, %11111000, %00000000   ; ...........#####........#####...........
            DEFB    %00000000, %00011111, %00000000, %11111000, %00000000   ; ...........#####........#####...........
            DEFB    %00000000, %00011111, %10000001, %11111000, %00000000   ; ...........######......######...........
            DEFB    %00000000, %00011111, %10000001, %11111000, %00000000   ; ...........######......######...........
            DEFB    %00000000, %00011111, %11000011, %11111000, %00000000   ; ...........#######....#######...........
            DEFB    %00000000, %00011111, %11000011, %11111000, %00000000   ; ...........#######....#######...........
            DEFB    %00000000, %00011111, %11000011, %11111000, %00000000   ; ...........#######....#######...........
            DEFB    %00000000, %00011111, %11000011, %11111000, %00000000   ; ...........#######....#######...........
            DEFB    %00000000, %00011111, %11000011, %11111000, %00000000   ; ...........#######....#######...........
            DEFB    %00000000, %00111111, %11111111, %11111100, %00000000   ; ..........####################..........
            DEFB    %00000000, %11111111, %11111111, %11111111, %00000000   ; ........########################........
            DEFB    %00000000, %11111111, %11111111, %11111111, %00000000   ; ........########################........
            DEFB    %00000000, %00000111, %10000001, %11100000, %00000000   ; .............####......####.............
            DEFB    %00000000, %00001111, %11000011, %11110000, %00000000   ; ............######....######............
            DEFB    %00000000, %00011000, %01100110, %00011000, %00000000   ; ...........##....##..##....##...........
            DEFB    %00000000, %00011000, %01100110, %00011000, %00000000   ; ...........##....##..##....##...........
            DEFB    %00000000, %00011000, %01100110, %00011000, %00000000   ; ...........##....##..##....##...........
            DEFB    %00000000, %00011000, %01100110, %00011000, %00000000   ; ...........##....##..##....##...........
            DEFB    %00000000, %00001111, %11000011, %11110000, %00000000   ; ............######....######............
            DEFB    %00000000, %00000111, %10000001, %11100000, %00000000   ; .............####......####.............
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000000   ; ........................................

spr_ataud_m:             ; ataud con margenes, 40x16
            DEFB    %00000000, %00000000, %11111111, %00000000, %00000000   ; ................########................
            DEFB    %00000000, %00000001, %11111111, %10000000, %00000000   ; ...............##########...............
            DEFB    %00000000, %00000011, %11100111, %11000000, %00000000   ; ..............#####..#####..............
            DEFB    %00000000, %00000111, %11100111, %11100000, %00000000   ; .............######..######.............
            DEFB    %00000000, %00000111, %10000001, %11100000, %00000000   ; .............####......####.............
            DEFB    %00000000, %00000111, %10000001, %11100000, %00000000   ; .............####......####.............
            DEFB    %00000000, %00000111, %11100111, %11100000, %00000000   ; .............######..######.............
            DEFB    %00000000, %00000011, %11100111, %11000000, %00000000   ; ..............#####..#####..............
            DEFB    %00000000, %00000011, %11100111, %11000000, %00000000   ; ..............#####..#####..............
            DEFB    %00000000, %00000001, %11100111, %10000000, %00000000   ; ...............####..####...............
            DEFB    %00000000, %00000001, %11111111, %10000000, %00000000   ; ...............##########...............
            DEFB    %00000000, %00000000, %11111111, %00000000, %00000000   ; ................########................
            DEFB    %00000000, %00000000, %11111111, %00000000, %00000000   ; ................########................
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000000   ; ........................................
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000000   ; ........................................
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000000   ; ........................................

spr_barril:              ; barril de whisky, 16x32
            DEFB    %00011111, %11111000   ; ...##########...
            DEFB    %00111111, %11111100   ; ..############..
            DEFB    %01111111, %11111110   ; .##############.
            DEFB    %11111111, %11111111   ; ################
            DEFB    %11111111, %11111111   ; ################
            DEFB    %01101101, %10110110   ; .##.##.##.##.##.
            DEFB    %01101101, %10110110   ; .##.##.##.##.##.
            DEFB    %11011011, %01101101   ; ##.##.##.##.##.#
            DEFB    %11011011, %01101101   ; ##.##.##.##.##.#
            DEFB    %11111111, %11111111   ; ################
            DEFB    %11111111, %11111111   ; ################
            DEFB    %11011011, %01101101   ; ##.##.##.##.##.#
            DEFB    %11011011, %01101101   ; ##.##.##.##.##.#
            DEFB    %11011011, %01101101   ; ##.##.##.##.##.#
            DEFB    %11011011, %01101101   ; ##.##.##.##.##.#
            DEFB    %11011011, %01101101   ; ##.##.##.##.##.#
            DEFB    %11011011, %01101101   ; ##.##.##.##.##.#
            DEFB    %11111111, %11111111   ; ################
            DEFB    %11111111, %11111111   ; ################
            DEFB    %11011011, %01101101   ; ##.##.##.##.##.#
            DEFB    %11011011, %01101101   ; ##.##.##.##.##.#
            DEFB    %11011011, %01101101   ; ##.##.##.##.##.#
            DEFB    %11011011, %01101101   ; ##.##.##.##.##.#
            DEFB    %11011011, %01101101   ; ##.##.##.##.##.#
            DEFB    %11011011, %01101101   ; ##.##.##.##.##.#
            DEFB    %11111111, %11111111   ; ################
            DEFB    %11111111, %11111111   ; ################
            DEFB    %01101101, %10110110   ; .##.##.##.##.##.
            DEFB    %01111111, %11111110   ; .##############.
            DEFB    %01111111, %11111110   ; .##############.
            DEFB    %00111111, %11111100   ; ..############..
            DEFB    %00011111, %11111000   ; ...##########...

spr_balita:              ; una bala del contador, 8x8
            DEFB    %00000000   ; ........
            DEFB    %00111100   ; ..####..
            DEFB    %01111110   ; .######.
            DEFB    %01111110   ; .######.
            DEFB    %01111110   ; .######.
            DEFB    %01111110   ; .######.
            DEFB    %00111100   ; ..####..
            DEFB    %00000000   ; ........
;---------------------------------------------------------------------
; canciones para el AY: tres canales, periodo (dos bytes) y duracion
; en fotogramas por nota; 0xFFFF cierra el canal y vuelve a empezar
;---------------------------------------------------------------------
cancion_menu:
            DEFW    menu_a, menu_b, menu_c
            DEFB    2                       ; notas cortas, muy punteadas
cancion_funeral:
            DEFW    fune_a, fune_b, fune_c
            DEFB    3
cancion_creditos:
            DEFW    cre_a, cre_b, cre_c
            DEFB    5                       ; notas largas, que se sostengan

menu_a:              ; Oh! Susanna: la melodia
            DEFW      212
            DEFB    12                  ; C5
            DEFW      189
            DEFB    12                  ; D5
            DEFW      168
            DEFB    25                  ; E5
            DEFW      141
            DEFB    25                  ; G5
            DEFW      141
            DEFB    12                  ; G5
            DEFW      126
            DEFB    12                  ; A5
            DEFW      141
            DEFB    25                  ; G5
            DEFW      168
            DEFB    12                  ; E5
            DEFW      212
            DEFB    12                  ; C5
            DEFW      189
            DEFB    25                  ; D5
            DEFW      168
            DEFB    25                  ; E5
            DEFW      168
            DEFB    12                  ; E5
            DEFW      189
            DEFB    12                  ; D5
            DEFW      212
            DEFB    25                  ; C5
            DEFW      189
            DEFB    37                  ; D5
            DEFW        0
            DEFB    12                  ; -
            DEFW      212
            DEFB    12                  ; C5
            DEFW      189
            DEFB    12                  ; D5
            DEFW      168
            DEFB    25                  ; E5
            DEFW      141
            DEFB    25                  ; G5
            DEFW      141
            DEFB    12                  ; G5
            DEFW      126
            DEFB    12                  ; A5
            DEFW      141
            DEFB    25                  ; G5
            DEFW      168
            DEFB    12                  ; E5
            DEFW      212
            DEFB    12                  ; C5
            DEFW      189
            DEFB    25                  ; D5
            DEFW      168
            DEFB    25                  ; E5
            DEFW      189
            DEFB    25                  ; D5
            DEFW      212
            DEFB    50                  ; C5
            DEFW        0
            DEFB    12                  ; -
            DEFW      159
            DEFB    25                  ; F5
            DEFW      159
            DEFB    25                  ; F5
            DEFW      126
            DEFB    25                  ; A5
            DEFW      126
            DEFB    25                  ; A5
            DEFW      126
            DEFB    12                  ; A5
            DEFW      141
            DEFB    12                  ; G5
            DEFW      168
            DEFB    25                  ; E5
            DEFW      212
            DEFB    25                  ; C5
            DEFW      189
            DEFB    25                  ; D5
            DEFW      168
            DEFB    25                  ; E5
            DEFW      189
            DEFB    12                  ; D5
            DEFW      212
            DEFB    12                  ; C5
            DEFW      189
            DEFB    50                  ; D5
            DEFW        0
            DEFB    25                  ; -
            DEFW    0xFFFF

menu_b:               ; el bajo
            DEFW      847
            DEFB    12                  ; C3
            DEFW     1131
            DEFB    12                  ; G2
            DEFW      847
            DEFB    25                  ; C3
            DEFW      847
            DEFB    25                  ; C3
            DEFW      847
            DEFB    12                  ; C3
            DEFW     1270
            DEFB    12                  ; F2
            DEFW      847
            DEFB    25                  ; C3
            DEFW      847
            DEFB    24                  ; C3
            DEFW     1131
            DEFB    25                  ; G2
            DEFW      847
            DEFB    25                  ; C3
            DEFW      847
            DEFB    12                  ; C3
            DEFW     1131
            DEFB    12                  ; G2
            DEFW      847
            DEFB    25                  ; C3
            DEFW     1131
            DEFB    25                  ; G2
            DEFW     1131
            DEFB    24                  ; G2
            DEFW      847
            DEFB    12                  ; C3
            DEFW     1131
            DEFB    12                  ; G2
            DEFW      847
            DEFB    25                  ; C3
            DEFW      847
            DEFB    25                  ; C3
            DEFW      847
            DEFB    12                  ; C3
            DEFW     1270
            DEFB    12                  ; F2
            DEFW      847
            DEFB    25                  ; C3
            DEFW      847
            DEFB    24                  ; C3
            DEFW     1131
            DEFB    25                  ; G2
            DEFW      847
            DEFB    25                  ; C3
            DEFW     1131
            DEFB    25                  ; G2
            DEFW      847
            DEFB    25                  ; C3
            DEFW      847
            DEFB    25                  ; C3
            DEFW      847
            DEFB    12                  ; C3
            DEFW     1270
            DEFB    25                  ; F2
            DEFW     1270
            DEFB    25                  ; F2
            DEFW     1270
            DEFB    25                  ; F2
            DEFW     1270
            DEFB    25                  ; F2
            DEFW     1270
            DEFB    12                  ; F2
            DEFW      847
            DEFB    25                  ; C3
            DEFW      847
            DEFB    25                  ; C3
            DEFW      847
            DEFB    12                  ; C3
            DEFW     1131
            DEFB    25                  ; G2
            DEFW      847
            DEFB    25                  ; C3
            DEFW     1131
            DEFB    12                  ; G2
            DEFW      847
            DEFB    12                  ; C3
            DEFW     1131
            DEFB    25                  ; G2
            DEFW     1131
            DEFB    25                  ; G2
            DEFW     1131
            DEFB    25                  ; G2
            DEFW    0xFFFF

menu_c:               ; el arpegio
            DEFW      424
            DEFB    12                  ; C4
            DEFW      377
            DEFB    12                  ; D4
            DEFW      424
            DEFB    12                  ; C4
            DEFW      336
            DEFB    13                  ; E4
            DEFW      283
            DEFB    12                  ; G4
            DEFW      336
            DEFB    13                  ; E4
            DEFW      424
            DEFB    12                  ; C4
            DEFW      424
            DEFB    12                  ; C4
            DEFW      424
            DEFB    12                  ; C4
            DEFW      336
            DEFB    13                  ; E4
            DEFW      283
            DEFB    12                  ; G4
            DEFW      336
            DEFB    12                  ; E4
            DEFW      377
            DEFB    12                  ; D4
            DEFW      283
            DEFB    13                  ; G4
            DEFW      424
            DEFB    12                  ; C4
            DEFW      336
            DEFB    13                  ; E4
            DEFW      283
            DEFB    12                  ; G4
            DEFW      377
            DEFB    12                  ; D4
            DEFW      424
            DEFB    12                  ; C4
            DEFW      336
            DEFB    13                  ; E4
            DEFW      377
            DEFB    12                  ; D4
            DEFW      283
            DEFB    13                  ; G4
            DEFW      224
            DEFB    12                  ; B4
            DEFW      283
            DEFB    12                  ; G4
            DEFW      424
            DEFB    12                  ; C4
            DEFW      377
            DEFB    12                  ; D4
            DEFW      424
            DEFB    12                  ; C4
            DEFW      336
            DEFB    13                  ; E4
            DEFW      283
            DEFB    12                  ; G4
            DEFW      336
            DEFB    13                  ; E4
            DEFW      424
            DEFB    12                  ; C4
            DEFW      424
            DEFB    12                  ; C4
            DEFW      424
            DEFB    12                  ; C4
            DEFW      336
            DEFB    13                  ; E4
            DEFW      283
            DEFB    12                  ; G4
            DEFW      336
            DEFB    12                  ; E4
            DEFW      377
            DEFB    12                  ; D4
            DEFW      283
            DEFB    13                  ; G4
            DEFW      424
            DEFB    12                  ; C4
            DEFW      336
            DEFB    13                  ; E4
            DEFW      377
            DEFB    12                  ; D4
            DEFW      283
            DEFB    13                  ; G4
            DEFW      424
            DEFB    12                  ; C4
            DEFW      336
            DEFB    13                  ; E4
            DEFW      283
            DEFB    12                  ; G4
            DEFW      336
            DEFB    13                  ; E4
            DEFW      424
            DEFB    12                  ; C4
            DEFW      424
            DEFB    13                  ; C4
            DEFW      317
            DEFB    12                  ; F4
            DEFW      252
            DEFB    13                  ; A4
            DEFW      317
            DEFB    12                  ; F4
            DEFW      424
            DEFB    13                  ; C4
            DEFW      317
            DEFB    12                  ; F4
            DEFW      252
            DEFB    13                  ; A4
            DEFW      317
            DEFB    12                  ; F4
            DEFW      424
            DEFB    12                  ; C4
            DEFW      424
            DEFB    12                  ; C4
            DEFW      336
            DEFB    13                  ; E4
            DEFW      283
            DEFB    12                  ; G4
            DEFW      336
            DEFB    13                  ; E4
            DEFW      424
            DEFB    12                  ; C4
            DEFW      377
            DEFB    13                  ; D4
            DEFW      283
            DEFB    12                  ; G4
            DEFW      424
            DEFB    13                  ; C4
            DEFW      336
            DEFB    12                  ; E4
            DEFW      377
            DEFB    12                  ; D4
            DEFW      424
            DEFB    12                  ; C4
            DEFW      377
            DEFB    13                  ; D4
            DEFW      283
            DEFB    12                  ; G4
            DEFW      224
            DEFB    13                  ; B4
            DEFW      283
            DEFB    12                  ; G4
            DEFW      377
            DEFB    13                  ; D4
            DEFW      283
            DEFB    12                  ; G4
            DEFW    0xFFFF

fune_a:              ; marcha funebre: la melodia
            DEFW      424
            DEFB    37                  ; C4
            DEFW      424
            DEFB    12                  ; C4
            DEFW      424
            DEFB    25                  ; C4
            DEFW      424
            DEFB    25                  ; C4
            DEFW      356
            DEFB    37                  ; D#4
            DEFW      377
            DEFB    12                  ; D4
            DEFW      377
            DEFB    25                  ; D4
            DEFW      424
            DEFB    25                  ; C4
            DEFW      424
            DEFB    37                  ; C4
            DEFW      476
            DEFB    12                  ; A#3
            DEFW      476
            DEFB    25                  ; A#3
            DEFW      534
            DEFB    25                  ; G#3
            DEFW      534
            DEFB    37                  ; G#3
            DEFW      566
            DEFB    12                  ; G3
            DEFW      566
            DEFB    25                  ; G3
            DEFW      424
            DEFB    50                  ; C4
            DEFW        0
            DEFB    25                  ; -
            DEFW    0xFFFF

fune_b:               ; el bajo
            DEFW     1695
            DEFB    50                  ; C2
            DEFW     1695
            DEFB    50                  ; C2
            DEFW     1695
            DEFB    36                  ; C2
            DEFW     1131
            DEFB    37                  ; G2
            DEFW     1695
            DEFB    62                  ; C2
            DEFW     1425
            DEFB    37                  ; D#2
            DEFW     1068
            DEFB    62                  ; G#2
            DEFW     1695
            DEFB    50                  ; C2
            DEFW     1695
            DEFB    62                  ; C2
            DEFW    0xFFFF

fune_c:               ; el arpegio
            DEFW      847
            DEFB    25                  ; C3
            DEFW      712
            DEFB    26                  ; D#3
            DEFW      566
            DEFB    25                  ; G3
            DEFW      712
            DEFB    26                  ; D#3
            DEFW      847
            DEFB    34                  ; C3
            DEFW      755
            DEFB    37                  ; D3
            DEFW      847
            DEFB    25                  ; C3
            DEFW      712
            DEFB    37                  ; D#3
            DEFW      712
            DEFB    37                  ; D#3
            DEFW      847
            DEFB    26                  ; C3
            DEFW      712
            DEFB    36                  ; D#3
            DEFW      847
            DEFB    26                  ; C3
            DEFW      712
            DEFB    25                  ; D#3
            DEFW      566
            DEFB    26                  ; G3
            DEFW      712
            DEFB    35                  ; D#3
            DEFW    0xFFFF

; ---- trozos de pantalla que hay que salvar del funeral ---------------
decorado:                                   ; columna, y, filas, ancho
            DEFB    CACTUS1_COL, CACTUS1_Y, CACTUS_ALTO, 2
            DEFB    CACTUS2_COL, CACTUS2_Y, CACTUS_ALTO, 2
barril1_tab:
            DEFB    CAJA1_COL, 0, CAJA_ALTO, 2      ; la y la pone cada partida
barril2_tab:
            DEFB    CAJA2_COL, 0, CAJA_ALTO, 2
            DEFB    0

; ---- variables ------------------------------------------------------
b1:              DEFS NUM_BALAS*3       ; x, y y activa de cada bala
b2:              DEFS NUM_BALAS*3
balas1:          DEFB MUNICION
balas2:          DEFB MUNICION
tecla1:          DEFB 0                 ; para que un tiro sea una pulsacion
tecla2:          DEFB 0
bal_sent:        DEFB 0
bal_ranura:      DEFW 0
barril1_y:       DEFB 80
barril2_y:       DEFB 144
carreta_y:       DEFB CARRETA_ABAJO
carreta_t:       DEFB 0
carreta_espera:  DEFB 1
modo_ia:         DEFB 0                 ; 1 = el bandido lo lleva la maquina
ia_espera:       DEFB 12
ia_mira:         DEFB 16
dd_buf:          DEFS 12                ; una fila del sprite doblado
ancho_bloque:    DEFB ANCHO_JUG
tmp_x:           DEFB 0
tmp_y:           DEFB 0
caja_fila:       DEFB 0
semilla:         DEFB 0x5A
mov_x:           DEFB 0
mov_y:           DEFB 0
mov_alto:        DEFB 0
caido_y:         DEFB 0
caido_col:       DEFB 0
esc_x:           DEFB 0
dec_modo:        DEFB 0
dec_ancho:       DEFB 0
dec_tabla:       DEFW 0
dec_buf:         DEFW 0
gen_n:           DEFB 0
gen_ancho:       DEFB CAB_ANCHO
gen_alto:        DEFB CAB_ALTO
gen_filas:       DEFB 0
gen_bytes:       DEFB 0
gen_resto:       DEFB 0
ay_est_a:        DEFS 6                 ; puntero, inicio, contador y volumen
ay_est_b:        DEFS 6
ay_est_c:        DEFS 6
ay_num:          DEFB 0
ay_est:          DEFW 0
ia_peor_x:       DEFB 0                     ; la bala que le viene mas cerca
ia_peor_y:       DEFB 0
ay_par:          DEFB 0
vel_decae:       DEFB 2
musica:          DEFB 0
pc_tabla:        DEFW 0
fx_t:            DEFB 0
fx_vol:          DEFB 0
p1_y:            DEFB P1_INI_Y
p2_y:            DEFB P2_INI_Y
puntos1:         DEFB 0
puntos2:         DEFB 0

cre_a:                ; la melodia
            DEFW      377
            DEFB    75                  ; D4
            DEFW      252
            DEFB    75                  ; A4
            DEFW      317
            DEFB    50                  ; F4
            DEFW      336
            DEFB    25                  ; E4
            DEFW      377
            DEFB    100                  ; D4
            DEFW        0
            DEFB    25                  ; silencio
            DEFW      377
            DEFB    75                  ; D4
            DEFW      238
            DEFB    75                  ; A#4
            DEFW      252
            DEFB    50                  ; A4
            DEFW      283
            DEFB    25                  ; G4
            DEFW      317
            DEFB    100                  ; F4
            DEFW        0
            DEFB    25                  ; silencio
            DEFW      252
            DEFB    75                  ; A4
            DEFW      189
            DEFB    75                  ; D5
            DEFW      212
            DEFB    50                  ; C5
            DEFW      238
            DEFB    25                  ; A#4
            DEFW      252
            DEFB    100                  ; A4
            DEFW        0
            DEFB    25                  ; silencio
            DEFW      317
            DEFB    50                  ; F4
            DEFW      283
            DEFB    50                  ; G4
            DEFW      252
            DEFB    75                  ; A4
            DEFW      317
            DEFB    25                  ; F4
            DEFW      336
            DEFB    50                  ; E4
            DEFW      377
            DEFB    150                  ; D4
            DEFW        0
            DEFB    50                  ; silencio
            DEFW    0xFFFF

cre_b:                ; el bajo
            DEFW     1510
            DEFB    100                  ; D2
            DEFW     1510
            DEFB    100                  ; D2
            DEFW     1008
            DEFB    25                  ; A2
            DEFW     1510
            DEFB    125                  ; D2
            DEFW     1510
            DEFB    75                  ; D2
            DEFW      951
            DEFB    75                  ; A#2
            DEFW     1510
            DEFB    50                  ; D2
            DEFW     1131
            DEFB    25                  ; G2
            DEFW     1270
            DEFB    125                  ; F2
            DEFW     1510
            DEFB    100                  ; D2
            DEFW     1510
            DEFB    50                  ; D2
            DEFW     1270
            DEFB    50                  ; F2
            DEFW      951
            DEFB    25                  ; A#2
            DEFW     1008
            DEFB    125                  ; A2
            DEFW     1510
            DEFB    50                  ; D2
            DEFW     1131
            DEFB    50                  ; G2
            DEFW     1008
            DEFB    75                  ; A2
            DEFW     1510
            DEFB    25                  ; D2
            DEFW     1008
            DEFB    50                  ; A2
            DEFW     1510
            DEFB    100                  ; D2
            DEFW     1510
            DEFB    100                  ; D2
            DEFW    0xFFFF

cre_c:                ; el arpegio
            DEFW      755
            DEFB    50                  ; D3
            DEFW      635
            DEFB    51                  ; F3
            DEFW      504
            DEFB    99                  ; A3
            DEFW      673
            DEFB    25                  ; E3
            DEFW      755
            DEFB    50                  ; D3
            DEFW      635
            DEFB    75                  ; F3
            DEFW      755
            DEFB    75                  ; D3
            DEFW      755
            DEFB    75                  ; D3
            DEFW      755
            DEFB    50                  ; D3
            DEFW      566
            DEFB    25                  ; G3
            DEFW      635
            DEFB    50                  ; F3
            DEFW      504
            DEFB    75                  ; A3
            DEFW      755
            DEFB    50                  ; D3
            DEFW      635
            DEFB    100                  ; F3
            DEFW      635
            DEFB    50                  ; F3
            DEFW      755
            DEFB    25                  ; D3
            DEFW      673
            DEFB    50                  ; E3
            DEFW      504
            DEFB    75                  ; A3
            DEFW      755
            DEFB    50                  ; D3
            DEFW      566
            DEFB    50                  ; G3
            DEFW      673
            DEFB    75                  ; E3
            DEFW      755
            DEFB    25                  ; D3
            DEFW      673
            DEFB    50                  ; E3
            DEFW      755
            DEFB    51                  ; D3
            DEFW      635
            DEFB    50                  ; F3
            DEFW      504
            DEFB    99                  ; A3
            DEFW    0xFFFF

;---------------------------------------------------------------------
; la foto del autor, tramada a un bit y ya en el orden de la memoria
; de video: pintarla es un LDIR (la genera tools/foto.py)
;---------------------------------------------------------------------
foto:
            INCBIN  "build/foto.bin"

fin_codigo:
            END inicio
