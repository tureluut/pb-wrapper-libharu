; ---------------------------------------------------------------------------
; link_annotation.pb - PureBasic port of libharu's link_annotation.c
; (<< Haru Free PDF Library 2.0.0 >>, Copyright (c) 1999-2006 Takeshi Kanno,
; ZLIB license - see ../THIRD-PARTY-NOTICES.md).
; A 300x220 index page plus seven 200x200 pages ("Page:1..7"). The index page
; holds eight link annotations: four highlight modes (NO_HIGHTLIGHT,
; INVERT_BOX, INVERT_BORDER, DOWN_APPEARANCE), three border styles (dash,
; none, bold) and one URI link to http://libharu.org. Every annotation rect
; is derived from the text position before/after the label (4pt margins,
; 10pt height).
;
; Deviations from the C original (wrapper subset, see ../hpdf.pbi):
;  - no setjmp/longjmp error handler: libharu latches the first error, so the
;    drawing is gated by one HPDF_GetError check before the save;
;  - HPDF_Page_GetCurrentTextPos() returns a struct BY VALUE (banned in the
;    wrapper); the port uses the documented out-parameter variant
;    HPDF_Page_GetCurrentTextPos2() into an HPDFPoint - identical values;
;  - the C's by-value HPDF_Rect argument passes as a pointer to an HPDFRect
;    struct (Win64 ABI: struct args > 8 bytes by reference);
;  - the C's HPDF_GetFont(pdf, "Helvetica", NULL) (NULL = font default
;    encoding) becomes HaruGetFont(pdf, "Helvetica", ""); all text is ASCII;
;  - argv[0] + ".pdf" output replaced with the stable filename
;    link_annotation.pdf.
;
; Build (from samples/):
;   MSYS2_ARG_CONV_EXCL='*' "$PUREBASIC_HOME/Compilers/pbcompilerc.exe" \
;     /CONSOLE /THREAD /EXE link_annotation.exe link_annotation.pb
; ---------------------------------------------------------------------------

EnableExplicit

XIncludeFile "../hpdf.pbi"

; link_annotation.c print_page(): "Page:<n>" at (50, 150), 20pt.
Procedure PrintPage(page.i, font.i, pageNum.l)
  HPDF_Page_SetWidth(page, 200)
  HPDF_Page_SetHeight(page, 200)

  HPDF_Page_SetFontAndSize(page, font, 20)

  HPDF_Page_BeginText(page)
  HPDF_Page_MoveTextPos(page, 50, 150)
  HPDF_Page_ShowText(page, "Page:" + Str(pageNum))
  HPDF_Page_EndText(page)
EndProcedure

; One index-page entry: query the text position, show the label, build the
; annotation rect around it, advance to the next (23pt leading) line.
; Returns the annotation handle (0 for the URI variant, which is created by
; the caller).
Procedure.i IndexEntry(page.i, label$, *rect.HPDFRect)
  Dim tp.HPDFPoint(0)
  Dim tp2.HPDFPoint(0)

  HPDF_Page_GetCurrentTextPos2(page, @tp(0))
  HPDF_Page_ShowText(page, label$)
  HPDF_Page_GetCurrentTextPos2(page, @tp2(0))

  *rect\left = tp(0)\x - 4
  *rect\bottom = tp(0)\y - 4
  *rect\right = tp2(0)\x + 4
  *rect\top = tp(0)\y + 10

  HPDF_Page_MoveToNextLine(page)
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
Define font.i = HaruGetFont(pdf, "Helvetica", "")
If font = 0
  PrintN("FAIL font (GetFont Helvetica) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

; create index page
Define indexPage.i = HPDF_AddPage(pdf)
If indexPage = 0
  PrintN("FAIL page " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
HPDF_Page_SetWidth(indexPage, 300)
HPDF_Page_SetHeight(indexPage, 220)

; Add 7 pages to the document.
Dim page.i(6)
Define i.l
For i = 0 To 6
  page(i) = HPDF_AddPage(pdf)
  If page(i) = 0
    PrintN("FAIL page " + Str(i) + " " + HaruErrorText(pdf))
    HaruFree(pdf)
    End 1
  EndIf
  PrintPage(page(i), font, i + 1)
Next

HPDF_Page_BeginText(indexPage)
HPDF_Page_SetFontAndSize(indexPage, font, 10)
HPDF_Page_MoveTextPos(indexPage, 15, 200)
HPDF_Page_ShowText(indexPage, "Link Annotation Demo")
HPDF_Page_EndText(indexPage)

;
; Create Link-Annotation object on index page.
;
HPDF_Page_BeginText(indexPage)
HPDF_Page_SetFontAndSize(indexPage, font, 8)
HPDF_Page_MoveTextPos(indexPage, 20, 180)
HPDF_Page_SetTextLeading(indexPage, 23)

Define rect.HPDFRect
Define dst.i
Define annot.i

; page1 (HPDF_ANNOT_NO_HIGHTLIGHT)
IndexEntry(indexPage, "Jump to Page1 (HilightMode=HPDF_ANNOT_NO_HIGHTLIGHT)", rect)
dst = HPDF_Page_CreateDestination(page(0))
annot = HPDF_Page_CreateLinkAnnot(indexPage, @rect, dst)
HPDF_LinkAnnot_SetHighlightMode(annot, #HPDF_ANNOT_NO_HIGHTLIGHT)

; page2 (HPDF_ANNOT_INVERT_BOX)
IndexEntry(indexPage, "Jump to Page2 (HilightMode=HPDF_ANNOT_INVERT_BOX)", rect)
dst = HPDF_Page_CreateDestination(page(1))
annot = HPDF_Page_CreateLinkAnnot(indexPage, @rect, dst)
HPDF_LinkAnnot_SetHighlightMode(annot, #HPDF_ANNOT_INVERT_BOX)

; page3 (HPDF_ANNOT_INVERT_BORDER)
IndexEntry(indexPage, "Jump to Page3 (HilightMode=HPDF_ANNOT_INVERT_BORDER)", rect)
dst = HPDF_Page_CreateDestination(page(2))
annot = HPDF_Page_CreateLinkAnnot(indexPage, @rect, dst)
HPDF_LinkAnnot_SetHighlightMode(annot, #HPDF_ANNOT_INVERT_BORDER)

; page4 (HPDF_ANNOT_DOWN_APPEARANCE)
IndexEntry(indexPage, "Jump to Page4 (HilightMode=HPDF_ANNOT_DOWN_APPEARANCE)", rect)
dst = HPDF_Page_CreateDestination(page(3))
annot = HPDF_Page_CreateLinkAnnot(indexPage, @rect, dst)
HPDF_LinkAnnot_SetHighlightMode(annot, #HPDF_ANNOT_DOWN_APPEARANCE)

; page5 (dash border)
IndexEntry(indexPage, "Jump to Page5 (dash border)", rect)
dst = HPDF_Page_CreateDestination(page(4))
annot = HPDF_Page_CreateLinkAnnot(indexPage, @rect, dst)
HPDF_LinkAnnot_SetBorderStyle(annot, 1, 3, 2)

; page6 (no border)
IndexEntry(indexPage, "Jump to Page6 (no border)", rect)
dst = HPDF_Page_CreateDestination(page(5))
annot = HPDF_Page_CreateLinkAnnot(indexPage, @rect, dst)
HPDF_LinkAnnot_SetBorderStyle(annot, 0, 0, 0)

; page7 (bold border)
IndexEntry(indexPage, "Jump to Page7 (bold border)", rect)
dst = HPDF_Page_CreateDestination(page(6))
annot = HPDF_Page_CreateLinkAnnot(indexPage, @rect, dst)
HPDF_LinkAnnot_SetBorderStyle(annot, 2, 0, 0)

; URI link
Define uri$ = "http://libharu.org"
Dim tp.HPDFPoint(0)
Dim tp2.HPDFPoint(0)
HPDF_Page_GetCurrentTextPos2(indexPage, @tp(0))

HPDF_Page_ShowText(indexPage, "URI (")
HPDF_Page_ShowText(indexPage, uri$)
HPDF_Page_ShowText(indexPage, ")")

HPDF_Page_GetCurrentTextPos2(indexPage, @tp2(0))
rect\left = tp(0)\x - 4
rect\bottom = tp(0)\y - 4
rect\right = tp2(0)\x + 4
rect\top = tp(0)\y + 10

HPDF_Page_CreateURILinkAnnot(indexPage, @rect, uri$)

HPDF_Page_EndText(indexPage)

; --- gate + save ---------------------------------------------------------------
If HPDF_GetError(pdf) <> #HPDF_OK
  PrintN("FAIL draw (latched error) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

If HPDF_SaveToFile(pdf, "link_annotation.pdf") <> #HPDF_OK
  PrintN("FAIL save " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
HaruFree(pdf)
PrintN("PASS link_annotation -> link_annotation.pdf")

HaruShutdown()
CloseConsole()
End 0

; IDE Options = PureBasic 6.40 (Windows - x64)
; ExecutableFormat = Console
; EnableXP
; DPIAware
