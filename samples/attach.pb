; ---------------------------------------------------------------------------
; attach.pb - PureBasic port of libharu's attach.c
; (<< Haru Free PDF Library 2.0.0 >>, Copyright (c) 1999-2006 Takeshi Kanno,
; ZLIB license - see ../THIRD-PARTY-NOTICES.md).
; One LETTER portrait page with the centered line "This PDF should have an
; attachment named basn3p08.png" (Helvetica 20) and the bundled PNG embedded
; as a document attachment (HPDF_AttachFile -> /EmbeddedFiles name tree).
;
; Deviations from the C original (wrapper subset, see ../hpdf.pbi):
;  - no setjmp/longjmp error handler: one latched-error gate before the save;
;  - the C's HPDF_GetFont(pdf, "Helvetica", NULL) (NULL = font default
;    encoding) becomes HaruGetFont(pdf, "Helvetica", "") - a real C NULL;
;    all text is ASCII;
;  - argv[0] + ".pdf" output replaced with the stable filename attach.pdf.
;
; Build (from samples/):
;   MSYS2_ARG_CONV_EXCL='*' "$PUREBASIC_HOME/Compilers/pbcompilerc.exe" \
;     /CONSOLE /THREAD /EXE attach.exe attach.pb
; ---------------------------------------------------------------------------

EnableExplicit

XIncludeFile "../hpdf.pbi"

#ATTACH_TEXT = "This PDF should have an attachment named basn3p08.png"

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

; create default-font
Define hfont.i = HaruGetFont(pdf, "Helvetica", "")
If hfont = 0
  PrintN("FAIL font (GetFont Helvetica) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

; add a new page object
Define page.i = HPDF_AddPage(pdf)
If page = 0
  PrintN("FAIL page " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

HPDF_Page_SetSize(page, #HPDF_PAGE_SIZE_LETTER, #HPDF_PAGE_PORTRAIT)

HPDF_Page_BeginText(page)
HPDF_Page_SetFontAndSize(page, hfont, 20)
Define tw.f = HPDF_Page_TextWidth(page, #ATTACH_TEXT)
HPDF_Page_MoveTextPos(page, (HPDF_Page_GetWidth(page) - tw) / 2, (HPDF_Page_GetHeight(page) - 20) / 2)
HPDF_Page_ShowText(page, #ATTACH_TEXT)
HPDF_Page_EndText(page)

; attach a file to the document
If HPDF_AttachFile(pdf, "pngsuite/basn3p08.png") = 0
  PrintN("FAIL attach " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

; --- gate + save ---------------------------------------------------------------
If HPDF_GetError(pdf) <> #HPDF_OK
  PrintN("FAIL draw (latched error) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

If HPDF_SaveToFile(pdf, "attach.pdf") <> #HPDF_OK
  PrintN("FAIL save " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
HaruFree(pdf)
PrintN("PASS attach -> attach.pdf")

HaruShutdown()
CloseConsole()
End 0

; IDE Options = PureBasic 6.40 (Windows - x64)
; ExecutableFormat = Console
; EnableXP
; DPIAware
