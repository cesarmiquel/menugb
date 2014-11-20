;===============================================================================
; Program that displays some information about the ROM for testing purpose
;===============================================================================

INCLUDE "hardware.inc"
INCLUDE "display.inc"
INCLUDE "bootstrap.inc"
INCLUDE "keypad.inc"

SECTION "WRAM", WRAM0

gbtype	db
title	ds 16

SECTION "MAIN", ROM0

unknowsizestr	db "UNKNOW SIZE",0

start::
	; If called from the test menu, the top of the stack will contains
	; the state of the menu and SP will be $FFFC

	ld a,[gbtype]
	call initdisplay

	ld a,KEY_NONE
	call initkeypad

	WRITESTRING_XY_LIT 0, 0, "HEADER INFO:"

	; *** Title ***

	; Replace chars 32-95 of the title by spaces
	ld hl,$134
	ld de,title
	ld b,16
.l10:
	ld a,[hl+]
	cp 32
	jr c,.l20
	cp 95+1
	jr c,.l30
.l20:
	ld a,32
.l30:
	ld [de],a
	inc de
	dec b
	jr nz,.l10

	ld de,_SCRN0+32
	ld hl,title
	ld b,16
	call writestring_n

	; *** Size ***

SELECTSIZE:	MACRO
	ld hl,.str\@
	cp \1
	jp z,.writesize
	jr .next\@
.str\@:	db \2,0
.next\@:
ENDM

	ld a,[$148] ; size code

	SELECTSIZE 0,"32 KB"
	SELECTSIZE 1,"64 KB"
	SELECTSIZE 2,"128 KB"
	SELECTSIZE 3,"256 KB"
	SELECTSIZE 4,"512 KB"
	SELECTSIZE 5,"1024 KB"
	SELECTSIZE 6,"2048 KB"
	SELECTSIZE 7,"4096 KB"
	SELECTSIZE 8,"8192 KB"
	SELECTSIZE $52,"1152 KB"
	SELECTSIZE $53,"1280 KB"
	SELECTSIZE $54,"1536 KB"

	ld hl,unknowsizestr
.writesize:
	ld de,_SCRN0+32*2
	call writestring

	; *** CGB and SGB functions ***

	WRITESTRING_XY_LIT 0, 3, "GBC FUNCTIONS "
	ld a,[$143]
	and $80
	jr z,.l40
	WRITESTRING_LIT "ON"
	jr .l50
.l40:
	WRITESTRING_LIT "OFF"
.l50:
	WRITESTRING_XY_LIT 0, 4, "SGB FUNCTIONS "
	ld a,[$14b]
	cp $33
	jr nz,.l60
	ld a,[$146]
	cp 3
	jr nz,.l60
	WRITESTRING_LIT "ON"
	jr .l65
.l60:
	WRITESTRING_LIT "OFF"
.l65:

	; Waits until the user press Start and bootstrap the menu

	WRITESTRING_Y_LIT_CENTER 6, "PRESS START"	

	call lcdc_on
	call waitnokey
.l80:
	call waitkey
	cp KEY_START
	jr nz,.l80

	; Switch back to the menu
	ld a,[gbtype]
	ld c,a
	ld b,0
	ld de,_RAM
	; Leave SP to this original value (SP = $FFFC if we were called by the
	; test menu or $FFFE otherwise) to pass back the state of the menu
	jp bootstrap_customsp
