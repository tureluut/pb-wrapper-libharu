; ---------------------------------------------------------------------------
; slide_show_demo.pb - PureBasic port of libharu's slide_show_demo.c
; (<< Haru Free PDF Library 2.0.6 >>, Copyright (c) 1999-2006 Takeshi Kanno,
; ZLIB license - see ../THIRD-PARTY-NOTICES.md).
; 17 pages 800x600, one per HPDF_TS_* transition style (WIPE_RIGHT .. REPLACE),
; random full-page background color, caption + "Ctrl+L" hint in inverse color
; (compressed 0.8 x-scale text matrix), SetSlideShow(5.0, 1.0) per page,
; Next=>/<=Prev INVERT_BOX link annotations between neighbors, document in
; FULL_SCREEN page mode.
;
; Deviations from the C original (wrapper subset, see ../hpdf.pbi):
;  - no setjmp/longjmp error handler: libharu latches the first error, so the
;    drawing is gated by one HPDF_GetError check before the save;
;  - the C's HPDF_GetFont(pdf, "Courier", NULL) (NULL = font default
;    encoding) becomes HaruGetFont(pdf, "Courier", "") - a real C NULL
;    through the raw binding; all text is ASCII;
;  - C rand()/(RAND_MAX+1.0) (deterministic without srand) becomes PB
;    Random()/2^31 - same [0,1) range, different (and seeded) values;
;  - the C's by-value HPDF_Rect argument passes as a pointer to an HPDFRect
;    struct (Win64 ABI: struct args > 8 bytes by reference);
;  - argv[0] + ".pdf" output replaced with the stable filename
;    slide_show_demo.pdf.
;
; Build (from samples/):
;   MSYS2_ARG_CONV_EXCL='*' "$PUREBASIC_HOME/Compilers/pbcompilerc.exe" \
;     /CONSOLE /THREAD /EXE slide_show_demo.exe slide_show_demo.pb
; ---------------------------------------------------------------------------

EnableExplicit

XIncludeFile "../hpdf.pbi"

; slide_show_demo.c print_page(): one 800x600 slide.
Procedure PrintPage(page.i, caption$, font.i, style.l, prevPage.i, nextPage.i)
  Protected r.f = Random(2147483647) / 2147483648.0   ; C: rand() / (RAND_MAX + 1.0)
  Protected g.f = Random(2147483647) / 2147483648.0
  Protected b.f = Random(2147483647) / 2147483648.0
  Protected rect.HPDFRect
  Protected dst.i
  Protected annot.i

  HPDF_Page_SetWidth(page, 800)
  HPDF_Page_SetHeight(page, 600)

  HPDF_Page_SetRGBFill(page, r, g, b)

  HPDF_Page_Rectangle(page, 0, 0, 800, 600)
  HPDF_Page_Fill(page)

  HPDF_Page_SetRGBFill(page, 1.0 - r, 1.0 - g, 1.0 - b)

  HPDF_Page_SetFontAndSize(page, font, 30)

  HPDF_Page_BeginText(page)
  HPDF_Page_SetTextMatrix(page, 0.8, 0, 0, 1.0, 0, 0)
  HPDF_Page_TextOut(page, 50, 530, caption$)

  HPDF_Page_SetTextMatrix(page, 1.0, 0, 0, 1.0, 0, 0)
  HPDF_Page_SetFontAndSize(page, font, 20)
  HPDF_Page_TextOut(page, 55, 300, ~"Type \"Ctrl+L\" in order to return from full screen mode.")
  HPDF_Page_EndText(page)

  HPDF_Page_SetSlideShow(page, style, 5.0, 1.0)

  HPDF_Page_SetFontAndSize(page, font, 20)

  If nextPage
    HPDF_Page_BeginText(page)
    HPDF_Page_TextOut(page, 680, 50, "Next=>")
    HPDF_Page_EndText(page)

    rect\left = 680
    rect\right = 750
    rect\top = 70
    rect\bottom = 50
    dst = HPDF_Page_CreateDestination(nextPage)
    HPDF_Destination_SetFit(dst)
    annot = HPDF_Page_CreateLinkAnnot(page, @rect, dst)
    HPDF_LinkAnnot_SetBorderStyle(annot, 0, 0, 0)
    HPDF_LinkAnnot_SetHighlightMode(annot, #HPDF_ANNOT_INVERT_BOX)
  EndIf

  If prevPage
    HPDF_Page_BeginText(page)
    HPDF_Page_TextOut(page, 50, 50, "<=Prev")
    HPDF_Page_EndText(page)

    rect\left = 50
    rect\right = 110
    rect\top = 70
    rect\bottom = 50
    dst = HPDF_Page_CreateDestination(prevPage)
    HPDF_Destination_SetFit(dst)
    annot = HPDF_Page_CreateLinkAnnot(page, @rect, dst)
    HPDF_LinkAnnot_SetBorderStyle(annot, 0, 0, 0)
    HPDF_LinkAnnot_SetHighlightMode(annot, #HPDF_ANNOT_INVERT_BOX)
  EndIf
EndProcedure

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

; create default-font
Define font.i = HaruGetFont(pdf, "Courier", "")
If font = 0
  PrintN("FAIL font (GetFont Courier) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

; Add 17 pages to the document.
Dim page.i(16)
Define i.l
For i = 0 To 16
  page(i) = HPDF_AddPage(pdf)
  If page(i) = 0
    PrintN("FAIL page " + Str(i) + " " + HaruErrorText(pdf))
    HaruFree(pdf)
    End 1
  EndIf
Next

PrintPage(page(0), "HPDF_TS_WIPE_RIGHT", font, #HPDF_TS_WIPE_RIGHT, 0, page(1))
PrintPage(page(1), "HPDF_TS_WIPE_UP", font, #HPDF_TS_WIPE_UP, page(0), page(2))
PrintPage(page(2), "HPDF_TS_WIPE_LEFT", font, #HPDF_TS_WIPE_LEFT, page(1), page(3))
PrintPage(page(3), "HPDF_TS_WIPE_DOWN", font, #HPDF_TS_WIPE_DOWN, page(2), page(4))
PrintPage(page(4), "HPDF_TS_BARN_DOORS_HORIZONTAL_OUT", font, #HPDF_TS_BARN_DOORS_HORIZONTAL_OUT, page(3), page(5))
PrintPage(page(5), "HPDF_TS_BARN_DOORS_HORIZONTAL_IN", font, #HPDF_TS_BARN_DOORS_HORIZONTAL_IN, page(4), page(6))
PrintPage(page(6), "HPDF_TS_BARN_DOORS_VERTICAL_OUT", font, #HPDF_TS_BARN_DOORS_VERTICAL_OUT, page(5), page(7))
PrintPage(page(7), "HPDF_TS_BARN_DOORS_VERTICAL_IN", font, #HPDF_TS_BARN_DOORS_VERTICAL_IN, page(6), page(8))
PrintPage(page(8), "HPDF_TS_BOX_OUT", font, #HPDF_TS_BOX_OUT, page(7), page(9))
PrintPage(page(9), "HPDF_TS_BOX_IN", font, #HPDF_TS_BOX_IN, page(8), page(10))
PrintPage(page(10), "HPDF_TS_BLINDS_HORIZONTAL", font, #HPDF_TS_BLINDS_HORIZONTAL, page(9), page(11))
PrintPage(page(11), "HPDF_TS_BLINDS_VERTICAL", font, #HPDF_TS_BLINDS_VERTICAL, page(10), page(12))
PrintPage(page(12), "HPDF_TS_DISSOLVE", font, #HPDF_TS_DISSOLVE, page(11), page(13))
PrintPage(page(13), "HPDF_TS_GLITTER_RIGHT", font, #HPDF_TS_GLITTER_RIGHT, page(12), page(14))
PrintPage(page(14), "HPDF_TS_GLITTER_DOWN", font, #HPDF_TS_GLITTER_DOWN, page(13), page(15))
PrintPage(page(15), "HPDF_TS_GLITTER_TOP_LEFT_TO_BOTTOM_RIGHT", font, #HPDF_TS_GLITTER_TOP_LEFT_TO_BOTTOM_RIGHT, page(14), page(16))
PrintPage(page(16), "HPDF_TS_REPLACE", font, #HPDF_TS_REPLACE, page(15), 0)

HPDF_SetPageMode(pdf, #HPDF_PAGE_MODE_FULL_SCREEN)

; --- gate + save ---------------------------------------------------------------
If HPDF_GetError(pdf) <> #HPDF_OK
  PrintN("FAIL draw (latched error) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

If HPDF_SaveToFile(pdf, "slide_show_demo.pdf") <> #HPDF_OK
  PrintN("FAIL save " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
HaruFree(pdf)
PrintN("PASS slide_show_demo -> slide_show_demo.pdf")

HaruShutdown()
CloseConsole()
End 0

; IDE Options = PureBasic 6.40 (Windows - x64)
; ExecutableFormat = Console
; EnableXP
; DPIAware
