; ---------------------------------------------------------------------------
; probe_noembed.pb : base-14 (non-embedded) fonts - WinAnsi-byte pipeline.
;
; PROBE-VERIFIED (hpdf 2.4.6, 07/10/2026):
;  - single-byte fonts do NO text conversion: HPDF_Page_TextOut writes the
;    input bytes 1:1 (\ooo-escaped) into the stream; /Encoding only tells
;    the VIEWER how to read the bytes. So: the caller supplies the WinAnsi
;    bytes itself (HaruWinAnsiMem + HaruTextOutRaw from hpdf.pbi).
;  - SetCurrentEncoder("WinAnsiEncoding") on a doc WITHOUT UseUTFEncodings
;    crashes (AV) - so don't do that either; the raw paths ignore the
;    encoder anyway.
;  - HPDF_Page_TextOut without BeginText = HPDF_PAGE_INVALID_GMODE 0x1051
;    (it latches; HaruTextOut/HaruTextOutRaw bracket BT/ET themselves).
; Text contains £ (A3) — (97) é (E9) € (80): all CP1252 specials.
; Build: MSYS2_ARG_CONV_EXCL='*' "$PUREBASIC_HOME/Compilers/pbcompilerc.exe"
;        /CONSOLE /THREAD /EXE probe_noembed.exe probe_noembed.pb
; Verifier: node litstr-decode or tests/dump_pdf_text.js (literal-Tj branch).
; ---------------------------------------------------------------------------
XIncludeFile "../hpdf.pbi"

OpenConsole()

; Local fallback dir is OS-specific (Windows DLL set vs Linux .so mirror);
; plain HaruInit() first = exe-dir (Win) / ld.so (Linux) search.
CompilerIf #PB_Compiler_OS = #PB_OS_Linux
  Define fallbackDir$ = "../libraries/linux/x64/"
CompilerElse
  Define fallbackDir$ = "../libraries/windows/x64/"
CompilerEndIf
If HaruInit() = 0
  If HaruInit(fallbackDir$) = 0
    PrintN("FAIL init: " + HaruMissing$)
    End 1
  EndIf
EndIf
PrintN("libharu " + PeekS(HPDF_GetVersion(), -1, #PB_Ascii))

; Build the WinAnsi bytes PB-side (the compiler's reading of source literals
; is platform-dependent - so don't hardcode the literal test string but
; inject the specials via the converter; in the engine the text comes from
; JSON anyway = correct UTF-16)
Define text$ = "Invoice " + Chr($A3) + " 4797,65 " + Chr($2014) + " caf" + Chr($E9) + " " + Chr($20AC) + " 12,50"
Define *bytes = HaruWinAnsiMem(text$)
If *bytes = 0
  PrintN("FAIL WinAnsiMem")
  End 1
EndIf

Define pdf.i = HPDF_New(0, 0)               ; no UseUTFEncodings needed
If pdf = 0 : PrintN("FAIL HPDF_New") : End 1 : EndIf
Define font.i = HPDF_GetFont(pdf, "Helvetica", "WinAnsiEncoding")
If font = 0 : PrintN("FAIL GetFont: " + HaruErrorText(pdf)) : End 1 : EndIf
Define page.i = HPDF_AddPage(pdf)
HPDF_Page_SetFontAndSize(page, font, 12)
PrintN("TextWidth : " + StrF(HPDF_Page_TextWidthRaw(page, *bytes), 2))
PrintN("TextOut   : " + Str(HaruTextOutRaw(page, 50, 700, *bytes)))
If HPDF_SaveToFile(pdf, "probe_noembed.pdf") <> #HPDF_OK
  PrintN("save FAIL : " + HaruErrorText(pdf))
EndIf
HPDF_Free(pdf)
FreeMemory(*bytes)
HaruShutdown()

; expected: 1 page, /Helvetica + /WinAnsiEncoding, NO FontFile2,
; stream contains (Invoice \243 4797,65 \227 caf\251 \200 12,50) Tj
PrintN("done -> probe_noembed.pdf")
CloseConsole()

; IDE Options = PureBasic 6.40 (Windows - x64)
; ExecutableFormat = Console
; CursorPosition = 22
; FirstLine = 5
; EnableXP
; DPIAware