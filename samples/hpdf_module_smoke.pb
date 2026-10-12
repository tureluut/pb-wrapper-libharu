; HPDF module smoke test. Run from samples/; writes hpdf_module_smoke.pdf.
; Uses only bundled assets. All libharu names are explicitly namespaced.
EnableExplicit
XIncludeFile "../hpdf_module.pbi"

Procedure.i Main()
  Protected pdf.i, page.i, font.i, gs.i, emfile.i, *bytes
  Protected result.i = 1
  Protected pos.HPDF::HPDFPoint
  Protected rect.HPDF::HPDFRect
  Protected date.HPDF::HPDFDate
  Protected fallbackDir.s

  CompilerIf #PB_Compiler_OS = #PB_OS_Linux
    fallbackDir = "../libraries/linux/x64/"
  CompilerElse
    fallbackDir = "../libraries/windows/x64/"
  CompilerEndIf

  ; A missing library must fail cleanly, before any function-pointer call.
  If HPDF::HaruInit("./nonexistent-hpdf-module-directory/") <> 0
    PrintN("FAIL: missing-library test unexpectedly succeeded")
    HPDF::HaruShutdown()
    ProcedureReturn 1
  EndIf
  If HPDF::HaruInit(fallbackDir) = 0
    PrintN("FAIL init: " + HPDF::HaruMissing$)
    ProcedureReturn 1
  EndIf
  PrintN("libharu " + PeekS(HPDF::HPDF_GetVersion(), -1, #PB_Ascii))
  PrintN("Bound functions: " + Str(HPDF::HaruBound))

  Repeat
    If HPDF::HaruBound <> 169 Or HPDF::HaruMissing$ <> ""
      PrintN("FAIL: incomplete bindings") : Break
    EndIf
    If SizeOf(HPDF::HPDFPoint) <> 8 Or SizeOf(HPDF::HPDFRect) <> 16 Or SizeOf(HPDF::HPDFDate) <> 36
      PrintN("FAIL: public structure layout") : Break
    EndIf
    pdf = HPDF::HaruNew()
    If pdf = 0
      PrintN("FAIL: HaruNew") : Break
    EndIf
    page = HPDF::HaruAddPage(pdf)
    font = HPDF::HaruTTFFont(pdf, "ttfont/PenguinAttack.ttf")
    If page = 0 Or font = 0
      PrintN("FAIL page/font: " + HPDF::HaruErrorText(pdf)) : Break
    EndIf
    If HPDF::HaruTTFFont(pdf, "ttfont/PenguinAttack.ttf") <> font
      PrintN("FAIL: font cache") : Break
    EndIf
    HPDF::HPDF_Page_SetFontAndSize(page, font, 22)
    If HPDF::HaruTextOut(page, 50, 750, "Module UTF-8: caf" + Chr($E9)) <> HPDF::#HPDF_OK
      PrintN("FAIL UTF-8 text: " + HPDF::HaruErrorText(pdf)) : Break
    EndIf

    font = HPDF::HaruGetFont(pdf, "Helvetica", "WinAnsiEncoding")
    *bytes = HPDF::HaruWinAnsiMem("Namespaced API " + Chr($2014) + " " + Chr($20AC) + " 12.50")
    If font = 0 Or *bytes = 0
      PrintN("FAIL: raw font/buffer") : Break
    EndIf
    HPDF::HPDF_Page_SetFontAndSize(page, font, 14)
    If HPDF::HaruTextOutRaw(page, 50, 710, *bytes) <> HPDF::#HPDF_OK
      PrintN("FAIL raw text: " + HPDF::HaruErrorText(pdf)) : Break
    EndIf
    gs = HPDF::HaruAlpha(pdf, 0.5)
    If gs = 0 Or HPDF::HaruAlpha(pdf, 0.5) <> gs
      PrintN("FAIL: alpha cache") : Break
    EndIf
    HPDF::HPDF_Page_SetExtGState(page, gs)
    HPDF::HPDF_Page_SetRGBStroke(page, 0.2, 0.4, 0.8)
    HPDF::HPDF_Page_MoveTo(page, 50, 680)
    HPDF::HPDF_Page_LineTo(page, 300, 680)
    If HPDF::HPDF_Page_GetCurrentPos2(page, @pos) <> HPDF::#HPDF_OK Or pos\x <> 300 Or pos\y <> 680
      PrintN("FAIL: point output parameter") : Break
    EndIf
    HPDF::HPDF_Page_Stroke(page)

    rect\left = 50 : rect\bottom = 705 : rect\right = 300 : rect\top = 730
    If HPDF::HPDF_Page_CreateURILinkAnnot(page, @rect, "https://libharu.org/") = 0
      PrintN("FAIL: rectangle parameter") : Break
    EndIf
    ; Exercise all three by-value date exports with nonzero time/offsets.
    date\year = 2026 : date\month = 1 : date\day = 2
    date\hour = 17 : date\minutes = 10 : date\seconds = 30
    date\ind = Asc("+") : date\off_hour = 1 : date\off_minutes = 30
    If HPDF::HPDF_SetInfoDateAttr(pdf, HPDF::#HPDF_INFO_CREATION_DATE, @date) <> HPDF::#HPDF_OK
      PrintN("FAIL: document date " + HPDF::HaruErrorText(pdf)) : Break
    EndIf
    emfile = HPDF::HPDF_AttachFile(pdf, "pdf_a/factur-x.xml")
    If emfile = 0
      PrintN("FAIL: embedded file " + HPDF::HaruErrorText(pdf)) : Break
    EndIf
    If HPDF::HPDF_EmbeddedFile_SetCreationDate(emfile, @date) <> HPDF::#HPDF_OK
      PrintN("FAIL: embedded creation date " + HPDF::HaruErrorText(pdf)) : Break
    EndIf
    date\day = 3 : date\ind = Asc("-") : date\off_hour = 2 : date\off_minutes = 15
    If HPDF::HPDF_EmbeddedFile_SetLastModificationDate(emfile, @date) <> HPDF::#HPDF_OK
      PrintN("FAIL: embedded modification date " + HPDF::HaruErrorText(pdf)) : Break
    EndIf
    HPDF::HPDF_SetInfoAttr(pdf, HPDF::#HPDF_INFO_TITLE, "HPDF module smoke test")
    If HPDF::HPDF_GetError(pdf) <> HPDF::#HPDF_OK
      PrintN("FAIL drawing/metadata: " + HPDF::HaruErrorText(pdf)) : Break
    EndIf
    If HPDF::HPDF_SaveToFile(pdf, "hpdf_module_smoke.pdf") <> HPDF::#HPDF_OK
      PrintN("FAIL save: " + HPDF::HaruErrorText(pdf)) : Break
    EndIf
    result = 0
  Until #True

  If *bytes : FreeMemory(*bytes) : EndIf
  If pdf : HPDF::HaruFree(pdf) : EndIf
  HPDF::HaruShutdown()
  If result = 0 : PrintN("PASS -> hpdf_module_smoke.pdf") : EndIf
  ProcedureReturn result
EndProcedure

If OpenConsole() = 0 : End 1 : EndIf
Define exitCode.i = Main()
CloseConsole()
End exitCode

; IDE Options = PureBasic 6.40 (Windows - x64)
; ExecutableFormat = Console
