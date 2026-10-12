#!/usr/bin/env bash
# Full i386 verification: compile + run smoke test + inspect output PDF.
set -e
SRC=/mnt/c/docs/DONE/pb-wrapper-libharu/tools/smoke_x86.c
INC=/mnt/c/docs/DONE/pb-wrapper-libharu
LIB=$HOME/build/libharu-2.4.6/build32/src

gcc -m32 "$SRC" -I"$INC" -L"$LIB" -lhpdf -Wl,-rpath,"$LIB" -o /tmp/smoke_x86
/tmp/smoke_x86

PDF=/tmp/m32out.pdf
echo "header: $(head -c 8 "$PDF")"
echo "flate_streams: $(grep -ac FlateDecode "$PDF")"
echo "text_found: $(grep -ac 'Hello from 32-bit' "$PDF")"
echo "image_dims: $(grep -aoE '/(Width|Height) 32' "$PDF" | sort -u | tr '\n' ' ')"
echo "eof_marker: $(tail -c 32 "$PDF" | grep -ac '%%EOF')"
