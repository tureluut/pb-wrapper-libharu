; ---------------------------------------------------------------------------
; ext_gstate_demo.pb - PureBasic port of libharu's ext_gstate_demo.c
; (<< Haru Free PDF Library 2.0.0 >>, Copyright (c) 1999-2006 Takeshi Kanno,
; ZLIB license - see ../THIRD-PARTY-NOTICES.md).
; Prints three overlapping RGB circles under 14 different ExtGStates:
; normal, alpha fill 0.8, alpha fill 0.4, and all 12 blend modes (including
; libharu's "EXCLUSHON" spelling), each bracketed in GSave/GRestore.
;
; Deviations from the C original (wrapper subset, see ../hpdf.pbi):
;  - no setjmp/longjmp error handler: one latched-error gate before the save;
;  - the C's HPDF_GetFont(pdf, "Helvetica-Bold", NULL) (NULL = font default
;    encoding) becomes HaruGetFont(pdf, "Helvetica-Bold", "") - a real C
;    NULL through the raw binding; all text is ASCII;
;  - argv[0] + ".pdf" output replaced with the stable filename
;    ext_gstate_demo.pdf.
;
; Build (from samples/):
;   MSYS2_ARG_CONV_EXCL='*' "$PUREBASIC_HOME/Compilers/pbcompilerc.exe" \
;     /CONSOLE /THREAD /EXE ext_gstate_demo.exe ext_gstate_demo.pb
; ---------------------------------------------------------------------------

EnableExplicit

XIncludeFile "../hpdf.pbi"
XIncludeFile "grid_sheet.pbi"   ; included for parity with the C build (ext_gstate links grid_sheet.c); grid unused

#PAGE_WIDTH  = 600
#PAGE_HEIGHT = 900

; ext_gstate_demo.c draw_circles(): red/green/blue overlapping circles with
; black outline plus a description above them.
Procedure DrawCircles(page.i, description$, x.f, y.f)
  HPDF_Page_SetLineWidth(page, 1.0)
  HPDF_Page_SetRGBStroke(page, 0.0, 0.0, 0.0)
  HPDF_Page_SetRGBFill(page, 1.0, 0.0, 0.0)
  HPDF_Page_Circle(page, x + 40, y + 40, 40)
  HPDF_Page_ClosePathFillStroke(page)
  HPDF_Page_SetRGBFill(page, 0.0, 1.0, 0.0)
  HPDF_Page_Circle(page, x + 100, y + 40, 40)
  HPDF_Page_ClosePathFillStroke(page)
  HPDF_Page_SetRGBFill(page, 0.0, 0.0, 1.0)
  HPDF_Page_Circle(page, x + 70, y + 74.64, 40)
  HPDF_Page_ClosePathFillStroke(page)

  HPDF_Page_SetRGBFill(page, 0.0, 0.0, 0.0)
  HPDF_Page_BeginText(page)
  HPDF_Page_TextOut(page, x + 0.0, y + 130.0, description$)
  HPDF_Page_EndText(page)
EndProcedure

OpenConsole()

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

Define hfont.i = HaruGetFont(pdf, "Helvetica-Bold", "")
If hfont = 0
  PrintN("FAIL font (GetFont Helvetica-Bold) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

; add a new page object
Define page.i = HPDF_AddPage(pdf)
If page = 0
  PrintN("FAIL page " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

HPDF_Page_SetFontAndSize(page, hfont, 10)

HPDF_Page_SetHeight(page, #PAGE_HEIGHT)
HPDF_Page_SetWidth(page, #PAGE_WIDTH)

; normal
HPDF_Page_GSave(page)
DrawCircles(page, "normal", 40.0, #PAGE_HEIGHT - 170)
HPDF_Page_GRestore(page)

; transparency (0.8)
HPDF_Page_GSave(page)
Define gstate.i = HPDF_CreateExtGState(pdf)
HPDF_ExtGState_SetAlphaFill(gstate, 0.8)
HPDF_ExtGState_SetAlphaStroke(gstate, 0.8)
HPDF_Page_SetExtGState(page, gstate)
DrawCircles(page, "alpha fill = 0.8", 230.0, #PAGE_HEIGHT - 170)
HPDF_Page_GRestore(page)

; transparency (0.4)
HPDF_Page_GSave(page)
gstate = HPDF_CreateExtGState(pdf)
HPDF_ExtGState_SetAlphaFill(gstate, 0.4)
HPDF_Page_SetExtGState(page, gstate)
DrawCircles(page, "alpha fill = 0.4", 420.0, #PAGE_HEIGHT - 170)
HPDF_Page_GRestore(page)

; blend-mode=HPDF_BM_MULTIPLY
HPDF_Page_GSave(page)
gstate = HPDF_CreateExtGState(pdf)
HPDF_ExtGState_SetBlendMode(gstate, #HPDF_BM_MULTIPLY)
HPDF_Page_SetExtGState(page, gstate)
DrawCircles(page, "HPDF_BM_MULTIPLY", 40.0, #PAGE_HEIGHT - 340)
HPDF_Page_GRestore(page)

; blend-mode=HPDF_BM_SCREEN
HPDF_Page_GSave(page)
gstate = HPDF_CreateExtGState(pdf)
HPDF_ExtGState_SetBlendMode(gstate, #HPDF_BM_SCREEN)
HPDF_Page_SetExtGState(page, gstate)
DrawCircles(page, "HPDF_BM_SCREEN", 230.0, #PAGE_HEIGHT - 340)
HPDF_Page_GRestore(page)

; blend-mode=HPDF_BM_OVERLAY
HPDF_Page_GSave(page)
gstate = HPDF_CreateExtGState(pdf)
HPDF_ExtGState_SetBlendMode(gstate, #HPDF_BM_OVERLAY)
HPDF_Page_SetExtGState(page, gstate)
DrawCircles(page, "HPDF_BM_OVERLAY", 420.0, #PAGE_HEIGHT - 340)
HPDF_Page_GRestore(page)

; blend-mode=HPDF_BM_DARKEN
HPDF_Page_GSave(page)
gstate = HPDF_CreateExtGState(pdf)
HPDF_ExtGState_SetBlendMode(gstate, #HPDF_BM_DARKEN)
HPDF_Page_SetExtGState(page, gstate)
DrawCircles(page, "HPDF_BM_DARKEN", 40.0, #PAGE_HEIGHT - 510)
HPDF_Page_GRestore(page)

; blend-mode=HPDF_BM_LIGHTEN
HPDF_Page_GSave(page)
gstate = HPDF_CreateExtGState(pdf)
HPDF_ExtGState_SetBlendMode(gstate, #HPDF_BM_LIGHTEN)
HPDF_Page_SetExtGState(page, gstate)
DrawCircles(page, "HPDF_BM_LIGHTEN", 230.0, #PAGE_HEIGHT - 510)
HPDF_Page_GRestore(page)

; blend-mode=HPDF_BM_COLOR_DODGE
HPDF_Page_GSave(page)
gstate = HPDF_CreateExtGState(pdf)
HPDF_ExtGState_SetBlendMode(gstate, #HPDF_BM_COLOR_DODGE)
HPDF_Page_SetExtGState(page, gstate)
DrawCircles(page, "HPDF_BM_COLOR_DODGE", 420.0, #PAGE_HEIGHT - 510)
HPDF_Page_GRestore(page)

; blend-mode=HPDF_BM_COLOR_BUM
HPDF_Page_GSave(page)
gstate = HPDF_CreateExtGState(pdf)
HPDF_ExtGState_SetBlendMode(gstate, #HPDF_BM_COLOR_BUM)
HPDF_Page_SetExtGState(page, gstate)
DrawCircles(page, "HPDF_BM_COLOR_BUM", 40.0, #PAGE_HEIGHT - 680)
HPDF_Page_GRestore(page)

; blend-mode=HPDF_BM_HARD_LIGHT
HPDF_Page_GSave(page)
gstate = HPDF_CreateExtGState(pdf)
HPDF_ExtGState_SetBlendMode(gstate, #HPDF_BM_HARD_LIGHT)
HPDF_Page_SetExtGState(page, gstate)
DrawCircles(page, "HPDF_BM_HARD_LIGHT", 230.0, #PAGE_HEIGHT - 680)
HPDF_Page_GRestore(page)

; blend-mode=HPDF_BM_SOFT_LIGHT
HPDF_Page_GSave(page)
gstate = HPDF_CreateExtGState(pdf)
HPDF_ExtGState_SetBlendMode(gstate, #HPDF_BM_SOFT_LIGHT)
HPDF_Page_SetExtGState(page, gstate)
DrawCircles(page, "HPDF_BM_SOFT_LIGHT", 420.0, #PAGE_HEIGHT - 680)
HPDF_Page_GRestore(page)

; blend-mode=HPDF_BM_DIFFERENCE
HPDF_Page_GSave(page)
gstate = HPDF_CreateExtGState(pdf)
HPDF_ExtGState_SetBlendMode(gstate, #HPDF_BM_DIFFERENCE)
HPDF_Page_SetExtGState(page, gstate)
DrawCircles(page, "HPDF_BM_DIFFERENCE", 40.0, #PAGE_HEIGHT - 850)
HPDF_Page_GRestore(page)

; blend-mode=HPDF_BM_EXCLUSHON
HPDF_Page_GSave(page)
gstate = HPDF_CreateExtGState(pdf)
HPDF_ExtGState_SetBlendMode(gstate, #HPDF_BM_EXCLUSHON)
HPDF_Page_SetExtGState(page, gstate)
DrawCircles(page, "HPDF_BM_EXCLUSHON", 230.0, #PAGE_HEIGHT - 850)
HPDF_Page_GRestore(page)

; --- gate + save ---------------------------------------------------------------
If HPDF_GetError(pdf) <> #HPDF_OK
  PrintN("FAIL draw (latched error) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

If HPDF_SaveToFile(pdf, "ext_gstate_demo.pdf") <> #HPDF_OK
  PrintN("FAIL save " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
HaruFree(pdf)
PrintN("PASS ext_gstate_demo -> ext_gstate_demo.pdf")

HaruShutdown()
CloseConsole()
End 0

; IDE Options = PureBasic 6.40 (Windows - x64)
; ExecutableFormat = Console
; EnableXP
; DPIAware
