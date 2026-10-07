; ---------------------------------------------------------------------------
; grid_sheet.pbi - PureBasic port of libharu's grid_sheet.c (print_grid)
; (<< Haru Free PDF Library 2.0.0 >>, Copyright (c) 1999-2006 Takeshi Kanno,
; ZLIB license - see ../THIRD-PARTY-NOTICES.md).
;
; Reusable include for the sample ports: XIncludeFile "grid_sheet.pbi" and
; call PrintGrid(pdf, page) after the page exists. Page dimensions are
; queried live (HPDF_Page_GetWidth/GetHeight), so any page size works.
;
; Faithful to the C original:
;  - 5pt grid, major horizontal lines every 10pt (0.5 width, tick at the
;    left edge + y-label), major vertical lines every 10pt width with 50pt
;    edge ticks and x-labels at bottom and top;
;  - the C's "only set 0.25 when GetLineWidth() differs" branch is kept
;    (HPDF_Page_GetLineWidth is bound);
;  - labels are decimal coordinate numbers, drawn Helvetica 5pt (the C
;    requests NULL encoding = font default; all labels are ASCII digits, so
;    the default/WinAnsi byte pass-through is identical either way);
;  - gray fill/stroke reset to 0 (black) at the end.
;
; Requires HaruInit() + a doc from HaruNew() before use.
; ---------------------------------------------------------------------------

Procedure PrintGrid(pdf.i, page.i)
  Protected height.f = HPDF_Page_GetHeight(page)
  Protected width.f = HPDF_Page_GetWidth(page)
  Protected font.i = HaruGetFont(pdf, "Helvetica", "")
  Protected x.l
  Protected y.l

  HPDF_Page_SetFontAndSize(page, font, 5)
  HPDF_Page_SetGrayFill(page, 0.5)
  HPDF_Page_SetGrayStroke(page, 0.8)

  ; Draw horizontal lines
  y = 0
  While y < height
    If y % 10 = 0
      HPDF_Page_SetLineWidth(page, 0.5)
    Else
      If HPDF_Page_GetLineWidth(page) <> 0.25
        HPDF_Page_SetLineWidth(page, 0.25)
      EndIf
    EndIf

    HPDF_Page_MoveTo(page, 0, y)
    HPDF_Page_LineTo(page, width, y)
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
  While x < width
    If x % 10 = 0
      HPDF_Page_SetLineWidth(page, 0.5)
    Else
      If HPDF_Page_GetLineWidth(page) <> 0.25
        HPDF_Page_SetLineWidth(page, 0.25)
      EndIf
    EndIf

    HPDF_Page_MoveTo(page, x, 0)
    HPDF_Page_LineTo(page, x, height)
    HPDF_Page_Stroke(page)

    If x % 50 = 0 And x > 0
      HPDF_Page_SetGrayStroke(page, 0.5)

      HPDF_Page_MoveTo(page, x, 0)
      HPDF_Page_LineTo(page, x, 5)
      HPDF_Page_Stroke(page)

      HPDF_Page_MoveTo(page, x, height)
      HPDF_Page_LineTo(page, x, height - 5)
      HPDF_Page_Stroke(page)

      HPDF_Page_SetGrayStroke(page, 0.8)
    EndIf

    x + 5
  Wend

  ; Draw horizontal text
  y = 0
  While y < height
    If y % 10 = 0 And y > 0
      HPDF_Page_BeginText(page)
      HPDF_Page_MoveTextPos(page, 5, y - 2)
      HPDF_Page_ShowText(page, Str(y))    ; ASCII digits - byte-identical pass-through
      HPDF_Page_EndText(page)
    EndIf

    y + 5
  Wend

  ; Draw vertical text
  x = 0
  While x < width
    If x % 50 = 0 And x > 0
      HPDF_Page_BeginText(page)
      HPDF_Page_MoveTextPos(page, x, 5)
      HPDF_Page_ShowText(page, Str(x))
      HPDF_Page_EndText(page)

      HPDF_Page_BeginText(page)
      HPDF_Page_MoveTextPos(page, x, height - 10)
      HPDF_Page_ShowText(page, Str(x))
      HPDF_Page_EndText(page)
    EndIf

    x + 5
  Wend

  HPDF_Page_SetGrayFill(page, 0)
  HPDF_Page_SetGrayStroke(page, 0)
EndProcedure
