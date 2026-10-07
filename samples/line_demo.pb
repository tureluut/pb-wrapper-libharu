; ---------------------------------------------------------------------------
; line_demo.pb - port of libharu's line_demo.c (<< Haru Free PDF Library >>,
; Copyright (c) 1999-2006 Takeshi Kanno, ZLIB license - see
; ../THIRD-PARTY-NOTICES.md). Exercises the line/curve render surface of
; hpdf.pbi: line widths, dash patterns, line cap and join styles, rectangle
; stroke / fill / fill-stroke / clipping, and the three Bezier operators
; (CurveTo, CurveTo2, CurveTo3).
;
; Deviations from the C original (wrapper subset, see hpdf.pbi):
;  - no setjmp/longjmp error handler: libharu latches the first error, so the
;    drawing is gated by one HPDF_GetError check before the save;
;  - page geometry: HaruAddPage() fixes A4 portrait and the wrapper binds no
;    HPDF_Page_GetWidth/GetHeight, so the exact A4 values libharu writes
;    (MediaBox "595.276 841.89001") are used as constants;
;  - clip text: the C demo uses SetTextLeading + 3x ShowTextNextLine; the
;    wrapper has no SetTextLeading, so the same layout is produced with an
;    explicit relative MoveTextPos(0, -12) between ShowText calls;
;  - text: base-14 Helvetica with "WinAnsiEncoding" - every label is pure
;    ASCII, so the byte pass-through of single-byte fonts is exact (see
;    probe_noembed.pb).
;
; Build (from samples/):
;   MSYS2_ARG_CONV_EXCL='*' "$PUREBASIC_HOME/Compilers/pbcompilerc.exe" \
;     /CONSOLE /THREAD /EXE line_demo.exe line_demo.pb
; ---------------------------------------------------------------------------

EnableExplicit

XIncludeFile "../hpdf.pbi"

#PAGE_W = 595.276     ; A4 portrait, fixed by HaruAddPage()
#PAGE_H = 841.89001

; dash patterns (HPDF_REAL arrays: SetDash takes pointer + count + phase)
Dim Dash1.f(0) : Dash1(0) = 3
Dim Dash2.f(1) : Dash2(0) = 3 : Dash2(1) = 7
Dim Dash3.f(3) : Dash3(0) = 8 : Dash3(1) = 7 : Dash3(2) = 2 : Dash3(3) = 7

Procedure DrawLine(page.i, x.f, y.f, label$)
  HPDF_Page_BeginText(page)
  HPDF_Page_MoveTextPos(page, x, y - 10)
  HPDF_Page_ShowText(page, label$)
  HPDF_Page_EndText(page)

  HPDF_Page_MoveTo(page, x, y - 15)
  HPDF_Page_LineTo(page, x + 220, y - 15)
  HPDF_Page_Stroke(page)
EndProcedure

Procedure DrawLine2(page.i, x.f, y.f, label$)
  HPDF_Page_BeginText(page)
  HPDF_Page_MoveTextPos(page, x, y)
  HPDF_Page_ShowText(page, label$)
  HPDF_Page_EndText(page)

  HPDF_Page_MoveTo(page, x + 30, y - 25)
  HPDF_Page_LineTo(page, x + 160, y - 25)
  HPDF_Page_Stroke(page)
EndProcedure

; draws the label and BEGINS the rectangle path (the caller paints it:
; Stroke / Fill / FillStroke / Clip)
Procedure DrawRect(page.i, x.f, y.f, label$)
  HPDF_Page_BeginText(page)
  HPDF_Page_MoveTextPos(page, x, y - 10)
  HPDF_Page_ShowText(page, label$)
  HPDF_Page_EndText(page)

  HPDF_Page_Rectangle(page, x, y - 40, 220, 25)
EndProcedure

OpenConsole()

; --- init (OS-branched, same pattern as hpdf_smoke.pb) -----------------------
CompilerIf #PB_Compiler_OS = #PB_OS_Linux
  If HaruInit() = 0
    If HaruInit("../libraries/linux/x64/") = 0
      PrintN("FAIL init (libhpdf.so not loadable - install libharu system-wide or place libhpdf.so[.2] in ../libraries/linux/x64/)")
      End 1
    EndIf
  EndIf
CompilerElse
  If HaruInit("../libraries/windows/x64/") = 0
    PrintN("FAIL init (hpdf.dll not loadable - hpdf.dll + zlib.dll + libpng16.dll must sit beside the exe; or wrong DLL version)")
    End 1
  EndIf
CompilerEndIf
PrintN("libharu " + PeekS(HPDF_GetVersion(), -1, #PB_Ascii))

Define pdf.i = HaruNew()
If pdf = 0
  PrintN("FAIL doc (HaruNew returned 0)")
  End 1
EndIf

; --- doc / font / page --------------------------------------------------------
Define font.i = HPDF_GetFont(pdf, "Helvetica", "WinAnsiEncoding")
If font = 0
  PrintN("FAIL font (GetFont Helvetica) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

Define page.i = HaruAddPage(pdf)
If page = 0
  PrintN("FAIL page (HaruAddPage) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

; --- frame + page title (centered via TextWidth) -------------------------------
HPDF_Page_SetLineWidth(page, 1)
HPDF_Page_Rectangle(page, 50, 50, #PAGE_W - 100, #PAGE_H - 110)
HPDF_Page_Stroke(page)

HPDF_Page_SetFontAndSize(page, font, 24)
Define tw.f = HPDF_Page_TextWidth(page, "Line Example")
HPDF_Page_BeginText(page)
HPDF_Page_MoveTextPos(page, (#PAGE_W - tw) / 2, #PAGE_H - 50)
HPDF_Page_ShowText(page, "Line Example")
HPDF_Page_EndText(page)

HPDF_Page_SetFontAndSize(page, font, 10)

; --- various line widths --------------------------------------------------------
HPDF_Page_SetLineWidth(page, 0)
DrawLine(page, 60, 770, "line width = 0")

HPDF_Page_SetLineWidth(page, 1.0)
DrawLine(page, 60, 740, "line width = 1.0")

HPDF_Page_SetLineWidth(page, 2.0)
DrawLine(page, 60, 710, "line width = 2.0")

; --- line dash patterns ----------------------------------------------------------
HPDF_Page_SetLineWidth(page, 1.0)

HPDF_Page_SetDash(page, @Dash1(0), 1, 1.0)
DrawLine(page, 60, 680, "dash_ptn=[3], phase=1 -- 2 on, 3 off, 3 on...")

HPDF_Page_SetDash(page, @Dash2(0), 2, 2.0)
DrawLine(page, 60, 650, "dash_ptn=[7, 3], phase=2 -- 5 on 3 off, 7 on,...")

HPDF_Page_SetDash(page, @Dash3(0), 4, 0.0)
DrawLine(page, 60, 620, "dash_ptn=[8, 7, 2, 7], phase=0")

HPDF_Page_SetDash(page, 0, 0, 0.0)   ; reset to solid

; --- line cap style ----------------------------------------------------------------
HPDF_Page_SetLineWidth(page, 30)
HPDF_Page_SetRGBStroke(page, 0.0, 0.5, 0.0)

HPDF_Page_SetLineCap(page, #HPDF_BUTT_END)
DrawLine2(page, 60, 570, "PDF_BUTT_END")

HPDF_Page_SetLineCap(page, #HPDF_ROUND_END)
DrawLine2(page, 60, 505, "PDF_ROUND_END")

HPDF_Page_SetLineCap(page, #HPDF_PROJECTING_SQUARE_END)
DrawLine2(page, 60, 440, "PDF_PROJECTING_SQUARE_END")

; --- line join style -----------------------------------------------------------------
HPDF_Page_SetLineWidth(page, 30)
HPDF_Page_SetRGBStroke(page, 0.0, 0.0, 0.5)

HPDF_Page_SetLineJoin(page, #HPDF_MITER_JOIN)
HPDF_Page_MoveTo(page, 120, 300)
HPDF_Page_LineTo(page, 160, 340)
HPDF_Page_LineTo(page, 200, 300)
HPDF_Page_Stroke(page)

HPDF_Page_BeginText(page)
HPDF_Page_MoveTextPos(page, 60, 360)
HPDF_Page_ShowText(page, "PDF_MITER_JOIN")
HPDF_Page_EndText(page)

HPDF_Page_SetLineJoin(page, #HPDF_ROUND_JOIN)
HPDF_Page_MoveTo(page, 120, 195)
HPDF_Page_LineTo(page, 160, 235)
HPDF_Page_LineTo(page, 200, 195)
HPDF_Page_Stroke(page)

HPDF_Page_BeginText(page)
HPDF_Page_MoveTextPos(page, 60, 255)
HPDF_Page_ShowText(page, "PDF_ROUND_JOIN")
HPDF_Page_EndText(page)

HPDF_Page_SetLineJoin(page, #HPDF_BEVEL_JOIN)
HPDF_Page_MoveTo(page, 120, 90)
HPDF_Page_LineTo(page, 160, 130)
HPDF_Page_LineTo(page, 200, 90)
HPDF_Page_Stroke(page)

HPDF_Page_BeginText(page)
HPDF_Page_MoveTextPos(page, 60, 150)
HPDF_Page_ShowText(page, "PDF_BEVEL_JOIN")
HPDF_Page_EndText(page)

; --- rectangles: stroke / fill / fill+stroke ------------------------------------------
HPDF_Page_SetLineWidth(page, 2)
HPDF_Page_SetRGBStroke(page, 0, 0, 0)
HPDF_Page_SetRGBFill(page, 0.75, 0.0, 0.0)

DrawRect(page, 300, 770, "Stroke")
HPDF_Page_Stroke(page)

DrawRect(page, 300, 720, "Fill")
HPDF_Page_Fill(page)

DrawRect(page, 300, 670, "Fill then Stroke")
HPDF_Page_FillStroke(page)

; --- clip rectangle (GSave/GRestore scope the clip to this block) ----------------------
HPDF_Page_GSave(page)
DrawRect(page, 300, 620, "Clip Rectangle")
HPDF_Page_Clip(page)
HPDF_Page_Stroke(page)
HPDF_Page_SetFontAndSize(page, font, 13)

HPDF_Page_BeginText(page)
HPDF_Page_MoveTextPos(page, 290, 600)
HPDF_Page_ShowText(page, "Clip Clip Clip Clip Clip Clipi Clip Clip Clip")
HPDF_Page_MoveTextPos(page, 0, -12)   ; C demo: SetTextLeading(12) + ShowTextNextLine
HPDF_Page_ShowText(page, "Clip Clip Clip Clip Clip Clip Clip Clip Clip")
HPDF_Page_MoveTextPos(page, 0, -12)
HPDF_Page_ShowText(page, "Clip Clip Clip Clip Clip Clip Clip Clip Clip")
HPDF_Page_EndText(page)
HPDF_Page_GRestore(page)

; --- curve example (CurveTo2, first control point implied = current point) --------------
Define x.f  = 330
Define y.f  = 440
Define x1.f = 430
Define y1.f = 530
Define x2.f = 480
Define y2.f = 470
Define x3.f = 480
Define y3.f = 90

HPDF_Page_SetRGBFill(page, 0, 0, 0)

HPDF_Page_BeginText(page)
HPDF_Page_MoveTextPos(page, 300, 540)
HPDF_Page_ShowText(page, "CurveTo2(x1, y1, x2. y2)")
HPDF_Page_EndText(page)

HPDF_Page_BeginText(page)
HPDF_Page_MoveTextPos(page, x + 5, y - 5)
HPDF_Page_ShowText(page, "Current point")
HPDF_Page_MoveTextPos(page, x1 - x, y1 - y)
HPDF_Page_ShowText(page, "(x1, y1)")
HPDF_Page_MoveTextPos(page, x2 - x1, y2 - y1)
HPDF_Page_ShowText(page, "(x2, y2)")
HPDF_Page_EndText(page)

HPDF_Page_SetDash(page, @Dash1(0), 1, 0.0)

HPDF_Page_SetLineWidth(page, 0.5)
HPDF_Page_MoveTo(page, x1, y1)
HPDF_Page_LineTo(page, x2, y2)
HPDF_Page_Stroke(page)

HPDF_Page_SetDash(page, 0, 0, 0.0)

HPDF_Page_SetLineWidth(page, 1.5)

HPDF_Page_MoveTo(page, x, y)
HPDF_Page_CurveTo2(page, x1, y1, x2, y2)
HPDF_Page_Stroke(page)

; --- curve example (CurveTo3, second control point implied = end point) -----------------
y  = y - 150
y1 = y1 - 150
y2 = y2 - 150

HPDF_Page_BeginText(page)
HPDF_Page_MoveTextPos(page, 300, 390)
HPDF_Page_ShowText(page, "CurveTo3(x1, y1, x2. y2)")
HPDF_Page_EndText(page)

HPDF_Page_BeginText(page)
HPDF_Page_MoveTextPos(page, x + 5, y - 5)
HPDF_Page_ShowText(page, "Current point")
HPDF_Page_MoveTextPos(page, x1 - x, y1 - y)
HPDF_Page_ShowText(page, "(x1, y1)")
HPDF_Page_MoveTextPos(page, x2 - x1, y2 - y1)
HPDF_Page_ShowText(page, "(x2, y2)")
HPDF_Page_EndText(page)

HPDF_Page_SetDash(page, @Dash1(0), 1, 0.0)

HPDF_Page_SetLineWidth(page, 0.5)
HPDF_Page_MoveTo(page, x, y)
HPDF_Page_LineTo(page, x1, y1)
HPDF_Page_Stroke(page)

HPDF_Page_SetDash(page, 0, 0, 0.0)

HPDF_Page_SetLineWidth(page, 1.5)
HPDF_Page_MoveTo(page, x, y)
HPDF_Page_CurveTo3(page, x1, y1, x2, y2)
HPDF_Page_Stroke(page)

; --- curve example (CurveTo, both control points + end point) ---------------------------
y  = y - 150
y1 = y1 - 160
y2 = y2 - 130
x2 = x2 + 10

HPDF_Page_BeginText(page)
HPDF_Page_MoveTextPos(page, 300, 240)
HPDF_Page_ShowText(page, "CurveTo(x1, y1, x2. y2, x3, y3)")
HPDF_Page_EndText(page)

HPDF_Page_BeginText(page)
HPDF_Page_MoveTextPos(page, x + 5, y - 5)
HPDF_Page_ShowText(page, "Current point")
HPDF_Page_MoveTextPos(page, x1 - x, y1 - y)
HPDF_Page_ShowText(page, "(x1, y1)")
HPDF_Page_MoveTextPos(page, x2 - x1, y2 - y1)
HPDF_Page_ShowText(page, "(x2, y2)")
HPDF_Page_MoveTextPos(page, x3 - x2, y3 - y2)
HPDF_Page_ShowText(page, "(x3, y3)")
HPDF_Page_EndText(page)

HPDF_Page_SetDash(page, @Dash1(0), 1, 0.0)

HPDF_Page_SetLineWidth(page, 0.5)
HPDF_Page_MoveTo(page, x, y)
HPDF_Page_LineTo(page, x1, y1)
HPDF_Page_Stroke(page)
HPDF_Page_MoveTo(page, x2, y2)
HPDF_Page_LineTo(page, x3, y3)
HPDF_Page_Stroke(page)

HPDF_Page_SetDash(page, 0, 0, 0.0)

HPDF_Page_SetLineWidth(page, 1.5)
HPDF_Page_MoveTo(page, x, y)
HPDF_Page_CurveTo(page, x1, y1, x2, y2, x3, y3)
HPDF_Page_Stroke(page)

; --- gate + save -------------------------------------------------------------------------
; libharu latches the first error; one check covers every draw call above
; (the C original's setjmp/longjmp error handler equivalent).
If HPDF_GetError(pdf) <> #HPDF_OK
  PrintN("FAIL draw (latched error) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

If HPDF_SaveToFile(pdf, "line_demo.pdf") <> #HPDF_OK
  PrintN("FAIL save " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
HaruFree(pdf)
PrintN("PASS line_demo -> line_demo.pdf")

HaruShutdown()
CloseConsole()
End 0

; IDE Options = PureBasic 6.40 (Windows - x64)
; ExecutableFormat = Console
; EnableXP
; DPIAware
