INCLUDE "hardware.inc"
INCLUDE "display.inc"
INCLUDE "keypad.inc"

SECTION "MAIN", ROM0

INCLUDE "testromlist.inc"

;-------------------------------------------------------------------------------
; Take a list of ROM entries and a sorted list of pointer to ROM entries
; (i.e. the outputs of the routines buildromlist and sortromlist) and compare
; them with the correct ones built by mktestimage.sh.
;
; In:
;   HL = non sorted list (normaly romlist)
;   DE = sorted list of pointer to ROM entries (normaly romsortedlist)
;   A = number of entries
;-------------------------------------------------------------------------------
dotests::
	; Save DE and A for the next test
	push af
	push de

	; Test buildromlist
	call testuromlist
	jr nc,.l10
	; Test failed
	add sp,4 ; discards the backup of DE and A (we won't do the second test)
	push hl
	push de
	push bc
	WRITESTRING_XY_LIT 0, 0, "UROMLIST TEST FAILED"
	pop bc
	pop de
	pop hl
	jr .failuredetails
.l10:
	; Restore address of sorted list and length
	pop hl
	pop af

	; Test sortromlist
	call testsromlist
	jr nc,.l55
	; Test failed
	push hl
	push de
	push bc
	WRITESTRING_LIT 0, 0, "SROMLIST TEST FAILED"
	pop bc
	pop de
	pop hl
.failuredetails:
	; HL = address of erroneous entry (End of list if B=0)
	; DE = address of correct excepted entry (End of list if C=0)
	push hl
	push bc

	; Write the entries if not at end of list
	ld a,c
	or a
	jr z,.l40

	ld l,e
	ld h,d
	ld de,_SCRN0+32*3
	call writeerr
.l40:
	pop bc
	pop hl
	ld a,b
	or a
	jr z,.l50
	ld de,_SCRN0+32*6
	call writeerr
.l50:
	WRITESTRING_XY_LIT 0, 2, "SHOULD HAVE BEEN:"
	WRITESTRING_XY_LIT 0, 5, "GOT:"

	jr .l60

.l55:
	WRITESTRING_XY_LIT 0,0, "ROMLIST TESTS PASSED"

.l60:
	WRITESTRING_Y_LIT_CENTER 8, "PRESS START"

	call lcdc_on
	call waitnokey
.l70
	call waitkey
	cp KEY_START
	jr nz,.l70

	call lcdc_off
	call clearscreen
	ret

writeerr:
	ld a,[hl+]
	push hl
	call writehex
	pop hl
	ld b,16
	inc de
	inc de
	call writestring_n
	ret

writehex:
	ld b,2
.l10:
	swap a
	push af

	and $0f
	add a,"0"-32
	cp "9"+1-32
	jr c,.l20
	add a,"A"-("9"+1)
.l20:
	ld [de],a
	inc de
	pop af
	dec b
	jr nz,.l10

	ret

;-------------------------------------------------------------------------------
; Test buildromlist
;
; Input:
;   HL = list of entries
;   A  = number of entries
;
; Ouput:
;   CF = reset if ok
;   in case of error:
;     CF = 1
;     B = 0 if no element in orig list
;     C = 0 if no remaining element in checked list
;     HL = point to erroneous entry (unless B=0)
;     DE = point to correct expected entry (unless C=0)
;-------------------------------------------------------------------------------
testuromlist:
	ld b,a
	ld de,uromlisttest_start
	ld a,uromlisttest_nb
	ld c,a
.l10:
	ld a,b
	or a
	jr z,.l60
	ld a,c
	or a
	jr z,.l60

	; Compare two entries

	push hl
	push de
	push bc

	ld b,17
.l30:
	ld a,[de]
	cp [hl]
	jr nz,.l40
	inc de
	inc hl
	dec b
	jr nz,.l30

	pop bc
	dec b
	dec c
	add sp,4
	jr .l10

.l40:
	pop bc
	pop de
	pop hl
.l50:

	scf
	ret
.l60:
	ld a,b
	cp c
	jr nz,.l50

	; Carry flag = 0

	ret

;-------------------------------------------------------------------------------
; Test sortromlist
;
; Input:
;   HL = list of bank numbers
;   A  = number of entries
;
; Output:
;   CF = set in case of error
;-------------------------------------------------------------------------------
testsromlist:
	cp sromlisttest_nb
	scf
	ret nz
	or a
	ret z
	ld b,a
	ld de,sromlisttest_start
.l10:
	push hl
	ld a,[hl+]
	ld h,[hl]
	ld l,a

	ld a,[de]
	cp [hl]
	pop hl
	scf
	ret nz

	inc hl
	inc hl
	inc de
	dec b
	jr nz,.l10
	or a ;CF=0
	ret
