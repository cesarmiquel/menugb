GLOBAL start

SECTION "INTERRUPTS", ROM0[0]

	; Empty as there is no RST call and interrupts will remain disabled
	; (IME=0)

	REPT $100
	db $ff
	ENDR

SECTION "HEADER", ROM0[$100]

        nop
        jp start

        ; The header will be filled by the rgbfix tool
        REPT $150-$100-4
        db 0
        ENDR
