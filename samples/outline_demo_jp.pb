; ---------------------------------------------------------------------------
; outline_demo_jp.pb - PureBasic port of libharu's outline_demo_jp.c
; (<< Haru Free PDF Library 2.0.0 >>, Copyright (c) 1999-2006 Takeshi Kanno,
; ZLIB license - see ../THIRD-PARTY-NOTICES.md).
; Three 200x300 pages ("Page:1..3") with an outline root and three children -
; the third titled with the raw SJIS line from mbtext/sjis.txt through the
; 90ms-RKSJ-H encoder; page mode USE_OUTLINE.
;
; Deviations from the C original (wrapper subset, see ../hpdf.pbi):
;  - the C's HPDF_New(...) is HaruNew() (adds the UTF-8 pipeline - no
;    behavioral difference: the SJIS outline title is passed as RAW bytes);
;  - no setjmp/longjmp error handler: one latched-error gate before the save;
;  - HPDF_CreateOutline takes a char* title - the raw binding
;    HPDF_CreateOutlineRaw + HaruAsciiMem is used; the SJIS title goes in as
;    the exact file bytes with the 90ms-RKSJ-H encoder, like the C (a
;    p-utf8/p-ascii string arg would re-encode them);
;  - the C's fgets sample-line buffer (SAMP_TXT[2048]) becomes a
;    NUL-terminated byte buffer of the whole first line (sjis.txt has no
;    line terminator); the line is read with direct ReadByte() calls -
;    PB ReadString(#PB_Ascii) would NOT be byte-exact (it converts file
;    bytes through the system ANSI codepage CP1252, remapping SJIS bytes
;    like 0x82/0x83 to U+201A/U+0192; verified: that turned the outline
;    title into '?' runs, fixed by raw-byte reading);
;  - path separator '/' instead of the C's "\\\\";
;  - argv[0] + ".pdf" output replaced with the stable filename
;    outline_demo_jp.pdf.
;
; Build (from samples/):
;   MSYS2_ARG_CONV_EXCL='*' "$PUREBASIC_HOME/Compilers/pbcompilerc.exe" \
;     /CONSOLE /THREAD /EXE outline_demo_jp.exe outline_demo_jp.pb
; ---------------------------------------------------------------------------

EnableExplicit

XIncludeFile "../hpdf.pbi"

; HPDF_CreateOutline with a raw byte buffer title (raw char* binding;
; encoder 0 = the C's NULL). Bytes are consumed synchronously.
Procedure.i CreateOutlineRaw(pdf.i, parent.i, *title, encoder.i = 0)
  ProcedureReturn HPDF_CreateOutlineRaw(pdf, parent, *title, encoder)
EndProcedure

; HPDF_CreateOutline with a PB string title (ASCII titles).
Procedure.i CreateOutline(pdf.i, parent.i, title$, encoder.i = 0)
  Protected *title = HaruAsciiMem(title$)
  Protected outline.i = HPDF_CreateOutlineRaw(pdf, parent, *title, encoder)
  FreeMemory(*title)
  ProcedureReturn outline
EndProcedure

; outline_demo_jp.c print_page(): "Page:<n>" at (50, 250).
Procedure PrintPage(page.i, pageNum.l)
  HPDF_Page_SetWidth(page, 200)
  HPDF_Page_SetHeight(page, 300)

  HPDF_Page_BeginText(page)
  HPDF_Page_MoveTextPos(page, 50, 250)
  HPDF_Page_ShowText(page, "Page:" + Str(pageNum))
  HPDF_Page_EndText(page)
EndProcedure

; Reads the first line of a file as raw single-byte bytes (the C's
; fgets(SAMP_TXT, 2048, f): up to 2047 bytes, '\n' kept if present,
; NUL-terminated). NOTE: ReadString(#PB_Ascii) must NOT be used here - PB 6.40
; converts file bytes through the system ANSI codepage (CP1252), which remaps
; SJIS bytes (0x82/0x83 -> U+201A/U+0192 etc.) and breaks the byte-exact
; round-trip. Direct ReadByte() is the faithful fgets equivalent.
Procedure.i ReadFirstLineBytes(path$)
  Protected fd.i = ReadFile(#PB_Any, path$)
  If fd = 0
    ProcedureReturn 0
  EndIf
  Protected *buf = AllocateMemory(2048)    ; C: char SAMP_TXT[2048]
  If *buf = 0
    CloseFile(fd)
    ProcedureReturn 0
  EndIf
  Protected n.i = 0
  Protected c.i
  While n < 2047 And Not Eof(fd)
    c = ReadByte(fd) & $FF
    PokeA(*buf + n, c)
    n + 1
    If c = 10                              ; '\n' - fgets stops after, keeping it
      Break
    EndIf
  Wend
  CloseFile(fd)
  PokeA(*buf + n, 0)
  ProcedureReturn *buf
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

; the raw SJIS sample line
Define *sampText = ReadFirstLineBytes("mbtext/sjis.txt")
If *sampText = 0
  PrintN("error: cannot open 'mbtext/sjis.txt'")
  End 1
EndIf

Define pdf.i = HaruNew()
If pdf = 0
  PrintN("FAIL doc (HaruNew returned 0)")
  FreeMemory(*sampText)
  End 1
EndIf

; declaration for using Japanese encoding.
HPDF_UseJPEncodings(pdf)

; create default-font
Define font.i = HaruGetFont(pdf, "Helvetica", "")
If font = 0
  PrintN("FAIL font (GetFont Helvetica) " + HaruErrorText(pdf))
  HaruFree(pdf)
  FreeMemory(*sampText)
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
    FreeMemory(*sampText)
    End 1
  EndIf
  HPDF_Page_SetFontAndSize(page(i), font, 20)
  PrintPage(page(i), i + 1)
Next

; create outline root.
Define root.i = CreateOutline(pdf, 0, "OutlineRoot")
HPDF_Outline_SetOpened(root, #HPDF_TRUE)

outline(0) = CreateOutline(pdf, root, "page1")
outline(1) = CreateOutline(pdf, root, "page2")

; create outline with test which is  encoding (SJIS line via 90ms-RKSJ-H)
outline(2) = CreateOutlineRaw(pdf, root, *sampText, HPDF_GetEncoder(pdf, "90ms-RKSJ-H"))

If root = 0 Or outline(0) = 0 Or outline(1) = 0 Or outline(2) = 0
  PrintN("FAIL outline " + HaruErrorText(pdf))
  HaruFree(pdf)
  FreeMemory(*sampText)
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
  FreeMemory(*sampText)
  End 1
EndIf

If HPDF_SaveToFile(pdf, "outline_demo_jp.pdf") <> #HPDF_OK
  PrintN("FAIL save " + HaruErrorText(pdf))
  HaruFree(pdf)
  FreeMemory(*sampText)
  End 1
EndIf
HaruFree(pdf)
FreeMemory(*sampText)
PrintN("PASS outline_demo_jp -> outline_demo_jp.pdf")

HaruShutdown()
CloseConsole()
End 0

; IDE Options = PureBasic 6.40 (Windows - x64)
; ExecutableFormat = Console
; EnableXP
; DPIAware
