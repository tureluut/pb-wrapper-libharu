; ---------------------------------------------------------------------------
; ttfont_demo.pb - PureBasic port of libharu's ttfont_demo.c
; (<< Haru Free PDF Library 2.0.0 >>, Copyright (c) 1999-2006 Takeshi Kanno,
; ZLIB license - see ../THIRD-PARTY-NOTICES.md).
; TrueType font demo: loads a TTF/TTC (embedded subset with the -E flag),
; prints the internal font name plus alphabet/digit lines and the pangram at
; 10/16/23/30pt, then resizes the page to the measured text width + 40 by 210
; and draws two rules.
;
; Usage: ttfont_demo <font-file> [-E]
;
; Deviations from the C original (wrapper subset, see ../hpdf.pbi):
;  - no setjmp/longjmp error handler: libharu latches the first error, so the
;    drawing is gated by one HPDF_GetError check before the save;
;  - the C's HPDF_GetFont(pdf, <name>, NULL) calls (NULL = font default
;    encoding) become HaruGetFont(pdf, <name>, "") - a real C NULL through
;    the raw binding; all text is ASCII (single-byte font: byte pass-through);
;  - a failed font load FAILs cleanly instead of passing NULL into
;    HPDF_Page_ShowText (same latched-error code, no crash);
;  - argv[0] + ".pdf" output replaced with the stable filename
;    ttfont_demo.pdf.
;
; Build (from samples/):
;   MSYS2_ARG_CONV_EXCL='*' "$PUREBASIC_HOME/Compilers/pbcompilerc.exe" \
;     /CONSOLE /THREAD /EXE ttfont_demo.exe ttfont_demo.pb
; ---------------------------------------------------------------------------

EnableExplicit

XIncludeFile "../hpdf.pbi"

OpenConsole()

Define fontFile$ = ProgramParameter(0)
Define embedArg$ = ProgramParameter(1)

If fontFile$ = ""
  PrintN("usage: ttfont_demo [path to font file] -E(embedding font).")
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

Define sampText$ = "The quick brown fox jumps over the lazy dog."

; Add a new page object.
Define page.i = HPDF_AddPage(pdf)
If page = 0
  PrintN("FAIL page " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

Define titleFont.i = HaruGetFont(pdf, "Helvetica", "")
If titleFont = 0
  PrintN("FAIL font (GetFont Helvetica) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

; if argc > 2 && memcmp(argv[2], "-E", 2) == 0 -> embed
Define embed.l = #HPDF_FALSE
If Left(embedArg$, 2) = "-E"
  embed = #HPDF_TRUE
EndIf

Define namePtr.i = HPDF_LoadTTFontFromFile(pdf, fontFile$, embed)
If namePtr = 0
  PrintN("FAIL font load (" + fontFile$ + ") " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
Define detailFontName$ = PeekS(namePtr, -1, #PB_Ascii)

Define detailFont.i = HaruGetFont(pdf, detailFontName$, "")
If detailFont = 0
  PrintN("FAIL font (GetFont " + detailFontName$ + ") " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

HPDF_Page_SetFontAndSize(page, titleFont, 10)

HPDF_Page_BeginText(page)

; Move the position of the text to top of the page.
HPDF_Page_MoveTextPos(page, 10, 190)
HPDF_Page_ShowText(page, detailFontName$)

If embed
  HPDF_Page_ShowText(page, "(Embedded Subset)")
EndIf

HPDF_Page_SetFontAndSize(page, detailFont, 15)
HPDF_Page_MoveTextPos(page, 10, -20)
HPDF_Page_ShowText(page, "abcdefghijklmnopqrstuvwxyz")
HPDF_Page_MoveTextPos(page, 0, -20)
HPDF_Page_ShowText(page, "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
HPDF_Page_MoveTextPos(page, 0, -20)
HPDF_Page_ShowText(page, "1234567890")
HPDF_Page_MoveTextPos(page, 0, -20)

HPDF_Page_SetFontAndSize(page, detailFont, 10)
HPDF_Page_ShowText(page, sampText$)
HPDF_Page_MoveTextPos(page, 0, -18)

HPDF_Page_SetFontAndSize(page, detailFont, 16)
HPDF_Page_ShowText(page, sampText$)
HPDF_Page_MoveTextPos(page, 0, -27)

HPDF_Page_SetFontAndSize(page, detailFont, 23)
HPDF_Page_ShowText(page, sampText$)
HPDF_Page_MoveTextPos(page, 0, -36)

HPDF_Page_SetFontAndSize(page, detailFont, 30)
HPDF_Page_ShowText(page, sampText$)
HPDF_Page_MoveTextPos(page, 0, -36)

Define pw.f = HPDF_Page_TextWidth(page, sampText$)
Define pageHeight.f = 210
Define pageWidth.f = pw + 40

HPDF_Page_SetWidth(page, pageWidth)
HPDF_Page_SetHeight(page, pageHeight)

; Finish to print text.
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
  End 1
EndIf

If HPDF_SaveToFile(pdf, "ttfont_demo.pdf") <> #HPDF_OK
  PrintN("FAIL save " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
HaruFree(pdf)
PrintN("PASS ttfont_demo -> ttfont_demo.pdf")

HaruShutdown()
CloseConsole()
End 0

; IDE Options = PureBasic 6.40 (Windows - x64)
; ExecutableFormat = Console
; EnableXP
; DPIAware
