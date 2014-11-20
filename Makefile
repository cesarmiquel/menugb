GBAS = rgbasm
GBLD = rgblink
GBFIX = rgbfix

GBASFLAGS = -h
GBLDFLAGS = -p 0xff -t
GBFIXFLAGS = -p 0xff -v

MENUTITLE = GB16M

MENUOBJS = header.o menu.o bootstrap.o keypad.o display.o
TESTOBJS = header.o test.o bootstrap.o keypad.o display.o
MENUTESTOBJS = header.o menu-romlisttest.o bootstrap.o keypad.o \
		display.o testromlist.o
TESTROMS = test??.gb

.SUFFIXES: .asm

all: menu.gb

tests: test.gb
	./mktests.sh

clean:
	rm -f menu.gb menu-romlisttest.gb test.gb testromlist.inc tiles.inc \
	      tiles.def $(MENUOBJS) $(MENUTESTOBJS) $(TESTOBJS) $(TESTROMS) 

menu.o: hardware.inc bootstrap.inc keypad.inc display.inc tiles.def
bootstrap.o: hardware.inc bootstrap.inc
keypad.o: hardware.inc keypad.inc
display.o: hardware.inc display.inc tiles.inc tiles.def

menu-romlisttest.o: hardware.inc bootstrap.inc keypad.inc display.inc tiles.def
testromlist.o: hardware.inc display.inc keypad.inc testromlist.inc

menu.gb: $(MENUOBJS)
	$(GBLD) $(GBLDFLAGS) -o $@ $(MENUOBJS)
	$(GBFIX) $(GBFIXFLAGS) -t '$(MENUTITLE)' $@

menu-romlisttest.gb: $(MENUTESTOBJS)
	$(GBLD) $(GBLDFLAGS) -o $@ $(MENUTESTOBJS)
	$(GBFIX) $(GBFIXFLAGS) -t '$(MENUTITLE)' $@

test.gb: $(TESTOBJS)
	$(GBLD) $(GBLDFLAGS) -o $@ $(TESTOBJS)
	$(GBFIX) $(GBFIXFLAGS) -t 'UNTITLED' $@

menu-romlisttest.o: menu.asm
	trap 'rm -f "$$tmp"' EXIT ; \
	tmp=$$(mktemp) && \
	echo "TESTROMLIST EQU 1" >"$$tmp" && \
	cat menu.asm >>"$$tmp" && \
	$(GBAS) $(GBASFLAGS) -o $@ "$$tmp"

.asm.o:
	$(GBAS) $(GBASFLAGS) -o $@ $<

tiles.def: tiles.inc
tiles.inc: mktiles.sh
	./mktiles.sh >tiles.inc 3>tiles.def
