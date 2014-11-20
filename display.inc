GLOBAL initdisplay, lcdc_on, lcdc_off, waitvblank, clearscreen
GLOBAL writestring, writestring_n, writestring_lit, invertcolstring

WRITESTRING_LIT: MACRO
	call writestring_lit
	db \1, 0
ENDM

WRITESTRING_XY_LIT: MACRO
	ld de,_SCRN0+(\2)*32+(\1)
	WRITESTRING_LIT \3
ENDM

WRITESTRING_Y_LIT_CENTER: MACRO
	ld de,_SCRN0+(\1)*32+(10-STRLEN(\2)/2)
	WRITESTRING_LIT \2
ENDM
