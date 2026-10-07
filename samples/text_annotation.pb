; ---------------------------------------------------------------------------
; text_annotation.pb - PureBasic port of libharu's text_annotation.c
; (<< Haru Free PDF Library 2.0.0 >>, Copyright (c) 1999-2006 Takeshi Kanno,
; ZLIB license - see ../THIRD-PARTY-NOTICES.md).
; Eight text annotations with fixed rects on a 400x500 page (Times-Roman,
; WinAnsiEncoding): all seven icons (Comment/Key/Note/Help/NewParagraph/
; Paragraph/Insert), the first annotation opened initially, plus an eighth
; annotation with ISO8859-2 contents through the ISO8859-2 encoder, and a
; static label under each rect.
;
; Deviations from the C original (wrapper subset, see ../hpdf.pbi):
;  - no setjmp/longjmp error handler: libharu latches the first error, so the
;    drawing is gated by one HPDF_GetError check before the save;
;  - HPDF_Page_CreateTextAnnot takes a char* contents - the wrapper binds
;    only the raw variant HPDF_Page_CreateTextAnnotRaw; contents go through
;    HaruAsciiMem (1:1 single-byte buffer). The ISO8859-2 contents' accented
;    letters are built as the exact bytes D3..D9 (matching the C source's
;    Latin-2 literals) and handed to libharu with the ISO8859-2 encoder, and
;    the NULL encoder of the other seven becomes encoder 0 - all like the C;
;  - the C's by-value HPDF_Rect arguments pass as pointers to HPDFRect
;    structs (Win64 ABI: struct args > 8 bytes by reference);
;  - the C source's Latin-2 comment letters in this header are described, not
;    embedded - all drawn text is ASCII except the annotation contents;
;  - argv[0] + ".pdf" output replaced with the stable filename
;    text_annotation.pdf.
;
; Build (from samples/):
;   MSYS2_ARG_CONV_EXCL='*' "$PUREBASIC_HOME/Compilers/pbcompilerc.exe" \
;     /CONSOLE /THREAD /EXE text_annotation.exe text_annotation.pb
; ---------------------------------------------------------------------------

EnableExplicit

XIncludeFile "../hpdf.pbi"

; HPDF_Page_CreateTextAnnot with a PB string contents (raw char* binding +
; HaruAsciiMem; encoder 0 = the C's NULL). Bytes are consumed synchronously.
Procedure.i CreateTextAnnot(page.i, *rect, contents$, encoder.i = 0)
  Protected *contents = HaruAsciiMem(contents$)
  Protected annot.i = HPDF_Page_CreateTextAnnotRaw(page, *rect, *contents, encoder)
  FreeMemory(*contents)
  ProcedureReturn annot
EndProcedure

; text_annotation.c's static label under a rect.
Procedure ShowLabel(page.i, font.i, *rect.HPDFRect, label$)
  HPDF_Page_BeginText(page)
  HPDF_Page_MoveTextPos(page, *rect\left + 35, *rect\top - 20)
  HPDF_Page_ShowText(page, label$)
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

; use Times-Roman font.
Define font.i = HaruGetFont(pdf, "Times-Roman", "WinAnsiEncoding")
If font = 0
  PrintN("FAIL font (GetFont Times-Roman) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

Define page.i = HPDF_AddPage(pdf)
If page = 0
  PrintN("FAIL page " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

HPDF_Page_SetWidth(page, 400)
HPDF_Page_SetHeight(page, 500)

HPDF_Page_BeginText(page)
HPDF_Page_SetFontAndSize(page, font, 16)
HPDF_Page_MoveTextPos(page, 130, 450)
HPDF_Page_ShowText(page, "Annotation Demo")
HPDF_Page_EndText(page)

; HPDF_Rect rectN = {left, bottom, right, top} initializers
Define rect1.HPDFRect : rect1\left = 50 : rect1\bottom = 350 : rect1\right = 150 : rect1\top = 400
Define rect2.HPDFRect : rect2\left = 210 : rect2\bottom = 350 : rect2\right = 350 : rect2\top = 400
Define rect3.HPDFRect : rect3\left = 50 : rect3\bottom = 250 : rect3\right = 150 : rect3\top = 300
Define rect4.HPDFRect : rect4\left = 210 : rect4\bottom = 250 : rect4\right = 350 : rect4\top = 300
Define rect5.HPDFRect : rect5\left = 50 : rect5\bottom = 150 : rect5\right = 150 : rect5\top = 200
Define rect6.HPDFRect : rect6\left = 210 : rect6\bottom = 150 : rect6\right = 350 : rect6\top = 200
Define rect7.HPDFRect : rect7\left = 50 : rect7\bottom = 50 : rect7\right = 150 : rect7\top = 100
Define rect8.HPDFRect : rect8\left = 210 : rect8\bottom = 50 : rect8\right = 350 : rect8\top = 100

Define annot.i

annot = CreateTextAnnot(page, @rect1, "Annotation with Comment Icon. " + Chr(10) + " This annotation set to be opened initially.")
HPDF_TextAnnot_SetIcon(annot, #HPDF_ANNOT_ICON_COMMENT)
HPDF_TextAnnot_SetOpened(annot, #HPDF_TRUE)

annot = CreateTextAnnot(page, @rect2, "Annotation with Key Icon")
HPDF_TextAnnot_SetIcon(annot, #HPDF_ANNOT_ICON_PARAGRAPH)

annot = CreateTextAnnot(page, @rect3, "Annotation with Note Icon")
HPDF_TextAnnot_SetIcon(annot, #HPDF_ANNOT_ICON_NOTE)

annot = CreateTextAnnot(page, @rect4, "Annotation with Help Icon")
HPDF_TextAnnot_SetIcon(annot, #HPDF_ANNOT_ICON_HELP)

annot = CreateTextAnnot(page, @rect5, "Annotation with NewParagraph Icon")
HPDF_TextAnnot_SetIcon(annot, #HPDF_ANNOT_ICON_NEW_PARAGRAPH)

annot = CreateTextAnnot(page, @rect6, "Annotation with Paragraph Icon")
HPDF_TextAnnot_SetIcon(annot, #HPDF_ANNOT_ICON_PARAGRAPH)

annot = CreateTextAnnot(page, @rect7, "Annotation with Insert Icon")
HPDF_TextAnnot_SetIcon(annot, #HPDF_ANNOT_ICON_INSERT)

; ISO8859-2-encoded contents ("ISO8859-2 text " + D3..D9 bytes)
Define encoder.i = HPDF_GetEncoder(pdf, "ISO8859-2")
annot = CreateTextAnnot(page, @rect8, "Annotation with ISO8859 text " + Chr($D3) + Chr($D4) + Chr($D5) + Chr($D6) + Chr($D7) + Chr($D8) + Chr($D9), encoder)

HPDF_Page_SetFontAndSize(page, font, 11)

ShowLabel(page, font, rect1, "Comment Icon.")
ShowLabel(page, font, rect2, "Key Icon")
ShowLabel(page, font, rect3, "Note Icon.")
ShowLabel(page, font, rect4, "Help Icon")
ShowLabel(page, font, rect5, "NewParagraph Icon")
ShowLabel(page, font, rect6, "Paragraph Icon")
ShowLabel(page, font, rect7, "Insert Icon")
ShowLabel(page, font, rect8, "Text Icon(ISO8859-2 text)")

; --- gate + save ---------------------------------------------------------------
If HPDF_GetError(pdf) <> #HPDF_OK
  PrintN("FAIL draw (latched error) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

If HPDF_SaveToFile(pdf, "text_annotation.pdf") <> #HPDF_OK
  PrintN("FAIL save " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
HaruFree(pdf)
PrintN("PASS text_annotation -> text_annotation.pdf")

HaruShutdown()
CloseConsole()
End 0

; IDE Options = PureBasic 6.40 (Windows - x64)
; ExecutableFormat = Console
; EnableXP
; DPIAware
