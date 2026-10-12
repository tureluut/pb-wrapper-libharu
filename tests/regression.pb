; ----------------------------------------------------------------------------
; tests/regression.pb - focused regression tests for code-review findings
; R1 (HaruAlpha), R2 (lifecycle/cache invalidation), R3 (EndText status),
; R4/R5 (init ownership, pointer clearing), R6 (layout), R9 (dir$ without
; trailing separator). Windows console program; run with tests/ as working
; directory. Exit code = number of failed checks.
;
; The flat include exposes the internal cache maps, so the tests can assert
; cache eviction directly (pointer inequality alone would be insufficient:
; allocators reuse addresses).
; ----------------------------------------------------------------------------
EnableExplicit
XIncludeFile "../hpdf.pbi"

Global Failed.i

Procedure Check(name$, ok.i)
  If ok
    PrintN("PASS " + name$)
  Else
    Failed + 1
    PrintN("FAIL " + name$)
  EndIf
EndProcedure

; IEEE-754 quiet NaN as float - built by bit pattern because PB float
; literals cannot express it and PB float compares are non-IEEE for NaN.
Procedure.f MakeNaN()
  Protected bits.l = $7FC00000
  Protected f.f
  CopyMemory(@bits, @f, 4)
  ProcedureReturn f
EndProcedure

; R3 fault injection: matching stub for HPDF_Page_EndText.
Procedure.l Stub_EndText(page.i)
  ProcedureReturn $DEAD
EndProcedure

Procedure.i CountGsCacheFor(doc.i)
  Protected prefix$ = Str(doc) + "|"
  Protected n.i
  ForEach HaruGsCache()
    If Left(MapKey(HaruGsCache()), Len(prefix$)) = prefix$
      n + 1
    EndIf
  Next
  ProcedureReturn n
EndProcedure

Procedure.i CountFontCacheFor(doc.i)
  Protected prefix$ = Str(doc) + "|"
  Protected n.i
  ForEach HaruFontCache()
    If Left(MapKey(HaruFontCache()), Len(prefix$)) = prefix$
      n + 1
    EndIf
  Next
  ProcedureReturn n
EndProcedure

Procedure.i Main()
  Protected libBefore.i, pdf.i, docB.i, page.i, font.i, gs.i, gs2.i, gsB.i
  Protected gsn.i, ret.i, r.i, oldGs.i, *bytes
  Protected nan.f = MakeNaN()
  Protected libDir$ = "../libraries/windows/x64"          ; R9: NO trailing slash
  Protected ttf$ = "../samples/ttfont/PenguinAttack.ttf"

  ; --- R9/R4: explicit dir without trailing separator -----------------------
  ret = HaruInit(libDir$)
  Check("init(no trailing slash) returns 1", Bool(ret = 1))
  Check("HaruReady = 1 after init", Bool(HaruReady = #True))
  Check("all 169 exports bound", Bool(HaruBound = 169 And HaruMissing$ = ""))

  ; --- R4: re-init while ready is rejected, library untouched ---------------
  libBefore = HaruLib
  ret = HaruInit(libDir$)
  Check("re-init while ready returns -1", Bool(ret = -1))
  Check("re-init left library untouched", Bool(HaruLib = libBefore And HaruReady = #True))

  ; --- R6: runtime layout printout (compile-time asserts guard hpdf.pbi) ----
  PrintN("info HPDFPoint=" + Str(SizeOf(HPDFPoint)) + " HPDFRect=" + Str(SizeOf(HPDFRect)) +
         " HPDFDate=" + Str(SizeOf(HPDFDate)) + " ind@" + Str(OffsetOf(HPDFDate\ind)) +
         " off_hour@" + Str(OffsetOf(HPDFDate\off_hour)))
  Check("R6 runtime layout", Bool(SizeOf(HPDFPoint) = 8 And SizeOf(HPDFRect) = 16 And
        SizeOf(HPDFDate) = 36 And OffsetOf(HPDFDate\ind) = 24 And OffsetOf(HPDFDate\off_hour) = 28))

  ; --- R1: HaruAlpha validation ---------------------------------------------
  pdf = HaruNew()
  Check("HaruNew", Bool(pdf <> 0))
  page = HaruAddPage(pdf)
  Check("HaruAddPage", Bool(page <> 0))
  Check("alpha -0.5 rejected", Bool(HaruAlpha(pdf, -0.5) = 0))
  Check("alpha 1.5 rejected", Bool(HaruAlpha(pdf, 1.5) = 0))
  Check("alpha NaN rejected (bit pattern)", Bool(HaruAlpha(pdf, nan) = 0))
  Check("rejected alphas left no cache entries", Bool(CountGsCacheFor(pdf) = 0))
  gs = HaruAlpha(pdf, 0.0)
  Check("alpha 0.0 endpoint ok", Bool(gs <> 0))
  gs2 = HaruAlpha(pdf, 1.0)
  Check("alpha 1.0 endpoint ok", Bool(gs2 <> 0))
  Check("endpoints cached", Bool(CountGsCacheFor(pdf) = 2))
  oldGs = HaruAlpha(pdf, 0.5)
  Check("alpha 0.5 ok", Bool(oldGs <> 0))
  Check("repeated alpha returns same handle", Bool(HaruAlpha(pdf, 0.5) = oldGs))
  Check("0.5 cached exactly once", Bool(CountGsCacheFor(pdf) = 3))
  Check("cached handle usable", Bool(HPDF_Page_SetExtGState(page, oldGs) = #HPDF_OK))

  ; native range check still latches HPDF_EXT_GSTATE_OUT_OF_RANGE ($1080 = 4224)
  gsn = HPDF_CreateExtGState(pdf)
  ret = HPDF_ExtGState_SetAlphaFill(gsn, 1.5)
  Check("raw setter latches $1080", Bool(ret = $1080 And HPDF_GetError(pdf) = $1080))
  HPDF_ResetError(pdf)
  Check("ResetError clears $1080", Bool(HPDF_GetError(pdf) = #HPDF_OK))

  ; --- R3: EndText failure must not be masked -------------------------------
  font = HaruTTFFont(pdf, ttf$)
  Check("HaruTTFFont", Bool(font <> 0))
  HPDF_Page_SetFontAndSize(page, font, 12)
  Protected savedEndText.Proto_HPDF_Page_EndText = HPDF_Page_EndText
  HPDF_Page_EndText = @Stub_EndText()
  r = HaruTextOut(page, 50, 750, "fault injection")
  Check("HaruTextOut propagates EndText failure ($DEAD)", Bool(r = $DEAD))
  ; the stub never ran the native ET, so the page still has an open text
  ; object (gmode stuck in TEXT_OBJECT) - restore and really close it before
  ; the next injection
  HPDF_Page_EndText = savedEndText
  HPDF_Page_EndText(page)
  HPDF_ResetError(pdf)
  *bytes = HaruAsciiMem("raw fault injection")
  HPDF_Page_EndText = @Stub_EndText()
  r = HaruTextOutRaw(page, 50, 710, *bytes)
  Check("HaruTextOutRaw propagates EndText failure ($DEAD)", Bool(r = $DEAD))
  If *bytes : FreeMemory(*bytes) : EndIf
  HPDF_Page_EndText = savedEndText
  HPDF_Page_EndText(page)
  HPDF_ResetError(pdf)
  Check("HaruTextOut ok again after restore", Bool(HaruTextOut(page, 50, 670, "restored") = #HPDF_OK))

  ; --- R2: lifecycle helpers invalidate caches ------------------------------
  Check("pre-reset caches: 3 gs + 1 font", Bool(CountGsCacheFor(pdf) = 3 And CountFontCacheFor(pdf) = 1))
  ret = HaruResetDoc(pdf)
  Check("HaruResetDoc returns OK", Bool(ret = #HPDF_OK))
  Check("HaruResetDoc purged gs cache", Bool(CountGsCacheFor(pdf) = 0))
  Check("HaruResetDoc purged font cache", Bool(CountFontCacheFor(pdf) = 0))
  page = HaruAddPage(pdf)
  Check("new page after reset", Bool(page <> 0))
  gs = HaruAlpha(pdf, 0.5)               ; cache was empty -> must build fresh
  Check("HaruAlpha after reset builds fresh handle (cache was empty)", Bool(gs <> 0 And CountGsCacheFor(pdf) = 1))
  PrintN("info old gs=$" + Hex(oldGs) + " new gs=$" + Hex(gs))
  Check("fresh gs usable", Bool(HPDF_Page_SetExtGState(page, gs) = #HPDF_OK))
  font = HaruTTFFont(pdf, ttf$)
  Check("font after reset", Bool(font <> 0))
  HPDF_Page_SetFontAndSize(page, font, 12)
  Check("UTF-8 text works after reset", Bool(HaruTextOut(page, 50, 750, "reset caf" + Chr($E9)) = #HPDF_OK))

  ret = HaruClearDoc(pdf)
  Check("HaruClearDoc returns OK", Bool(ret = #HPDF_OK))
  Check("HaruClearDoc purged caches", Bool(CountGsCacheFor(pdf) = 0 And CountFontCacheFor(pdf) = 0))
  page = HaruAddPage(pdf)
  font = HaruTTFFont(pdf, ttf$)
  HPDF_Page_SetFontAndSize(page, font, 12)
  Check("full UTF-8 pipeline restored after ClearDoc",
        Bool(font <> 0 And HaruTextOut(page, 50, 750, "clear caf" + Chr($E9)) = #HPDF_OK))
  Check("HaruGetFont works after ClearDoc", Bool(HaruGetFont(pdf, "Helvetica", "WinAnsiEncoding") <> 0))

  HaruFreeDoc(pdf)
  ret = HaruResetDoc(pdf)                ; revive the doc allocation
  page = HaruAddPage(pdf)
  gs = HaruAlpha(pdf, 0.5)
  Check("HaruFreeDoc + HaruResetDoc revive", Bool(ret = #HPDF_OK And page <> 0 And gs <> 0))

  ; --- R2: per-doc purge scoping (interleaved documents) ---------------------
  docB = HaruNew()
  page = HaruAddPage(docB)
  gsB = HaruAlpha(docB, 0.25)
  font = HaruTTFFont(docB, ttf$)
  Check("docB populated", Bool(docB <> 0 And gsB <> 0 And font <> 0))
  HaruFree(pdf)
  Check("HaruFree(docA) kept docB gs cached", Bool(CountGsCacheFor(docB) = 1))
  Check("HaruFree(docA) kept docB font cached", Bool(CountFontCacheFor(docB) = 1))
  Check("docB alpha still a cache hit", Bool(HaruAlpha(docB, 0.25) = gsB))
  HaruFree(docB)
  Check("all caches empty after freeing both docs", Bool(MapSize(HaruGsCache()) = 0 And MapSize(HaruFontCache()) = 0))

  ; --- R5/R4: shutdown, failed init, retry -----------------------------------
  HaruShutdown()
  Check("shutdown cleared HPDF_Free", Bool(HPDF_Free = 0))
  Check("shutdown cleared HaruReady", Bool(HaruReady = #False))
  ret = HaruInit("./nonexistent-hpdf-regression-dir/")
  Check("failed init returns 0", Bool(ret = 0))
  Check("failed init left HPDF_Free = 0", Bool(HPDF_Free = 0))
  Check("failed init: HaruMissing$ empty (OpenLibrary stage)", Bool(HaruMissing$ = ""))
  Check("failed init: HaruReady still 0", Bool(HaruReady = #False))
  ret = HaruInit(libDir$)
  Check("retry after failed init succeeds", Bool(ret = 1 And HaruReady = #True And HaruBound = 169))

  ; --- R7 (spot check): statuses round-trip through the adapter --------------
  pdf = HaruNew()
  Check("R7 spot check: fresh doc status adapter", Bool(pdf <> 0 And HPDF_GetError(pdf) = #HPDF_OK))
  HaruFree(pdf)

  HaruShutdown()
  Check("final shutdown", Bool(HaruReady = #False And HPDF_Free = 0))

  PrintN("---")
  PrintN(Str(Failed) + " check(s) failed")
  ProcedureReturn Failed
EndProcedure

If OpenConsole() = 0 : End 1 : EndIf
Define exitCode.i = Main()
CloseConsole()
End exitCode

; IDE Options = PureBasic 6.40 (Windows - x64)
; ExecutableFormat = Console
