# WSL-VERIFICATION.md — Linux verification of the libharu wrapper

Verification record for the Linux side of this wrapper: environment,
results, the SysV ABI fixes in `hpdf.pbi`/`hpdf_module.pbi`, and the scope
of what was (and was not) verified. Recreated from the tooling in `tools/`
and a fresh re-run of every check described below.

## Environment

| Component  | Version / path                                             |
| ---------- | ---------------------------------------------------------- |
| OS         | WSL2, Ubuntu 26.04.1 LTS (x86_64), kernel 6.18 microsoft-standard-WSL2 |
| Compiler   | PureBasic 6.41 Linux C backend (`pbcompilerc`), `~/Apps/purebasic-v641` |
| C toolchain| gcc 15.2.0 (Ubuntu 15.2.0-16ubuntu1)                       |
| libharu src| 2.4.6, CMake build tree `~/build/libharu-2.4.6` (`build32/` for the 32-bit build) |
| Checkout   | `/mnt/c/docs/DONE/pb-wrapper-libharu`                      |

## Linux x64 — sample suite

Verified result: **27 PASS, 0 FAIL, 2 SKIP** (re-confirmed with a fresh
run; same numbers as the original session).

- All 29 sample programs **compile** with the C backend
  (`pbcompilerc -cl -t`, gcc behind it).
- 27 execute with exit code 0 and produce their expected output; the
  per-sample PDF properties listed in the README (grep-level checks:
  stream counts, MediaBox, filters, annotations, outline counts, …) were
  verified against those outputs.
- 2 skip execution by design (asset-dependent, like their C originals):
  `chfont_demo`, `ttfont_demo_jp`.
- `hpdf_smoke` deliberately uses the bundled TTF + PNG on Linux — no
  system fonts, no GTK image-library dependency in console builds, no
  display required.

Run it with:

```bash
cd samples && ./run_all.sh          # needs PUREBASIC_HOME or a known install path
```

## SysV ABI fixes (Linux x64)

libharu 2.4.6 takes `HPDF_Rect`/`HPDF_Date` **by value** in six bound
exports:

- `HPDF_Page_CreateLinkAnnot`
- `HPDF_Page_CreateURILinkAnnot`
- `HPDF_Page_CreateTextAnnot`
- `HPDF_EmbeddedFile_SetCreationDate`
- `HPDF_EmbeddedFile_SetLastModificationDate`
- `HPDF_SetInfoDateAttr`

PureBasic cannot express struct-by-value parameters. On **Win64** struct
args travel by hidden pointer, so plain pointer prototypes happen to be
ABI-correct by accident. On **SysV x86-64** that breaks:

- `HPDF_Rect` (16 B, two all-float eightbytes) is classified into
  **XMM0 + XMM1**, and every following argument shifts one GP register
  down. A pointer prototype hands libharu the rect *pointer* where it
  reads the uri/text string — the first rect bytes terminate the "string"
  immediately (observed as `HPDF_INVALID_URI`).
- `HPDF_Date` (36 B) travels **in memory** in this build (verified with
  `objdump`: both date setters read the struct from the stack slots right
  after the return address; `SetCreationDate` tail-jumps into
  `Info_SetInfoDateAttr` keeping that layout). A pointer prototype makes
  libharu read the pointer *value* as "year".

**Fix** (in `hpdf.pbi`, mirrored by generation into `hpdf_module.pbi`):
on `#PB_OS_Linux` the six public names are not bound to `GetFunction`
directly — `HaruInit()` points them at `HaruShim_*` procedures with the
same pointer signature as on Windows (sample code stays OS-agnostic).
The shims repack the struct bytes:

- `HPDF_Rect` → two 8-byte chunks passed as `.d` args → land in XMM0/XMM1.
- `HPDF_Date` → dead `.l` args eat the remaining GP register slots, then
  five 8-byte `.q` chunks land on the stack at offsets 0/8/16/24/32 —
  exactly where libharu reads its spilled by-value struct.

Layout calibrated against the shipped `libhpdf.so` with `objdump` and
against gcc 15.2 / Ubuntu 26.04 behavior (by-value aggregates of this
size are passed in memory on this platform). `HPDF_Point`
(`HPDF_LineAnnot_SetPosition`) is not bound by this wrapper; if it ever
is, pack its 8 bytes into one `.d` arg.

**These shims are x64-specific.** The wrapper is not verified with a
32-bit PB compiler on Linux (see below).

## Linux x86 — 32-bit `libhpdf.so` (C-ABI level)

Built libharu 2.4.6 as a self-contained 32-bit shared object (CMake,
`build32/`); the result ships in `libraries/linux/x86/`
(`libhpdf.so[.2.4][.2.4.6]`). Verified at **C-ABI level only** — see
limits below.

### Symbol-level checks — `tools/check_x86_so.sh`

```
file      : ELF 32-bit LSB shared object, Intel i386, dynamically linked, not stripped
NEEDED    : libm.so.6, libc.so.6        (nothing else — zlib/libpng are baked in)
SONAME    : libhpdf.so.2.4
HPDF_ T-symbols : 636 (x86)  vs  636 (x64 reference)
non-HPDF_ exports: ConvertDateToXMDate, ExtGState_Check, GetElement
            (present in the x64 reference too — upstream never hid them)
zlib/png exports : 0  (inflate/deflate/png_* statically linked with hidden symbols)
T-symbol set diff vs x64 reference: identical
```

### Runtime smoke test — `tools/verify_x86_all.sh`

Compiles `tools/smoke_x86.c` with `gcc -m32` against the 32-bit library,
runs it, and greps the output PDF:

```
header      : %PDF-1.3
flate_streams: 1        (image stream, HPDF_COMP_IMAGE)
text_found  : 1         ("Hello from 32-bit", embedded PenguinAttack TTF)
image_dims  : /Width 32 /Height 32   (pngsuite/basn3p08.png)
eof_marker  : 1         (%%EOF)
```

The 32-bit library is self-contained at runtime: only glibc is required
(no libpng/zlib packages).

### Reproducing

```bash
# inside WSL, from the checkout:
bash tools/check_x86_so.sh      # symbol-level ABI audit
bash tools/verify_x86_all.sh    # compile + run + inspect smoke PDF
```

Both scripts expect the build tree at `~/build/libharu-2.4.6/build32/`
and the checkout at `/mnt/c/docs/DONE/pb-wrapper-libharu`.

## Not verified / limits

- **32-bit PureBasic on Linux is not verified.** The `HaruShim_*` block
  hardcodes the x86-64 SysV register/stack layout; the wrapper cannot
  load the x86 `.so` until equivalent i386 shims (different calling
  convention — everything on the stack) are written and tested.
- `chfont_demo` and `ttfont_demo_jp` are compile-verified only (they need
  user font files, like their C originals).
- Verified only on this WSL2/Ubuntu 26.04 + gcc 15.2 setup; other distros,
  non-WSL Linux, and musl-based systems are untested. The `HPDF_Date`
  in-memory layout in particular is a *platform* classification result,
  not a SysV-spec guarantee for every compiler.
