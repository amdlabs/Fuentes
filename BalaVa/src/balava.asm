;=====================================================================
;  B A L A V A   -  ZX Spectrum 48K  -  2 jugadores
;---------------------------------------------------------------------
;  Duelo en el oeste: el sheriff (izquierda) y el bandido (derecha) se
;  disparan de lado a lado.  Solo pueden moverse arriba y abajo para
;  esquivar las balas, y la carreta y los dos cactus del centro paran
;  los disparos, asi que hay que buscar el hueco.
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

MIN_Y       EQU 16                  ; limite superior del campo de juego
MAX_Y       EQU 160                 ; limite inferior (160 + 31 = 191)
VEL_JUG     EQU 1                   ; pixeles por fotograma (movimiento fino)

P1_INI_Y    EQU 40
P2_INI_Y    EQU 120

VEL_BALA    EQU 3                   ; pixeles por fotograma
BALA_DY     EQU 13                  ; altura del revolver dentro del sprite
BAL_INI_1   EQU 32                  ; x de salida de la bala del sheriff
BAL_FIN_1   EQU 224                 ; x donde alcanza al bandido
BAL_INI_2   EQU 220                 ; x de salida de la bala del bandido
BAL_FIN_2   EQU 28                  ; x donde alcanza al sheriff

; --- decorado (tambien para la tabla de obstaculos) -------------------
CARRETA_COL EQU 14                  ; x = 112 .. 135
CARRETA_Y   EQU 20                  ; y =  20 ..  47
CARRETA_ALTO EQU 28
CACTUS_ALTO EQU 32
CACTUS1_COL EQU 8                   ; x =  64 ..  79
CACTUS1_Y   EQU 100                 ; y = 100 .. 131
CACTUS2_COL EQU 21                  ; x = 168 .. 183
CACTUS2_Y   EQU 60                  ; y =  60 ..  91

; --- cajas rompibles (una delante de cada pistolero) ------------------
CAJA1_COL   EQU 5                   ; x =  40 ..  55
CAJA2_COL   EQU 25                  ; x = 200 .. 215
CAJA_Y      EQU 80                  ; y =  80 .. 111
CAJA_ALTO   EQU 32                  ; cuatro tramos de 8 pixeles
CAJA_ENTERA EQU %00001111           ; los cuatro tramos en pie

; --- el caracol gigante que cruza el campo ----------------------------
CARACOL_Y   EQU 136
CARACOL_ALTO EQU 24
CARACOL_ANCHO EQU 6                 ; 48 pixeles: 32 de bicho y un byte
CARACOL_BYTES EQU CARACOL_ANCHO*CARACOL_ALTO      ; en blanco a cada lado
CARACOL_MIN EQU 32
CARACOL_MAX EQU 176
CARACOL_LENTO EQU 3                 ; un pixel cada 3 fotogramas
BUF_CARACOL_D EQU 0xE000            ; las 8 copias desplazadas de cada
BUF_CARACOL_I EQU 0xE480            ; sentido, generadas al arrancar

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
            ld      hl,spr_caracol_d        ; copias desplazadas del caracol
            ld      de,BUF_CARACOL_D
            call    genera_desplazados
            ld      hl,spr_caracol_i
            ld      de,BUF_CARACOL_I
            call    genera_desplazados
            im      1
            ei

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
            ld      (b1_act),a
            ld      (b2_act),a
            ld      (caracol_dir),a
            ld      (caracol_t),a
            ld      a,CARACOL_MIN
            ld      (caracol_x),a
            ld      a,CAJA_ENTERA           ; las cajas empiezan enteras
            ld      (caja1),a
            ld      (caja2),a

            call    limpia_pantalla
            call    dibuja_marcador
            call    dibuja_escenario
            call    dibuja_cajas
            call    dibuja_caracol
            call    hud_puntos
            call    coloca_jugadores

bucle:
            halt                            ; sincroniza a 50 Hz
            call    actualiza_p1
            call    actualiza_p2
            call    actualiza_bala1
            call    actualiza_bala2
            call    actualiza_caracol

            ld      a,(puntos1)
            cp      PUNTOS_WIN
            jr      z,gana_poli
            ld      a,(puntos2)
            cp      PUNTOS_WIN
            jr      z,gana_ladron
            jr      bucle

gana_poli:
            ld      hl,txt_gana_poli
            ld      c,8
            jr      fin_partida
gana_ladron:
            ld      hl,txt_gana_ladron
            ld      c,8
fin_partida:
            push    hl
            push    bc
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
; JUGADOR 1 - POLICIA   (Q arriba / A abajo / V dispara)
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
            ret     nz
            ld      a,(b1_act)
            or      a
            ret     nz                      ; ya tiene una bala en vuelo
            ld      a,BAL_INI_1
            ld      (b1_x),a
            ld      a,(p1_y)
            add     a,BALA_DY               ; altura del revolver
            ld      (b1_y),a
            ld      a,1
            ld      (b1_act),a
            ld      a,(b1_y)
            ld      b,a
            ld      a,(b1_x)
            call    bala_xor
            jp      sonido_tiro

;=====================================================================
; JUGADOR 2 - LADRON   (P arriba / L abajo / ESPACIO dispara)
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
            ret     nz
            ld      a,(b2_act)
            or      a
            ret     nz
            ld      a,BAL_INI_2
            ld      (b2_x),a
            ld      a,(p2_y)
            add     a,BALA_DY
            ld      (b2_y),a
            ld      a,1
            ld      (b2_act),a
            ld      a,(b2_y)
            ld      b,a
            ld      a,(b2_x)
            call    bala_xor
            jp      sonido_tiro

;=====================================================================
; BALA DEL POLICIA (viaja hacia la derecha)
;=====================================================================
actualiza_bala1:
            ld      a,(b1_act)
            or      a
            ret     z
            ld      a,(b1_y)                ; borrar en la posicion actual
            ld      b,a
            ld      a,(b1_x)
            call    bala_xor
            ld      a,(b1_x)                ; avanzar
            add     a,VEL_BALA
            ld      (b1_x),a
            cp      BAL_FIN_1
            jr      c,ab1_decorado
            xor     a                       ; ha llegado al ladron
            ld      (b1_act),a
            ld      a,(b1_y)
            inc     a                       ; fila inferior de la bala
            ld      hl,p2_y
            sub     (hl)                    ; A = bala_abajo - jugador_arriba
            ret     c                       ; pasa por encima
            cp      ALTO_SPR+1
            ret     nc                      ; pasa por debajo
            jp      impacto_ladron
ab1_decorado:
            ld      a,(b1_y)
            ld      b,a
            ld      a,(b1_x)
            call    choca_caja              ; la caja se va rompiendo
            jr      c,ab1_muere
            ld      a,(b1_y)
            ld      b,a
            ld      a,(b1_x)
            call    choca_obstaculo         ; decorado fijo y caracol
            jr      nc,ab1_pinta
            call    sonido_rebote
ab1_muere:
            xor     a
            ld      (b1_act),a
            ret
ab1_pinta:
            ld      a,(b1_y)
            ld      b,a
            ld      a,(b1_x)
            jp      bala_xor

;=====================================================================
; BALA DEL LADRON (viaja hacia la izquierda)
;=====================================================================
actualiza_bala2:
            ld      a,(b2_act)
            or      a
            ret     z
            ld      a,(b2_y)
            ld      b,a
            ld      a,(b2_x)
            call    bala_xor
            ld      a,(b2_x)
            sub     VEL_BALA
            ld      (b2_x),a
            cp      BAL_FIN_2+1
            jr      nc,ab2_decorado
            xor     a                       ; ha llegado al policia
            ld      (b2_act),a
            ld      a,(b2_y)
            inc     a
            ld      hl,p1_y
            sub     (hl)
            ret     c
            cp      ALTO_SPR+1
            ret     nc
            jp      impacto_poli
ab2_decorado:
            ld      a,(b2_y)
            ld      b,a
            ld      a,(b2_x)
            call    choca_caja              ; la caja se va rompiendo
            jr      c,ab2_muere
            ld      a,(b2_y)
            ld      b,a
            ld      a,(b2_x)
            call    choca_obstaculo         ; decorado fijo y caracol
            jr      nc,ab2_pinta
            call    sonido_rebote
ab2_muere:
            xor     a
            ld      (b2_act),a
            ret
ab2_pinta:
            ld      a,(b2_y)
            ld      b,a
            ld      a,(b2_x)
            jp      bala_xor

;=====================================================================
; IMPACTOS
;=====================================================================
impacto_ladron:                             ; acierta el policia
            ld      hl,puntos1
            inc     (hl)
            jr      impacto_comun
impacto_poli:                               ; acierta el ladron
            ld      hl,puntos2
            inc     (hl)
impacto_comun:
            call    sonido_impacto
            call    hud_puntos
            ; fin de ronda: quita las balas en vuelo y recoloca a los dos
            ld      a,(b1_act)
            or      a
            jr      z,ic_bala2
            ld      a,(b1_y)
            ld      b,a
            ld      a,(b1_x)
            call    bala_xor
            xor     a
            ld      (b1_act),a
ic_bala2:
            ld      a,(b2_act)
            or      a
            jr      z,ic_borra
            ld      a,(b2_y)
            ld      b,a
            ld      a,(b2_x)
            call    bala_xor
            xor     a
            ld      (b2_act),a
ic_borra:
            ld      a,(p1_y)
            ld      c,COL_P1
            ld      b,ALTO_SPR
            call    borra_jugador
            ld      a,(p2_y)
            ld      c,COL_P2
            ld      b,ALTO_SPR
            call    borra_jugador
            call    coloca_jugadores
            ld      b,40                    ; pausa entre rondas
ic_pausa:
            halt
            djnz    ic_pausa
            ret

;=====================================================================
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
            ld      a,ANCHO_JUG             ; la carreta tambien mide 24
            ld      (ancho_bloque),a
            ld      a,CARRETA_Y
            ld      c,CARRETA_COL
            ld      de,spr_carreta
            ld      b,CARRETA_ALTO
            call    dibuja_bloque
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
            push    hl
            ld      a,CARACOL_ALTO
            ld      (gen_filas),a
gd_fila:
            xor     a
            ld      (gen_resto),a
            ld      a,CARACOL_ANCHO
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
            ld      a,(gen_n)
            inc     a
            ld      (gen_n),a
            cp      8
            jr      c,gd_copia
            ret

;---------------------------------------------------------------------
; actualiza_caracol - lo mueve un pixel cada CARACOL_LENTO fotogramas
;   y le da la vuelta al llegar a cada extremo
;---------------------------------------------------------------------
actualiza_caracol:
            ld      a,(caracol_t)
            inc     a
            cp      CARACOL_LENTO
            jr      nc,ac_mueve
            ld      (caracol_t),a
            ret
ac_mueve:
            xor     a
            ld      (caracol_t),a
            ld      a,(caracol_dir)
            or      a
            jr      nz,ac_izquierda
            ld      a,(caracol_x)           ; va hacia la derecha
            inc     a
            cp      CARACOL_MAX+1
            jr      c,ac_pinta
            ld      a,1
            ld      (caracol_dir),a
            ld      a,CARACOL_MAX
            jr      ac_pinta
ac_izquierda:
            ld      a,(caracol_x)
            dec     a
            cp      CARACOL_MIN
            jr      nc,ac_pinta
            xor     a
            ld      (caracol_dir),a
            ld      a,CARACOL_MIN
ac_pinta:
            ld      (caracol_x),a
            ; cae en dibuja_caracol

;---------------------------------------------------------------------
; dibuja_caracol - vuelca la copia que toca segun el pixel exacto
;---------------------------------------------------------------------
dibuja_caracol:
            ld      hl,0
            ld      de,CARACOL_BYTES
            ld      a,(caracol_x)
            and     %00000111               ; copia = desplazamiento en pixeles
            jr      z,dc_base
            ld      b,a
dc_suma:
            add     hl,de
            djnz    dc_suma
dc_base:
            ld      de,BUF_CARACOL_D
            ld      a,(caracol_dir)
            or      a
            jr      z,dc_sentido
            ld      de,BUF_CARACOL_I
dc_sentido:
            add     hl,de
            ex      de,hl                   ; DE = datos ya desplazados
            ld      a,CARACOL_ANCHO
            ld      (ancho_bloque),a
            ld      a,(caracol_x)
            rrca
            rrca
            rrca
            and     %00011111
            ld      c,a
            ld      a,CARACOL_Y
            ld      b,CARACOL_ALTO
            jp      dibuja_bloque

;---------------------------------------------------------------------
; dibuja_cajas - las dos cajas, tramo a tramo segun lo que quede en pie
;---------------------------------------------------------------------
dibuja_cajas:
            ld      hl,caja1
            ld      c,CAJA1_COL
            call    dibuja_caja
            ld      hl,caja2
            ld      c,CAJA2_COL
dibuja_caja:                                ; HL = estado, C = columna
            ld      a,2
            ld      (ancho_bloque),a
            ld      a,(hl)
            ld      (caja_masc),a
            ld      a,CAJA_Y
            ld      (caja_fila),a
            ld      b,4
dcaja_bucle:
            push    bc
            ld      a,(caja_masc)
            srl     a
            ld      (caja_masc),a
            jr      nc,dcaja_sig            ; ese tramo ya no esta
            ld      a,(caja_fila)
            ld      de,spr_caja
            ld      b,8
            call    dibuja_bloque
dcaja_sig:
            ld      a,(caja_fila)
            add     a,8
            ld      (caja_fila),a
            pop     bc
            djnz    dcaja_bucle
            ret

;---------------------------------------------------------------------
; choca_caja - la bala contra las cajas: si el tramo esta en pie lo
;   rompe y se para; si ya estaba roto, pasa por el hueco
;   entrada: A = x de la bala, B = y
;   salida : carry = 1 si la caja detiene la bala
;---------------------------------------------------------------------
choca_caja:
            ld      (tmp_x),a
            ld      a,b
            ld      (tmp_y),a
            inc     a                       ; fila de abajo de la bala
            sub     CAJA_Y
            jr      c,cc_no                 ; pasa por encima
            cp      CAJA_ALTO+1
            jr      nc,cc_no                ; pasa por debajo
            ld      a,(tmp_x)
            add     a,3
            cp      CAJA1_COL*8
            jr      c,cc_no                 ; aun no ha llegado a la caja 1
            ld      a,(tmp_x)
            cp      CAJA1_COL*8+16
            jr      c,cc_caja1
            ld      a,(tmp_x)
            add     a,3
            cp      CAJA2_COL*8
            jr      c,cc_no                 ; entre las dos cajas
            ld      a,(tmp_x)
            cp      CAJA2_COL*8+16
            jr      c,cc_caja2
cc_no:
            or      a                       ; sin acarreo: la bala sigue
            ret
cc_caja2:
            ld      hl,caja2
            ld      c,CAJA2_COL
            jr      cc_tramo
cc_caja1:
            ld      hl,caja1
            ld      c,CAJA1_COL
cc_tramo:
            ld      a,(tmp_y)               ; tramo = (y - CAJA_Y) / 8
            sub     CAJA_Y
            jr      nc,cc_dentro
            xor     a                       ; la bala asoma por arriba
cc_dentro:
            rrca
            rrca
            rrca
            and     %00000011
            ld      b,a                     ; B = numero de tramo (0 a 3)
            ld      a,CAJA_Y                ; y del tramo y bit que le toca
            ld      e,1
            inc     b
cc_altura:
            dec     b
            jr      z,cc_prueba
            add     a,8
            sla     e
            jr      cc_altura
cc_prueba:
            ld      (caja_fila),a
            ld      a,e                     ; E = bit del tramo
            and     (hl)
            ret     z                       ; ya estaba roto: la bala pasa
            ld      a,(hl)
            xor     e                       ; se lo lleva por delante
            ld      (hl),a
            ld      a,2
            ld      (ancho_bloque),a
            ld      a,(caja_fila)
            ld      b,8
            call    borra_bloque
            call    sonido_rotura
            scf
            ret

;---------------------------------------------------------------------
; choca_obstaculo - mira si la bala toca algo del decorado
;   entrada: A = x de la bala, B = y
;   salida : carry = 1 si choca
;---------------------------------------------------------------------
choca_obstaculo:
            ld      (tmp_x),a
            ld      a,b
            ld      (tmp_y),a
            ld      a,(caracol_x)           ; el caracol, que va andando
            ld      b,a
            add     a,CARACOL_ANCHO*8-1
            ld      c,a
            ld      d,CARACOL_Y
            ld      e,CARACOL_Y+CARACOL_ALTO-1
            call    co_prueba
            ret     c
            ld      hl,obstaculos
co_bucle:
            ld      a,(hl)                  ; x0 (0 = fin de la tabla)
            or      a
            ret     z
            ld      b,a
            inc     hl
            ld      c,(hl)                  ; x1
            inc     hl
            ld      d,(hl)                  ; y0
            inc     hl
            ld      e,(hl)                  ; y1
            inc     hl
            push    hl
            call    co_prueba
            pop     hl
            ret     c
            jr      co_bucle

;---------------------------------------------------------------------
; co_prueba - la bala guardada en (tmp_x, tmp_y) contra un rectangulo
;   entrada: B = x0, C = x1, D = y0, E = y1
;   salida : carry = 1 si se tocan
;---------------------------------------------------------------------
co_prueba:
            ld      a,(tmp_x)
            add     a,3                     ; ultimo pixel de la bala
            cp      b
            jr      c,cp_no                 ; la bala acaba antes
            ld      a,(tmp_x)
            cp      c
            jr      z,cp_mira_y
            jr      nc,cp_no                ; la bala empieza despues
cp_mira_y:
            ld      a,(tmp_y)
            inc     a                       ; fila de abajo de la bala
            cp      d
            jr      c,cp_no                 ; pasa por encima
            ld      a,(tmp_y)
            cp      e
            jr      z,cp_choca
            jr      nc,cp_no                ; pasa por debajo
cp_choca:
            scf
            ret
cp_no:
            or      a                       ; carry a cero: no se tocan
            ret

;---------------------------------------------------------------------
; bala_xor - dibuja/borra una bala (4x2 pixeles) en modo XOR
;   La bala puede estar en cualquier x: el patron de 4 pixeles se
;   desplaza dentro de una pareja de bytes, asi que se mueve pixel a
;   pixel y no a saltos de caracter.
;   entrada: A = x en pixeles, B = y
;---------------------------------------------------------------------
bala_xor:
            ld      c,a
            and     %00000111               ; desplazamiento dentro del byte
            ld      hl,0xF000               ; patron de 4 pixeles
            jr      z,bx_listo
            ld      d,a
bx_desp:
            srl     h
            rr      l
            dec     d
            jr      nz,bx_desp
bx_listo:
            ld      a,c
            rrca
            rrca
            rrca
            and     %00011111
            ld      c,a                     ; C = columna
            ld      a,b                     ; A = y
            push    hl
            call    scr_addr
            pop     de                      ; D y E = las dos mitades del patron
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
            ld      a,13                    ; linea horizontal bajo el marcador
            jp      linea_horizontal

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
            ld      b,13
            ld      c,12
            call    print_str
            ld      hl,txt_op2
            ld      b,15
            ld      c,12
            call    print_str
            ld      hl,txt_pulsa
            ld      b,19
            ld      c,10
            call    print_str
            ld      hl,txt_autor
            ld      b,21
            ld      c,8
            call    print_str
            ; el aviso parpadea con el bit FLASH de los atributos
            ld      hl,ATTRS+(19*32)+10
            ld      b,11
menu_flash:
            ld      (hl),0x80+ATTR_JUEGO
            inc     hl
            djnz    menu_flash
            call    espera_libre
            di                              ; la melodia necesita el reloj entero
            ld      hl,musica
            ld      (mus_ptr),hl
            xor     a
            ld      (mus_ticks),a
menu_espera:
            call    musica_tick             ; 60 ms de musica por vuelta
            ld      bc,0xF7FE               ; fila 1 2 3 4 5
            in      a,(c)
            ld      b,a
            and     %00000001               ; tecla 1 = jugar
            jr      nz,menu_otra
            ei
            ret
menu_otra:
            ld      a,b
            and     %00000010               ; tecla 2 = controles
            jr      nz,menu_espera
            ei
            call    pantalla_controles
            jp      menu                    ; el menu queda fuera del alcance de JR

;---------------------------------------------------------------------
; pantalla_controles - la ayuda del menu
;---------------------------------------------------------------------
pantalla_controles:
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
; SONIDO
;=====================================================================
;   entrada: B = numero de ciclos, C = periodo
sonido:
snd_ciclo:
            ld      a,%00010110             ; altavoz ON + borde amarillo
            out     (0xFE),a
            ld      a,c
snd_d1:
            dec     a
            jr      nz,snd_d1
            ld      a,%00000110             ; altavoz OFF + borde amarillo
            out     (0xFE),a
            ld      a,c
snd_d2:
            dec     a
            jr      nz,snd_d2
            djnz    snd_ciclo
            ret

sonido_tiro:
            ld      b,14
            ld      c,40
            jp      sonido

sonido_rotura:
            ld      b,18
            ld      c,60
            call    sonido
            ld      b,12
            ld      c,150
            jp      sonido

sonido_rebote:
            ld      b,10
            ld      c,18
            jp      sonido

sonido_impacto:
            ld      b,25
            ld      c,110
            call    sonido
            ld      b,30
            ld      c,190
            jp      sonido

;=====================================================================
; MUSICA DEL MENU
;=====================================================================
;---------------------------------------------------------------------
; musica_tick - suena 60 ms de la melodia y vuelve, para que el menu
;   pueda mirar el teclado entre tick y tick
;---------------------------------------------------------------------
musica_tick:
            ld      a,(mus_ticks)
            or      a
            jr      nz,mt_suena
            ld      hl,(mus_ptr)            ; toca nota nueva
            ld      a,(hl)
            cp      0xFF
            jr      nz,mt_nota
            ld      hl,musica               ; se acabo: vuelta a empezar
            ld      a,(hl)
mt_nota:
            ld      (mus_per),a
            inc     hl
            ld      a,(hl)
            ld      (mus_cic),a
            inc     hl
            ld      a,(hl)
            ld      (mus_ticks),a
            inc     hl
            ld      (mus_ptr),hl
mt_suena:
            ld      a,(mus_ticks)
            dec     a
            ld      (mus_ticks),a
            ld      a,(mus_per)
            or      a
            jr      z,mt_silencio
            ld      c,a
            ld      a,(mus_cic)
            ld      b,a
            jp      sonido                  ; B ciclos con periodo C
mt_silencio:
            ld      b,60                    ; misma duracion, sin altavoz
mt_pausa1:
            ld      a,219
mt_pausa2:
            dec     a
            jr      nz,mt_pausa2
            djnz    mt_pausa1
            ret

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
txt_op1:         DEFB "1  JUGAR",0
txt_op2:         DEFB "2  CONTROLES",0
txt_pulsa:       DEFB "PULSA 1 O 2",0
txt_autor:       DEFB "(C) 2026  AMDLABS",0
txt_controles:   DEFB "CONTROLES",0
txt_j1:          DEFB "JUGADOR 1 - SHERIFF",0
txt_j1b:         DEFB "Q=ARRIBA  A=ABAJO",0
txt_j1c:         DEFB "Z=DISPARO",0
txt_j2:          DEFB "JUGADOR 2 - BANDIDO",0
txt_j2b:         DEFB "P=ARRIBA  L=ABAJO",0
txt_j2c:         DEFB "B=DISPARO",0
txt_reglas:      DEFB "5 IMPACTOS PARA GANAR",0
txt_tecla:       DEFB "PULSA CUALQUIER TECLA",0
txt_gana_poli:   DEFB "GANA EL SHERIFF",0
txt_gana_ladron: DEFB "GANA EL BANDIDO",0
txt_final:       DEFB "RESULTADO",0

spr_caracol_d:           ; caracol mirando a la derecha, 48x24 con margenes
            DEFB    %00000000, %00000000, %00000000, %00000000, %00100100, %00000000   ; ..................................#..#..........
            DEFB    %00000000, %00000000, %00000000, %00000000, %00100100, %00000000   ; ..................................#..#..........
            DEFB    %00000000, %00000000, %00000000, %00000000, %00010100, %00000000   ; ...................................#.#..........
            DEFB    %00000000, %00000011, %11111100, %00000000, %00011100, %00000000   ; ..............########.............###..........
            DEFB    %00000000, %00001111, %11111111, %00000000, %00111100, %00000000   ; ............############..........####..........
            DEFB    %00000000, %00011110, %00000111, %10000000, %01111100, %00000000   ; ...........####......####........#####..........
            DEFB    %00000000, %00111001, %11111001, %11000000, %11111100, %00000000   ; ..........###..######..###......######..........
            DEFB    %00000000, %00110011, %00001100, %11000001, %11111100, %00000000   ; ..........##..##....##..##.....#######..........
            DEFB    %00000000, %01110110, %01100110, %11100011, %11111100, %00000000   ; .........###.##..##..##.###...########..........
            DEFB    %00000000, %01110110, %11110110, %11100111, %11111100, %00000000   ; .........###.##.####.##.###..#########..........
            DEFB    %00000000, %01110110, %11110110, %11101111, %11111100, %00000000   ; .........###.##.####.##.###.##########..........
            DEFB    %00000000, %01110110, %00000110, %11101111, %11111100, %00000000   ; .........###.##......##.###.##########..........
            DEFB    %00000000, %00110011, %11111100, %11001111, %11111100, %00000000   ; ..........##..########..##..##########..........
            DEFB    %00000000, %00111000, %00000001, %11011111, %11111100, %00000000   ; ..........###..........###.###########..........
            DEFB    %00000000, %00011110, %00000111, %10011111, %11111100, %00000000   ; ...........####......####..###########..........
            DEFB    %00000000, %00001111, %11111111, %00011111, %11111100, %00000000   ; ............############...###########..........
            DEFB    %00000000, %00000011, %11111100, %00011111, %11111100, %00000000   ; ..............########.....###########..........
            DEFB    %00000000, %00000000, %00000000, %00011111, %11111100, %00000000   ; ...........................###########..........
            DEFB    %00000000, %00111111, %11111111, %11111111, %11111110, %00000000   ; ..........#############################.........
            DEFB    %00000000, %01111111, %11111111, %11111111, %11111110, %00000000   ; .........##############################.........
            DEFB    %00000000, %01111111, %11111111, %11111111, %11111110, %00000000   ; .........##############################.........
            DEFB    %00000000, %00111111, %11111111, %11111111, %11111100, %00000000   ; ..........############################..........
            DEFB    %00000000, %00011111, %11111111, %11111111, %11111000, %00000000   ; ...........##########################...........
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000000, %00000000   ; ................................................

spr_caracol_i:           ; caracol mirando a la izquierda
            DEFB    %00000000, %00100100, %00000000, %00000000, %00000000, %00000000   ; ..........#..#..................................
            DEFB    %00000000, %00100100, %00000000, %00000000, %00000000, %00000000   ; ..........#..#..................................
            DEFB    %00000000, %00101000, %00000000, %00000000, %00000000, %00000000   ; ..........#.#...................................
            DEFB    %00000000, %00111000, %00000000, %00111111, %11000000, %00000000   ; ..........###.............########..............
            DEFB    %00000000, %00111100, %00000000, %11111111, %11110000, %00000000   ; ..........####..........############............
            DEFB    %00000000, %00111110, %00000001, %11100000, %01111000, %00000000   ; ..........#####........####......####...........
            DEFB    %00000000, %00111111, %00000011, %10011111, %10011100, %00000000   ; ..........######......###..######..###..........
            DEFB    %00000000, %00111111, %10000011, %00110000, %11001100, %00000000   ; ..........#######.....##..##....##..##..........
            DEFB    %00000000, %00111111, %11000111, %01100110, %01101110, %00000000   ; ..........########...###.##..##..##.###.........
            DEFB    %00000000, %00111111, %11100111, %01101111, %01101110, %00000000   ; ..........#########..###.##.####.##.###.........
            DEFB    %00000000, %00111111, %11110111, %01101111, %01101110, %00000000   ; ..........##########.###.##.####.##.###.........
            DEFB    %00000000, %00111111, %11110111, %01100000, %01101110, %00000000   ; ..........##########.###.##......##.###.........
            DEFB    %00000000, %00111111, %11110011, %00111111, %11001100, %00000000   ; ..........##########..##..########..##..........
            DEFB    %00000000, %00111111, %11111011, %10000000, %00011100, %00000000   ; ..........###########.###..........###..........
            DEFB    %00000000, %00111111, %11111001, %11100000, %01111000, %00000000   ; ..........###########..####......####...........
            DEFB    %00000000, %00111111, %11111000, %11111111, %11110000, %00000000   ; ..........###########...############............
            DEFB    %00000000, %00111111, %11111000, %00111111, %11000000, %00000000   ; ..........###########.....########..............
            DEFB    %00000000, %00111111, %11111000, %00000000, %00000000, %00000000   ; ..........###########...........................
            DEFB    %00000000, %01111111, %11111111, %11111111, %11111100, %00000000   ; .........#############################..........
            DEFB    %00000000, %01111111, %11111111, %11111111, %11111110, %00000000   ; .........##############################.........
            DEFB    %00000000, %01111111, %11111111, %11111111, %11111110, %00000000   ; .........##############################.........
            DEFB    %00000000, %00111111, %11111111, %11111111, %11111100, %00000000   ; ..........############################..........
            DEFB    %00000000, %00011111, %11111111, %11111111, %11111000, %00000000   ; ...........##########################...........
            DEFB    %00000000, %00000000, %00000000, %00000000, %00000000, %00000000   ; ................................................

spr_caja:                ; un tramo de caja, 16x8 (la caja son cuatro)
            DEFB    %11111111, %11111111   ; ################
            DEFB    %11000000, %00000011   ; ##............##
            DEFB    %11011111, %11111011   ; ##.##########.##
            DEFB    %11011111, %11111011   ; ##.##########.##
            DEFB    %11011111, %11111011   ; ##.##########.##
            DEFB    %11011111, %11111011   ; ##.##########.##
            DEFB    %11000000, %00000011   ; ##............##
            DEFB    %11111111, %11111111   ; ################

;---------------------------------------------------------------------
; melodia del menu: Oh! Susanna (Stephen Foster, 1848, dominio publico)
; cada nota son tres bytes: periodo, ciclos por tick y numero de ticks
; (periodo 0 = silencio, 0xFF cierra la melodia y vuelve a empezar)
;---------------------------------------------------------------------
musica:
            DEFB    207, 31, 2  ; C5 (523 Hz -> 524 Hz)
            DEFB    184, 35, 2  ; D5 (587 Hz -> 588 Hz)
            DEFB    164, 40, 4  ; E5 (659 Hz -> 659 Hz)
            DEFB    138, 47, 4  ; G5 (784 Hz -> 782 Hz)
            DEFB    138, 47, 2  ; G5 (784 Hz -> 782 Hz)
            DEFB    122, 53, 2  ; A5 (880 Hz -> 883 Hz)
            DEFB    138, 47, 4  ; G5 (784 Hz -> 782 Hz)
            DEFB    164, 40, 2  ; E5 (659 Hz -> 659 Hz)
            DEFB    207, 31, 2  ; C5 (523 Hz -> 524 Hz)
            DEFB    184, 35, 4  ; D5 (587 Hz -> 588 Hz)
            DEFB    164, 40, 4  ; E5 (659 Hz -> 659 Hz)
            DEFB    164, 40, 2  ; E5 (659 Hz -> 659 Hz)
            DEFB    184, 35, 2  ; D5 (587 Hz -> 588 Hz)
            DEFB    207, 31, 6  ; C5 (523 Hz -> 524 Hz)
            DEFB    0, 0, 2          ; silencio
            DEFB    207, 31, 2  ; C5 (523 Hz -> 524 Hz)
            DEFB    184, 35, 2  ; D5 (587 Hz -> 588 Hz)
            DEFB    164, 40, 4  ; E5 (659 Hz -> 659 Hz)
            DEFB    138, 47, 4  ; G5 (784 Hz -> 782 Hz)
            DEFB    138, 47, 2  ; G5 (784 Hz -> 782 Hz)
            DEFB    122, 53, 2  ; A5 (880 Hz -> 883 Hz)
            DEFB    138, 47, 4  ; G5 (784 Hz -> 782 Hz)
            DEFB    164, 40, 2  ; E5 (659 Hz -> 659 Hz)
            DEFB    207, 31, 2  ; C5 (523 Hz -> 524 Hz)
            DEFB    184, 35, 4  ; D5 (587 Hz -> 588 Hz)
            DEFB    164, 40, 4  ; E5 (659 Hz -> 659 Hz)
            DEFB    184, 35, 4  ; D5 (587 Hz -> 588 Hz)
            DEFB    207, 31, 8  ; C5 (523 Hz -> 524 Hz)
            DEFB    0, 0, 3          ; silencio
            DEFB    155, 42, 4  ; F5 (698 Hz -> 697 Hz)
            DEFB    155, 42, 4  ; F5 (698 Hz -> 697 Hz)
            DEFB    122, 53, 4  ; A5 (880 Hz -> 883 Hz)
            DEFB    122, 53, 4  ; A5 (880 Hz -> 883 Hz)
            DEFB    122, 53, 2  ; A5 (880 Hz -> 883 Hz)
            DEFB    138, 47, 2  ; G5 (784 Hz -> 782 Hz)
            DEFB    164, 40, 4  ; E5 (659 Hz -> 659 Hz)
            DEFB    207, 31, 4  ; C5 (523 Hz -> 524 Hz)
            DEFB    184, 35, 4  ; D5 (587 Hz -> 588 Hz)
            DEFB    164, 40, 4  ; E5 (659 Hz -> 659 Hz)
            DEFB    184, 35, 2  ; D5 (587 Hz -> 588 Hz)
            DEFB    207, 31, 2  ; C5 (523 Hz -> 524 Hz)
            DEFB    184, 35, 8  ; D5 (587 Hz -> 588 Hz)
            DEFB    0, 0, 4          ; silencio
            DEFB    0xFF

; ---- obstaculos: x0, x1, y0, y1 (x0 = 0 cierra la tabla) -------------
obstaculos:
            DEFB    112, 135,  20,  47      ; carreta
            DEFB     64,  79, 100, 131      ; cactus de abajo
            DEFB    168, 183,  60,  91      ; cactus de arriba
            DEFB    0

; ---- variables ------------------------------------------------------
ancho_bloque:    DEFB ANCHO_JUG
tmp_x:           DEFB 0
tmp_y:           DEFB 0
caja1:           DEFB CAJA_ENTERA        ; un bit por tramo en pie
caja2:           DEFB CAJA_ENTERA
caja_masc:       DEFB 0
caja_fila:       DEFB 0
caracol_x:       DEFB CARACOL_MIN
caracol_dir:     DEFB 0                  ; 0 = a la derecha, 1 = a la izquierda
caracol_t:       DEFB 0
gen_n:           DEFB 0
gen_filas:       DEFB 0
gen_bytes:       DEFB 0
gen_resto:       DEFB 0
mus_ptr:         DEFW 0
mus_ticks:       DEFB 0
mus_per:         DEFB 0
mus_cic:         DEFB 0
p1_y:            DEFB P1_INI_Y
p2_y:            DEFB P2_INI_Y
b1_x:            DEFB 0
b1_y:            DEFB 0
b1_act:          DEFB 0
b2_x:            DEFB 0
b2_y:            DEFB 0
b2_act:          DEFB 0
puntos1:         DEFB 0
puntos2:         DEFB 0

fin_codigo:
            END inicio
