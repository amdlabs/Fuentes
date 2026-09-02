;=====================================================================
;  B A L A V A   -  ZX Spectrum 48K  -  2 jugadores
;---------------------------------------------------------------------
;  El policia (izquierda) y el ladron (derecha) se disparan de lado a
;  lado.  Solo pueden moverse arriba y abajo para esquivar las balas.
;  Fondo amarillo (PAPER 6), sprites en negro (INK 0).
;
;  Controles:
;     Jugador 1 - POLICIA : Q = arriba   A = abajo   V = disparo
;     Jugador 2 - LADRON  : P = arriba   L = abajo   ESPACIO = disparo
;
;  Ensamblar con:  pasmo --bin src/balava.asm build/balava.bin
;=====================================================================

SCREEN      EQU 0x4000              ; memoria de pantalla
ATTRS       EQU 0x5800              ; area de atributos
FONT        EQU 0x3C00              ; juego de caracteres de la ROM

PAPEL       EQU 6                   ; amarillo
TINTA       EQU 0                   ; negro
ATTR_JUEGO  EQU (PAPEL*8)+TINTA     ; = 0x30

COL_P1      EQU 2                   ; columna de caracteres del policia
COL_P2      EQU 29                  ; columna de caracteres del ladron

MIN_Y       EQU 16                  ; limite superior del campo de juego
MAX_Y       EQU 176                 ; limite inferior (sprite de 16 alto)
VEL_JUG     EQU 2                   ; pixeles por fotograma

P1_INI_Y    EQU 48
P2_INI_Y    EQU 128

VEL_BALA    EQU 4                   ; pixeles por fotograma
BAL_INI_1   EQU 24                  ; x de salida de la bala del policia
BAL_FIN_1   EQU 232                 ; x donde alcanza la columna del ladron
BAL_INI_2   EQU 228                 ; x de salida de la bala del ladron
BAL_FIN_2   EQU 20                  ; x donde alcanza la columna del policia

ALTO_SPR    EQU 16
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

            call    limpia_pantalla
            call    dibuja_marcador
            call    hud_puntos
            call    coloca_jugadores

bucle:
            halt                            ; sincroniza a 50 Hz
            call    actualiza_p1
            call    actualiza_p2
            call    actualiza_bala1
            call    actualiza_bala2

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
            ld      c,9
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
            and     %00010000               ; V
            ret     nz
            ld      a,(b1_act)
            or      a
            ret     nz                      ; ya tiene una bala en vuelo
            ld      a,BAL_INI_1
            ld      (b1_x),a
            ld      a,(p1_y)
            add     a,7                     ; altura del brazo
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
            and     %00000001               ; ESPACIO
            ret     nz
            ld      a,(b2_act)
            or      a
            ret     nz
            ld      a,BAL_INI_2
            ld      (b2_x),a
            ld      a,(p2_y)
            add     a,7
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
            jr      c,ab1_pinta
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
            jr      nc,ab2_pinta
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
            call    borra_filas
            ld      a,(p2_y)
            ld      c,COL_P2
            ld      b,ALTO_SPR
            call    borra_filas
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
            call    borra_filas
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
            call    borra_filas
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
; dibuja_jugador - vuelca 16 bytes de sprite
;   entrada: A = y, C = columna, DE = sprite
;---------------------------------------------------------------------
dibuja_jugador:
            call    scr_addr
            ld      b,ALTO_SPR
dj_bucle:
            ld      a,(de)
            ld      (hl),a
            inc     de
            call    down_hl
            djnz    dj_bucle
            ret

;---------------------------------------------------------------------
; borra_filas - pone a 0 B filas de una columna
;   entrada: A = y, C = columna, B = numero de filas
;---------------------------------------------------------------------
borra_filas:
            call    scr_addr
bf_bucle:
            ld      (hl),0
            call    down_hl
            djnz    bf_bucle
            ret

;---------------------------------------------------------------------
; bala_xor - dibuja/borra una bala (4x2 pixeles) en modo XOR
;   entrada: A = x en pixeles, B = y
;---------------------------------------------------------------------
bala_xor:
            ld      c,a
            and     %00000100               ; mitad izquierda o derecha
            ld      a,%11110000
            jr      z,bx_pat
            ld      a,%00001111
bx_pat:
            ld      d,a                     ; D = patron
            ld      a,c
            rrca
            rrca
            rrca
            and     %00011111
            ld      c,a                     ; C = columna
            ld      a,b                     ; A = y
            call    scr_addr
            ld      a,(hl)
            xor     d
            ld      (hl),a
            call    down_hl
            ld      a,(hl)
            xor     d
            ld      (hl),a
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
            ld      c,1
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
            ld      c,6
            call    print_char
            ld      a,(puntos2)
            add     a,'0'
            ld      b,0
            ld      c,29
            jp      print_char

;=====================================================================
; PANTALLA DE PRESENTACION
;=====================================================================
menu:
            call    limpia_pantalla
            call    dibuja_marco
            call    dibuja_logo
            ; los dos personajes apuntandose bajo el logotipo
            ld      a,72
            ld      c,8
            ld      de,spr_poli
            call    dibuja_jugador
            ld      a,72
            ld      c,22
            ld      de,spr_ladron
            call    dibuja_jugador
            ld      b,79                    ; y de la bala entre los dos
            ld      a,120                   ; x de la bala
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
menu_espera:
            halt
            ld      bc,0xF7FE               ; fila 1 2 3 4 5
            in      a,(c)
            ld      b,a
            and     %00000001               ; tecla 1 = jugar
            ret     z
            ld      a,b
            and     %00000010               ; tecla 2 = controles
            jr      nz,menu_espera
            call    pantalla_controles
            jr      menu

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

sonido_impacto:
            ld      b,25
            ld      c,110
            call    sonido
            ld      b,30
            ld      c,190
            jp      sonido

;=====================================================================
; DATOS
;=====================================================================
; ---- sprites de 8x16, el bit a 1 se pinta en negro ------------------
spr_poli:                                   ; mira hacia la derecha
            DEFB    %00111100               ; ..XXXX..  copa de la gorra
            DEFB    %01111110               ; .XXXXXX.  visera
            DEFB    %00111100               ; ..XXXX..  cara
            DEFB    %00100100               ; ..X..X..  ojos
            DEFB    %00111100               ; ..XXXX..
            DEFB    %00011000               ; ...XX...  cuello
            DEFB    %01111110               ; .XXXXXX.  hombros
            DEFB    %11111111               ; XXXXXXXX  brazo y pistola
            DEFB    %01111100               ; .XXXXX..  torso
            DEFB    %01111100               ; .XXXXX..
            DEFB    %01111100               ; .XXXXX..  cinturon
            DEFB    %00111100               ; ..XXXX..
            DEFB    %00111100               ; ..XXXX..
            DEFB    %00110110               ; ..XX.XX.  piernas
            DEFB    %00110110               ; ..XX.XX.
            DEFB    %01100110               ; .XX..XX.  pies

spr_ladron:                                 ; mira hacia la izquierda
            DEFB    %00011000               ; ...XX...  gorro
            DEFB    %00111100               ; ..XXXX..
            DEFB    %01111110               ; .XXXXXX.  ala del gorro
            DEFB    %00111100               ; ..XXXX..  antifaz
            DEFB    %00100100               ; ..X..X..  ojos
            DEFB    %00011000               ; ...XX...  cuello
            DEFB    %01111110               ; .XXXXXX.  hombros
            DEFB    %11111111               ; XXXXXXXX  brazo y pistola
            DEFB    %00111110               ; ..XXXXX.  torso
            DEFB    %00111110               ; ..XXXXX.
            DEFB    %00111110               ; ..XXXXX.
            DEFB    %00111100               ; ..XXXX..
            DEFB    %00111100               ; ..XXXX..
            DEFB    %01101100               ; .XX.XX..  piernas
            DEFB    %01101100               ; .XX.XX..
            DEFB    %01100110               ; .XX..XX.  pies

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
txt_poli:        DEFB "POLI:",0
txt_ladron:      DEFB "LADRON:",0
txt_juego:       DEFB "BALAVA",0
txt_op1:         DEFB "1  JUGAR",0
txt_op2:         DEFB "2  CONTROLES",0
txt_pulsa:       DEFB "PULSA 1 O 2",0
txt_autor:       DEFB "(C) 2026  AMDLABS",0
txt_controles:   DEFB "CONTROLES",0
txt_j1:          DEFB "JUGADOR 1 - POLICIA",0
txt_j1b:         DEFB "Q=ARRIBA  A=ABAJO",0
txt_j1c:         DEFB "V=DISPARO",0
txt_j2:          DEFB "JUGADOR 2 - LADRON",0
txt_j2b:         DEFB "P=ARRIBA  L=ABAJO",0
txt_j2c:         DEFB "ESPACIO=DISPARO",0
txt_reglas:      DEFB "5 IMPACTOS PARA GANAR",0
txt_tecla:       DEFB "PULSA CUALQUIER TECLA",0
txt_gana_poli:   DEFB "GANA EL POLICIA",0
txt_gana_ladron: DEFB "GANA EL LADRON",0
txt_final:       DEFB "RESULTADO",0

; ---- variables ------------------------------------------------------
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
