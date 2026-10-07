; ---------------------------------------------------------------------------
; font_demo.pb - PureBasic port of libharu's font_demo.c
; (<< Haru Free PDF Library 2.0.0 >>, Copyright (c) 1999-2006 Takeshi Kanno,
; ZLIB license - see ../THIRD-PARTY-NOTICES.md).
; Lists all 14 standard Type1 (base-14) fonts with a sample line each, on a
; default-size page with a border rectangle and a centered title.
;
; Deviations from the C original (wrapper subset, see ../hpdf.pbi):
;  - no setjmp/longjmp error handler: one latched-error gate before the save;
;  - HPDF_GetFont(pdf, name, NULL): the C passes NULL for the font default
;    encoding; the port uses HaruGetFont(pdf, name, "") which passes a real
;    C NULL through the raw HPDF_GetFont binding - all sample text is pure
;    ASCII, so Standard/WinAnsi byte pass-through is identical;
;  - page geometry queried live via HPDF_Page_GetWidth/GetHeight (now bound);
;  - argv[0] + ".pdf" output replaced with the stable filename font_demo.pdf.
;
; Build (from samples/):
;   MSYS2_ARG_CONV_EXCL='*' "$PUREBASIC_HOME/Compilers/pbcompilerc.exe" \
;     /CONSOLE /THREAD /EXE font_demo.exe font_demo.pb
; ---------------------------------------------------------------------------

EnableExplicit

XIncludeFile "../hpdf.pbi"

OpenConsole()

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

; Add a new page object.
Define page.i = HPDF_AddPage(pdf)
If page = 0
  PrintN("FAIL page " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

Define height.f = HPDF_Page_GetHeight(page)
Define width.f = HPDF_Page_GetWidth(page)

; Print the lines of the page.
HPDF_Page_SetLineWidth(page, 1)
HPDF_Page_Rectangle(page, 50, 50, width - 100, height - 110)
HPDF_Page_Stroke(page)

; Print the title of the page (with positioning center).
Define defFont.i = HaruGetFont(pdf, "Helvetica", "")
If defFont = 0
  PrintN("FAIL font (GetFont Helvetica) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

HPDF_Page_SetFontAndSize(page, defFont, 24)

Define pageTitle$ = "Font Demo"
Define tw.f = HPDF_Page_TextWidth(page, pageTitle$)
HPDF_Page_BeginText(page)
HPDF_Page_TextOut(page, (width - tw) / 2, height - 50, pageTitle$)
HPDF_Page_EndText(page)

; output subtitle.
HPDF_Page_BeginText(page)
HPDF_Page_SetFontAndSize(page, defFont, 16)
HPDF_Page_TextOut(page, 60, height - 80, "<Standard Type1 fonts samples>")
HPDF_Page_EndText(page)

HPDF_Page_BeginText(page)
HPDF_Page_MoveTextPos(page, 60, height - 105)

Dim fontList.s(13)
fontList(0) = "Courier"
fontList(1) = "Courier-Bold"
fontList(2) = "Courier-Oblique"
fontList(3) = "Courier-BoldOblique"
fontList(4) = "Helvetica"
fontList(5) = "Helvetica-Bold"
fontList(6) = "Helvetica-Oblique"
fontList(7) = "Helvetica-BoldOblique"
fontList(8) = "Times-Roman"
fontList(9) = "Times-Bold"
fontList(10) = "Times-Italic"
fontList(11) = "Times-BoldItalic"
fontList(12) = "Symbol"
fontList(13) = "ZapfDingbats"

Define i.l
Define sampText$ = "abcdefgABCDEFG12345!#$%&+-@?"

For i = 0 To 13
  Define font.i = HaruGetFont(pdf, fontList(i), "")
  If font = 0
    PrintN("FAIL font (" + fontList(i) + ") " + HaruErrorText(pdf))
    HaruFree(pdf)
    End 1
  EndIf

  ; print a label of text
  HPDF_Page_SetFontAndSize(page, defFont, 9)
  HPDF_Page_ShowText(page, fontList(i))
  HPDF_Page_MoveTextPos(page, 0, -18)

  ; print a sample text.
  HPDF_Page_SetFontAndSize(page, font, 20)
  HPDF_Page_ShowText(page, sampText$)
  HPDF_Page_MoveTextPos(page, 0, -20)
Next

HPDF_Page_EndText(page)

; --- gate + save ---------------------------------------------------------------
If HPDF_GetError(pdf) <> #HPDF_OK
  PrintN("FAIL draw (latched error) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

If HPDF_SaveToFile(pdf, "font_demo.pdf") <> #HPDF_OK
  PrintN("FAIL save " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
HaruFree(pdf)
PrintN("PASS font_demo -> font_demo.pdf")

HaruShutdown()
CloseConsole()
End 0

; IDE Options = PureBasic 6.40 (Windows - x64)
; ExecutableFormat = Console
; EnableXP
; DPIAware
