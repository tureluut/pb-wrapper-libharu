; ---------------------------------------------------------------------------
; encoding_list.pb - PureBasic port of libharu's encoding_list.c
; (<< Haru Free PDF Library 2.0.0 >>, Copyright (c) 1999-2006 Takeshi Kanno,
; ZLIB license - see ../THIRD-PARTY-NOTICES.md).
; Loads the bundled Type1 font (type1/a010013l URW Gothic), then draws a
; 16x16 character grid (0x20-0xFF) for each of the 21 standard encodings,
; one 420x400 page per encoding with an outline entry and XYZ destination;
; page mode USE_OUTLINE.
;
; Deviations from the C original (wrapper subset, see ../hpdf.pbi):
;  - the C's HPDF_NewEx(error_handler, NULL, NULL, 0, NULL) is functionally
;    HPDF_New; the port uses HaruNew() which additionally enables the UTF-8
;    pipeline - no behavioral difference here (all grid characters are drawn
;    as RAW single bytes, all labels are ASCII);
;  - no setjmp/longjmp error handler: one latched-error gate before the save;
;  - draw_fonts() passes unsigned char buf[2] to HPDF_Page_TextOut/
;    TextWidth; the port uses the same DLL exports through the raw bindings
;    (HPDF_Page_TextOutRaw/TextWidthRaw) with a 2-byte NUL-terminated buffer,
;    so bytes 0x80-0xFF reach the single-byte fonts unconverted (a p-utf8
;    string arg would re-encode them);
;  - the C's HPDF_GetFont(pdf, <name>, NULL) calls (NULL = font default
;    encoding) become HaruGetFont(pdf, <name>, "") - real C NULLs;
;  - path separator '/' instead of the C's "\\\\";
;  - argv[0] + ".pdf" output replaced with the stable filename
;    encoding_list.pdf.
;
; Build (from samples/):
;   MSYS2_ARG_CONV_EXCL='*' "$PUREBASIC_HOME/Compilers/pbcompilerc.exe" \
;     /CONSOLE /THREAD /EXE encoding_list.exe encoding_list.pb
; ---------------------------------------------------------------------------

EnableExplicit

XIncludeFile "../hpdf.pbi"

#PAGE_WIDTH  = 420
#PAGE_HEIGHT = 400
#CELL_WIDTH  = 20
#CELL_HEIGHT = 20

; encoding_list.c draw_graph(): 16x15 cell grid with hex axis labels.
Procedure DrawGraph(page.i)
  Protected i.l
  Protected x.l
  Protected y.l

  ; Draw vertical lines.
  HPDF_Page_SetLineWidth(page, 0.5)

  For i = 0 To 17
    x = i * #CELL_WIDTH + 40

    HPDF_Page_MoveTo(page, x, #PAGE_HEIGHT - 60)
    HPDF_Page_LineTo(page, x, 40)
    HPDF_Page_Stroke(page)

    If i > 0 And i <= 16
      HPDF_Page_BeginText(page)
      HPDF_Page_MoveTextPos(page, x + 5, #PAGE_HEIGHT - 75)
      HPDF_Page_ShowText(page, Hex(i - 1))
      HPDF_Page_EndText(page)
    EndIf
  Next

  ; Draw horizontal lines.
  For i = 0 To 15
    y = i * #CELL_HEIGHT + 40

    HPDF_Page_MoveTo(page, 40, y)
    HPDF_Page_LineTo(page, #PAGE_WIDTH - 40, y)
    HPDF_Page_Stroke(page)

    If i < 14
      HPDF_Page_BeginText(page)
      HPDF_Page_MoveTextPos(page, 45, y + 5)
      HPDF_Page_ShowText(page, Hex(15 - i))
      HPDF_Page_EndText(page)
    EndIf
  Next
EndProcedure

; encoding_list.c draw_fonts(): all characters 0x20-0xFF centered in the
; grid cells, raw single bytes (see header note).
Procedure DrawFonts(page.i)
  Protected i.l
  Protected j.l
  Protected y.l
  Protected x.l
  Protected d.f
  Protected *buf = AllocateMemory(2)   ; unsigned char buf[2] with buf[1] = 0

  HPDF_Page_BeginText(page)

  For i = 1 To 16
    For j = 1 To 16
      y = #PAGE_HEIGHT - 55 - ((i - 1) * #CELL_HEIGHT)
      x = j * #CELL_WIDTH + 50

      PokeA(*buf + 1, $00)
      PokeA(*buf, (i - 1) * 16 + (j - 1))
      If PeekA(*buf) >= 32
        d = x - HPDF_Page_TextWidthRaw(page, *buf) / 2
        HPDF_Page_TextOutRaw(page, d, y, *buf)
      EndIf
    Next
  Next

  HPDF_Page_EndText(page)
  FreeMemory(*buf)
EndProcedure

; HPDF_CreateOutline with a PB string title (raw char* binding + HaruAsciiMem;
; encoder 0 = the C's NULL). Title bytes are consumed synchronously.
Procedure.i CreateOutline(pdf.i, parent.i, title$, encoder.i = 0)
  Protected *title = HaruAsciiMem(title$)
  Protected outline.i = HPDF_CreateOutlineRaw(pdf, parent, *title, encoder)
  FreeMemory(*title)
  ProcedureReturn outline
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

Dim encodings.s(20)
encodings(0) = "StandardEncoding"
encodings(1) = "MacRomanEncoding"
encodings(2) = "WinAnsiEncoding"
encodings(3) = "ISO8859-2"
encodings(4) = "ISO8859-3"
encodings(5) = "ISO8859-4"
encodings(6) = "ISO8859-5"
encodings(7) = "ISO8859-9"
encodings(8) = "ISO8859-10"
encodings(9) = "ISO8859-13"
encodings(10) = "ISO8859-14"
encodings(11) = "ISO8859-15"
encodings(12) = "ISO8859-16"
encodings(13) = "CP1250"
encodings(14) = "CP1251"
encodings(15) = "CP1252"
encodings(16) = "CP1254"
encodings(17) = "CP1257"
encodings(18) = "KOI8-R"
encodings(19) = "Symbol-Set"
encodings(20) = "ZapfDingbats-Set"

; set compression mode
HPDF_SetCompressionMode(pdf, #HPDF_COMP_ALL)

; Set page mode to use outlines.
HPDF_SetPageMode(pdf, #HPDF_PAGE_MODE_USE_OUTLINE)

; get default font
Define font.i = HaruGetFont(pdf, "Helvetica", "")
If font = 0
  PrintN("FAIL font (GetFont Helvetica) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

; load font object
Define namePtr.i = HPDF_LoadType1FontFromFile(pdf, "type1/a010013l.afm", "type1/a010013l.pfb")
If namePtr = 0
  PrintN("FAIL type1 font load " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
Define fontName$ = PeekS(namePtr, -1, #PB_Ascii)

; create outline root.
Define root.i = CreateOutline(pdf, 0, "Encoding list")
HPDF_Outline_SetOpened(root, #HPDF_TRUE)
If root = 0
  PrintN("FAIL outline " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

Define i.l
For i = 0 To 20
  Define page.i = HPDF_AddPage(pdf)
  If page = 0
    PrintN("FAIL page " + Str(i) + " " + HaruErrorText(pdf))
    HaruFree(pdf)
    End 1
  EndIf

  HPDF_Page_SetWidth(page, #PAGE_WIDTH)
  HPDF_Page_SetHeight(page, #PAGE_HEIGHT)

  Define outline.i = CreateOutline(pdf, root, encodings(i))
  Define dst.i = HPDF_Page_CreateDestination(page)
  HPDF_Destination_SetXYZ(dst, 0, HPDF_Page_GetHeight(page), 1)
  ; HPDF_Destination_SetFitB(dst);
  HPDF_Outline_SetDestination(outline, dst)

  HPDF_Page_SetFontAndSize(page, font, 15)
  DrawGraph(page)

  HPDF_Page_BeginText(page)
  HPDF_Page_SetFontAndSize(page, font, 20)
  HPDF_Page_MoveTextPos(page, 40, #PAGE_HEIGHT - 50)
  HPDF_Page_ShowText(page, encodings(i))
  HPDF_Page_ShowText(page, " Encoding")
  HPDF_Page_EndText(page)

  Define font2.i
  If encodings(i) = "Symbol-Set"
    font2 = HaruGetFont(pdf, "Symbol", "")
  ElseIf encodings(i) = "ZapfDingbats-Set"
    font2 = HaruGetFont(pdf, "ZapfDingbats", "")
  Else
    font2 = HaruGetFont(pdf, fontName$, encodings(i))
  EndIf

  If font2 = 0
    PrintN("FAIL font2 (" + encodings(i) + ") " + HaruErrorText(pdf))
    HaruFree(pdf)
    End 1
  EndIf

  HPDF_Page_SetFontAndSize(page, font2, 14)
  DrawFonts(page)

Next

; --- gate + save ---------------------------------------------------------------
If HPDF_GetError(pdf) <> #HPDF_OK
  PrintN("FAIL draw (latched error) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

If HPDF_SaveToFile(pdf, "encoding_list.pdf") <> #HPDF_OK
  PrintN("FAIL save " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
HaruFree(pdf)
PrintN("PASS encoding_list -> encoding_list.pdf")

HaruShutdown()
CloseConsole()
End 0

; IDE Options = PureBasic 6.40 (Windows - x64)
; ExecutableFormat = Console
; EnableXP
; DPIAware
