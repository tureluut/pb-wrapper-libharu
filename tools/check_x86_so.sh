#!/usr/bin/env bash
# Verify the 32-bit libhpdf.so build (run inside WSL)
set -e
NEW=~/build/libharu-2.4.6/build32/src/libhpdf.so.2.4.6
REF=/mnt/c/docs/DONE/pb-wrapper-libharu/libraries/linux/x64/libhpdf.so.2.4.6

echo "== file =="
file "$NEW"

echo "== NEEDED/SONAME =="
readelf -d "$NEW" | grep -E 'NEEDED|SONAME'

echo "== exported HPDF_ T-symbol counts (new vs x64 ref) =="
nm -D --defined-only "$NEW" | grep -c ' T HPDF_'
nm -D --defined-only "$REF" | grep -c ' T HPDF_'

echo "== exported T symbols NOT starting with HPDF_ =="
nm -D --defined-only "$NEW" | awk '$2 == "T" && $3 !~ /^HPDF_/ {print $3}'

echo "== zlib/png symbols must NOT be exported =="
nm -D --defined-only "$NEW" | grep -cE ' T (inflate|deflate|png_)' || echo "none (good)"

echo "== symbol-set diff (T symbols, x86 vs x64) =="
diff <(nm -D --defined-only "$NEW" | awk '$2=="T"{print $3}' | sort) \
     <(nm -D --defined-only "$REF" | awk '$2=="T"{print $3}' | sort) && echo "identical"
