; ---------------------------------------------------------------------------
; raw_image_demo.pb - PureBasic port of libharu's raw_image_demo.c
; (<< Haru Free PDF Library 2.0.0 >>, Copyright (c) 1999-2006 Takeshi Kanno,
; ZLIB license - see ../THIRD-PARTY-NOTICES.md).
; Draws three 32x32 images on a 172x80 page: a raw RGB file
; (rawimage/32_32_rgb.dat), a raw grayscale file (rawimage/32_32_gray.dat)
; and the C's 128-byte 1-bit grayscale blob loaded from memory.
;
; Deviations from the C original (wrapper subset, see ../hpdf.pbi):
;  - no setjmp/longjmp error handler: libharu latches the first error, so the
;    drawing is gated by one HPDF_GetError check before the save;
;  - the C's HPDF_GetFont(pdf, "Helvetica", NULL) (NULL = font default
;    encoding) becomes HaruGetFont(pdf, "Helvetica", "") - a real C NULL
;    through the raw binding; all text is ASCII;
;  - path separator '/' instead of the C's "\\" (libharu's fopen-equivalent
;    accepts forward slashes on Windows);
;  - argv[0] + ".pdf" output replaced with the stable filename
;    raw_image_demo.pdf. (The C's "RawImageDemo" title is drawn at x=220 on
;    a 172-wide page - outside the MediaBox, exactly as in the C original.)
;
; Build (from samples/):
;   MSYS2_ARG_CONV_EXCL='*' "$PUREBASIC_HOME/Compilers/pbcompilerc.exe" \
;     /CONSOLE /THREAD /EXE raw_image_demo.exe raw_image_demo.pb
; ---------------------------------------------------------------------------

EnableExplicit

XIncludeFile "../hpdf.pbi"

OpenConsole()

; --- init (OS-branched, same pattern as the other samples) -------------------
CompilerIf #PB_Compiler_OS = #PB_OS_Linux
  If HaruInit() = 0
    If HaruInit("../libraries/linux/x64/") = 0
      PrintN("FAIL init (libhpdf.so not loadable)")
      End 1
    EndIf
  EndIf
CompilerElse
  If HaruInit("../libraries/windows/x64/") = 0
    PrintN("FAIL init (hpdf.dll + zlib.dll + libpng16.dll not loadable from ../libraries/windows/x64/)")
    End 1
  EndIf
CompilerEndIf
PrintN("libharu " + PeekS(HPDF_GetVersion(), -1, #PB_Ascii))

Define pdf.i = HaruNew()
If pdf = 0
  PrintN("FAIL doc (HaruNew returned 0)")
  End 1
EndIf

HPDF_SetCompressionMode(pdf, #HPDF_COMP_ALL)

; create default-font
Define font.i = HaruGetFont(pdf, "Helvetica", "")
If font = 0
  PrintN("FAIL font (GetFont Helvetica) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

; add a new page object.
Define page.i = HPDF_AddPage(pdf)
If page = 0
  PrintN("FAIL page " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

HPDF_Page_SetWidth(page, 172)
HPDF_Page_SetHeight(page, 80)

HPDF_Page_BeginText(page)
HPDF_Page_SetFontAndSize(page, font, 20)
HPDF_Page_MoveTextPos(page, 220, HPDF_Page_GetHeight(page) - 70)
HPDF_Page_ShowText(page, "RawImageDemo")
HPDF_Page_EndText(page)

Define x.f
Define y.f

; load RGB raw-image file.
Define image.i = HPDF_LoadRawImageFromFile(pdf, "rawimage/32_32_rgb.dat", 32, 32, #HPDF_CS_DEVICE_RGB)
If image = 0
  PrintN("FAIL image load (rgb) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

x = 20
y = 20

; Draw image to the canvas. (normal-mode with actual size.)
HPDF_Page_DrawImage(page, image, x, y, 32, 32)

; load GrayScale raw-image file.
image = HPDF_LoadRawImageFromFile(pdf, "rawimage/32_32_gray.dat", 32, 32, #HPDF_CS_DEVICE_GRAY)
If image = 0
  PrintN("FAIL image load (gray) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

x = 70
y = 20

; Draw image to the canvas. (normal-mode with actual size.)
HPDF_Page_DrawImage(page, image, x, y, 32, 32)

; load GrayScale raw-image (1bit) file from memory.
image = HPDF_LoadRawImageFromMem(pdf, ?RawImageData, 32, 32, #HPDF_CS_DEVICE_GRAY, 1)
If image = 0
  PrintN("FAIL image load (mem) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

x = 120
y = 20

; Draw image to the canvas. (normal-mode with actual size.)
HPDF_Page_DrawImage(page, image, x, y, 32, 32)

; --- gate + save ---------------------------------------------------------------
If HPDF_GetError(pdf) <> #HPDF_OK
  PrintN("FAIL draw (latched error) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

If HPDF_SaveToFile(pdf, "raw_image_demo.pdf") <> #HPDF_OK
  PrintN("FAIL save " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
HaruFree(pdf)
PrintN("PASS raw_image_demo -> raw_image_demo.pdf")

HaruShutdown()
CloseConsole()
End 0

; raw_image_demo.c RAW_IMAGE_DATA[128]: 32x32 1-bit grayscale blob.
DataSection
  RawImageData:
    Data.a $ff, $ff, $ff, $fe, $ff, $ff, $ff, $fc
    Data.a $ff, $ff, $ff, $f8, $ff, $ff, $ff, $f0
    Data.a $f3, $f3, $ff, $e0, $f3, $f3, $ff, $c0
    Data.a $f3, $f3, $ff, $80, $f3, $33, $ff, $00
    Data.a $f3, $33, $fe, $00, $f3, $33, $fc, $00
    Data.a $f8, $07, $f8, $00, $f8, $07, $f0, $00
    Data.a $fc, $cf, $e0, $00, $fc, $cf, $c0, $00
    Data.a $ff, $ff, $80, $00, $ff, $ff, $00, $00
    Data.a $ff, $fe, $00, $00, $ff, $fc, $00, $00
    Data.a $ff, $f8, $0f, $e0, $ff, $f0, $0f, $e0
    Data.a $ff, $e0, $0c, $30, $ff, $c0, $0c, $30
    Data.a $ff, $80, $0f, $e0, $ff, $00, $0f, $e0
    Data.a $fe, $00, $0c, $30, $fc, $00, $0c, $30
    Data.a $f8, $00, $0f, $e0, $f0, $00, $0f, $e0
    Data.a $e0, $00, $00, $00, $c0, $00, $00, $00
    Data.a $80, $00, $00, $00, $00, $00, $00, $00
EndDataSection

; IDE Options = PureBasic 6.40 (Windows - x64)
; ExecutableFormat = Console
; EnableXP
; DPIAware
