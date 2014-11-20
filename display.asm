INCLUDE "hardware.inc"

SECTION "MAIN", ROM0

INCLUDE "display.inc"

INCLUDE "tiles.def"
INCLUDE "tiles.inc"

;=== Constants ===

LCDC_DEFAULT    equ $91   ; default settings for LCDC

;-------------------------------------------------------------------------------
; Initialize the display
;
; Input:
;   A = Game Boy type (the value of the A register at start up)
;
; Should be called at the start of the program. Expects that the LCDC is
; enabled (it is at startup).
;
; Operations:
;   - Enable the VBlank interrupt
;   - Set the BG palette 0 if run by a GBC and not in compatibility mode (GBC
;     flag is set in the header). In other cases expects that the BG palette is
;     set to the default.
;   - Load the tiles in Character RAM
;   - Turn off LCDC
;-------------------------------------------------------------------------------
initdisplay:
	push af ; save GB type

	; Enable V-Blank interrupts only
	ld hl,rIF
	res 0,[hl]
	ld hl,rIE
	set 0,[hl]

	; Wait for VBlank is recommended before turning off the LCDC
	call waitvblank

	; Turn off the LCD controller
	call lcdc_off

	; Load the tiles into the character RAM

	ld hl,_VRAM
	ld de,tiles
	ld bc,TILES_NB*8
.l5:
	ld a,[de]
	ld [hl+],a
	ld [hl+],a
	inc de
	dec bc
	ld a,b
	or c
	jr nz,.l5

	pop bc ; B = GB type
	; Menu runs on a GBC and not in DMG compatibility mode
	ld a,[$143]
	and $80
	jr z,.l10
	ld a,b
	cp a,$11 ; GBC
	jr nz,.l10

	; Initialize Color palette 0 in GBC mode
	; Color 0 = White (no color in fact), Color 3=Black

	; bit 7=1 BCPS will be auto incremented after each write to BCPD
	ld a,0+128
	ldh [rBCPS],a

	ld a,$ff
	ldh [rBCPD],a
	ld a,$7f
	ldh [rBCPD],a

	ld a,6+128
	ldh [rBCPS],a
	xor a
	ldh [rBCPD],a
	ldh [rBCPD],a

	; Clear the background attributes area
	ld a,1
	ldh [rVBK],a ; select video bank 1

	call clearscreen

	; Select the background characters area (video bank 0)
	xor a
	ldh [rVBK],a
.l10:
	; Clear the screen
	call clearscreen
	ret

;-------------------------------------------------------------------------------
; Turn on LCDC
;-------------------------------------------------------------------------------
lcdc_on:
	ld a,LCDC_DEFAULT
	ldh [rLCDC],a
	ret

;-------------------------------------------------------------------------------
; Turn off LCDC
;-------------------------------------------------------------------------------
lcdc_off:
	xor a
	ldh [rLCDC],a
	ret

;-------------------------------------------------------------------------------
; Wait for the start of a V-Blank
;-------------------------------------------------------------------------------
waitvblank:
	push hl

	ld hl,rIF
	res 0,[hl]
.l10:
	halt
	nop
	bit 0,[hl]
	jr z,.l10

	pop hl
	ret

;-------------------------------------------------------------------------------
; Clear the screen (in fact, 18 lines of 32 chars of _SCRN0)
;-------------------------------------------------------------------------------
clearscreen:
	; Clear the background chars area
	ld bc,18*32
	ld hl,_SCRN0
.l10:
	xor a
	ld [hl+],a
	dec bc
	ld a,b
	or c
	jr nz,.l10

	ret

;-------------------------------------------------------------------------------
; Display a NUL-terminated string
;
; Input:
;   HL = string address (NUL-terminated).
;   DE = address in VRAM
;
; Output:
;   DE = address after the last displayed character
;-------------------------------------------------------------------------------
writestring:
.l10:
	ld a,[hl+]
	or a
	ret z
	sub 32 ; tiles 0 = char 32
	ld [de],a
	inc de
	jr .l10

;-------------------------------------------------------------------------------
; Display a literal string.
;
; Input:
;   The call must be followed by a NUL-terminated string
;   DE = address in VRAM
;
; Output:
;   DE = address after the last displayed character
;-------------------------------------------------------------------------------
writestring_lit:
	pop hl
	call writestring
	jp [hl]

;-------------------------------------------------------------------------------
; Display a fixed length string
;
; Input:
;   B = string length
;   HL = string address
;   DE = address in VRAM
;
; Output:
;   DE = address after the last displayed character
;-------------------------------------------------------------------------------
writestring_n:
.l10:
	ld a,[hl+]
	sub 32 ; tiles 0 = char 32
	ld [de],a
	inc de
	dec b
	jr nz,.l10
	ret

;-------------------------------------------------------------------------------
; Invert the colors of a string displayed in VRAM
;
; Input:
;   HL = address of the string in VRAM
;   B  = length of the string
;-------------------------------------------------------------------------------
invertcolstring:
.l10
	ld a,[hl]
	cp TILE_ASCII_REV
	jr c,.l20
	sub TILE_ASCII_REV*2
.l20:
	add TILE_ASCII_REV
	ld [hl+],a
	dec b
	jr nz,.l10
	ret
