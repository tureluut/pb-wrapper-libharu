; ---------------------------------------------------------------------------
; text_demo.pb - port of libharu's text_demo.c + its grid_sheet.c companion
; (<< Haru Free PDF Library 2.0.0 >>, Copyright (c) 1999-2006 Takeshi Kanno,
; ZLIB license - see ../THIRD-PARTY-NOTICES.md). Exercises the text render
; surface of hpdf.pbi: font sizes, MeasureText truncation, rainbow fill
; colors, the six text rendering modes (fill/stroke/clipping + stripe
; pattern), text matrices (rotation, skew, X/Y scaling), char/word spacing,
; and the coordinate grid from grid_sheet.c's print_grid().
;
; Deviations from the C original (wrapper subset, see hpdf.pbi):
;  - no setjmp/longjmp error handler: libharu latches the first error, so the
;    drawing is gated by one HPDF_GetError check before the save;
;  - page geometry: HaruAddPage() fixes A4 portrait and the wrapper binds no
;    HPDF_Page_GetWidth/GetHeight, so the exact A4 values libharu writes
;    (MediaBox "595.276 841.89001") are used as constants;
;  - show_description(): the C version queries the page state
;    (GetCurrentFont/GetCurrentFontSize/GetRGBFill) to restore it after the
;    black 10pt label. GetRGBFill returns a struct BY VALUE - banned in this
;    wrapper - so the label is bracketed in GSave/GRestore instead: PDF q/Q
;    restores fill color, font, size and rendering mode identically (every
;    call site in this demo runs with mode = HPDF_FILL, so nothing changes);
;  - grid_sheet: HPDF_Page_GetLineWidth is not bound, so print_grid sets the
;    0.25 width unconditionally instead of only when it differs;
;  - text: base-14 Helvetica with "WinAnsiEncoding" (the C passes NULL =
;    default encoding) - every string is pure ASCII, so the byte
;    pass-through of single-byte fonts is identical either way;
;  - snprintf("%u"/"%.0f") -> Str()/StrF().
;
; Build (from samples/):
;   MSYS2_ARG_CONV_EXCL='*' "$PUREBASIC_HOME/Compilers/pbcompilerc.exe" \
;     /CONSOLE /THREAD /EXE text_demo.exe text_demo.pb
; ---------------------------------------------------------------------------

EnableExplicit

XIncludeFile "../hpdf.pbi"

#PAGE_W = 595.276     ; A4 portrait, fixed by HaruAddPage()
#PAGE_H = 841.89001

; grid_sheet.c print_grid(): 5pt coordinate grid over the whole page, major
; lines every 10pt (horizontal labels) / 50pt (vertical labels + edge ticks)
Procedure PrintGrid(pdf.i, page.i)
  Protected font.i = HPDF_GetFont(pdf, "Helvetica", "WinAnsiEncoding")
  Protected x.l
  Protected y.l

  HPDF_Page_SetFontAndSize(page, font, 5)
  HPDF_Page_SetGrayFill(page, 0.5)
  HPDF_Page_SetGrayStroke(page, 0.8)

  ; Draw horizontal lines
  y = 0
  While y < #PAGE_H
    If y % 10 = 0
      HPDF_Page_SetLineWidth(page, 0.5)
    Else
      HPDF_Page_SetLineWidth(page, 0.25)  ; C: only when GetLineWidth() <> 0.25
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

  ; Draw vertical lines
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

  ; Draw horizontal text
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

  ; Draw vertical text
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

; text_demo.c show_stripe_pattern(): blue stripes under clipped text
Procedure ShowStripePattern(page.i, x.f, y.f)
  Protected iy.l = 0
  Protected w.f = HPDF_Page_TextWidth(page, "ABCabc123")

  While iy < 50
    HPDF_Page_SetRGBStroke(page, 0.0, 0.0, 0.5)
    HPDF_Page_SetLineWidth(page, 1)
    HPDF_Page_MoveTo(page, x, y + iy)
    HPDF_Page_LineTo(page, x + w, y + iy)
    HPDF_Page_Stroke(page)
    iy + 3
  Wend

  HPDF_Page_SetLineWidth(page, 2.5)
EndProcedure

; text_demo.c show_description(): black 10pt label under (x, y); the current
; graphics state (fill color, font, size, rendering mode) is saved/restored
; with q/Q - see the deviation notes in the header.
Procedure ShowDescription(page.i, font.i, x.f, y.f, text$)
  HPDF_Page_GSave(page)

  HPDF_Page_BeginText(page)
  HPDF_Page_SetRGBFill(page, 0, 0, 0)
  HPDF_Page_SetTextRenderingMode(page, #HPDF_FILL)
  HPDF_Page_SetFontAndSize(page, font, 10)
  HPDF_Page_TextOut(page, x, y - 12, text$)
  HPDF_Page_EndText(page)

  HPDF_Page_GRestore(page)
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

; set compression mode
If HPDF_SetCompressionMode(pdf, #HPDF_COMP_ALL) <> #HPDF_OK
  PrintN("FAIL compression mode " + HaruErrorText(pdf))
  HaruFree(pdf)
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

; draw grid to the page
PrintGrid(pdf, page)

; --- page title (positioning center) --------------------------------------------
Define tw.f
Define tlen.l
Define i.l

HPDF_Page_SetFontAndSize(page, font, 24)
tw = HPDF_Page_TextWidth(page, "Text Demo")
HPDF_Page_BeginText(page)
HPDF_Page_TextOut(page, (#PAGE_W - tw) / 2, #PAGE_H - 50, "Text Demo")
HPDF_Page_EndText(page)

HPDF_Page_BeginText(page)
HPDF_Page_MoveTextPos(page, 60, #PAGE_H - 60)

; --- font size --------------------------------------------------------------------
Define sampText$  = "abcdefgABCDEFG123!#$%&+-@?"
Define fsize.f = 8
While fsize < 60
  ; set style and size of font
  HPDF_Page_SetFontAndSize(page, font, fsize)

  ; set the position of the text
  HPDF_Page_MoveTextPos(page, 0, -5 - fsize)

  ; measure the number of characters which included in the page, truncate
  tlen = HPDF_Page_MeasureText(page, sampText$, #PAGE_W - 120, #HPDF_FALSE, 0)
  HPDF_Page_ShowText(page, Left(sampText$, tlen))

  ; print the description
  HPDF_Page_MoveTextPos(page, 0, -10)
  HPDF_Page_SetFontAndSize(page, font, 8)
  HPDF_Page_ShowText(page, "Fontsize=" + StrF(fsize, 0))

  fsize * 1.5
Wend

; --- font color ----------------------------------------------------------------------
HPDF_Page_SetFontAndSize(page, font, 8)
HPDF_Page_MoveTextPos(page, 0, -30)
HPDF_Page_ShowText(page, "Font color")

HPDF_Page_SetFontAndSize(page, font, 18)
HPDF_Page_MoveTextPos(page, 0, -20)
tlen = Len(sampText$)
For i = 1 To tlen
  HPDF_Page_SetRGBFill(page, (i - 1) / tlen, 1 - (i - 1) / tlen, 0.0)
  HPDF_Page_ShowText(page, Mid(sampText$, i, 1))
Next
HPDF_Page_MoveTextPos(page, 0, -25)

For i = 1 To tlen
  HPDF_Page_SetRGBFill(page, (i - 1) / tlen, 0.0, 1 - (i - 1) / tlen)
  HPDF_Page_ShowText(page, Mid(sampText$, i, 1))
Next
HPDF_Page_MoveTextPos(page, 0, -25)

For i = 1 To tlen
  HPDF_Page_SetRGBFill(page, 0.0, 1 - (i - 1) / tlen, (i - 1) / tlen)
  HPDF_Page_ShowText(page, Mid(sampText$, i, 1))
Next

HPDF_Page_EndText(page)

Define ypos.f = 450

; --- font rendering mode ---------------------------------------------------------------
HPDF_Page_SetFontAndSize(page, font, 32)
HPDF_Page_SetRGBFill(page, 0.5, 0.5, 0.0)
HPDF_Page_SetLineWidth(page, 1.5)

; HPDF_FILL
ShowDescription(page, font, 60, ypos, "RenderingMode=PDF_FILL")
HPDF_Page_SetTextRenderingMode(page, #HPDF_FILL)
HPDF_Page_BeginText(page)
HPDF_Page_TextOut(page, 60, ypos, "ABCabc123")
HPDF_Page_EndText(page)

; HPDF_STROKE
ShowDescription(page, font, 60, ypos - 50, "RenderingMode=PDF_STROKE")
HPDF_Page_SetTextRenderingMode(page, #HPDF_STROKE)
HPDF_Page_BeginText(page)
HPDF_Page_TextOut(page, 60, ypos - 50, "ABCabc123")
HPDF_Page_EndText(page)

; HPDF_FILL_THEN_STROKE
ShowDescription(page, font, 60, ypos - 100, "RenderingMode=PDF_FILL_THEN_STROKE")
HPDF_Page_SetTextRenderingMode(page, #HPDF_FILL_THEN_STROKE)
HPDF_Page_BeginText(page)
HPDF_Page_TextOut(page, 60, ypos - 100, "ABCabc123")
HPDF_Page_EndText(page)

; HPDF_FILL_CLIPPING
ShowDescription(page, font, 60, ypos - 150, "RenderingMode=PDF_FILL_CLIPPING")
HPDF_Page_GSave(page)
HPDF_Page_SetTextRenderingMode(page, #HPDF_FILL_CLIPPING)
HPDF_Page_BeginText(page)
HPDF_Page_TextOut(page, 60, ypos - 150, "ABCabc123")
HPDF_Page_EndText(page)
ShowStripePattern(page, 60, ypos - 150)
HPDF_Page_GRestore(page)

; HPDF_STROKE_CLIPPING
ShowDescription(page, font, 60, ypos - 200, "RenderingMode=PDF_STROKE_CLIPPING")
HPDF_Page_GSave(page)
HPDF_Page_SetTextRenderingMode(page, #HPDF_STROKE_CLIPPING)
HPDF_Page_BeginText(page)
HPDF_Page_TextOut(page, 60, ypos - 200, "ABCabc123")
HPDF_Page_EndText(page)
ShowStripePattern(page, 60, ypos - 200)
HPDF_Page_GRestore(page)

; HPDF_FILL_STROKE_CLIPPING
ShowDescription(page, font, 60, ypos - 250, "RenderingMode=PDF_FILL_STROKE_CLIPPING")
HPDF_Page_GSave(page)
HPDF_Page_SetTextRenderingMode(page, #HPDF_FILL_STROKE_CLIPPING)
HPDF_Page_BeginText(page)
HPDF_Page_TextOut(page, 60, ypos - 250, "ABCabc123")
HPDF_Page_EndText(page)
ShowStripePattern(page, 60, ypos - 250)
HPDF_Page_GRestore(page)

; reset text attributes
HPDF_Page_SetTextRenderingMode(page, #HPDF_FILL)
HPDF_Page_SetRGBFill(page, 0, 0, 0)
HPDF_Page_SetFontAndSize(page, font, 30)

; --- rotating text ----------------------------------------------------------------------
Define angle1.f = 30                    ; a rotation of 30 degrees
Define angle2.f
Define rad1.f = angle1 / 180 * 3.141592 ; calculate the radian value
Define rad2.f

ShowDescription(page, font, 320, ypos - 60, "Rotating text")
HPDF_Page_BeginText(page)
HPDF_Page_SetTextMatrix(page, Cos(rad1), Sin(rad1), -Sin(rad1), Cos(rad1), 330, ypos - 60)
HPDF_Page_ShowText(page, "ABCabc123")
HPDF_Page_EndText(page)

; --- skewing text -------------------------------------------------------------------------
ShowDescription(page, font, 320, ypos - 120, "Skewing text")
HPDF_Page_BeginText(page)

angle1 = 10
angle2 = 20
rad1 = angle1 / 180 * 3.141592
rad2 = angle2 / 180 * 3.141592

HPDF_Page_SetTextMatrix(page, 1, Tan(rad1), Tan(rad2), 1, 320, ypos - 120)
HPDF_Page_ShowText(page, "ABCabc123")
HPDF_Page_EndText(page)

; --- scaling text (X direction) -------------------------------------------------------------
ShowDescription(page, font, 320, ypos - 175, "Scaling text (X direction)")
HPDF_Page_BeginText(page)
HPDF_Page_SetTextMatrix(page, 1.5, 0, 0, 1, 320, ypos - 175)
HPDF_Page_ShowText(page, "ABCabc12")
HPDF_Page_EndText(page)

; --- scaling text (Y direction) ---------------------------------------------------------------
ShowDescription(page, font, 320, ypos - 250, "Scaling text (Y direction)")
HPDF_Page_BeginText(page)
HPDF_Page_SetTextMatrix(page, 1, 0, 0, 2, 320, ypos - 250)
HPDF_Page_ShowText(page, "ABCabc123")
HPDF_Page_EndText(page)

; --- char spacing, word spacing ------------------------------------------------------------------
ShowDescription(page, font, 60, 140, "char-spacing 0")
ShowDescription(page, font, 60, 100, "char-spacing 1.5")
ShowDescription(page, font, 60, 60, "char-spacing 1.5, word-spacing 2.5")

HPDF_Page_SetFontAndSize(page, font, 20)
HPDF_Page_SetRGBFill(page, 0.1, 0.3, 0.1)

; char-spacing 0
HPDF_Page_BeginText(page)
HPDF_Page_TextOut(page, 60, 140, "The quick brown fox jumps over the lazy dog.")
HPDF_Page_EndText(page)

; char-spacing 1.5
HPDF_Page_SetCharSpace(page, 1.5)
HPDF_Page_BeginText(page)
HPDF_Page_TextOut(page, 60, 100, "The quick brown fox jumps over the lazy dog.")
HPDF_Page_EndText(page)

; char-spacing 1.5, word-spacing 2.5
HPDF_Page_SetWordSpace(page, 2.5)
HPDF_Page_BeginText(page)
HPDF_Page_TextOut(page, 60, 60, "The quick brown fox jumps over the lazy dog.")
HPDF_Page_EndText(page)

; --- gate + save ----------------------------------------------------------------------------
; libharu latches the first error; one check covers every draw call above
; (the C original's setjmp/longjmp error handler equivalent).
If HPDF_GetError(pdf) <> #HPDF_OK
  PrintN("FAIL draw (latched error) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

If HPDF_SaveToFile(pdf, "text_demo.pdf") <> #HPDF_OK
  PrintN("FAIL save " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
HaruFree(pdf)
PrintN("PASS text_demo -> text_demo.pdf")

HaruShutdown()
CloseConsole()
End 0

; IDE Options = PureBasic 6.40 (Windows - x64)
; ExecutableFormat = Console
; EnableXP
; DPIAware
