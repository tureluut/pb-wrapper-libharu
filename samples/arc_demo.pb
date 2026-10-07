; ---------------------------------------------------------------------------
; arc_demo.pb - PureBasic port of libharu's arc_demo.c
; (<< Haru Free PDF Library 2.0.0 >>, Copyright (c) 1999-2006 Takeshi Kanno,
; ZLIB license - see ../THIRD-PARTY-NOTICES.md).
; Draws a 45/25/15/15 pie chart out of four filled arcs plus a center circle
; on a 200x220 gridded page.
;
; Deviations from the C original (wrapper subset, see ../hpdf.pbi):
;  - no setjmp/longjmp error handler: libharu latches the first error, so the
;    drawing is gated by one HPDF_GetError check before the save;
;  - HPDF_Page_GetCurrentPos() returns a struct BY VALUE (banned in the
;    wrapper); the port uses the documented out-parameter variant
;    HPDF_Page_GetCurrentPos2() into an HPDFPoint - identical values;
;  - grid from the shared grid_sheet.pbi port (page dimensions are queried
;    live, matching the C's HPDF_Page_GetWidth/GetHeight use);
;  - argv[0] + ".pdf" output replaced with the stable filename arc_demo.pdf
;    in the current working directory.
;
; Build (from samples/):
;   MSYS2_ARG_CONV_EXCL='*' "$PUREBASIC_HOME/Compilers/pbcompilerc.exe" \
;     /CONSOLE /THREAD /EXE arc_demo.exe arc_demo.pb
; ---------------------------------------------------------------------------

EnableExplicit

XIncludeFile "../hpdf.pbi"
XIncludeFile "grid_sheet.pbi"

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

; add a new page object
Define page.i = HPDF_AddPage(pdf)
If page = 0
  PrintN("FAIL page " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

HPDF_Page_SetHeight(page, 220)
HPDF_Page_SetWidth(page, 200)

; draw grid to the page
PrintGrid(pdf, page)

; draw pie chart
;   A: 45% Red
;   B: 25% Blue
;   C: 15% green
;   D: other yellow
;
; pos = HPDF_Page_GetCurrentPos(page) in C; GetCurrentPos2 out-param here.
Dim pos.HPDFPoint(0)

; A
HPDF_Page_SetRGBFill(page, 1.0, 0, 0)
HPDF_Page_MoveTo(page, 100, 100)
HPDF_Page_LineTo(page, 100, 180)
HPDF_Page_Arc(page, 100, 100, 80, 0, 360 * 0.45)
HPDF_Page_GetCurrentPos2(page, @pos(0))
HPDF_Page_LineTo(page, 100, 100)
HPDF_Page_Fill(page)

; B
HPDF_Page_SetRGBFill(page, 0, 0, 1.0)
HPDF_Page_MoveTo(page, 100, 100)
HPDF_Page_LineTo(page, pos(0)\x, pos(0)\y)
HPDF_Page_Arc(page, 100, 100, 80, 360 * 0.45, 360 * 0.7)
HPDF_Page_GetCurrentPos2(page, @pos(0))
HPDF_Page_LineTo(page, 100, 100)
HPDF_Page_Fill(page)

; C
HPDF_Page_SetRGBFill(page, 0, 1.0, 0)
HPDF_Page_MoveTo(page, 100, 100)
HPDF_Page_LineTo(page, pos(0)\x, pos(0)\y)
HPDF_Page_Arc(page, 100, 100, 80, 360 * 0.7, 360 * 0.85)
HPDF_Page_GetCurrentPos2(page, @pos(0))
HPDF_Page_LineTo(page, 100, 100)
HPDF_Page_Fill(page)

; D
HPDF_Page_SetRGBFill(page, 1.0, 1.0, 0)
HPDF_Page_MoveTo(page, 100, 100)
HPDF_Page_LineTo(page, pos(0)\x, pos(0)\y)
HPDF_Page_Arc(page, 100, 100, 80, 360 * 0.85, 360)
HPDF_Page_GetCurrentPos2(page, @pos(0))
HPDF_Page_LineTo(page, 100, 100)
HPDF_Page_Fill(page)

; draw center circle
HPDF_Page_SetGrayStroke(page, 0)
HPDF_Page_SetGrayFill(page, 1)
HPDF_Page_Circle(page, 100, 100, 30)
HPDF_Page_Fill(page)

; --- gate + save ---------------------------------------------------------------
If HPDF_GetError(pdf) <> #HPDF_OK
  PrintN("FAIL draw (latched error) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

If HPDF_SaveToFile(pdf, "arc_demo.pdf") <> #HPDF_OK
  PrintN("FAIL save " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
HaruFree(pdf)
PrintN("PASS arc_demo -> arc_demo.pdf")

HaruShutdown()
CloseConsole()
End 0

; IDE Options = PureBasic 6.40 (Windows - x64)
; ExecutableFormat = Console
; EnableXP
; DPIAware
