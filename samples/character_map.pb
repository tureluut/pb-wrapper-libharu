; ---------------------------------------------------------------------------
; character_map.pb - PureBasic port of libharu's character_map.c
; (<< Haru Free PDF Library 2.0.0 >>, Copyright (c) 1999-2006 Takeshi Kanno,
; ZLIB license - see ../THIRD-PARTY-NOTICES.md).
; Double-byte encoder character-map dump: scans all 0x0000-0xFFFF codes of
; the given encoding (Encoder_GetByteType/GetUnicode), prints the used
; high/low ranges and draws one grid page per used high byte with the
; characters of that plane, an outline entry per page and USE_OUTLINE mode.
;
; Usage: character_map <encoding-name> <font-name>
;   e.g.  character_map 90ms-RKSJ-H MS-Mincho
;
; Deviations from the C original (wrapper subset, see ../hpdf.pbi):
;  - the C's HPDF_New(...) is HaruNew() (adds the UTF-8 pipeline - no
;    behavioral difference: every CJK glyph is drawn as RAW bytes);
;  - no setjmp/longjmp error handler: one latched-error gate before the save;
;  - C unsigned char buffers for HPDF_Page_TextWidth/ShowText become
;    AllocateMemory buffers drawn through the raw bindings
;    (HPDF_Page_TextWidthRaw/ShowTextRaw) - bytes reach the double-byte font
;    unconverted;
;  - HPDF_CreateOutline takes a char* title - the raw binding
;    HPDF_CreateOutlineRaw + HaruAsciiMem is used (titles are ASCII hex
;    ranges / the encoding name);
;  - %04X formatting via RSet(Hex(), 4, "0");
;  - argv[0] + ".pdf" output replaced with the stable filename
;    character_map.pdf.
;
; Build (from samples/):
;   MSYS2_ARG_CONV_EXCL='*' "$PUREBASIC_HOME/Compilers/pbcompilerc.exe" \
;     /CONSOLE /THREAD /EXE character_map.exe character_map.pb
; ---------------------------------------------------------------------------

EnableExplicit

XIncludeFile "../hpdf.pbi"

#PAGE_WIDTH  = 420
#CELL_HEIGHT = 20
#CELL_WIDTH  = 20

; HPDF_CreateOutline with a PB string title (raw char* binding + HaruAsciiMem;
; encoder 0 = the C's NULL). Title bytes are consumed synchronously.
Procedure.i CreateOutline(pdf.i, parent.i, title$, encoder.i = 0)
  Protected *title = HaruAsciiMem(title$)
  Protected outline.i = HPDF_CreateOutlineRaw(pdf, parent, *title, encoder)
  FreeMemory(*title)
  ProcedureReturn outline
EndProcedure

; character_map.c draw_page(): one grid page for high byte h_byte, cells
; from l_byte (rounded down to 16) upward; hex axis labels (title font) and
; the encoded 2-byte characters of the plane (map font).
Procedure DrawPage(page.i, titleFont.i, font.i, hByte.l, lByte.l)
  Protected hCount.l
  Protected xpos.l
  Protected ypos.l
  Protected pageHeight.l
  Protected y.l
  Protected x.l
  Protected w.f
  Protected *buf2 = AllocateMemory(2)   ; 1-char label, NUL-terminated
  Protected *buf3 = AllocateMemory(3)   ; 2-byte code, NUL-terminated

  lByte = Int(lByte / 16) * 16
  hCount = 16 - (lByte / 16)
  pageHeight = 40 + 40 + (hCount + 1) * #CELL_HEIGHT

  HPDF_Page_SetHeight(page, pageHeight)
  HPDF_Page_SetWidth(page, #PAGE_WIDTH)

  HPDF_Page_SetFontAndSize(page, titleFont, 10)

  ypos = hCount + 1
  Repeat
    y = ypos * #CELL_HEIGHT + 40

    HPDF_Page_MoveTo(page, 40, y)
    HPDF_Page_LineTo(page, 380, y)
    HPDF_Page_Stroke(page)

    If ypos < hCount
      Protected label.l = 16 - ypos - 1
      If label < 10
        label + 48        ; '0'
      Else
        label + 55        ; 'A' - 10
      EndIf
      PokeA(*buf2, label)
      PokeA(*buf2 + 1, 0)

      w = HPDF_Page_TextWidthRaw(page, *buf2)
      HPDF_Page_BeginText(page)
      HPDF_Page_MoveTextPos(page, 40 + (20 - w) / 2, y + 5)
      HPDF_Page_ShowTextRaw(page, *buf2)
      HPDF_Page_EndText(page)
    EndIf

    If ypos = 0
      Break
    EndIf
    ypos - 1
  Forever

  For xpos = 0 To 17
    y = (hCount + 1) * #CELL_HEIGHT + 40
    x = xpos * #CELL_WIDTH + 40

    HPDF_Page_MoveTo(page, x, 40)
    HPDF_Page_LineTo(page, x, y)
    HPDF_Page_Stroke(page)

    If xpos > 0 And xpos <= 16
      Protected label2.l = xpos - 1
      If label2 < 10
        label2 + 48       ; '0'
      Else
        label2 + 55       ; 'A' - 10
      EndIf
      PokeA(*buf2, label2)
      PokeA(*buf2 + 1, 0)

      w = HPDF_Page_TextWidthRaw(page, *buf2)
      HPDF_Page_BeginText(page)
      HPDF_Page_MoveTextPos(page, x + (20 - w) / 2, hCount * #CELL_HEIGHT + 45)
      HPDF_Page_ShowTextRaw(page, *buf2)
      HPDF_Page_EndText(page)
    EndIf
  Next

  HPDF_Page_SetFontAndSize(page, font, 15)

  ypos = hCount
  Repeat
    y = (ypos - 1) * #CELL_HEIGHT + 45

    For xpos = 0 To 15
      x = xpos * #CELL_WIDTH + 40 + #CELL_WIDTH

      PokeA(*buf3, hByte)
      PokeA(*buf3 + 1, (16 - ypos) * 16 + xpos)
      PokeA(*buf3 + 2, $00)

      w = HPDF_Page_TextWidthRaw(page, *buf3)
      If w > 0
        HPDF_Page_BeginText(page)
        HPDF_Page_MoveTextPos(page, x + (20 - w) / 2, y)
        HPDF_Page_ShowTextRaw(page, *buf3)
        HPDF_Page_EndText(page)
      EndIf
    Next

    If ypos = 0
      Break
    EndIf
    ypos - 1
  Forever

  FreeMemory(*buf2)
  FreeMemory(*buf3)
EndProcedure

OpenConsole()

Define encodingName$ = ProgramParameter(0)
Define fontName$ = ProgramParameter(1)

If encodingName$ = "" Or fontName$ = ""
  PrintN("usage: character_map <encoding-name> <font-name>")
  End 1
EndIf

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

; configure pdf-document (showing outline, compression enabled)
HPDF_SetPageMode(pdf, #HPDF_PAGE_MODE_USE_OUTLINE)
HPDF_SetCompressionMode(pdf, #HPDF_COMP_ALL)
HPDF_SetPagesConfiguration(pdf, 10)

HPDF_UseJPEncodings(pdf)
HPDF_UseJPFonts(pdf)
HPDF_UseKREncodings(pdf)
HPDF_UseKRFonts(pdf)
HPDF_UseCNSEncodings(pdf)
HPDF_UseCNSFonts(pdf)
HPDF_UseCNTEncodings(pdf)
HPDF_UseCNTFonts(pdf)

Define encoder.i = HPDF_GetEncoder(pdf, encodingName$)
If HPDF_Encoder_GetType(encoder) <> #HPDF_ENCODER_TYPE_DOUBLE_BYTE
  PrintN("error: " + encodingName$ + " is not cmap-encoder")
  HaruFree(pdf)
  End 1
EndIf

Define font.i = HaruGetFont(pdf, fontName$, encodingName$)
If font = 0
  PrintN("FAIL font (GetFont " + fontName$ + ", " + encodingName$ + ") " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

; scan the used code ranges (HPDF_BYTE_TYPE_LEAD codes that do not map to
; the "missing glyph" box 0x25A1)
Dim flg.l(255)
Define minL.l = 255
Define minH.l = 256
Define maxL.l = 0
Define maxH.l = 0

Define *buf = AllocateMemory(3)
Define i.l
Define j.l
Define btype.l
Define unicode.l

For i = 0 To 255
  For j = 20 To 255
    PokeA(*buf, i)
    PokeA(*buf + 1, j)
    PokeA(*buf + 2, 0)

    btype = HPDF_Encoder_GetByteType(encoder, *buf, 0)
    unicode = HPDF_Encoder_GetUnicode(encoder, i * 256 + j)

    If btype = #HPDF_BYTE_TYPE_LEAD And unicode <> $25A1
      If minL > j
        minL = j
      EndIf
      If maxL < j
        maxL = j
      EndIf
      If minH > i
        minH = i
      EndIf
      If maxH < i
        maxH = i
      EndIf

      flg(i) = 1
    EndIf
  Next
Next

PrintN("min_h=" + RSet(Hex(minH), 4, "0") + " max_h=" + RSet(Hex(maxH), 4, "0") +
       " min_l=" + RSet(Hex(minL), 4, "0") + " max_l=" + RSet(Hex(maxL), 4, "0"))

FreeMemory(*buf)

; create outline root.
Define root.i = CreateOutline(pdf, 0, encodingName$)
HPDF_Outline_SetOpened(root, #HPDF_TRUE)
If root = 0
  PrintN("FAIL outline " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

Define range0$
Define pageHeader$
Define page.i
Define titleFont.i
Define outline.i
Define dst.i

For i = 0 To 255
  If flg(i)
    range0$ = "0x" + RSet(Hex(i * 256 + minL), 4, "0") + "-0x" + RSet(Hex(i * 256 + maxL), 4, "0")

    page = HPDF_AddPage(pdf)
    If page = 0
      PrintN("FAIL page " + Str(i) + " " + HaruErrorText(pdf))
      HaruFree(pdf)
      End 1
    EndIf
    titleFont = HaruGetFont(pdf, "Helvetica", "")
    outline = CreateOutline(pdf, root, range0$)
    dst = HPDF_Page_CreateDestination(page)
    HPDF_Outline_SetDestination(outline, dst)

    DrawPage(page, titleFont, font, i, minL)

    pageHeader$ = encodingName$ + " (" + fontName$ + ") 0x" + RSet(Hex(i * 256 + minL), 4, "0") +
                  "-0x" + RSet(Hex(i * 256 + maxL), 4, "0")
    HPDF_Page_SetFontAndSize(page, titleFont, 10)
    HPDF_Page_BeginText(page)
    HPDF_Page_MoveTextPos(page, 40, HPDF_Page_GetHeight(page) - 35)
    HPDF_Page_ShowText(page, pageHeader$)
    HPDF_Page_EndText(page)
  EndIf
Next

; --- gate + save ---------------------------------------------------------------
If HPDF_GetError(pdf) <> #HPDF_OK
  PrintN("FAIL draw (latched error) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

If HPDF_SaveToFile(pdf, "character_map.pdf") <> #HPDF_OK
  PrintN("FAIL save " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
HaruFree(pdf)
PrintN("PASS character_map -> character_map.pdf")

HaruShutdown()
CloseConsole()
End 0

; IDE Options = PureBasic 6.40 (Windows - x64)
; ExecutableFormat = Console
; EnableXP
; DPIAware
