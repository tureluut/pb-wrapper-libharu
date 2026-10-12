; ----------------------------------------------------------------------------
; hpdf_smoke.pb - full-feature smoke test for the libharu ImportC wrapper
; ----------------------------------------------------------------------------
; Exercises the full render surface that motivated libharu: embedded TTF with
; UTF-8 text, RGB fill, custom dash, alpha watermark (ExtGState), rotated
; text (transform matrix), PNG image (bundled on Linux, runtime-generated
; with the PB Image library on Windows).
;
; ----------------------------------------------------------------------------

EnableExplicit

XIncludeFile "../hpdf.pbi"

OpenConsole()

; --- block: init (OpenLibrary + bind all exports) ---------------------------
; Library dir is OS-specific: Windows = DLL set in libraries/windows/x64
; (zlib/libpng preloaded by HaruInit). Linux = ld.so-resolved system libharu
; first (plain HaruInit() = dlopen search path), then the local build-tree
; mirror libraries/linux/x64/ (expects libhpdf.so or libhpdf.so.2 there).
CompilerIf #PB_Compiler_OS = #PB_OS_Linux
  If HaruInit() = 0
    If HaruInit("../libraries/linux/x64/") = 0
      PrintN("FAIL init (libhpdf.so not loadable - install libharu system-wide or place libhpdf.so[.2] in ../libraries/linux/x64/)")
      If HaruMissing$ = ""
        PrintN("  dlopen failed (library missing)")
      Else
        PrintN("  missing exports: " + HaruMissing$)
      EndIf
      End 1
    EndIf
  EndIf
CompilerElse
  If HaruInit("../libraries/windows/x64/") = 0
    PrintN("FAIL init (hpdf.dll not loadable - hpdf.dll + zlib.dll + libpng16.dll must sit beside the exe; or wrong DLL version)")
    If HaruMissing$ = ""
      PrintN("  OpenLibrary failed (DLLs missing)")
    Else
      PrintN("  missing exports: " + HaruMissing$)
    EndIf
    End 1
  EndIf
CompilerEndIf

Define pdf.i = HaruNew()
If pdf = 0
  PrintN("FAIL doc (HaruNew returned 0)")
  End 1
EndIf

; --- block: doc -------------------------------------------------------------
If HPDF_SetCompressionMode(pdf, #HPDF_COMP_ALL) <> #HPDF_OK
  PrintN("FAIL doc (SetCompressionMode) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
PrintN("libharu version: " + PeekS(HPDF_GetVersion(), -1, #PB_Ascii))
PrintN("PASS init (OpenLibrary, " + Str(HaruBound) + " functions bound)")
PrintN("PASS doc (HaruNew + UTF-8 encoder + compression)")

; --- block: page --------------------------------------------------------------
Define page.i = HaruAddPage(pdf)
If page = 0
  PrintN("FAIL page (HaruAddPage) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
PrintN("PASS page (A4 portrait)")

; --- block: embedded TTF font ---------------------------------------------------
; Fail fast on a stripped box: no silent fallback to core Helvetica - the
; UTF-8 assertion depends on the embedded TTF.
; Linux uses the bundled font so no desktop/system font package is needed.
CompilerIf #PB_Compiler_OS = #PB_OS_Linux
  Define arial$ = "ttfont/PenguinAttack.ttf"
CompilerElse
  Define arial$ = "C:/Windows/Fonts/arial.ttf"
CompilerEndIf
If FileSize(arial$) < 0
  PrintN("FAIL font (required TTF not found: " + arial$ + ")")
  HaruFree(pdf)
  End 1
EndIf
Define font.i = HaruTTFFont(pdf, arial$)
If font = 0
  PrintN("FAIL font (HaruTTFFont) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
PrintN("PASS font (embedded TTF " + arial$ + ", UTF-8 encoding)")

; --- block: UTF-8 text (non-ASCII proves the UTF-8 pipeline) ---------------------
If HPDF_Page_SetFontAndSize(page, font, 24) <> #HPDF_OK
  PrintN("FAIL utf8-text (SetFontAndSize) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
If HaruTextOut(page, 72, 750, "Invoice £ 4797,65 — café") <> #HPDF_OK
  PrintN("FAIL utf8-text (TextOut) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
PrintN("PASS utf8-text (non-ASCII via embedded TTF)")

; --- block: RGB-filled rect -------------------------------------------------------
If HPDF_Page_SetRGBFill(page, 0.85, 0.2, 0.15) <> #HPDF_OK
  PrintN("FAIL rect (SetRGBFill) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
If HPDF_Page_Rectangle(page, 72, 610, 200, 100) <> #HPDF_OK Or HPDF_Page_Fill(page) <> #HPDF_OK
  PrintN("FAIL rect (Rectangle/Fill) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
PrintN("PASS rect (RGB fill)")

; --- block: custom dash -----------------------------------------------------------
Dim dash.f(1)
dash(0) = 3.0
dash(1) = 7.0
If HPDF_Page_SetLineWidth(page, 1.5) <> #HPDF_OK Or HPDF_Page_SetDash(page, @dash(0), 2, 0.0) <> #HPDF_OK
  PrintN("FAIL dash (SetDash) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
If HPDF_Page_MoveTo(page, 72, 570) <> #HPDF_OK Or HPDF_Page_LineTo(page, 523, 570) <> #HPDF_OK Or HPDF_Page_Stroke(page) <> #HPDF_OK
  PrintN("FAIL dash (stroke line) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
HPDF_Page_SetDash(page, 0, 0, 0.0) ; reset to solid so later blocks stay clean
PrintN("PASS dash ([3 7] pattern)")

; --- block: alpha watermark --------------------------------------------------------
Define gs.i = HaruAlpha(pdf, 0.25)
If gs = 0
  PrintN("FAIL alpha (HaruAlpha) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
If HPDF_Page_GSave(page) <> #HPDF_OK Or HPDF_Page_SetExtGState(page, gs) <> #HPDF_OK
  PrintN("FAIL alpha (SetExtGState) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
If HPDF_Page_SetGrayFill(page, 0.5) <> #HPDF_OK Or HPDF_Page_Rectangle(page, 72, 80, 451, 80) <> #HPDF_OK Or HPDF_Page_Fill(page) <> #HPDF_OK
  PrintN("FAIL alpha (watermark rect) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
HPDF_Page_GRestore(page) ; scope the alpha state to this block
PrintN("PASS alpha (gray watermark, alpha 0.25)")

; --- block: rotated text (GSave + rotation matrix + TextOut + GRestore) ------------
Define cs.f = Cos(#PI / 4)
Define sn.f = Sin(#PI / 4)
If HPDF_Page_GSave(page) <> #HPDF_OK Or HPDF_Page_Concat(page, cs, sn, -sn, cs, 300, 400) <> #HPDF_OK
  PrintN("FAIL rotation (GSave/Concat) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
If HaruTextOut(page, 0, 0, "Rotated 45°") <> #HPDF_OK
  PrintN("FAIL rotation (TextOut) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
HPDF_Page_GRestore(page)
PrintN("PASS rotation (45 deg matrix)")

; --- block: PNG image -------------------------------------------------------------
; PB's Linux Image library pulls GTK symbols that console builds do not link.
; Use a bundled PNG instead so this test also works headlessly under WSL.
CompilerIf #PB_Compiler_OS = #PB_OS_Linux
  Define png$ = "pngsuite/basn2c08.png"
CompilerElse
UsePNGImageEncoder()
Define img.i = CreateImage(#PB_Any, 160, 90)
If img = 0
  PrintN("FAIL image (CreateImage)")
  HaruFree(pdf)
  End 1
EndIf
StartDrawing(ImageOutput(img))
Box(0, 0, 160, 90, RGB(28, 90, 190))
Box(24, 22, 112, 46, RGB(255, 205, 40))
StopDrawing()
Define png$ = GetTemporaryDirectory() + "hpdf_smoke_img.png"
If SaveImage(img, png$, #PB_ImagePlugin_PNG) = 0
  PrintN("FAIL image (SaveImage -> " + png$ + ")")
  FreeImage(img)
  HaruFree(pdf)
  End 1
EndIf
FreeImage(img)
CompilerEndIf
Define himg.i = HaruPngFromFile(pdf, png$)
If himg = 0
  PrintN("FAIL image (HaruPngFromFile) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
If HPDF_Page_DrawImage(page, himg, 300, 620, 160, 90) <> #HPDF_OK
  PrintN("FAIL image (DrawImage) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
PrintN("PASS image (PNG " + Str(HPDF_Image_GetWidth(himg)) + "x" + Str(HPDF_Image_GetHeight(himg)) + ")")

; --- block: save -------------------------------------------------------------------
If HPDF_GetError(pdf) <> #HPDF_OK
  PrintN("FAIL save (latched error before save) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
If HPDF_SaveToFile(pdf, "hpdf_smoke.pdf") <> #HPDF_OK
  PrintN("FAIL save (SaveToFile) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
HaruFree(pdf)
PrintN("PASS save (hpdf_smoke.pdf)")

HaruShutdown()
CloseConsole()
End 0

; IDE Options = PureBasic 6.40 (Windows - x64)
; ExecutableFormat = Console
; CursorPosition = 16
; FirstLine = 7
; Folding = -
; Optimizer
; EnableXP
; DPIAware