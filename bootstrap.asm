;===============================================================================
; Bootstrap routines for the EMS "GB USB Smart Card"
;===============================================================================

INCLUDE "hardware.inc"
INCLUDE "bootstrap.inc"

SECTION "MAIN", ROM0

;-------------------------------------------------------------------------------
; Bootstrap a ROM
;
; In:
;  B = first bank of the ROM
;  C = GB type (value of A at boot)
;  DE = address where the switch procedure will be copied
;
; After this call, the Game Boy will see the specified ROM as if it was
; installed at the beginning of the cartridge (at bank 0 and following).
;
; The Game Boy is (mostly) restored to the boot time state:
;  - Reset rIE, rIF and EMI
;  - Set SP to $FFFE (except with bootstrap_customsp)
;  - Turn on the LCDC with the initial value ($91)
;  - Restore the GB type in A (given as parameter)
;
; The VRAM and the palettes are left untouched for now.
;
; Jump to boostrap_customsp if you want to pass parameters to the ROM. You will
; have to set SP yourself. Actually used so that the state of the menu can be
; restored when a test ROM switch back to it.
;
; References:
;  - Info about programming the EMS cartridge by Didrik Madheden:
;     http://blog.gg8.se/gameboyprojects/week09/EMS_FAQ.txt
;     (Source: http://blog.gg8.se/wordpress/2013/03/04/gameboy-project-week-9-
;      the-ems-cartridges-something-old-and-something-new-something-black-and-
;      something-blue-and-how-sloppy-cartridge-design-affects-you/)
;
; Tested on a 64Mbit USB model but should work on EMS 32M rev2
;-------------------------------------------------------------------------------
bootstrap:
	; Restore SP
	ld hl,$fffe
	ld sp,hl

bootstrap_customsp:
	push bc

	; Disable interrupts and clear interrupt request flags
	di

	xor a
	ldh [rIE],a ; disable interrupts before clearing rIF
	ldh [rIF],a

	; Turn on the LCDC with the default value
	ld a,$91
	ld [rLCDC],a

	; Copy the switch procedure into RAM and call it
	; this is needed as 0-$7FFF will be remapped
	push de

	ld hl,bootstrap_proc
	ld b,bootstrap_proc_end-bootstrap_proc
.l10:
	ld a,[hl+]
	ld [de],a
	inc de
	dec b
	jr nz,.l10

	pop hl
	pop bc

	jp [hl]

; Bootstrap procedure
; In: 
;  B = first bank of the ROM
;  C = GB type (value of A at boot)
bootstrap_proc:
	; Bootstrap the ROM
	; See the EMS FAQ document referenced in the header of this file
	; for detailed information about programming the cartridge

	; Select the first bank of the ROM
	ld a,b
	ld [rROMB0],a

	; Unlock EMS config mode. No effect on the 64M cartrige but allow us
	; to test the program with the BGB emulator.
	ld a,$a5
	ld [$1000],a

	; Tell the EMS cartridge to map the ROM whose first bank is in rROMB0.
	; The actual value written is ignored by the 64Mbit cartridge
	; (for BGB: 8 set RAM=max, ROM=max and MBC5 memory controller like the
	; real 64Mbit cartridge).
	ld a,8
	ld [$7000],a

	; Lock config mode (no effect on 64M cartridge)
	ld a,$98
	ld [$1000],a

	; Restore A to its initial value (machine type)
	ld a,c

	; Bootstrap the ROM
	jp $100
bootstrap_proc_end:
