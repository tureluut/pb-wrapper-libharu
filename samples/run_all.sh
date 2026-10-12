#!/usr/bin/env bash
# run_all.sh - compile + run every sample port, one PASS/FAIL/SKIP line each.
#
# Works on Linux/WSL and on Windows (MSYS2/git-bash). Run it FROM samples/
# (the asset directories are relative to that directory):
#
#     cd samples && ./run_all.sh
#
# Per sample the runner compiles <name>.pb to bin/<name>, executes it with
# cwd = samples/, and checks the exit code + the expected output file.
# Most samples also self-verify and print their own PASS/FAIL line.
#
# Skipped by design (asset-dependent, need user font files, like the C
# originals): chfont_demo, ttfont_demo_jp.
#
# Compiler resolution order:
#   1. $PUREBASIC_HOME/compilers/pbcompilerc[.exe]
#   2. pbcompilerc[.exe] on $PATH
#   3. common install globs (Linux: /opt/purebasic*, ~/purebasic*, ~/Apps/purebasic*)
#      (Windows: %LOCALAPPDATA%\Programs\PureBasic)
#
# Exit code = number of failed samples.

set -u
cd "$(dirname "$0")"

os_name="$(uname -s)"                 # Linux | MINGW64_NT-* | MSYS_NT-* ...
case "$os_name" in
  Linux*)
    COMPILER_SUFFIX=""
    EXE_SUFFIX=""
    FLAGS=(-cl -t)                    # console + threadsafe (GNU-style switches)
    OUTFLAG=(-o)
    ;;
  *)
    COMPILER_SUFFIX=".exe"
    EXE_SUFFIX=".exe"
    FLAGS=(/CONSOLE /THREAD)          # Windows-style switches
    OUTFLAG=(/EXE)
    export MSYS2_ARG_CONV_EXCL='*'     # preserve /CONSOLE etc. in git-bash
    ;;
esac
compiler_name="pbcompilerc$COMPILER_SUFFIX"

# --- locate the compiler -----------------------------------------------------
find_compiler() {
  local cand
  if [ -n "${PUREBASIC_HOME:-}" ] && [ -x "$PUREBASIC_HOME/compilers/$compiler_name" ]; then
    printf '%s' "$PUREBASIC_HOME/compilers/$compiler_name"; return 0
  fi
  cand="$(command -v "$compiler_name" 2>/dev/null)" && [ -n "$cand" ] && { printf '%s' "$cand"; return 0; }
  for cand in /opt/purebasic*/compilers/$compiler_name \
              "$HOME"/purebasic*/compilers/$compiler_name \
              "$HOME"/Apps/purebasic*/compilers/$compiler_name; do
    [ -x "$cand" ] && { printf '%s' "$cand"; return 0; }
  done
  if [ "$COMPILER_SUFFIX" != "" ] && [ -n "${LOCALAPPDATA:-}" ]; then
    cand="$LOCALAPPDATA/Programs/PureBasic/Compilers/$compiler_name"
    [ -x "$cand" ] && { printf '%s' "$cand"; return 0; }
  fi
  return 1
}

PBC="$(find_compiler)" || { echo "ERROR: $compiler_name not found (set PUREBASIC_HOME or add to PATH)" >&2; exit 255; }
case "$os_name" in
  Linux*) export PUREBASIC_HOME="$(cd "$(dirname "$PBC")/.." && pwd)" ;;
esac
echo "Compiler : $PBC"
echo "Flags    : ${FLAGS[*]}"
echo ""

mkdir -p bin

# --- sample table: name|expected-output|args ---------------------------------
SAMPLES="
arc_demo|arc_demo.pdf|
attach|attach.pdf|
character_map|character_map.pdf|90ms-RKSJ-H MS-Mincho
chfont_demo|chfont_demo.pdf|
encoding_list|encoding_list.pdf|
encryption|encryption.pdf|
ext_gstate_demo|ext_gstate_demo.pdf|
font_demo|font_demo.pdf|
hpdf_module_smoke|hpdf_module_smoke.pdf|
hpdf_smoke|hpdf_smoke.pdf|
image_demo|image_demo.pdf|
jpeg_demo|jpeg_demo.pdf|
jpfont_demo|jpfont_demo.pdf|
line_demo|line_demo.pdf|
link_annotation|link_annotation.pdf|
make_rawimage|bin/make_rawimage_out.dat|pngsuite/basn3p08.png bin/make_rawimage_out.dat
outline_demo|outline_demo.pdf|
outline_demo_jp|outline_demo_jp.pdf|
pdf_a_conformance|pdf_a_conformance.pdf|
permission|permission.pdf|
png_demo|png_demo.pdf|
probe_noembed|probe_noembed.pdf|
raw_image_demo|raw_image_demo.pdf|
slide_show_demo|slide_show_demo.pdf|
text_annotation|text_annotation.pdf|
text_demo|text_demo.pdf|
text_demo2|text_demo2.pdf|
ttfont_demo|ttfont_demo.pdf|ttfont/PenguinAttack.ttf -E
ttfont_demo_jp|ttfont_demo_jp.pdf|
"

SKIP="chfont_demo ttfont_demo_jp"

# grid_sheet.pbi is a shared include - covered by every sample that uses it.

pass=0; fail=0; skipped=0
while IFS='|' read -r name outfile args; do
  [ -z "$name" ] && continue
  # Some PB Linux compiler failures return zero. Remove old executables and
  # require a fresh one, otherwise a stale binary can produce a false PASS.
  rm -f "bin/$name$EXE_SUFFIX"
  if ! "$PBC" "${FLAGS[@]}" "${OUTFLAG[@]}" "bin/$name$EXE_SUFFIX" "$name.pb" > "bin/${name}.compile.log" 2>&1 ||
     [ ! -s "bin/$name$EXE_SUFFIX" ]; then
    echo "FAIL  $name (compile)   -- see bin/${name}.compile.log"
    tail -3 "bin/${name}.compile.log" | sed 's/^/      /'
    fail=$((fail+1)); continue
  fi

  case " $SKIP " in
    *" $name "*) echo "SKIP  $name (compiled; needs user font files)"; skipped=$((skipped+1)); continue ;;
  esac
  if [ -f "$outfile" ]; then rm -f "$outfile"; fi

  # shellcheck disable=SC2086  # args is meant to word-split
  run_out="$(./"bin/$name$EXE_SUFFIX" $args 2>&1)"
  run_rc=$?
  printf '%s\n' "$run_out" > "bin/${name}.run.log"

  if [ $run_rc -ne 0 ]; then
    echo "FAIL  $name (exit $run_rc)"
    printf '%s\n' "$run_out" | tail -3 | sed 's/^/      /'
    fail=$((fail+1)); continue
  fi
  if [ -n "$outfile" ] && [ ! -s "$outfile" ]; then
    echo "FAIL  $name (output '$outfile' missing/empty)"
    printf '%s\n' "$run_out" | tail -3 | sed 's/^/      /'
    fail=$((fail+1)); continue
  fi
  echo "PASS  $name -> $outfile"
  pass=$((pass+1))
done <<< "$SAMPLES"

echo ""
echo "Result: $pass PASS, $fail FAIL, $skipped SKIP"
exit $fail
