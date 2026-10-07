; ---------------------------------------------------------------------------
; ttfont_demo_jp.pb - PureBasic port of libharu's ttfont_demo_jp.c
; (<< Haru Free PDF Library 2.0.0 >>, Copyright (c) 1999-2006 Takeshi Kanno,
; ZLIB license - see ../THIRD-PARTY-NOTICES.md).
; Japanese TrueType/TTC font demo: loads the font (optionally embedded with
; -E, or a TTC face by index), fetches it with 90msp-RKSJ-H, draws the font
; name + encoding name, alphabet/digit lines and the raw SJIS sample line
; from mbtext/sjis.txt at 10/16/23/30pt, then resizes the page to the
; measured width + 40 by 210 and draws two rules.
;
; Usage: ttfont_demo_jp <ttf-font-filename> [-E]
;        ttfont_demo_jp <ttc-font-filename> <index> [-E]
;
; Deviations from the C original (wrapper subset, see ../hpdf.pbi):
;  - the C's HPDF_New(...) is HaruNew() (adds the UTF-8 pipeline - no
;    behavioral difference: the SJIS text is drawn as RAW bytes);
;  - no setjmp/longjmp error handler: one latched-error gate before the save;
;  - samp_text (the raw SJIS line) is a NUL-terminated byte buffer drawn/
;    measured through the raw bindings HPDF_Page_ShowTextRaw /
;    HPDF_Page_TextWidthRaw - a p-utf8 string arg would re-encode it; the
;    line is read with direct ReadByte() calls, NOT ReadString(#PB_Ascii)
;    (that converts file bytes through the system ANSI codepage CP1252 and
;    remaps SJIS bytes - not byte-exact);
;  - the C stores the page width in an HPDF_UINT (integer truncation of
;    pw + 40); kept (pageHeight/pageWidth are integers here, unlike
;    ttfont_demo which uses HPDF_REAL);
;  - failed font loads FAIL cleanly instead of passing NULL on (same
;    latched-error code, no crash);
;  - path separator '/' instead of the C's "\\\\";
;  - argv[0] + ".pdf" output replaced with the stable filename
;    ttfont_demo_jp.pdf.
;
; Build (from samples/):
;   MSYS2_ARG_CONV_EXCL='*' "$PUREBASIC_HOME/Compilers/pbcompilerc.exe" \
;     /CONSOLE /THREAD /EXE ttfont_demo_jp.exe ttfont_demo_jp.pb
; ---------------------------------------------------------------------------

EnableExplicit

XIncludeFile "../hpdf.pbi"

OpenConsole()

; CLI dispatch (ttfont_demo_jp.c main): <ttf> [-E] | <ttc> <index> [-E]
Define arg1$ = ProgramParameter(0)
Define arg2$ = ProgramParameter(1)
Define arg3$ = ProgramParameter(2)
Define argCount.l = 0
If arg1$ <> ""
  argCount + 1
EndIf
If arg2$ <> ""
  argCount + 1
EndIf
If arg3$ <> ""
  argCount + 1
EndIf

If argCount < 1
  PrintN("ttfont_jp_demo <ttf-font-filename> [-E]")
  PrintN("ttfont_jp_demo <ttc-font-filename> <index> [-E]")
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

; the raw SJIS sample line (the C's fgets(SAMP_TXT, 2048, f)); read as raw
; bytes - ReadString(#PB_Ascii) goes through the system ANSI codepage and
; remaps SJIS bytes, so it is NOT byte-exact
Define fd.i = ReadFile(#PB_Any, "mbtext/sjis.txt")
If fd = 0
  PrintN("error: cannot open 'mbtext/sjis.txt'")
  End 1
EndIf
Define *sampText = AllocateMemory(2048)      ; C: char SAMP_TXT[2048]
Define sampLen.i = 0
While sampLen < 2047 And Not Eof(fd)
  Define c.i = ReadByte(fd) & $FF
  PokeA(*sampText + sampLen, c)
  sampLen + 1
  If c = 10                                  ; '\n' - fgets keeps it
    Break
  EndIf
Wend
CloseFile(fd)
PokeA(*sampText + sampLen, 0)

Define pdf.i = HaruNew()
If pdf = 0
  PrintN("FAIL doc (HaruNew returned 0)")
  FreeMemory(*sampText)
  End 1
EndIf

; declaration for using Japanese encoding.
HPDF_UseJPEncodings(pdf)

HPDF_SetCompressionMode(pdf, #HPDF_COMP_ALL)

; load ttc file (C arg dispatch: argc==4 && argv[3]=="-E" | argc==3 &&
; argv[2]=="-E" | argc==3 | else)
Define namePtr.i
If argCount = 3 And arg3$ = "-E"
  namePtr = HPDF_LoadTTFontFromFile2(pdf, arg1$, Val(arg2$), #HPDF_TRUE)
ElseIf argCount = 2 And arg2$ = "-E"
  namePtr = HPDF_LoadTTFontFromFile(pdf, arg1$, #HPDF_TRUE)
ElseIf argCount = 2
  namePtr = HPDF_LoadTTFontFromFile2(pdf, arg1$, Val(arg2$), #HPDF_FALSE)
Else
  namePtr = HPDF_LoadTTFontFromFile(pdf, arg1$, #HPDF_FALSE)
EndIf

If namePtr = 0
  PrintN("FAIL font load (" + arg1$ + ") " + HaruErrorText(pdf))
  HaruFree(pdf)
  FreeMemory(*sampText)
  End 1
EndIf
Define detailFontName$ = PeekS(namePtr, -1, #PB_Ascii)

; add a new page object.
Define page.i = HPDF_AddPage(pdf)
If page = 0
  PrintN("FAIL page " + HaruErrorText(pdf))
  HaruFree(pdf)
  FreeMemory(*sampText)
  End 1
EndIf

Define titleFont.i = HaruGetFont(pdf, "Helvetica", "")
If titleFont = 0
  PrintN("FAIL font (GetFont Helvetica) " + HaruErrorText(pdf))
  HaruFree(pdf)
  FreeMemory(*sampText)
  End 1
EndIf

Define detailFont.i = HaruGetFont(pdf, detailFontName$, "90msp-RKSJ-H")
If detailFont = 0
  PrintN("FAIL font (GetFont " + detailFontName$ + ") " + HaruErrorText(pdf))
  HaruFree(pdf)
  FreeMemory(*sampText)
  End 1
EndIf

HPDF_Page_SetFontAndSize(page, titleFont, 10)

HPDF_Page_BeginText(page)

; move the position of the text to top of the page.
HPDF_Page_MoveTextPos(page, 10, 190)
HPDF_Page_ShowText(page, detailFontName$)
HPDF_Page_ShowText(page, " (")
HPDF_Page_ShowText(page, PeekS(HPDF_Font_GetEncodingName(detailFont), -1, #PB_Ascii))
HPDF_Page_ShowText(page, ")")

HPDF_Page_SetFontAndSize(page, detailFont, 15)
HPDF_Page_MoveTextPos(page, 10, -20)
HPDF_Page_ShowText(page, "abcdefghijklmnopqrstuvwxyz")
HPDF_Page_MoveTextPos(page, 0, -20)
HPDF_Page_ShowText(page, "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
HPDF_Page_MoveTextPos(page, 0, -20)
HPDF_Page_ShowText(page, "1234567890")
HPDF_Page_MoveTextPos(page, 0, -20)

HPDF_Page_SetFontAndSize(page, detailFont, 10)
HPDF_Page_ShowTextRaw(page, *sampText)
HPDF_Page_MoveTextPos(page, 0, -18)

HPDF_Page_SetFontAndSize(page, detailFont, 16)
HPDF_Page_ShowTextRaw(page, *sampText)
HPDF_Page_MoveTextPos(page, 0, -27)

HPDF_Page_SetFontAndSize(page, detailFont, 23)
HPDF_Page_ShowTextRaw(page, *sampText)
HPDF_Page_MoveTextPos(page, 0, -36)

HPDF_Page_SetFontAndSize(page, detailFont, 30)
HPDF_Page_ShowTextRaw(page, *sampText)
HPDF_Page_MoveTextPos(page, 0, -36)

; the C's pw is HPDF_REAL but page_width/page_height are HPDF_UINT
; (integer truncation - kept)
Define pw.f = HPDF_Page_TextWidthRaw(page, *sampText)
Define pageHeight.l = 210
Define pageWidth.l = pw + 40

HPDF_Page_SetWidth(page, pageWidth)
HPDF_Page_SetHeight(page, pageHeight)

; finish to print text.
HPDF_Page_EndText(page)

HPDF_Page_SetLineWidth(page, 0.5)

HPDF_Page_MoveTo(page, 10, pageHeight - 25)
HPDF_Page_LineTo(page, pageWidth - 10, pageHeight - 25)
HPDF_Page_Stroke(page)

HPDF_Page_MoveTo(page, 10, pageHeight - 85)
HPDF_Page_LineTo(page, pageWidth - 10, pageHeight - 85)
HPDF_Page_Stroke(page)

; --- gate + save ---------------------------------------------------------------
If HPDF_GetError(pdf) <> #HPDF_OK
  PrintN("FAIL draw (latched error) " + HaruErrorText(pdf))
  HaruFree(pdf)
  FreeMemory(*sampText)
  End 1
EndIf

If HPDF_SaveToFile(pdf, "ttfont_demo_jp.pdf") <> #HPDF_OK
  PrintN("FAIL save " + HaruErrorText(pdf))
  HaruFree(pdf)
  FreeMemory(*sampText)
  End 1
EndIf
HaruFree(pdf)
FreeMemory(*sampText)
PrintN("PASS ttfont_demo_jp -> ttfont_demo_jp.pdf")

HaruShutdown()
CloseConsole()
End 0

; IDE Options = PureBasic 6.40 (Windows - x64)
; ExecutableFormat = Console
; EnableXP
; DPIAware
