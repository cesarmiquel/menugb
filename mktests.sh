#!/bin/sh

# mktests.sh - builds images to test the menu

# Creating a test image
# *********************
# 
# 1) Create a serie of test ROMs. test.gb, a 32KB classic Game Boy ROM
# displaying some header info (title, size, GBC or SGB features availability) is
# available as a model. You can use rgbfix (from RGBDS) to set the header
# fields.
#
# 2) Build a test image from these ROMs with mktestimage.sh
#
# mktestimage.sh uses a special test menu that makes two tests at startup:
#   - it compares the list of ROMs entries (bank+title) fetched by the menu
#     with a correct one built by mktestimage.sh
#   - it verifies that the list is sorted by title with ASCII ascending order
#
# If you create a ROM that should not be recognized by the menu (invalid
# header, ...), the title must begin with "**IGN**"
#
# Use the -d option of mktestimage.sh to get the memory map of the image.
# Use the -f option to create a full size image to avoid the need to format the
# page before writing a new image (useful with ems-flasher).

set -eu

trap 'rm -rf "$tmpdir"' EXIT 
tmpdir=$(mktemp -d)

echo "Building test images...."

#################
### test00.gb ###
#################

echo "
test00.gb
*********
  An image with a menu but no ROM.

  Should display a message and wait indefinitely"

./mktestimage.sh -f -o "test00.gb"

#################
### test01.gb ###
#################

echo "
test01.gb
*********
  An image with the maximum number of ROMs (127 ROMs of 32K).

  To check manually:
    * Menu navigation
    * The start button launches the selected ROM
    * Entries after the last ROM are empty"

#  Tested automatically:
#    * ROM listing routine
#    * Sort routine

i=127
while [ $i -ge 1 ]; do
    romf="$tmpdir/$i.gb"
    cp test.gb "$romf"
    if ! rgbfix -t $(printf '%016d' $i) -v "$romf" 2>/dev/null; then
        echo "rgbfix failed" >&2
	exit 1
    fi
    printf "%s\0" "$romf"
    i=$((i-1))
done | xargs -0 ./mktestimage.sh -f -o "test01.gb"

#################
### test02.gb ###
#################

echo "
test02.gb
*********
  Just one page

  To check manually:
    * There is just one page
    * The charset is correctly displayed:
     /0123456789:;<=
     >?@ABCDEFGHIJKL
     MNOPQRSTUVWXYZ[
     \]^_

  Test if it works on all kind of Game Boy. The GBC and SGB enhancements flags
  are disabled."

#  Tested automatically:
#    * ROM listing routine
#    * Sort routine
#    * ROMs with invalid header are ignored
#    * Chars outside the 32-95 range in the title are replaced by a space
#    * Free space between two ROMs
#    * After a ROM is found during, the scan restarts right after its end. Not
#      before or after.
#    * A ROM with an unrecognized size are considered as 32 KB ROM.

# Prepare ROMs for this test

# a ROM with a corrupted logo
# Note: the checksum is also invalid
# TODO: replace with a ROM with an incorrect logo and a valid checksum
romf="$tmpdir/corruptedlogo.gb"
cp test.gb "$romf"
rgbfix -t '**IGN**LOGO' -v "$romf"
printf '\0' | dd of="$romf" seek=307 count=1 bs=1 conv=notrunc 2>/dev/null

# Corrupted header checksum
romf="$tmpdir/corruptedchecksum.gb"
cp test.gb "$romf"
rgbfix -t '**IGN**CHKSUM' "$romf"

# A size code not recognized by the menu is defined in the header (7=4MB)
romf="$tmpdir/invalidsize.gb"
cp test.gb "$romf"
printf '\7' | dd of=$romf seek=328 count=1 bs=1 conv=notrunc 2>/dev/null
rgbfix -t 'INVALID SIZE' -v "$romf"

# A ROM with the GBC flag set (bit 7 of the last char of the title)
romf="$tmpdir/color.gbc"
cp test.gb "$romf"
rgbfix -t'COLOR' -v -c "$romf"

# Create a test ROM for each ROM size (32KB-2MB). These ROMs are composed of
# 32KB ROMs in order to test that when a ROM is found during the listing, the
# scan doesn't restarts before its end.
cp test.gb "$tmpdir/rom32.gb"
rgbfix -t 'EMBEDDED ROM' -v "$tmpdir/rom32.gb"
s=64
while [ $s -le 2048 ]; do
    cat "$tmpdir/rom$((s/2)).gb" "$tmpdir/rom$((s/2)).gb" > "$tmpdir/rom$s.gb"
    rgbfix -t 'NONAME' -p 0xff -v "$tmpdir/rom$s.gb"
    s=$((s*2))
done

# Create the test image from the ROM list below. The files must be located in
# $tmpdir. When a title is provided, a copy of the ROM is used and the ROM title
# is changed accordingly. The title is passed to printf(1) as the format
# argument so "\" and "%" must be escaped (with "\\" and "%%", resp.). Octal
# escape sequences may be used with the exception of "\0". ":" need to be
# escaped by "\72" as it is used as field separator.
i=0
while IFS=: read -r romf title; do
    romf="$tmpdir/$romf"
    if [ -n "$title" ]; then
        title=$(printf "$title")
        tempf="$tmpdir/tmp$i.gb"
	i=$((i+1))
	cp "$romf" "$tempf"
	romf=$tempf
        if ! rgbfix -v -t "$title" "$romf" 2>/dev/null; then
            echo "rgbfix failed" >&2
            exit 1
        fi
    fi
    printf "%s\0" "$romf"
done <<'EOT' | xargs -0 ./mktestimage.sh -f -o test02.gb
rom32.gb:________________
rom64.gb:AB
rom128.gb:BA
rom256.gb: ROM256
rom512.gb:ROM512
rom1024.gb:ROM1024
corruptedlogo.gb
color.gbc
corruptedchecksum.gb
rom128.gb: 0!"#$%%&'()*+,-.
invalidsize.gb
rom32.gb: /0123456789\72;<=
rom512.gb: >?@ABCDEFGHIJKL
rom256.gb: MNOPQRSTUVWXYZ[
rom256.gb: \\]^_
rom512.gb:\1empty\140{title}\300
EOT

#################
### test03.gb ###
#################

echo "
test03.gb
*********
  An image with GBC and SGB flags set

  To be tested on a Game Boy Color and on a Super Game Boy.
"
cp test02.gb test03.gb
rgbfix -c -v test03.gb
