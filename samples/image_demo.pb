; ---------------------------------------------------------------------------
; image_demo.pb - PureBasic port of libharu's image_demo.c
; (<< Haru Free PDF Library 2.0.0 >>, Copyright (c) 1999-2006 Takeshi Kanno,
; ZLIB license - see ../THIRD-PARTY-NOTICES.md).
; Image layout demo on a 550x500 page: basn3p02.png drawn at actual size,
; scaled in X and in Y, skewed (Concat + ExecuteXObject), rotated 30 deg,
; basn3p02 masked by basn0g01 (stencil mask, "MASKMASK" backdrop) and
; maskimage.png with an RGB /MaskColor (0,255,0,0,0,255).
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
;  - argv[0] + ".pdf" output replaced with the stable filename image_demo.pdf.
;
; Build (from samples/):
;   MSYS2_ARG_CONV_EXCL='*' "$PUREBASIC_HOME/Compilers/pbcompilerc.exe" \
;     /CONSOLE /THREAD /EXE image_demo.exe image_demo.pb
; ---------------------------------------------------------------------------

EnableExplicit

XIncludeFile "../hpdf.pbi"

; image_demo.c show_description(): coordinate crosshair at (x, y), the
; coordinates as text to its left, and the description underneath. The font
; is whatever is current on the page (HPDF_Page_GetCurrentFont).
Procedure ShowDescription(page.i, x.f, y.f, text$)
  Protected buf$ = "(x=" + Str(Int(x)) + ",y=" + Str(Int(y)) + ")"

  HPDF_Page_MoveTo(page, x, y - 10)
  HPDF_Page_LineTo(page, x, y + 10)
  HPDF_Page_MoveTo(page, x - 10, y)
  HPDF_Page_LineTo(page, x + 10, y)
  HPDF_Page_Stroke(page)

  HPDF_Page_SetFontAndSize(page, HPDF_Page_GetCurrentFont(page), 8)
  HPDF_Page_SetRGBFill(page, 0, 0, 0)

  HPDF_Page_BeginText(page)
  HPDF_Page_MoveTextPos(page, x - HPDF_Page_TextWidth(page, buf$) - 5, y - 10)
  HPDF_Page_ShowText(page, buf$)
  HPDF_Page_EndText(page)

  HPDF_Page_BeginText(page)
  HPDF_Page_MoveTextPos(page, x - 20, y - 25)
  HPDF_Page_ShowText(page, text$)
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

HPDF_Page_SetWidth(page, 550)
HPDF_Page_SetHeight(page, 500)

Define dst.i = HPDF_Page_CreateDestination(page)
HPDF_Destination_SetXYZ(dst, 0, HPDF_Page_GetHeight(page), 1)
HPDF_SetOpenAction(pdf, dst)

HPDF_Page_BeginText(page)
HPDF_Page_SetFontAndSize(page, font, 20)
HPDF_Page_MoveTextPos(page, 220, HPDF_Page_GetHeight(page) - 70)
HPDF_Page_ShowText(page, "ImageDemo")
HPDF_Page_EndText(page)

; load image files.
Define image.i = HPDF_LoadPngImageFromFile(pdf, "pngsuite/basn3p02.png")
; image1 is masked by image2.
Define image1.i = HPDF_LoadPngImageFromFile(pdf, "pngsuite/basn3p02.png")
; image2 is a mask image.
Define image2.i = HPDF_LoadPngImageFromFile(pdf, "pngsuite/basn0g01.png")
; image3 is a RGB-color image. we use this image for color-mask demo.
Define image3.i = HPDF_LoadPngImageFromFile(pdf, "pngsuite/maskimage.png")

If image = 0 Or image1 = 0 Or image2 = 0 Or image3 = 0
  PrintN("FAIL image load " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

Define iw.f = HPDF_Image_GetWidth(image)
Define ih.f = HPDF_Image_GetHeight(image)

HPDF_Page_SetLineWidth(page, 0.5)

Define x.f = 100
Define y.f = HPDF_Page_GetHeight(page) - 150

; Draw image to the canvas. (normal-mode with actual size.)
HPDF_Page_DrawImage(page, image, x, y, iw, ih)
ShowDescription(page, x, y, "Actual Size")

x + 150

; Scalling image (X direction)
HPDF_Page_DrawImage(page, image, x, y, iw * 1.5, ih)
ShowDescription(page, x, y, "Scalling image (X direction)")

x + 150

; Scalling image (Y direction).
HPDF_Page_DrawImage(page, image, x, y, iw, ih * 1.5)
ShowDescription(page, x, y, "Scalling image (Y direction)")

x = 100
y - 120

; Skewing image.
Define angle1.f = 10
Define angle2.f = 20
Define rad1.f = angle1 / 180 * 3.141592
Define rad2.f = angle2 / 180 * 3.141592

HPDF_Page_GSave(page)
HPDF_Page_Concat(page, iw, Tan(rad1) * iw, Tan(rad2) * ih, ih, x, y)
HPDF_Page_ExecuteXObject(page, image)
HPDF_Page_GRestore(page)

ShowDescription(page, x, y, "Skewing image")

x + 150

; Rotating image
Define angle.f = 30                    ; rotation of 30 degrees.
Define rad.f = angle / 180 * 3.141592  ; Calculate the radian value.

HPDF_Page_GSave(page)
HPDF_Page_Concat(page, iw * Cos(rad), iw * Sin(rad), ih * -Sin(rad), ih * Cos(rad), x, y)
HPDF_Page_ExecuteXObject(page, image)
HPDF_Page_GRestore(page)

ShowDescription(page, x, y, "Rotating image")

x + 150

; draw masked image.

; Set image2 to the mask image of image1
HPDF_Image_SetMaskImage(image1, image2)

HPDF_Page_SetRGBFill(page, 0, 0, 0)
HPDF_Page_BeginText(page)
HPDF_Page_MoveTextPos(page, x - 6, y + 14)
HPDF_Page_ShowText(page, "MASKMASK")
HPDF_Page_EndText(page)

HPDF_Page_DrawImage(page, image1, x - 3, y - 3, iw + 6, ih + 6)

ShowDescription(page, x, y, "masked image")

x = 100
y - 120

; color mask.
HPDF_Page_SetRGBFill(page, 0, 0, 0)
HPDF_Page_BeginText(page)
HPDF_Page_MoveTextPos(page, x - 6, y + 14)
HPDF_Page_ShowText(page, "MASKMASK")
HPDF_Page_EndText(page)

HPDF_Image_SetColorMask(image3, 0, 255, 0, 0, 0, 255)
HPDF_Page_DrawImage(page, image3, x, y, iw, ih)

ShowDescription(page, x, y, "Color Mask")

; --- gate + save ---------------------------------------------------------------
If HPDF_GetError(pdf) <> #HPDF_OK
  PrintN("FAIL draw (latched error) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

If HPDF_SaveToFile(pdf, "image_demo.pdf") <> #HPDF_OK
  PrintN("FAIL save " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
HaruFree(pdf)
PrintN("PASS image_demo -> image_demo.pdf")

HaruShutdown()
CloseConsole()
End 0

; IDE Options = PureBasic 6.40 (Windows - x64)
; ExecutableFormat = Console
; EnableXP
; DPIAware
