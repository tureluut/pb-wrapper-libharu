# hpdf.pbi — PureBasic wrapper for libharu (hpdf.dll 2.4.6)

PureBasic wrapper around the [libharu](https://github.com/libharu/libharu)
2.4.6 PDF generation library. The DLL is bound at runtime through
`OpenLibrary()` + `GetFunction()` + Prototypes — **no import library is
needed**.

- **Author:** Duk — [www.tureluut.be](https://www.tureluut.be)
- **License:** free to use. The shipped DLLs carry their own licenses, see
  [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) (libharu, zlib, libpng —
  all permit free commercial use and redistribution).
- **Requirements:** PureBasic **6.40 or higher**.
- **Current setup:** Windows 64-bit. The wrapper itself is architecture- and
  OS-agnostic (runtime binding), but only the x64 Windows DLLs are exercised
  by the current test setup.

## Files

| Path                       | Role                                                                                                                                 |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `hpdf.pbi`                 | The wrapper: constants, `HPDFPoint`/`HPDFRect`/`HPDFDate` structs (C-aligned), **169 prototypes** + fn-pointer globals, `HaruInit()`/`HaruShutdown()`, `Haru*` + raw-byte helpers — see the header comments, they are the authority |
| `hpdf_module.pbi`          | Standalone `HPDF::` module alternative with the same 169 function pointers and all helpers; library handles, binding macro and caches are private |
| `tools/generate_hpdf_module.cjs` | Regenerates the module from `hpdf.pbi`; `--check` verifies it is in sync (Node.js required only for regeneration) |
| `samples/hpdf_module_smoke.pb` | Namespaced module smoke test using bundled assets; writes `hpdf_module_smoke.pdf` |
| `libraries/windows/x64/`   | `hpdf.dll` + `zlib.dll` + `libpng16.dll`, 64-bit — the current, tested setup                                                         |
| `libraries/windows/x86/`   | The same DLL set, 32-bit builds (provided for x86 targets; not covered by the current test setup)                                    |
| `samples/grid_sheet.pbi`   | Shared include ported from `grid_sheet.c` (reference grid) — used by the samples that link the C file                               |
| `samples/run_all.sh`       | Runner: compiles + runs every port from `samples/`, per-sample PASS/FAIL (exit code + output file exists); skips the two asset-dependent samples |
| `PORTING_PLAN.md`          | Port plan: inventory, phases, conventions, risk register                                                                             |
| `THIRD-PARTY-NOTICES.md`   | License texts of the shipped DLLs and the sample sources                                                                             |
| `samples/*.pb`             | The sample programs — legacy samples and the C ports, see **Sample ports** below                                                     |

## Sample ports

All 24 C files in `samples/` are ported to PureBasic 6.40: the 23 sample
programs plus the shared `grid_sheet.c` helper (`samples/grid_sheet.pbi`).
Each port is a standalone console program with a header comment naming its C
source, license and numbered deviations. Build + run everything with:

```bash
cd samples && ./run_all.sh
```

or per sample (MSYS2/git-bash, from `samples/` — the assets are relative to
that directory):

```bash
PBC="$PUREBASIC_HOME/Compilers/pbcompilerc.exe"   # default: C:/Users/<you>/AppData/Local/Programs/PureBasic
MSYS2_ARG_CONV_EXCL='*' "$PBC" /CONSOLE /THREAD /EXE arc_demo.exe arc_demo.pb
./arc_demo.exe
```

Two samples are **asset-dependent** (like their C originals) and are skipped
by the runner: `chfont_demo` (two user TTC files) and `ttfont_demo_jp` (a
user TTF/TTC).

### C ports (23)

| Port | C source | Prerequisites / CLI args | Output | Verified PDF properties (grep-level) |
|---|---|---|---|---|
| `arc_demo.pb` | `arc_demo.c` | — | `arc_demo.pdf` | runs clean, arcs/circles/fills over a reference grid |
| `font_demo.pb` | `font_demo.c` | — | `font_demo.pdf` | base-14 font demo lines |
| `ext_gstate_demo.pb` | `ext_gstate_demo.c` | — | `ext_gstate_demo.pdf` | 14 ExtGStates (alpha + all blend modes, incl. libharu's "EXCLUSHON" spelling) |
| `jpeg_demo.pb` | `jpeg_demo.c` | `images/*.jpg` | `jpeg_demo.pdf` | 2× `/DCTDecode`, MediaBox `[0 0 650 500]`, `/OpenAction /XYZ` |
| `png_demo.pb` | `png_demo.c` | `pngsuite/*.png` | `png_demo.pdf` | 14 PNG + 4 SMask = 18 `/Subtype /Image`, `[0 0 550 650]` |
| `image_demo.pb` | `image_demo.c` | `pngsuite/*.png` | `image_demo.pdf` | 2× `/Mask` (stencil + color-key array), 4 image XObjects |
| `raw_image_demo.pb` | `raw_image_demo.c` | — (128-byte DataSection) | `raw_image_demo.pdf` | `[0 0 172 80]`, DeviceRGB + 2× DeviceGray, BitsPerComponent 1 |
| `make_rawimage.pb` | `make_rawimage.c` | CLI: `<png> <out.raw>` | libharu raw image file (not a PDF) | emits width/height/bits/color-space (Indexed for basn3p08) + 1024-byte pixel dump |
| `slide_show_demo.pb` | `slide_show_demo.c` | `images/*.jpg` | `slide_show_demo.pdf` | 17 pages `[0 0 800 600]`, `/Trans` per page, 32 `/Link` + `/Fit` dests, `/PageMode /FullScreen`; slide order differs from C (rand() — documented) |
| `outline_demo.pb` | `outline_demo.c` | — | `outline_demo.pdf` | `/Outlines`, `/PageMode /UseOutlines`, 3 `/XYZ` dests, ISO8859-2 title bytes |
| `link_annotation.pb` | `link_annotation.c` | — | `link_annotation.pdf` | 8 `/Link` (7 `/Dest` + 1 `/URI libharu.org`), `/H /N /O /P` (`/H /I` absent = PDF default, same as C) |
| `text_annotation.pb` | `text_annotation.c` | — | `text_annotation.pdf` | 8 `/Text` with icon `/Name`s, 1× `/Open true`, ISO8859-2 contents |
| `ttfont_demo.pb` | `ttfont_demo.c` | `ttfont/PenguinAttack.ttf`; args: `ttfont/PenguinAttack.ttf -E` | `ttfont_demo.pdf` | `/FontFile2` (embedded), BaseFont `/HPDFAA+PenguinAttack`, `[0 0 604.69 210]`; usage path exits 1 |
| `encoding_list.pb` | `encoding_list.c` | `type1/*.afm+*.pfb` | `encoding_list.pdf` | 21 pages, outline root `/Count 22`, `/FontFile` (Type1 URWGothicL-Book), grid chars via raw 2-byte buffers |
| `character_map.pb` | `character_map.c` | `type1/*`; args: `<encoding> <font-name>` (e.g. `90ms-RKSJ-H MS-Mincho`) | `character_map.pdf` | prints byte-range stats, 45 pages `[0 0 420 340]`, `/Count 10`, MS-Mincho Type0 |
| `chfont_demo.pb` | `chfont_demo.c` | **SKIPPED** — two user TTC files + indices (cp936/cp932), `mbtext/cp936.txt`+`cp932.txt` | `chfont_demo.pdf` | compiles; usage path exits 1; lines read as raw bytes (GBK/SJIS) |
| `jpfont_demo.pb` | `jpfont_demo.c` | `mbtext/sjis.txt` | `jpfont_demo.pdf` | 16 `/Subtype /Type0` (8× `/90ms-RKSJ-H` + 8× `/90msp-RKSJ-H`), outlines Count 16/17; SJIS line as raw bytes |
| `outline_demo_jp.pb` | `outline_demo_jp.c` | `mbtext/sjis.txt` | `outline_demo_jp.pdf` | 3 pages, `/UseOutlines`; SJIS outline title byte-exact (raw-byte file reader; verified `/Title` decodes to the CJK text) |
| `ttfont_demo_jp.pb` | `ttfont_demo_jp.c` | **SKIPPED** — user TTF/TTC; args like `ttfont_demo_jp <file> [-E \| <index>]` | `ttfont_demo_jp.pdf` | compiles; usage path exits 1; SJIS sample line as raw bytes |
| `attach.pb` | `attach.c` | `pngsuite/basn3p08.png` | `attach.pdf` | `/EmbeddedFiles` + `/EmbeddedFile`, LETTER `[0 0 612 792]` |
| `encryption.pb` | `encryption.c` | — | `encryption.pdf` | `/Encrypt`, `/Filter /Standard`, `/V 1 /R 2` (40-bit RC4, passwords owner/user) |
| `permission.pb` | `permission.c` | — | `permission.pdf` | `/Encrypt`, `/V 2 /R 3 /Length 128 /P 0` (read-only, empty user password) |
| `pdf_a_conformance.pb` | `pdf_a_conformance.c` | `ttfont/PenguinAttack.ttf`, `pdf_a/factur-x.xml`, `pdf_a/device_rgb.icc` | `pdf_a_conformance.pdf` | `/Metadata` (XMP incl. Factur-X extension schemas), `/OutputIntents` sRGB + `/GTS_PDFA1`, `/EmbeddedFile` + `/AFRelationship /Data`, `/FontFile2`; keeps the upstream quirk (EF CreationDate = modification date) |

### Shared include

| Port | C source | Role |
|---|---|---|
| `grid_sheet.pbi` | `grid_sheet.c` | Reference-grid drawing shared by the samples whose C build links `grid_sheet.c`; also included for parity where the C only includes the header but never calls it (`ext_gstate_demo`, `encryption`, `permission` — commented in each port) |

### Legacy samples (regression)

Kept from earlier sessions; no same-named C source exists in this checkout.
All compile against the extended wrapper and produce their PDF:

| Sample | Output | Notes |
|---|---|---|
| `hpdf_smoke.pb` | `hpdf_smoke.pdf` | UTF-8 + embedded TTF, RGB fill, dash, alpha, rotation, image |
| `line_demo.pb` | `line_demo.pdf` | line styles/caps/joins |
| `text_demo.pb` | `text_demo.pdf` | sizes, Tr modes, Tm, Tc/Tw (+ grid) |
| `text_demo2.pb` | `text_demo2.pdf` | TextRect alignment, transformed coords, text on a circle (+ grid) |
| `probe_noembed.pb` | `probe_noembed.pdf` | base-14 (non-embedded) fonts / WinAnsi raw-byte path |

## Usage

```purebasic
XIncludeFile "hpdf.pbi"    ; adjust path to your project

Procedure Main()
  ; HaruInit() ONCE, before ANY HPDF_* / Haru* call:
  ;   no argument   -> DLLs must sit beside the exe (OpenLibrary searches
  ;                    the exe directory first)
  ;   dir$ argument -> DLLs are loaded from that directory (must end with
  ;                    "/" or "\", e.g. "libraries/windows/x64/")
  If HaruInit("libraries/windows/x64/") = 0
    Debug "hpdf init failed: " + HaruMissing$   ; "" = DLL not found
    End 1
  EndIf

  Protected pdf.i  = HaruNew()                  ; UTF-8 pipeline enabled
  Protected page.i = HaruAddPage(pdf)           ; A4 portrait
  Protected font.i = HaruTTFFont(pdf, "C:/Windows/Fonts/arial.ttf")  ; embedded

  HPDF_Page_SetFontAndSize(page, font, 24)
  HaruTextOut(page, 72, 750, "Invoice £ 4797,65 — café")  ; UTF-8 in

  HPDF_SaveToFile(pdf, "out.pdf")
  HaruFree(pdf)
  HaruShutdown()                                ; at exit
EndProcedure
```

Usage contract:

- **`HaruInit()` before every other call.** Every `HPDF_*` name in the
  include is a global function _pointer_; calling before init dereferences
  null. Pair with `HaruShutdown()`.
- Helpers expect a doc from `HaruNew()` (UTF-8 encoder already set).
- `HaruErrorText(pdf)` returns `"err <hex>/<hex>"` for FAIL diagnostics
  (libharu errors **latch** until `HPDF_ResetError`).
- Runtime DLLs: `hpdf.dll` + `zlib.dll` + `libpng16.dll` (the latter two are
  `hpdf.dll` dependencies — the OS loads them for hpdf, not for your code).
  Keep them beside the exe or pass their directory to `HaruInit(dir$)`; if
  they cannot be loaded, `HaruInit()` returns 0 cleanly (no crash).

## Module alternative

Use `hpdf_module.pbi` instead of `hpdf.pbi` to keep the API inside the
`HPDF` namespace. It is standalone: no other include or import library is
required. All original names, types, signatures and runtime behavior are
preserved; this is namespace isolation, not a new high-level API.

```purebasic
EnableExplicit
XIncludeFile "hpdf_module.pbi"

If HPDF::HaruInit("libraries/windows/x64/") = 0
  Debug "hpdf init failed: " + HPDF::HaruMissing$
  End 1
EndIf

Define pdf.i = HPDF::HaruNew()
If pdf
  Define page.i = HPDF::HaruAddPage(pdf)
  Define font.i = HPDF::HaruTTFFont(pdf, "C:/Windows/Fonts/arial.ttf")
  If page And font
    HPDF::HPDF_Page_SetFontAndSize(page, font, 24)
    HPDF::HaruTextOut(page, 72, 750, "Hello from the HPDF module")
    If HPDF::HPDF_SaveToFile(pdf, "out.pdf") <> HPDF::#HPDF_OK
      Debug HPDF::HaruErrorText(pdf)
    EndIf
  EndIf
  HPDF::HaruFree(pdf)
EndIf
HPDF::HaruShutdown()
```

- Constants: `HPDF::#HPDF_PAGE_SIZE_A4`, `HPDF::#HPDF_OK`, etc.
- Structures: `Define rect.HPDF::HPDFRect` (also `HPDFPoint`, `HPDFDate`).
- Diagnostics: `HPDF::HaruBound` and `HPDF::HaruMissing$`.
- Library/dependency handles, `HaruBind` and per-document caches are private.
- For a minimal migration, change the include and add `UseModule HPDF`;
  existing unqualified API calls can then remain unchanged.
- Both wrappers may coexist when names are qualified. Each has independent
  loader/cache state; initialize, use and shut down each separately, and
  keep a document's lifecycle within the wrapper that created it. Avoid
  `UseModule HPDF` when also including the flat wrapper.
- The same lifecycle restrictions apply: initialize once successfully before
  calling function pointers, free documents with `HaruFree`, then shut down.
  Function pointers must not be called before init or after shutdown.

Compile/run `samples/hpdf_module_smoke.pb` from `samples/` to exercise the
module with the bundled TTF, raw WinAnsi text, public structure layouts,
annotation/metadata calls and per-document caches.

The module is generated from the flat wrapper so ABI fixes can be kept in
sync without maintaining two handwritten copies:

```bash
node tools/generate_hpdf_module.cjs
node tools/generate_hpdf_module.cjs --check
```

After modifying `hpdf.pbi`, regenerate and compile/test the module. Node.js
is **not** needed to compile or distribute the PureBasic module.

## Helper API (thin layer over the raw `HPDF_*` pointers)

| Helper                                            | Notes                                                                                                                                                                                                             |
| ------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `HaruNew()`                                       | doc with `HPDF_UseUTFEncodings` + encoder "UTF-8"; 0 on fail                                                                                                                                                      |
| `HaruFree(pdf)`                                   | frees doc + purges per-doc caches                                                                                                                                                                                 |
| `HaruErrorText(pdf)`                              | `"err <error-hex>/<detail-hex>"`                                                                                                                                                                                  |
| `HaruTTFFont(pdf, path$)`                         | loads + embeds TTF, caches per doc+path; `HPDF_LoadTTFontFromFile2` is **TTC-only** in 2.4.6 (plain TTF retry handled internally); never pre-probe font paths with PB `ReadFile` (fails under `C:\Windows\Fonts`) |
| `HaruAddPage(pdf)`                                | A4 portrait                                                                                                                                                                                                       |
| `HaruPngFromFile(pdf, path$)`                     | `HPDF_LoadPngImageFromFile2` (PNG is read at `HPDF_SaveToFile` time — keep the file around until the save)                                                                                                        |
| `HaruAlpha(pdf, a.f)`                             | cached ExtGState with fill+stroke alpha                                                                                                                                                                           |
| `HaruTextOut(page, x, y, s$)`                     | brackets `BeginText`/`EndText` itself — raw `HPDF_Page_TextOut` demands TEXT_OBJECT gmode                                                                                                                         |
| `HaruWinAnsiMem(s$)`                              | PB string → NUL-terminated WinAnsi/CP1252 byte buffer (`AllocateMemory`, caller frees); locale-independent                                                                                                        |
| `HaruTextOutRaw(page, x, y, *bytes)`              | as `HaruTextOut` but takes pre-encoded WinAnsi bytes — for **base-14 (non-embedded) fonts** (single-byte fonts do no conversion; raw byte pass-through)                                                           |
| `HPDF_Page_TextOutRaw` / `HPDF_Page_TextWidthRaw` | same DLL exports as `TextOut`/`TextWidth`, bound with raw `char*` instead of `p-utf8` — pair with `HaruWinAnsiMem`                                                                                                |

## Type-mapping rules (for every new declaration)

Source of truth: `hpdf.h` of libharu 2.4.6. Keep prototypes 1:1 with the
header:

| C type                                                               | PB type                           | Note                                                                                                        |
| -------------------------------------------------------------------- | --------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `HPDF_REAL` (float)                                                  | `.f`                              | never `.d`                                                                                                  |
| `HPDF_BOOL`/`HPDF_STATUS`/`HPDF_UINT`/`HPDF_INT`/`HPDF_UINT32`/enums | `.l`                              | 4-byte C int; declare an explicit `.l` **return** on int-returning functions                                |
| `HPDF_UINT16`                                                        | `.w`                              |                                                                                                             |
| `HPDF_*HANDLE` family                                                | `.i`                              | opaque pointers                                                                                             |
| `const char *` in                                                    | `.p-ascii`                        | pointer valid for call duration only — never store                                                          |
| display-text params                                                  | `.p-utf8`                         | `TextOut`, `ShowText`, `ShowTextNextLine`, `TextWidth`, `MeasureText`, `TextRect` (UTF-8 encoder docs only) |
| `char *` return                                                      | `.i` + `PeekS(*p, -1, #PB_Ascii)` | pseudotypes are **params-only** on prototypes                                                               |
| struct-by-value returns                                              | **banned**                        | use the `…2` out-param variants (`HPDF_Image_GetSize2`, `HPDF_Page_GetCurrentPos2`, …)                      |

## Distribution

Ship next to your exe: the DLL set for your architecture from
`libraries/windows/` (`x64` or `x86`) plus `THIRD-PARTY-NOTICES.md`. The
licenses permit commercial redistribution. The wrapper (`hpdf.pbi`) and the
samples are build-time artifacts and do not need to ship with an end-user
install.
