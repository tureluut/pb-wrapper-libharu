; ---------------------------------------------------------------------------
; jpeg_demo.pb - PureBasic port of libharu's jpeg_demo.c
; (<< Haru Free PDF Library 2.0.0 >>, Copyright (c) 1999-2006 Takeshi Kanno,
; ZLIB license - see ../THIRD-PARTY-NOTICES.md).
; Draws two JPEG images (images/rgb.jpg 24-bit, images/gray.jpg 8-bit gray)
; at original size with a caption each, on a 650x500 page with an XYZ
; open-action destination.
;
; Deviations from the C original (wrapper subset, see ../hpdf.pbi):
;  - no setjmp/longjmp error handler: libharu latches the first error, so the
;    drawing is gated by one HPDF_GetError check before the save;
;  - the C's HPDF_GetFont(pdf, "Helvetica", NULL) (NULL = font default
;    encoding) becomes HaruGetFont(pdf, "Helvetica", "") - a real C NULL
;    through the raw binding; all text is ASCII;
;  - path separator '/' instead of the C's "\\" (libharu's fopen-equivalent
;    accepts forward slashes on Windows);
;  - failed image loads FAIL cleanly instead of cascading a NULL handle
;    through the draw calls (same latched-error code as the C, no crash);
;  - argv[0] + ".pdf" output replaced with the stable filename jpeg_demo.pdf.
;
; Build (from samples/):
;   MSYS2_ARG_CONV_EXCL='*' "$PUREBASIC_HOME/Compilers/pbcompilerc.exe" \
;     /CONSOLE /THREAD /EXE jpeg_demo.exe jpeg_demo.pb
; ---------------------------------------------------------------------------

EnableExplicit

XIncludeFile "../hpdf.pbi"

; jpeg_demo.c draw_image(): current page, JPEG at original size, filename +
; caption below it (two ShowTextNextLine calls under a 16pt leading).
Procedure DrawJpegImage(pdf.i, filename$, x.f, y.f, text$)
  Protected page.i = HPDF_GetCurrentPage(pdf)
  Protected image.i = HPDF_LoadJpegImageFromFile(pdf, "images/" + filename$)
  If image = 0
    ProcedureReturn            ; latched error surfaces at the gate
  EndIf

  ; Draw image to the canvas.
  HPDF_Page_DrawImage(page, image, x, y, HPDF_Image_GetWidth(image), HPDF_Image_GetHeight(image))

  ; Print the text.
  HPDF_Page_BeginText(page)
  HPDF_Page_SetTextLeading(page, 16)
  HPDF_Page_MoveTextPos(page, x, y)
  HPDF_Page_ShowTextNextLine(page, filename$)
  HPDF_Page_ShowTextNextLine(page, text$)
  HPDF_Page_EndText(page)
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

HPDF_SetCompressionMode(pdf, #HPDF_COMP_ALL)

; create default-font
Define font.i = HaruGetFont(pdf, "Helvetica", "")
If font = 0
  PrintN("FAIL font (GetFont Helvetica) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

; add a new page object.
Define page.i = HPDF_AddPage(pdf)
If page = 0
  PrintN("FAIL page " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

HPDF_Page_SetWidth(page, 650)
HPDF_Page_SetHeight(page, 500)

Define dst.i = HPDF_Page_CreateDestination(page)
HPDF_Destination_SetXYZ(dst, 0, HPDF_Page_GetHeight(page), 1)
HPDF_SetOpenAction(pdf, dst)

HPDF_Page_BeginText(page)
HPDF_Page_SetFontAndSize(page, font, 20)
HPDF_Page_MoveTextPos(page, 220, HPDF_Page_GetHeight(page) - 70)
HPDF_Page_ShowText(page, "JpegDemo")
HPDF_Page_EndText(page)

HPDF_Page_SetFontAndSize(page, font, 12)

DrawJpegImage(pdf, "rgb.jpg", 70, HPDF_Page_GetHeight(page) - 410, "24bit color image")
DrawJpegImage(pdf, "gray.jpg", 340, HPDF_Page_GetHeight(page) - 410, "8bit grayscale image")

; --- gate + save ---------------------------------------------------------------
If HPDF_GetError(pdf) <> #HPDF_OK
  PrintN("FAIL draw (latched error) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

If HPDF_SaveToFile(pdf, "jpeg_demo.pdf") <> #HPDF_OK
  PrintN("FAIL save " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
HaruFree(pdf)
PrintN("PASS jpeg_demo -> jpeg_demo.pdf")

HaruShutdown()
CloseConsole()
End 0

; IDE Options = PureBasic 6.40 (Windows - x64)
; ExecutableFormat = Console
; EnableXP
; DPIAware
