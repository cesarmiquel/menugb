INCLUDE "hardware.inc"
INCLUDE "keypad.inc"

SECTION "WRAM",WRAM0

prevkey		db
keyrepf		db
keyrepcnt       db

SECTION "MAIN",ROM0

;-------------------------------------------------------------------------------
; Initialization
;
; Input:
;   A = bitmask of keys for which autorepeat feature will be enabled 
;       (or KEY_NONE)
;-------------------------------------------------------------------------------
initkeypad:
	ld [keyrepf],a
	xor a
	ld [prevkey],a
	ret

;-------------------------------------------------------------------------------
; Return the current state of the keypad. Multiple keys may be pressed at the
; same time
;
; Ouput:
;   A = bits 7-4: Down, Up, Left, Right (1=pressed)
;       bits 3-0: Start, Select, B, A 
;
; Reference: section 2.1.4 "Controller Data" of the GB programmer manual
;-------------------------------------------------------------------------------
getkeypadstate:
	; Tests directional keys
	; B = bits 7-4: Down, Up, Left and Right (1=pressed)
	ld a,$20
	ldh [rP1],a
	ldh a,[rP1] ; delay
	ldh a,[rP1]
	cpl         ; bit set means key pressed
	and $0f
	swap a      ; move bits 0-3 to 4-7
	ld b,a

	; Tests start/select/a/b
	; B = bits 3-0: Start, Select, B, A
	ld a,$10
	ldh [rP1],a
	ldh a,[rP1] ; 5x delay
	ldh a,[rP1]
	ldh a,[rP1]
	ldh a,[rP1]
	ldh a,[rP1]
	ldh a,[rP1]
	cpl
	and $0f
	or b
	ld b,a

	ld a,$30 ; reset port
	ldh [rP1],a

	ld a,b
	ret

;-------------------------------------------------------------------------------
; Return the currently pressed key
;
; Input:
;    keyrepf (byte) = list of keys (bit mask of key constants) that should be
;    repeated when held down. The repeat rate is 1 every 7 calls.
;
; Output:
;    A = a constant representing the key (KEY_DOWN, KEY_UP, ...)
;
; Only one key will be returned. If multiple keys are pressed, the one with the
; higher priority (the key whose the value is the highest) will be returned.
;
; Should be called at equal interval
;-------------------------------------------------------------------------------
getkey:
	call getkeypadstate
	or a
	jr z,.end

	; Consider only the key with the highest value (keep the most
	; significant set bit). So KEY_DOWN is prioritary to KEY_UP, ...
.l10:
	ld c,a
	ld b,a
	dec b
	and b
	jr nz,.l10
	ld a,c

	; Manage repeat delays when a key is pressed for more than
	; one game cycle
	ld hl,prevkey
	cp [hl]
	jr nz,.end

	ld b,a
	ld hl,keyrepf
	and [hl]
	jr nz,.l20

	ld a,KEY_NONE
	jr .endnoprev
.l20:
	; B=A
	ld hl,keyrepcnt
	ld a,[hl]
	inc a
	cp 7 ; 7 game cycles delay
	ld [hl],a
	ld a,KEY_NONE
	ret c
	xor a
	ld [hl],a
	ld a,b
	ret
.end:
	ld [prevkey],a
.endnoprev:
	ld hl,keyrepcnt
	ld [hl],0
	ret

;-------------------------------------------------------------------------------
;  Wait until the user presses a key
;  Calls getkey so only one key will be returned
;  LCDC must be on
;-------------------------------------------------------------------------------
waitkey:
.l10:
	call waitvblank
	call getkey
	cp KEY_NONE
	jr z,.l10
	ret

;-------------------------------------------------------------------------------
;  Wait until the user releases all keys
;  
;  LCDC must be on
;-------------------------------------------------------------------------------
waitnokey:
.l10:
	call waitvblank
	call getkey
	cp KEY_NONE
	jr nz,.l10
	ret
