; ---------------------------------------------------------------------------
; permission.pb - PureBasic port of libharu's permission.c
; (<< Haru Free PDF Library 2.0.0 >>, Copyright (c) 1999-2006 Takeshi Kanno,
; ZLIB license - see ../THIRD-PARTY-NOTICES.md).
; One B5 landscape page with the centered line "User cannot print and copy
; this document." (Helvetica 20), encrypted with an owner password only
; (user password ""), read-only permission (HPDF_ENABLE_READ) and revision 3
; (128-bit RC4, key length 16 -> /Encrypt /R 3 /V 2).
;
; Deviations from the C original (wrapper subset, see ../hpdf.pbi):
;  - no setjmp/longjmp error handler: one latched-error gate before the save;
;  - the C's HPDF_GetFont(pdf, "Helvetica", NULL) (NULL = font default
;    encoding) becomes HaruGetFont(pdf, "Helvetica", "") - a real C NULL;
;    all text is ASCII;
;  - grid_sheet.pbi is included for parity with the C build (the C includes
;    grid_sheet.h but never calls print_grid); grid unused;
;  - argv[0] + ".pdf" output replaced with the stable filename
;    permission.pdf.
;
; Build (from samples/):
;   MSYS2_ARG_CONV_EXCL='*' "$PUREBASIC_HOME/Compilers/pbcompilerc.exe" \
;     /CONSOLE /THREAD /EXE permission.exe permission.pb
; ---------------------------------------------------------------------------

EnableExplicit

XIncludeFile "../hpdf.pbi"
XIncludeFile "grid_sheet.pbi"   ; included for parity with the C build (the C includes grid_sheet.h); grid unused

#PERMISSION_TEXT = "User cannot print and copy this document."

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

HPDF_Page_SetSize(page, #HPDF_PAGE_SIZE_B5, #HPDF_PAGE_LANDSCAPE)

HPDF_Page_BeginText(page)
HPDF_Page_SetFontAndSize(page, hfont, 20)
Define tw.f = HPDF_Page_TextWidth(page, #PERMISSION_TEXT)
HPDF_Page_MoveTextPos(page, (HPDF_Page_GetWidth(page) - tw) / 2, (HPDF_Page_GetHeight(page) - 20) / 2)
HPDF_Page_ShowText(page, #PERMISSION_TEXT)
HPDF_Page_EndText(page)

If HPDF_SetPassword(pdf, "owner", "") <> #HPDF_OK
  PrintN("FAIL SetPassword " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
If HPDF_SetPermission(pdf, #HPDF_ENABLE_READ) <> #HPDF_OK
  PrintN("FAIL SetPermission " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
If HPDF_SetEncryptionMode(pdf, #HPDF_ENCRYPT_R3, 16) <> #HPDF_OK
  PrintN("FAIL SetEncryptionMode " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

; --- gate + save ---------------------------------------------------------------
If HPDF_GetError(pdf) <> #HPDF_OK
  PrintN("FAIL draw (latched error) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

If HPDF_SaveToFile(pdf, "permission.pdf") <> #HPDF_OK
  PrintN("FAIL save " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
HaruFree(pdf)
PrintN("PASS permission -> permission.pdf")

HaruShutdown()
CloseConsole()
End 0

; IDE Options = PureBasic 6.40 (Windows - x64)
; ExecutableFormat = Console
; EnableXP
; DPIAware
