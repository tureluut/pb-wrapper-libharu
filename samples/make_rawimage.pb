; ---------------------------------------------------------------------------
; make_rawimage.pb - PureBasic port of libharu's make_rawimage.c
; (<< Haru Free PDF Library 2.0.0 >>, Copyright (c) 1999-2006 Takeshi Kanno,
; ZLIB license - see ../THIRD-PARTY-NOTICES.md).
; Standalone PNG -> libharu raw-image converter (no PDF output): loads a PNG
; through the libharu PNG loader, prints width/height/bits-per-component/
; color-space and dumps the raw image stream to a file.
;
; Usage: make_rawimage <in-file.png> <out-file.dat>
;
; Deviations from the C original (wrapper subset, see ../hpdf.pbi):
;  - usage is enforced for BOTH arguments (the C only checks argc < 2 and
;    would crash on a missing output name);
;  - no setjmp/longjmp error handler: libharu latches the first error - the
;    dump is gated by one HPDF_GetError check;
;  - the C digs pdf->mmgr out of the (opaque) doc struct; the port adds a
;    throwaway page and takes the doc's mmgr via the exported
;    HPDF_GetPageMMgr (a page's mmgr IS the doc's mmgr). The page is never
;    saved - this converter produces no PDF;
;  - the C reads image->stream directly from the struct; there is no
;    exported accessor, so the port reads the HPDF_Image (= HPDF_Dict)
;    stream slot at offset 64 (x64, v2.4.6 hpdf_objects.h: Dict_Rec =
;    header(8) + mmgr/error/list/4 fn-ptrs = 7x8 = 56 -> stream@64);
;  - argv[0] + ".pdf" plays no role here; the converter reads CLI paths.
;
; Build (from samples/):
;   MSYS2_ARG_CONV_EXCL='*' "$PUREBASIC_HOME/Compilers/pbcompilerc.exe" \
;     /CONSOLE /THREAD /EXE make_rawimage.exe make_rawimage.pb
; ---------------------------------------------------------------------------

EnableExplicit

XIncludeFile "../hpdf.pbi"

OpenConsole()

Define inFile$ = ProgramParameter(0)
Define outFile$ = ProgramParameter(1)

If inFile$ = "" Or outFile$ = ""
  PrintN("usage: make_rawimage <in-file-name> <out-file-name>")
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

; C's HPDF_New; HaruNew additionally enables the UTF-8 pipeline - irrelevant
; for this converter (no text, no PDF save).
Define pdf.i = HaruNew()
If pdf = 0
  PrintN("FAIL doc (HaruNew returned 0)")
  End 1
EndIf

; load image file.
Define image.i = HPDF_LoadPngImageFromFile(pdf, inFile$)
If image = 0
  PrintN("FAIL image load " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

Define iw.l = HPDF_Image_GetWidth(image)
Define ih.l = HPDF_Image_GetHeight(image)
Define bitsPerComp.l = HPDF_Image_GetBitsPerComponent(image)
Define cs$ = PeekS(HPDF_Image_GetColorSpace(image), -1, #PB_Ascii)

PrintN("width=" + Str(iw))
PrintN("height=" + Str(ih))
PrintN("bits_per_comp=" + Str(bitsPerComp))
PrintN("color_space=" + cs$)

; The doc's mmgr: take it from a throwaway page (see header note). Adding the
; page is safe - this doc is never saved.
Define dummyPage.i = HPDF_AddPage(pdf)
If dummyPage = 0
  PrintN("FAIL page " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

; save raw-data to file
Define stream.i = HPDF_FileWriter_New(HPDF_GetPageMMgr(dummyPage), outFile$)
If stream = 0
  PrintN("cannot open " + outFile$)
Else
  ; image stream slot: HPDF_Image IS HPDF_Dict; on x64 2.4.6 the stream
  ; member sits at offset 64 (derivation in the header note).
  Define imageStream.i = PeekI(image + 64)
  If HPDF_GetError(pdf) <> #HPDF_OK Or HPDF_Stream_WriteToStream(imageStream, stream, 0, 0) <> #HPDF_OK
    PrintN("FAIL dump " + HaruErrorText(pdf))
    HPDF_Stream_Free(stream)
    HaruFree(pdf)
    End 1
  EndIf
EndIf

HPDF_Stream_Free(stream)

HaruFree(pdf)
PrintN("PASS make_rawimage " + inFile$ + " -> " + outFile$)

HaruShutdown()
CloseConsole()
End 0

; IDE Options = PureBasic 6.40 (Windows - x64)
; ExecutableFormat = Console
; EnableXP
; DPIAware
