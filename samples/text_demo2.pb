; ---------------------------------------------------------------------------
; text_demo2.pb - PureBasic port of libharu's text_demo2.c plus grid_sheet.c
; (<< Alternative PDF Library 1.0.0 >>, Copyright (c) 1999-2006 Takeshi
; Kanno; ZLIB license - see ../THIRD-PARTY-NOTICES.md).
; Demonstrates TextRect alignment, skewed/rotated coordinate systems, and
; individual glyph placement around a circle.
;
; Port notes:
;  - the C PrintText() helper is unused in the original main() and queries
;    HPDF_Page_GetCurrentTextPos() by-value; it is therefore omitted.
;  - grid_sheet's grid is implemented below for the A5 page dimensions.
;  - HPDF_Page_SetTextLeading is bound in hpdf.pbi so the wrapped text keeps
;    the original 20pt line spacing.
;  - the source's argv[0] + ".pdf" output is replaced with the stable filename
;    text_demo2.pdf in the current working directory.
;  - all sample text is ASCII; Helvetica/Courier-Bold are base-14 fonts.
;
; Build (from samples/):
;   MSYS2_ARG_CONV_EXCL='*' "$PUREBASIC_HOME/Compilers/pbcompilerc.exe" \
;     /CONSOLE /THREAD /EXE text_demo2.exe text_demo2.pb
; ---------------------------------------------------------------------------

EnableExplicit

XIncludeFile "../hpdf.pbi"

#PAGE_W = 419.528     ; A5 portrait
#PAGE_H = 595.276

; grid_sheet.c print_grid(), scaled to the A5 page used by text_demo2.c.
Procedure PrintGrid(page.i)
  Protected x.l
  Protected y.l

  ; The caller selects Helvetica at 5pt before drawing grid labels.
  HPDF_Page_SetGrayFill(page, 0.5)
  HPDF_Page_SetGrayStroke(page, 0.8)

  y = 0
  While y < #PAGE_H
    If y % 10 = 0
      HPDF_Page_SetLineWidth(page, 0.5)
    Else
      HPDF_Page_SetLineWidth(page, 0.25)
    EndIf
    HPDF_Page_MoveTo(page, 0, y)
    HPDF_Page_LineTo(page, #PAGE_W, y)
    HPDF_Page_Stroke(page)

    If y % 10 = 0 And y > 0
      HPDF_Page_SetGrayStroke(page, 0.5)
      HPDF_Page_MoveTo(page, 0, y)
      HPDF_Page_LineTo(page, 5, y)
      HPDF_Page_Stroke(page)
      HPDF_Page_SetGrayStroke(page, 0.8)
    EndIf
    y + 5
  Wend

  x = 0
  While x < #PAGE_W
    If x % 10 = 0
      HPDF_Page_SetLineWidth(page, 0.5)
    Else
      HPDF_Page_SetLineWidth(page, 0.25)
    EndIf
    HPDF_Page_MoveTo(page, x, 0)
    HPDF_Page_LineTo(page, x, #PAGE_H)
    HPDF_Page_Stroke(page)

    If x % 50 = 0 And x > 0
      HPDF_Page_SetGrayStroke(page, 0.5)
      HPDF_Page_MoveTo(page, x, 0)
      HPDF_Page_LineTo(page, x, 5)
      HPDF_Page_Stroke(page)
      HPDF_Page_MoveTo(page, x, #PAGE_H)
      HPDF_Page_LineTo(page, x, #PAGE_H - 5)
      HPDF_Page_Stroke(page)
      HPDF_Page_SetGrayStroke(page, 0.8)
    EndIf
    x + 5
  Wend

  y = 0
  While y < #PAGE_H
    If y % 10 = 0 And y > 0
      HPDF_Page_BeginText(page)
      HPDF_Page_MoveTextPos(page, 5, y - 2)
      HPDF_Page_ShowText(page, Str(y))
      HPDF_Page_EndText(page)
    EndIf
    y + 5
  Wend

  x = 0
  While x < #PAGE_W
    If x % 50 = 0 And x > 0
      HPDF_Page_BeginText(page)
      HPDF_Page_MoveTextPos(page, x, 5)
      HPDF_Page_ShowText(page, Str(x))
      HPDF_Page_EndText(page)
      HPDF_Page_BeginText(page)
      HPDF_Page_MoveTextPos(page, x, #PAGE_H - 10)
      HPDF_Page_ShowText(page, Str(x))
      HPDF_Page_EndText(page)
    EndIf
    x + 5
  Wend

  HPDF_Page_SetGrayFill(page, 0)
  HPDF_Page_SetGrayStroke(page, 0)
EndProcedure

; Draw one outlined text rectangle, its alignment title, and its sample copy.
Procedure DrawTextRect(page.i, font.i, left.f, top.f, right.f, bottom.f, label$, align.l, text$)
  HPDF_Page_Rectangle(page, left, bottom, right - left, top - bottom)
  HPDF_Page_Stroke(page)

  HPDF_Page_BeginText(page)
  HPDF_Page_SetFontAndSize(page, font, 10)
  HPDF_Page_TextOut(page, left, top + 3, label$)
  HPDF_Page_SetFontAndSize(page, font, 13)
  HPDF_Page_TextRect(page, left, top, right, bottom, text$, align, 0)
  HPDF_Page_EndText(page)
EndProcedure

OpenConsole()

CompilerIf #PB_Compiler_OS = #PB_OS_Linux
  If HaruInit() = 0
    If HaruInit("../libraries/linux/x64/") = 0
      PrintN("FAIL init (libhpdf.so not loadable - install libharu or place it in ../libraries/linux/x64/)")
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
  HaruShutdown()
  End 1
EndIf

Define page.i = HaruAddPage(pdf)
If page = 0
  PrintN("FAIL page (HaruAddPage) " + HaruErrorText(pdf))
  HaruFree(pdf)
  HaruShutdown()
  End 1
EndIf
If HPDF_Page_SetSize(page, #HPDF_PAGE_SIZE_A5, #HPDF_PAGE_PORTRAIT) <> #HPDF_OK
  PrintN("FAIL page size " + HaruErrorText(pdf))
  HaruFree(pdf)
  HaruShutdown()
  End 1
EndIf

Define font.i = HPDF_GetFont(pdf, "Helvetica", "WinAnsiEncoding")
If font = 0
  PrintN("FAIL font (GetFont Helvetica) " + HaruErrorText(pdf))
  HaruFree(pdf)
  HaruShutdown()
  End 1
EndIf

; Grid labels use the same base-14 font as the example content.
HPDF_Page_SetFontAndSize(page, font, 5)
PrintGrid(page)
HPDF_Page_SetTextLeading(page, 20)

Define sampText$ = "The quick brown fox jumps over the lazy dog. "
Define rectTop.f = 545
Define rectBottom.f = rectTop - 40

; Four text-rectangle alignments.
DrawTextRect(page, font, 25, rectTop, 200, rectBottom, "HPDF_TALIGN_LEFT", #HPDF_TALIGN_LEFT, sampText$)
DrawTextRect(page, font, 220, rectTop, 395, rectBottom, "HPDF_TALIGN_RIGHT", #HPDF_TALIGN_RIGHT, sampText$)
DrawTextRect(page, font, 25, 475, 200, 435, "HPDF_TALIGN_CENTER", #HPDF_TALIGN_CENTER, sampText$)
DrawTextRect(page, font, 220, 475, 395, 435, "HPDF_TALIGN_JUSTIFY", #HPDF_TALIGN_JUSTIFY, sampText$)

; Skewed coordinate system.
Define angle1.f = 5
Define angle2.f = 10
Define rad1.f = angle1 / 180 * #PI
Define rad2.f = angle2 / 180 * #PI
HPDF_Page_GSave(page)
HPDF_Page_Concat(page, 1, Tan(rad1), Tan(rad2), 1, 25, 350)
HPDF_Page_Rectangle(page, 0, 0, 175, 40)
HPDF_Page_Stroke(page)
HPDF_Page_BeginText(page)
HPDF_Page_SetFontAndSize(page, font, 10)
HPDF_Page_TextOut(page, 0, 43, "Skewed coordinate system")
HPDF_Page_SetFontAndSize(page, font, 13)
HPDF_Page_TextRect(page, 0, 40, 175, 0, sampText$, #HPDF_TALIGN_LEFT, 0)
HPDF_Page_EndText(page)
HPDF_Page_GRestore(page)

; Rotated coordinate system.
angle1 = 5
rad1 = angle1 / 180 * #PI
HPDF_Page_GSave(page)
HPDF_Page_Concat(page, Cos(rad1), Sin(rad1), -Sin(rad1), Cos(rad1), 220, 350)
HPDF_Page_Rectangle(page, 0, 0, 175, 40)
HPDF_Page_Stroke(page)
HPDF_Page_BeginText(page)
HPDF_Page_SetFontAndSize(page, font, 10)
HPDF_Page_TextOut(page, 0, 43, "Rotated coordinate system")
HPDF_Page_SetFontAndSize(page, font, 13)
HPDF_Page_TextRect(page, 0, 40, 175, 0, sampText$, #HPDF_TALIGN_LEFT, 0)
HPDF_Page_EndText(page)
HPDF_Page_GRestore(page)

; Text placed character-by-character around a circle.
HPDF_Page_SetGrayStroke(page, 0)
HPDF_Page_Circle(page, 210, 190, 145)
HPDF_Page_Circle(page, 210, 190, 113)
HPDF_Page_Stroke(page)

Define angleStep.f = 360 / Len(sampText$)
Define angle2.f = 180
Define i.i
Define x.f
Define y.f
Define courier.i = HPDF_GetFont(pdf, "Courier-Bold", "WinAnsiEncoding")
If courier = 0
  PrintN("FAIL font (GetFont Courier-Bold) " + HaruErrorText(pdf))
  HaruFree(pdf)
  HaruShutdown()
  End 1
EndIf

HPDF_Page_BeginText(page)
HPDF_Page_SetFontAndSize(page, courier, 30)
For i = 0 To Len(sampText$) - 1
  rad1 = (angle2 - 90) / 180 * #PI
  rad2 = angle2 / 180 * #PI
  x = 210 + Cos(rad2) * 122
  y = 190 + Sin(rad2) * 122
  HPDF_Page_SetTextMatrix(page, Cos(rad1), Sin(rad1), -Sin(rad1), Cos(rad1), x, y)
  HPDF_Page_ShowText(page, Mid(sampText$, i + 1, 1))
  angle2 - angleStep
Next i
HPDF_Page_EndText(page)

If HPDF_GetError(pdf) <> #HPDF_OK
  PrintN("FAIL draw (latched error) " + HaruErrorText(pdf))
  HaruFree(pdf)
  HaruShutdown()
  End 1
EndIf

If HPDF_SaveToFile(pdf, "text_demo2.pdf") <> #HPDF_OK
  PrintN("FAIL save " + HaruErrorText(pdf))
  HaruFree(pdf)
  HaruShutdown()
  End 1
EndIf

HaruFree(pdf)
HaruShutdown()
PrintN("PASS text_demo2 -> text_demo2.pdf")
CloseConsole()
End 0

; IDE Options = PureBasic 6.40 (Windows - x64)
; ExecutableFormat = Console
; EnableXP
; DPIAware
