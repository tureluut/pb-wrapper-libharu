; ---------------------------------------------------------------------------
; outline_demo.pb - PureBasic port of libharu's outline_demo.c
; (<< Haru Free PDF Library 2.0.0 >>, Copyright (c) 1999-2006 Takeshi Kanno,
; ZLIB license - see ../THIRD-PARTY-NOTICES.md).
; Three 800x800 pages ("Page:1..3"), an open outline root with three children
; ("page1", "page2", "ISO8859-2 text ÓÔÕÖ×ØÙ" through the ISO8859-2 encoder),
; each with an XYZ destination, page mode USE_OUTLINE.
;
; Deviations from the C original (wrapper subset, see ../hpdf.pbi):
;  - no setjmp/longjmp error handler: libharu latches the first error, so the
;    drawing is gated by one HPDF_GetError check before the save;
;  - HPDF_CreateOutline takes a char* title - the wrapper binds only the raw
;    variant HPDF_CreateOutlineRaw; every title goes through HaruAsciiMem
;    (1:1 single-byte buffer). The ISO8859-2 title's accented letters are
;    built as the exact bytes D3..D9 (matching the C source's Latin-2
;    literals) and handed to libharu with the ISO8859-2 encoder, like the C;
;  - the C's HPDF_GetFont(pdf, "Helvetica", NULL) (NULL = font default
;    encoding) becomes HaruGetFont(pdf, "Helvetica", ""); all page text is
;    ASCII;
;  - the C's commented-out HPDF_Catalog_SetOpenAction stays commented out;
;  - argv[0] + ".pdf" output replaced with the stable filename
;    outline_demo.pdf.
;
; Build (from samples/):
;   MSYS2_ARG_CONV_EXCL='*' "$PUREBASIC_HOME/Compilers/pbcompilerc.exe" \
;     /CONSOLE /THREAD /EXE outline_demo.exe outline_demo.pb
; ---------------------------------------------------------------------------

EnableExplicit

XIncludeFile "../hpdf.pbi"

; HPDF_CreateOutline with a PB string title (raw char* binding + HaruAsciiMem;
; encoder 0 = the C's NULL). Title bytes are consumed synchronously.
Procedure.i CreateOutline(pdf.i, parent.i, title$, encoder.i = 0)
  Protected *title = HaruAsciiMem(title$)
  Protected outline.i = HPDF_CreateOutlineRaw(pdf, parent, *title, encoder)
  FreeMemory(*title)
  ProcedureReturn outline
EndProcedure

; outline_demo.c print_page(): "Page:<n>" at (30, 740).
Procedure PrintPage(page.i, pageNum.l)
  HPDF_Page_SetWidth(page, 800)
  HPDF_Page_SetHeight(page, 800)

  HPDF_Page_BeginText(page)
  HPDF_Page_MoveTextPos(page, 30, 740)
  HPDF_Page_ShowText(page, "Page:" + Str(pageNum))
  HPDF_Page_EndText(page)
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

; Set page mode to use outlines.
HPDF_SetPageMode(pdf, #HPDF_PAGE_MODE_USE_OUTLINE)

; Add 3 pages to the document.
Dim page.i(2)
Dim outline.i(2)
Define i.l

For i = 0 To 2
  page(i) = HPDF_AddPage(pdf)
  If page(i) = 0
    PrintN("FAIL page " + Str(i) + " " + HaruErrorText(pdf))
    HaruFree(pdf)
    End 1
  EndIf
  HPDF_Page_SetFontAndSize(page(i), font, 30)
  PrintPage(page(i), i + 1)
Next

; create outline root.
Define root.i = CreateOutline(pdf, 0, "OutlineRoot")
HPDF_Outline_SetOpened(root, #HPDF_TRUE)

outline(0) = CreateOutline(pdf, root, "page1")
outline(1) = CreateOutline(pdf, root, "page2")

; create outline with test which is ISO8859-2 encoding
outline(2) = CreateOutline(pdf, root, "ISO8859-2 text " + Chr($D3) + Chr($D4) + Chr($D5) + Chr($D6) + Chr($D7) + Chr($D8) + Chr($D9), HPDF_GetEncoder(pdf, "ISO8859-2"))

If root = 0 Or outline(0) = 0 Or outline(1) = 0 Or outline(2) = 0
  PrintN("FAIL outline " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

; create destination objects on each pages
; and link it to outline items.
Define dst.i
For i = 0 To 2
  dst = HPDF_Page_CreateDestination(page(i))
  HPDF_Destination_SetXYZ(dst, 0, HPDF_Page_GetHeight(page(i)), 1)
  HPDF_Outline_SetDestination(outline(i), dst)
Next
;  HPDF_Catalog_SetOpenAction(dst);   (commented out in the C original)

; --- gate + save ---------------------------------------------------------------
If HPDF_GetError(pdf) <> #HPDF_OK
  PrintN("FAIL draw (latched error) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

If HPDF_SaveToFile(pdf, "outline_demo.pdf") <> #HPDF_OK
  PrintN("FAIL save " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
HaruFree(pdf)
PrintN("PASS outline_demo -> outline_demo.pdf")

HaruShutdown()
CloseConsole()
End 0

; IDE Options = PureBasic 6.40 (Windows - x64)
; ExecutableFormat = Console
; EnableXP
; DPIAware
