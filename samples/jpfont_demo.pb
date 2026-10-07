; ---------------------------------------------------------------------------
; jpfont_demo.pb - PureBasic port of libharu's jpfont_demo.c
; (<< Haru Free PDF Library 2.0.0 >>, Copyright (c) 1999-2006 Takeshi Kanno,
; ZLIB license - see ../THIRD-PARTY-NOTICES.md).
; 16 Japanese built-in CID fontdefs (MS-Mincho / MS-PMincho / MS-Gothic /
; MS-PGothic regular+Bold+Italic+BoldItalic through 90ms-RKSJ-H /
; 90msp-RKSJ-H): one page each with the raw SJIS sample line from
; mbtext/sjis.txt at 10/16/23/30pt, alphabet/digit lines, an outline entry
; per font, tick marks under the sample line and a page resized to the
; measured text extent.
;
; Deviations from the C original (wrapper subset, see ../hpdf.pbi):
;  - the C's HPDF_New(...) is HaruNew() (adds the UTF-8 pipeline - no
;    behavioral difference: the SJIS text is drawn as RAW bytes);
;  - no setjmp/longjmp error handler: one latched-error gate before the save;
;  - samp_text (the raw SJIS line incl. the C's fgets buffer semantics) is a
;    NUL-terminated byte buffer drawn/measured through the raw bindings
;    HPDF_Page_ShowTextRaw/HPDF_Page_TextWidthRaw - a p-utf8 string arg
;    would re-encode the double-byte codes; the line is read with direct
;    ReadByte() calls, NOT ReadString(#PB_Ascii) (that converts file bytes
;    through the system ANSI codepage CP1252 and remaps SJIS bytes - not
;    byte-exact);
;  - the C's by-value HPDF_Point from HPDF_Page_GetCurrentTextPos becomes
;    the documented out-parameter variant HPDF_Page_GetCurrentTextPos2 into
;    an HPDFPoint - identical values;
;  - HPDF_CreateOutline takes a char* title - the raw binding
;    HPDF_CreateOutlineRaw + HaruAsciiMem is used (titles are the ASCII font
;    names; encoder 0 = the C's NULL);
;  - path separator '/' instead of the C's "\\\\";
;  - argv[0] + ".pdf" output replaced with the stable filename
;    jpfont_demo.pdf.
;
; Build (from samples/):
;   MSYS2_ARG_CONV_EXCL='*' "$PUREBASIC_HOME/Compilers/pbcompilerc.exe" \
;     /CONSOLE /THREAD /EXE jpfont_demo.exe jpfont_demo.pb
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

; Reads the first line of a file as raw single-byte chars (the C's
; fgets(samp_text, 2048, f) semantics: up to 2047 bytes, EOL kept if any).
; Returns "" on failure. Caller frees the returned buffer.
; NOTE: reads raw bytes - ReadString(#PB_Ascii) runs through the system ANSI
; codepage (CP1252) and remaps SJIS bytes, breaking the byte-exact round-trip.
Procedure.i ReadFirstLineBytes(path$, *lenOut)
  Protected fd.i = ReadFile(#PB_Any, path$)
  If fd = 0
    ProcedureReturn 0
  EndIf
  Protected *buf = AllocateMemory(2048)    ; C: char samp_text[2048]
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
  PokeI(*lenOut, n)
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

; the raw SJIS sample line (mbtext/sjis.txt, first fgets block)
Define sampLen.i = 0
Define *sampText = ReadFirstLineBytes("mbtext/sjis.txt", @sampLen)
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

; configure pdf-document to be compressed.
HPDF_SetCompressionMode(pdf, #HPDF_COMP_ALL)

; declaration for using Japanese font, encoding.
HPDF_UseJPEncodings(pdf)
HPDF_UseJPFonts(pdf)

Dim detailFont.i(15)
Dim fontNames.s(15)
Define i.l

; the C's 16 GetFont calls (built-in fontdefs - no font files needed)
detailFont(0) = HaruGetFont(pdf, "MS-Mincho", "90ms-RKSJ-H")
detailFont(1) = HaruGetFont(pdf, "MS-Mincho,Bold", "90ms-RKSJ-H")
detailFont(2) = HaruGetFont(pdf, "MS-Mincho,Italic", "90ms-RKSJ-H")
detailFont(3) = HaruGetFont(pdf, "MS-Mincho,BoldItalic", "90ms-RKSJ-H")
detailFont(4) = HaruGetFont(pdf, "MS-PMincho", "90msp-RKSJ-H")
detailFont(5) = HaruGetFont(pdf, "MS-PMincho,Bold", "90msp-RKSJ-H")
detailFont(6) = HaruGetFont(pdf, "MS-PMincho,Italic", "90msp-RKSJ-H")
detailFont(7) = HaruGetFont(pdf, "MS-PMincho,BoldItalic", "90msp-RKSJ-H")
detailFont(8) = HaruGetFont(pdf, "MS-Gothic", "90ms-RKSJ-H")
detailFont(9) = HaruGetFont(pdf, "MS-Gothic,Bold", "90ms-RKSJ-H")
detailFont(10) = HaruGetFont(pdf, "MS-Gothic,Italic", "90ms-RKSJ-H")
detailFont(11) = HaruGetFont(pdf, "MS-Gothic,BoldItalic", "90ms-RKSJ-H")
detailFont(12) = HaruGetFont(pdf, "MS-PGothic", "90msp-RKSJ-H")
detailFont(13) = HaruGetFont(pdf, "MS-PGothic,Bold", "90msp-RKSJ-H")
detailFont(14) = HaruGetFont(pdf, "MS-PGothic,Italic", "90msp-RKSJ-H")
detailFont(15) = HaruGetFont(pdf, "MS-PGothic,BoldItalic", "90msp-RKSJ-H")

For i = 0 To 15
  If detailFont(i) = 0
    PrintN("FAIL font " + Str(i) + " " + HaruErrorText(pdf))
    HaruFree(pdf)
    FreeMemory(*sampText)
    End 1
  EndIf
  fontNames(i) = PeekS(HPDF_Font_GetFontName(detailFont(i)), -1, #PB_Ascii)
Next

#PAGE_HEIGHT = 210

; Set page mode to use outlines.
HPDF_SetPageMode(pdf, #HPDF_PAGE_MODE_USE_OUTLINE)

; create outline root.
Define root.i = CreateOutline(pdf, 0, "JP font demo")
HPDF_Outline_SetOpened(root, #HPDF_TRUE)
If root = 0
  PrintN("FAIL outline " + HaruErrorText(pdf))
  HaruFree(pdf)
  FreeMemory(*sampText)
  End 1
EndIf

Dim p.HPDFPoint(0)
Define page.i
Define outline.i
Define dst.i
Define titleFont.i
Define xPos.f
Define j.l

For i = 0 To 15
  ; add a new page object.
  page = HPDF_AddPage(pdf)
  If page = 0
    PrintN("FAIL page " + Str(i) + " " + HaruErrorText(pdf))
    HaruFree(pdf)
    FreeMemory(*sampText)
    End 1
  EndIf

  ; create outline entry
  outline = CreateOutline(pdf, root, fontNames(i))
  dst = HPDF_Page_CreateDestination(page)
  HPDF_Outline_SetDestination(outline, dst)

  titleFont = HaruGetFont(pdf, "Helvetica", "")
  HPDF_Page_SetFontAndSize(page, titleFont, 10)

  HPDF_Page_BeginText(page)

  ; move the position of the text to top of the page.
  HPDF_Page_MoveTextPos(page, 10, 190)
  HPDF_Page_ShowText(page, fontNames(i))

  HPDF_Page_SetFontAndSize(page, detailFont(i), 15)
  HPDF_Page_MoveTextPos(page, 10, -20)
  HPDF_Page_ShowText(page, "abcdefghijklmnopqrstuvwxyz")
  HPDF_Page_MoveTextPos(page, 0, -20)
  HPDF_Page_ShowText(page, "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
  HPDF_Page_MoveTextPos(page, 0, -20)
  HPDF_Page_ShowText(page, "1234567890")
  HPDF_Page_MoveTextPos(page, 0, -20)

  HPDF_Page_SetFontAndSize(page, detailFont(i), 10)
  HPDF_Page_ShowTextRaw(page, *sampText)
  HPDF_Page_MoveTextPos(page, 0, -18)

  HPDF_Page_SetFontAndSize(page, detailFont(i), 16)
  HPDF_Page_ShowTextRaw(page, *sampText)
  HPDF_Page_MoveTextPos(page, 0, -27)

  HPDF_Page_SetFontAndSize(page, detailFont(i), 23)
  HPDF_Page_ShowTextRaw(page, *sampText)
  HPDF_Page_MoveTextPos(page, 0, -36)

  HPDF_Page_SetFontAndSize(page, detailFont(i), 30)
  HPDF_Page_ShowTextRaw(page, *sampText)

  HPDF_Page_GetCurrentTextPos2(page, @p(0))

  ; finish to print text.
  HPDF_Page_EndText(page)

  HPDF_Page_SetLineWidth(page, 0.5)

  xPos = 20
  For j = 0 To sampLen / 2
    HPDF_Page_MoveTo(page, xPos, p(0)\y - 10)
    HPDF_Page_LineTo(page, xPos, p(0)\y - 12)
    HPDF_Page_Stroke(page)
    xPos + 30
  Next

  HPDF_Page_SetWidth(page, p(0)\x + 20)
  HPDF_Page_SetHeight(page, #PAGE_HEIGHT)

  HPDF_Page_MoveTo(page, 10, #PAGE_HEIGHT - 25)
  HPDF_Page_LineTo(page, p(0)\x + 10, #PAGE_HEIGHT - 25)
  HPDF_Page_Stroke(page)

  HPDF_Page_MoveTo(page, 10, #PAGE_HEIGHT - 85)
  HPDF_Page_LineTo(page, p(0)\x + 10, #PAGE_HEIGHT - 85)
  HPDF_Page_Stroke(page)

  HPDF_Page_MoveTo(page, 10, p(0)\y - 12)
  HPDF_Page_LineTo(page, p(0)\x + 10, p(0)\y - 12)
  HPDF_Page_Stroke(page)
Next

; --- gate + save ---------------------------------------------------------------
If HPDF_GetError(pdf) <> #HPDF_OK
  PrintN("FAIL draw (latched error) " + HaruErrorText(pdf))
  HaruFree(pdf)
  FreeMemory(*sampText)
  End 1
EndIf

If HPDF_SaveToFile(pdf, "jpfont_demo.pdf") <> #HPDF_OK
  PrintN("FAIL save " + HaruErrorText(pdf))
  HaruFree(pdf)
  FreeMemory(*sampText)
  End 1
EndIf
HaruFree(pdf)
FreeMemory(*sampText)
PrintN("PASS jpfont_demo -> jpfont_demo.pdf")

HaruShutdown()
CloseConsole()
End 0

; IDE Options = PureBasic 6.40 (Windows - x64)
; ExecutableFormat = Console
; EnableXP
; DPIAware
