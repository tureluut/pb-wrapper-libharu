; ---------------------------------------------------------------------------
; chfont_demo.pb - PureBasic port of libharu's chfont_demo.c
; (<< Haru Free PDF Library 2.0.0 >>, Copyright (c) 1999-2006 Takeshi Kanno,
; ZLIB license - see ../THIRD-PARTY-NOTICES.md).
; Alternating Chinese/Japanese text demo: loads two TTC faces by index (GBK
; and SJIS), fetches them with GBK-EUC-H and 90ms-RKSJ-H, then interleaves
; the lines of mbtext/cp936.txt and mbtext/cp932.txt over a gridded 550x300
; page.
;
; Usage: chfont_demo <cp936-ttc-font-file-name> <cp936-index>
;                    <cp932-ttc-font-file-name> <cp932-index>
;
; ASSET-DEPENDENT (like the C): needs two user-supplied TTC font files, not
; part of this repository.
;
; Deviations from the C original (wrapper subset, see ../hpdf.pbi):
;  - the C's HPDF_New(...) is HaruNew() (adds the UTF-8 pipeline - no
;    behavioral difference: the MBCS text is drawn as RAW bytes);
;  - no setjmp/longjmp error handler: one latched-error gate before the save;
;  - the MBCS file lines are drawn through the raw binding
;    HPDF_Page_ShowTextRaw - a p-utf8 string arg would re-encode the
;    double-byte codes (the C passes char buffers directly); lines are read
;    as raw bytes with direct ReadByte() calls, NOT ReadString(#PB_Ascii)
;    (that converts file bytes through the system ANSI codepage CP1252 and
;    remaps CJK lead bytes - not byte-exact); the C's no-op
;    buf[strlen(buf)] = 0 is dropped (the fgets '\n' stays in the buffer,
;    like the C);
;  - failed font loads / missing text files FAIL cleanly (the C would pass
;    NULL on after the latched error);
;  - path separator '/' instead of the C's "\\\\";
;  - argv[0] + ".pdf" output replaced with the stable filename
;    chfont_demo.pdf.
;
; Build (from samples/):
;   MSYS2_ARG_CONV_EXCL='*' "$PUREBASIC_HOME/Compilers/pbcompilerc.exe" \
;     /CONSOLE /THREAD /EXE chfont_demo.exe chfont_demo.pb
; ---------------------------------------------------------------------------

EnableExplicit

XIncludeFile "../hpdf.pbi"
XIncludeFile "grid_sheet.pbi"

; Reads one MBCS text line as a NUL-terminated raw byte buffer (the C's
; fgets(buf, 1024, f): up to 1023 bytes, '\n' kept if present). NOTE: reads
; raw bytes - ReadString(#PB_Ascii) runs through the system ANSI codepage
; (CP1252) and remaps CJK lead bytes, breaking the byte-exact round-trip.
; Caller frees.
Procedure.i ReadLineBytes(fd.i)
  Protected *buf = AllocateMemory(1024)      ; C: char buf[1024]
  If *buf = 0
    ProcedureReturn 0
  EndIf
  Protected n.i = 0
  Protected c.i
  While n < 1023 And Not Eof(fd)
    c = ReadByte(fd) & $FF
    PokeA(*buf + n, c)
    n + 1
    If c = 10                                ; '\n' - fgets stops after, keeping it
      Break
    EndIf
  Wend
  PokeA(*buf + n, 0)
  ProcedureReturn *buf
EndProcedure

OpenConsole()

; CLI (the C's argc < 4 usage gate; argv[0] is implicit in PB)
Define cp936Ttc$ = ProgramParameter(0)
Define cp936Index.l = Val(ProgramParameter(1))
Define cp932Ttc$ = ProgramParameter(2)
Define cp932Index.l = Val(ProgramParameter(3))

If cp936Ttc$ = "" Or cp932Ttc$ = ""
  PrintN("chfont_demo <cp936-ttc-font-file-name> <cp936-index> <cp932-ttc-font-file-name> <cp932-index>")
  End 1
EndIf

Define cp932Fd.i = ReadFile(#PB_Any, "mbtext/cp932.txt")
If cp932Fd = 0
  PrintN("error: cannot open cp932.txt")
  End 1
EndIf

Define cp936Fd.i = ReadFile(#PB_Any, "mbtext/cp936.txt")
If cp936Fd = 0
  PrintN("error: cannot open cp936.txt")
  CloseFile(cp932Fd)
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

HPDF_SetCompressionMode(pdf, #HPDF_COMP_ALL)
HPDF_UseJPEncodings(pdf)
HPDF_UseCNSEncodings(pdf)

Define namePtr.i = HPDF_LoadTTFontFromFile2(pdf, cp936Ttc$, cp936Index, #HPDF_TRUE)
If namePtr = 0
  PrintN("FAIL font load (" + cp936Ttc$ + ") " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
Define fcp936Name$ = PeekS(namePtr, -1, #PB_Ascii)

namePtr = HPDF_LoadTTFontFromFile2(pdf, cp932Ttc$, cp932Index, #HPDF_TRUE)
If namePtr = 0
  PrintN("FAIL font load (" + cp932Ttc$ + ") " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
Define fcp932Name$ = PeekS(namePtr, -1, #PB_Ascii)

; add a new page object.
Define page.i = HPDF_AddPage(pdf)
If page = 0
  PrintN("FAIL page " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

HPDF_Page_SetHeight(page, 300)
HPDF_Page_SetWidth(page, 550)

Define fcp936.i = HaruGetFont(pdf, fcp936Name$, "GBK-EUC-H")
Define fcp932.i = HaruGetFont(pdf, fcp932Name$, "90ms-RKSJ-H")
If fcp936 = 0 Or fcp932 = 0
  PrintN("FAIL font (GetFont) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

PrintGrid(pdf, page)

HPDF_Page_SetTextLeading(page, 20)

HPDF_Page_BeginText(page)
HPDF_Page_MoveTextPos(page, 50, 250)
HPDF_Page_SetTextLeading(page, 25)

Define *line
While Not Eof(cp936Fd)
  HPDF_Page_SetFontAndSize(page, fcp936, 18)
  *line = ReadLineBytes(cp936Fd)
  HPDF_Page_ShowTextRaw(page, *line)
  FreeMemory(*line)

  If Not Eof(cp932Fd)
    HPDF_Page_SetFontAndSize(page, fcp932, 18)
    *line = ReadLineBytes(cp932Fd)
    HPDF_Page_ShowTextRaw(page, *line)
    FreeMemory(*line)
  EndIf

  HPDF_Page_MoveToNextLine(page)
Wend

; --- gate + save ---------------------------------------------------------------
If HPDF_GetError(pdf) <> #HPDF_OK
  PrintN("FAIL draw (latched error) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

If HPDF_SaveToFile(pdf, "chfont_demo.pdf") <> #HPDF_OK
  PrintN("FAIL save " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
HaruFree(pdf)
PrintN("PASS chfont_demo -> chfont_demo.pdf")

CloseFile(cp936Fd)
CloseFile(cp932Fd)

HaruShutdown()
CloseConsole()
End 0

; IDE Options = PureBasic 6.40 (Windows - x64)
; ExecutableFormat = Console
; EnableXP
; DPIAware
