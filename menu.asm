;===============================================================================
; menu.gb v0.92 - a menu for the 64 MBit "GB USB Smart Card" from EMS
;===============================================================================

VERSION         equs "0.92"

INCLUDE "hardware.inc"
INCLUDE "bootstrap.inc"
INCLUDE "keypad.inc"
INCLUDE "display.inc"
INCLUDE "tiles.def"

;=== Variables ===

SECTION "WRAM", WRAM0

gbtype          db        ; Game Boy type (value of the A register at start up)

disabletests	db

menuscrpos      dw        ; index of the selected line (0=first line on screen) 
menuscrlen      dw        ; number of entries currently visible in the box
romlistpos      db        ; index in the rom list of the first visible entry
romlistlen      db        ; number of ROMs
romlist         ds 127*17 ; the rom list (one byte for the bank number +
			  ; 16 bytes for the title)
romlistendptr   dw        ; point at the end of romlist
romsortedlist   ds 127*2  ; sorted array of addresses to entries of romlist

; Used by buildromlist

banktmp         db
gap2            db

;===============================================================================
; Main program: init + menu main loop
;===============================================================================

SECTION "MAIN", ROM0[$150]

start::
	; Preserve the GB type code
	ld [gbtype],a

	; Test the presence of call parameters on the stack (when the test ROM
	; (test.gb) switches back to the menu with bootstrap_customsp by passing
	; the saved menu state).
	; Accepts two parameters (2x8 bits in $FFFC):
	;  romlistpos (high-order byte) and menuscrpos (low-order byte)
	; which represent the state of the menu.

	; Assume that if SP <> $FFFE (doesn't check that SP is really $FFFC)
	ld hl,[sp+0]
	inc hl
	inc hl
	ld a,l
	or h
	jr z,.l10
	; Parameters found
	ld a,1 ; disable the tests
	pop hl ; pop the parameter
.l10:
	ld [disabletests],a
	ld a,h
	ld [romlistpos],a
	ld a,l
	ld [menuscrpos],a

	ld a,[gbtype]
	call initdisplay

	ld a,KEY_UP|KEY_DOWN
	call initkeypad

	call buildromlist

IF DEF(TESTROMLIST)
	GLOBAL dotests

	ld a,[disabletests]
	or a
	jr nz,.l20

	ld hl,romlist
	ld de,romsortedlist
	ld a,[romlistlen]
	call dotests
.l20:
ENDC

    ; If there is only one ROM, launch it directly
    ld a,[romlistlen]
    cp 1
    jr nz,.l25

    ld a,[romlist]
    jp launchrom
.l25:
	WRITESTRING_Y_LIT_CENTER 0, "MENU.GB V{VERSION}"

	call drawbox

	; Test that at least one ROM was found
	ld a,[romlistlen]
	or a
	jr nz,.l30

	WRITESTRING_Y_LIT_CENTER 8, "ROM NOT FOUND"

	call lcdc_on

	; Wait forever
	xor a
	ldh [rIE],a
	halt

.l30:
	WRITESTRING_Y_LIT_CENTER 17, "START TO PLAY"

	call lcdc_on

	; Display the first page of the ROM titles
	call displaypage
	call waitnokey
mainloop:
	call waitkey

	ld hl,menuscrpos
	ld b,[hl]

	; Up and down: move the selector, never change page

	cp KEY_DOWN
	jr nz,.l10
	inc b
	jr .l20
.l10:
	cp KEY_UP
	jr nz,.l30
	dec b
.l20:
	ld a,b
	ld hl,menuscrlen
	cp [hl]
	jr nc,mainloop
	push af
	call invertentry
	ld a,[menuscrpos]
	call invertentry
	pop af
	ld [menuscrpos],a
	jr mainloop

	; Left and right: change page
	; Left key is ignored on first page and right key on last page
.l30:
	cp KEY_RIGHT
	jr nz,.l40
	ld a,[romlistpos]
	add 14
	jr c,mainloop
	ld hl,romlistlen
	cp [hl]
	jr nc,mainloop

	ld [romlistpos],a
	xor a
	ld [menuscrpos],a
	call displaypage
	jr mainloop
.l40:
	cp KEY_LEFT
	jr nz,.l50
	ld a,[romlistpos]
	or a
	jr z,mainloop
	sub 14

	ld [romlistpos],a
	xor a
	ld [menuscrpos],a
	call displaypage
	jr mainloop
.l50:
	cp KEY_START
	jr nz,mainloop

	; Get the first bank of the selected ROM
	ld a,[romlistpos]
	ld hl,menuscrpos
	add [hl]
	ld l,a
	ld h,0
	add hl,hl
	ld de,romsortedlist
	add hl,de
	ld a,[hl+]
	ld h,[hl]
	ld l,a

	; Jump into the selected ROM
	ld a,[hl]
launchrom:
	ld b,a
	ld a,[gbtype]
	ld c,a
	ld de,_RAM
IF DEF(TESTROMLIST)
	; Pass the state of the menu as parameter
	ld hl,$fffe
	ld sp,hl
	ld a,[romlistpos]
	ld h,a
	ld a,[menuscrpos]
	ld l,a
	push hl
	jp bootstrap_customsp
ELSE
	jp bootstrap
ENDC

;===============================================================================
; Fetch and sort the list of ROMs of the cartridge
;===============================================================================

;-------------------------------------------------------------------------------
; Scan the cartridge for ROMs and sort the list
;
; Out:
;  romlistlen    = number of ROMs
;  romlist       = romlistlen*17 bytes (1-byte bank + 16-char title).
;                  titles have fixed size, no invalid char and are padded
;                  with spaces.
;  romsortedlist = array of addresses to romlist entries sorted by title
;-------------------------------------------------------------------------------
buildromlist:
	xor a
	ld [romlistlen],a
	ld hl,romlistendptr
	ld de,romlist
	ld [hl],e
	inc hl
	ld [hl],d

	; Scan the entire page (256 banks) for ROMs.
	; The two first banks are taken by the menu.
	ld a,2
	ld [banktmp],a
.l10:
	; Switch bank (see GB programmer manual, section 4 (MBC5))
	; The selected bank is mapped to $4000-7FFF
	ld a,[banktmp]
	ld [rROMB0],a

	; Check if the Nintendo logo is present
	ld de,$104  ; the logo of the menu rom header
	ld hl,$4104 ; possibly ROM header
	ld b,$30
.l20:
	ld a,[de]
	cp [hl]
	ld a,2
	jp nz,.l110

	inc hl
	inc de
	dec b
	jr nz,.l20

	; Validate the header checksum

	; HL = $4134

	ld a,25
	ld b,a
.l40:
	add a,[hl]
	inc hl
	dec b
	jr nz,.l40
	add a,[hl]

	ld a,2
	jr nz,.l110

	; Insert the new entry into romlist
	; Chars outside 32-95 range are replaced by a space.
	ld hl,romlistendptr
	ld a,[hl+]
	ld e,a
	ld d,[hl]
	ld a,[banktmp]
	ld [de],a
	inc de
	ld hl,$4134
	ld c,16
.l50:
	ld a,[hl+]
	cp 32
	jr c,.l60
	cp 95+1
	jr c,.l70
.l60:
	ld a," "
.l70:
	ld [de],a
	inc de
	dec c
	jr nz,.l50

.l80:
	; Note: endlistptr has not been incremented yet and point to the new
	; entry

	; Insert the address of the new entry (pointed by romlistendptr) to HL
	; (sortedromlist) and eventualy increment romlistendptr and romlistlen

	ld a,[romlistlen]
	ld l,a
	ld h,0
	add hl,hl
	ld de,romsortedlist
	add hl,de

	ld a,[romlistendptr+1]
	ld d,a
	ld a,[romlistendptr]
	ld e,a

	ld [hl+],a
	ld [hl],d

	ld hl,romlistlen
	inc [hl]

	ld hl,17
	add hl,de
	push hl
	pop de
	ld hl,romlistendptr
	ld [hl],e
	inc hl
	ld [hl],d

	; Adjust banktmp so it points to the bank right after the end of the
	; current ROM.
	;
	; Assume 32KB for ROMs whose size is not a power of two, is greater
	; than 2MB or whose the size code is invalid.

	ld a,[$4148] ; size code (0-6 = 32KB-2MB)
	cp 7
	jr c,.l90

	; defaults to 2 banks (the minimum size)
	ld a,2
	jr .l110
.l90:
	; size = 2**(size_code+1) banks
	ld b,a
	inc b
	ld a,1
.l100:
	sla a
	dec b
	jr nz,.l100
.l110:
	ld hl,banktmp
	add [hl]
	jr c,sortromlist
	ld [hl],a
	jp nz,.l10

	jr sortromlist

; Sort romsortedlist with Shellsort using the Knuth sequence
;

knuthseq  db 40,13,4,1,0 ; Knuth sequence for romlistlen < 128 (0-terminated)

sortromlist:
	; Determine the starting gap:
	; the greatest number in the sequence that is <= romlistlen/3 or 1

	ld a,[romlistlen]
	ld b,a
	ld hl,knuthseq
.l10:
	ld a,[hl]
	or a
	jr z,.l20  ; end of list = choose 1
	ld c,a
	add a
	add c
	cp b
	inc hl
	jr z,.l20  ; choose gap if gap*3 <= romlistlen
	jr nc,.l10
.l20:
	dec hl

	; Loop through gap sequence from the selected one to 1
	; HL = address in knuthseq of the current gap sequence
.loop1:
	push hl
	ld a,[hl]
	or a
	jr z,.end

	add a
	ld [gap2],a ; gap2 is the current gap times two

	ld a,[hl]
	; Loop A from current gap to romlistlen
.loop2:
	; A = current position in romlist (cur)
	push af
	ld hl,romlistlen
	cp [hl]
	jr nc,.loop2_break

	; DE = address of romlist[cur]
	add a
	ld l,a
	ld h,0
	ld de,romsortedlist
	add hl,de
	ld d,h
	ld e,l

	; BC = element in romlist[cur]
	ld a,[de]
	ld c,a
	inc de
	ld a,[de]
	dec de
	ld b,a
.loop3:
	; HL = address of romlist[cur-gap]
	ld hl,gap2
	ld a,e
	sub [hl]
	ld l,a
	ld a,d
	sbc 0
	ld h,a

	; Break if HL < romsortedlist
	ld a,l
	sub romsortedlist & 255
	ld a,h
	sbc (romsortedlist >> 8) & 255
	jr c,.loop3_break

	; Compare strings pointed by BC and romlist[cur-gap]
	push hl
	push bc
	push de

	inc bc

	ld a,[hl+]
	ld h,[hl]
	ld l,a
	inc hl

	ld e,16+1
.l90:
	dec e
	jr nz,.l100
	pop de
	pop bc
	pop hl
	jr .loop3_break
.l100:
	ld a,[bc]
	cp [hl]
	inc hl
	inc bc
	jr z,.l90
	jr c,.l110
	pop de
	pop bc
	pop hl
	jr .loop3_break
.l110:
	pop de
	pop bc
	pop hl

	; Copy romlist[cur-gap] to romlist[cur]
	ld a,[hl+]
	ld [de],a
	inc de
	ld a,[hl]
	ld [de],a
	dec hl

	; DE = address of romlist[cur-gap]
	ld d,h
	ld e,l

	jr .loop3
.loop3_break:
	ld a,c
	ld [de],a
	inc de
	ld a,b
	ld [de],a

	pop af
	inc a
	jr .loop2
.loop2_break:
	pop af

	pop hl
	inc hl
	jp .loop1
.end:
	pop hl

	ret

;==============================================================================
; Menu display
;==============================================================================

;-------------------------------------------------------------------------------
; Draw a box for the ROM list
;-------------------------------------------------------------------------------
drawbox:
	ld a,TILE_ULEFT
	ld [_SCRN0+32*1+1],a
	ld a,TILE_URIGHT
	ld [_SCRN0+32*1+18],a
	ld a,TILE_LRIGHT
	ld [_SCRN0+32*16+18],a
	ld a,TILE_LLEFT
	ld [_SCRN0+32*16+1],a

	ld hl,_SCRN0+32*1+2
	ld de,_SCRN0+32*16+2
	ld a,TILE_HORIZ
	ld b,16
.l10:
	ld [hl+],a
	ld [de],a
	inc de
	dec b
	jr nz,.l10

	ld hl,_SCRN0+2*32+1
	ld a,TILE_VERT
	ld b,14
.l20:
	ld [hl],a
	ld de,17
	add hl,de
	ld [hl],a
	ld de,15
	add hl,de
	dec b
	jr nz,.l20

	ret

;-------------------------------------------------------------------------------
; Display a page of ROM entries according to romlistpos and menuscrpos
;-------------------------------------------------------------------------------
displaypage:
	ld a,[romlistpos]

	ld l,a
	ld h,0
	add hl,hl
	ld de,romsortedlist
	add hl,de

	xor a
	ld [menuscrlen],a
	ld b,a
	ld c,a
	ld de,_SCRN0+32*2+2
.l10:
	; Wait for V-Blank every 3 lines
	ld a,c
	or a
	jr z,.l20
	cp 3
	jr nz,.l30
.l20:
	push hl
	push de
	push bc
	call waitvblank
	pop bc
	pop de
	pop hl
	ld c,0
.l30:
	inc c
	push bc

	ld a,[romlistlen]
	ld c,a
	ld a,[romlistpos]
	add b
	cp c
	jr c,.l40

	; No more entries: blank out remaining slots
	push hl
	WRITESTRING_LIT "                "

	; Next line
	ld hl,32-16
	add hl,de
	ld e,l
	ld d,h
	pop hl
	jr .l50
.l40:
	push hl
	push de

	ld a,[hl+]
	ld h,[hl]
	ld l,a
	inc hl

	; Write the title
	ld b,16
	call writestring_n

	; Next line
	pop de
	ld hl,32
	add hl,de
	ld d,h
	ld e,l
	ld hl,menuscrlen
	inc [hl]
	pop hl

	; Next entry in romsortedlist
	inc hl
	inc hl
.l50:
	pop bc
	inc b
	ld a,b
	cp 14
	jr nz,.l10

	; Display left and right arrows when appropriate

	ld b,0
	ld a,[romlistpos]
	cp 14
	jr c,.l60
	ld b,TILE_LARROW
.l60:
	ld a,b
	ld [_SCRN0+32*8],a

	ld b,0
	ld a,[romlistpos]
	add 14
	ld hl,romlistlen
	cp [hl]
	jr nc,.l70
	ld b,TILE_RARROW
.l70:
	ld a,b
	ld [_SCRN0+32*8+19],a

	; Inverse the color of the current entry
	ld a,[menuscrpos]
	call invertentry

	ret

;-------------------------------------------------------------------------------
; Invert the colors of the characters of the specified line in the menu
;
; In:
;   A = line index in the menu box (0=1st line)
;-------------------------------------------------------------------------------
invertentry:
	; HL = A*32
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl

	ld de,_SCRN0+32*2+2
	add hl,de
	ld b,16
	call invertcolstring
	ret
