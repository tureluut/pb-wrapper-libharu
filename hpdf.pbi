; ----------------------------------------------------------------------------
; hpdf.pbi - PureBasic wrapper for libharu hpdf.dll 2.4.6 (Windows x64)
; ----------------------------------------------------------------------------
; Author  : Duk (www.tureluut.be)
; License : free to use. The shipped DLLs carry their own licenses - see
;           THIRD-PARTY-NOTICES.md (libharu, zlib, libpng).
; Requires: PureBasic 6.40 or higher. Current setup: Windows 64-bit; the
;           DLLs live in libraries/windows/x64 (x86 set also provided).
;
; Provenance:
;   - Signatures: hpdf.h of libharu 2.4.6 is the authority - it is the exact
;     contract of hpdf.dll on disk.
;   - Runtime: the exe needs hpdf.dll + zlib.dll + libpng16.dll (zlib/libpng
;     are hpdf.dll dependencies). OpenLibrary searches the exe directory
;     first, or pass the DLL directory to HaruInit(dir$). Without them
;     HaruInit() fails cleanly (no crash).
;   - Linux port : OpenLibrary/GetFunction/Prototypes
;     are cross-platform, so the prototype binding is untouched. Only the
;     load logic inside HaruInit() branches per OS (details there): dlopen
;     has NO exe-directory search (resolved via ProgramFilename()), cwd
;     needs the './' prefix, and 'libhpdf.so.2' candidates cover distro
;     runtime packages that ship only the versioned soname. zlib/libpng are
;     ld.so-resolved (system packages) or statically baked into libhpdf.so,
;     so the Windows dependency-preload is Windows-only. Strings need NO
;     changes: PB is UCS-2 internally on every OS, so p-ascii/p-utf8 param
;     conversion behaves identically, and #PB_Ascii PeekS on the (7-bit
;     ASCII) version / font-name returns is exact on Linux too.
;
; USAGE CONTRACT: call HaruInit() once, before any HPDF_* / Haru* call.
; Every HPDF_* name below is a global function POINTER (prototype-typed);
; calling it before HaruInit() dereferences null. HaruShutdown() at exit.
;
; Type-mapping rules (every prototype, kept 1:1 with hpdf.h):
;   HPDF_REAL (C float)                       -> .f        never .d
;   HPDF_BOOL/STATUS/UINT/INT/UINT32/enums    -> .l        4-byte C int; the
;     explicit .l return reads eax only (x64 rax sign-extension hygiene)
;   HPDF_UINT16                               -> .w
;   HPDF_*HANDLE (Doc/Page/Font/Image/...)    -> .i        opaque pointers
;   const char* in                            -> .p-ascii  PB converts string
;     args per call; pointer valid for call duration only (libharu consumes
;     synchronously - never store it)
;   const char* page-text fns                 -> .p-utf8  wrapper is UTF-8-first
;     (HaruNew enables UTF-8 encodings); applies to TextOut, ShowText,
;     ShowTextNextLine, TextWidth, MeasureText, TextRect
;   char* return                              -> .i then PeekS(*p, -1, #PB_Ascii)
;     (pseudotypes in prototypes are params-only, so char* returns must go
;     through .i + PeekS)
;   struct-by-value returns                   -> BANNED in v1; use the ...2
;     variants (HPDF_Image_GetSize2, HPDF_Page_GetCurrentPos2, ...)
; ----------------------------------------------------------------------------

; -----------------
; Constants subset 
; -----------------

#HPDF_TRUE  = 1
#HPDF_FALSE = 0
#HPDF_OK    = 0

; Compression mode flags (HPDF_SetCompressionMode)
#HPDF_COMP_NONE     = $00
#HPDF_COMP_TEXT     = $01
#HPDF_COMP_IMAGE    = $02
#HPDF_COMP_METADATA = $04
#HPDF_COMP_ALL      = $0F

; Page sizes (HPDF_Page_SetSize)
#HPDF_PAGE_SIZE_LETTER    = 0
#HPDF_PAGE_SIZE_LEGAL     = 1
#HPDF_PAGE_SIZE_A3        = 2
#HPDF_PAGE_SIZE_A4        = 3
#HPDF_PAGE_SIZE_A5        = 4
#HPDF_PAGE_SIZE_B4        = 5
#HPDF_PAGE_SIZE_B5        = 6
#HPDF_PAGE_SIZE_EXECUTIVE = 7
#HPDF_PAGE_SIZE_US4x6     = 8
#HPDF_PAGE_SIZE_US4x8     = 9
#HPDF_PAGE_SIZE_US5x7     = 10
#HPDF_PAGE_SIZE_COMM10    = 11

; Page direction (HPDF_Page_SetSize)
#HPDF_PAGE_PORTRAIT  = 0
#HPDF_PAGE_LANDSCAPE = 1

; Text alignment (HPDF_Page_TextRect)
#HPDF_TALIGN_LEFT    = 0
#HPDF_TALIGN_RIGHT   = 1
#HPDF_TALIGN_CENTER  = 2
#HPDF_TALIGN_JUSTIFY = 3

; Line cap (HPDF_Page_SetLineCap)
#HPDF_BUTT_END            = 0
#HPDF_ROUND_END           = 1
#HPDF_PROJECTING_SQUARE_END = 2

; Line join (HPDF_Page_SetLineJoin)
#HPDF_MITER_JOIN = 0
#HPDF_ROUND_JOIN = 1
#HPDF_BEVEL_JOIN = 2

; Info dictionary attributes (HPDF_SetInfoAttr / HPDF_GetInfoAttr)
#HPDF_INFO_CREATION_DATE = 0
#HPDF_INFO_MOD_DATE      = 1
#HPDF_INFO_AUTHOR        = 2
#HPDF_INFO_CREATOR       = 3
#HPDF_INFO_PRODUCER      = 4
#HPDF_INFO_TITLE         = 5
#HPDF_INFO_SUBJECT       = 6
#HPDF_INFO_KEYWORDS      = 7

; Text rendering mode (HPDF_Page_SetTextRenderingMode)
#HPDF_FILL                 = 0
#HPDF_STROKE               = 1
#HPDF_FILL_THEN_STROKE     = 2
#HPDF_INVISIBLE            = 3
#HPDF_FILL_CLIPPING        = 4
#HPDF_STROKE_CLIPPING      = 5
#HPDF_FILL_STROKE_CLIPPING = 6
#HPDF_CLIPPING             = 7

; Blend mode (HPDF_ExtGState_SetBlendMode) - note libharu's "EXCLUSHON" typo
#HPDF_BM_NORMAL      = 0
#HPDF_BM_MULTIPLY    = 1
#HPDF_BM_SCREEN      = 2
#HPDF_BM_OVERLAY     = 3
#HPDF_BM_DARKEN      = 4
#HPDF_BM_LIGHTEN     = 5
#HPDF_BM_COLOR_DODGE = 6
#HPDF_BM_COLOR_BUM   = 7
#HPDF_BM_HARD_LIGHT  = 8
#HPDF_BM_SOFT_LIGHT  = 9
#HPDF_BM_DIFFERENCE  = 10
#HPDF_BM_EXCLUSHON   = 11

; Error codes (from libharu hpdf_error.h 2.4.x) used by the helpers
#HPDF_INVALID_TTC_FILE = $103F

; Page mode (HPDF_SetPageMode)
#HPDF_PAGE_MODE_USE_NONE    = 0
#HPDF_PAGE_MODE_USE_OUTLINE = 1
#HPDF_PAGE_MODE_USE_THUMBS  = 2
#HPDF_PAGE_MODE_FULL_SCREEN = 3

; Page slide-show transition styles (HPDF_Page_SetSlideShow)
#HPDF_TS_WIPE_RIGHT                       = 0
#HPDF_TS_WIPE_UP                          = 1
#HPDF_TS_WIPE_LEFT                        = 2
#HPDF_TS_WIPE_DOWN                        = 3
#HPDF_TS_BARN_DOORS_HORIZONTAL_OUT        = 4
#HPDF_TS_BARN_DOORS_HORIZONTAL_IN         = 5
#HPDF_TS_BARN_DOORS_VERTICAL_OUT          = 6
#HPDF_TS_BARN_DOORS_VERTICAL_IN           = 7
#HPDF_TS_BOX_OUT                          = 8
#HPDF_TS_BOX_IN                           = 9
#HPDF_TS_BLINDS_HORIZONTAL                = 10
#HPDF_TS_BLINDS_VERTICAL                  = 11
#HPDF_TS_DISSOLVE                         = 12
#HPDF_TS_GLITTER_RIGHT                    = 13
#HPDF_TS_GLITTER_DOWN                     = 14
#HPDF_TS_GLITTER_TOP_LEFT_TO_BOTTOM_RIGHT = 15
#HPDF_TS_REPLACE                          = 16

; Link annotation highlight mode (HPDF_LinkAnnot_SetHighlightMode) -
; "HIGHTLIGHT" is libharu's own spelling
#HPDF_ANNOT_NO_HIGHTLIGHT   = 0
#HPDF_ANNOT_INVERT_BOX      = 1
#HPDF_ANNOT_INVERT_BORDER   = 2
#HPDF_ANNOT_DOWN_APPEARANCE = 3

; Text annotation icons (HPDF_TextAnnot_SetIcon)
#HPDF_ANNOT_ICON_COMMENT       = 0
#HPDF_ANNOT_ICON_KEY           = 1
#HPDF_ANNOT_ICON_NOTE          = 2
#HPDF_ANNOT_ICON_HELP          = 3
#HPDF_ANNOT_ICON_NEW_PARAGRAPH = 4
#HPDF_ANNOT_ICON_PARAGRAPH     = 5
#HPDF_ANNOT_ICON_INSERT        = 6

; Encoder type (HPDF_Encoder_GetType)
#HPDF_ENCODER_TYPE_SINGLE_BYTE   = 0
#HPDF_ENCODER_TYPE_DOUBLE_BYTE   = 1
#HPDF_ENCODER_TYPE_UNINITIALIZED = 2
#HPDF_ENCODER_UNKNOWN            = 3

; Byte type (HPDF_Encoder_GetByteType)
#HPDF_BYTE_TYPE_SINGLE  = 0
#HPDF_BYTE_TYPE_LEAD    = 1
#HPDF_BYTE_TYPE_TRAIL   = 2
#HPDF_BYTE_TYPE_UNKNOWN = 3

; Color space (HPDF_LoadRawImageFromFile / HPDF_LoadRawImageFromMem)
#HPDF_CS_DEVICE_GRAY = 0
#HPDF_CS_DEVICE_RGB  = 1
#HPDF_CS_DEVICE_CMYK = 2
#HPDF_CS_CAL_GRAY    = 3
#HPDF_CS_CAL_RGB     = 4
#HPDF_CS_LAB         = 5
#HPDF_CS_ICC_BASED   = 6
#HPDF_CS_SEPARATION  = 7
#HPDF_CS_DEVICE_N    = 8
#HPDF_CS_INDEXED     = 9
#HPDF_CS_PATTERN     = 10

; PDF-A conformance type (HPDF_SetPDFAConformance)
#HPDF_PDFA_NON_PDFA = -1
#HPDF_PDFA_1A       = 0
#HPDF_PDFA_1B       = 1
#HPDF_PDFA_2A       = 2
#HPDF_PDFA_2B       = 3
#HPDF_PDFA_2U       = 4
#HPDF_PDFA_3A       = 5
#HPDF_PDFA_3B       = 6
#HPDF_PDFA_3U       = 7
#HPDF_PDFA_4        = 8
#HPDF_PDFA_4E       = 9
#HPDF_PDFA_4F       = 10

; Associated-file relationship (HPDF_EmbeddedFile_SetAFRelationship)
#HPDF_AFRELATIONSHIP_SOURCE           = 0
#HPDF_AFRELATIONSHIP_DATA             = 1
#HPDF_AFRELATIONSHIP_ALTERNATIVE      = 2
#HPDF_AFRELATIONSHIP_SUPPLEMENT       = 3
#HPDF_AFRELATIONSHIP_ENCRYPTEDPAYLOAD = 4
#HPDF_AFRELATIONSHIP_FORMDATA         = 5
#HPDF_AFRELATIONSHIP_SCHEMA           = 6
#HPDF_AFRELATIONSHIP_UNSPECIFIED      = 7

; Encryption revision (HPDF_SetEncryptionMode)
#HPDF_ENCRYPT_R2 = 2
#HPDF_ENCRYPT_R3 = 3

; Permission flags (HPDF_SetPermission) - READ is the 0 baseline
#HPDF_ENABLE_READ     = 0
#HPDF_ENABLE_PRINT    = 4
#HPDF_ENABLE_EDIT_ALL = 8
#HPDF_ENABLE_COPY     = 16
#HPDF_ENABLE_EDIT     = 32

; ----------------------------------------------------------------------------
; Structures
; ----------------------------------------------------------------------------

Structure HPDFPoint
  x.f
  y.f
EndStructure

; hpdf_types.h _HPDF_Rect field order (left, bottom, right, top). AlignC:
; Win64 passes 16-byte C struct BY-VALUE args as a pointer to a caller copy,
; so annotation calls take @rect (HPDFRect) - layout has no padding either
; way, AlignC only pins it against future edits.
Structure HPDFRect Align #PB_Structure_AlignC
  left.f
  bottom.f
  right.f
  top.f
EndStructure

; hpdf_types.h _HPDF_Date. C layout: 6x HPDF_INT, 1x char (ind), 2x HPDF_INT
; -> the char lands at offset 24 and C realigns the following ints to 4.
; PB structures are PACKED by default (alignment 1) - without AlignC this
; would be 33 bytes with off_hour@25 instead of 36 bytes with off_hour@28
; (verified with OffsetOf against the C header).
Structure HPDFDate Align #PB_Structure_AlignC
  year.l
  month.l
  day.l
  hour.l
  minutes.l
  seconds.l
  ind.a          ; '+' / '-' (offset 24)
  off_hour.l
  off_minutes.l
EndStructure

; ----------------------------------------------------------------------------
; Prototypes - signatures verbatim from hpdf.h 2.4.6 (x64: stdcall == C
; convention, so plain Prototype is correct). Pseudotypes are legal on
; parameters only; char* returns are .i + PeekS. 169 prototypes = 169
; globals = 169 HaruBind calls (grep -c '^Prototype' hpdf.pbi).
;
; Raw *pointer variants of text-taking functions (suffix Raw / N) exist
; where the BYTES matter, not the PB string: CJK/MBCS encoders consume raw
; double-byte codes (ShowText, CreateOutline titles, TextAnnot contents),
; and NULL must be passed for "default" (GetFont encoding, encoder params).
; p-utf8 / p-ascii params would mangle or refuse those.
; ----------------------------------------------------------------------------

Prototype   Proto_HPDF_Free(pdf.i)                                            ; void
Prototype.i Proto_HPDF_New(user_error_fn.i, user_data.i)                     ; HPDF_Doc
Prototype.i Proto_HPDF_NewEx(user_error_fn.i, user_alloc_fn.i, user_free_fn.i, mem_pool_buf_size.l, user_data.i) ; HPDF_Doc
Prototype.l Proto_HPDF_SetErrorHandler(pdf.i, user_error_fn.i)               ; HPDF_STATUS

Prototype   Proto_HPDF_FreeDoc(pdf.i)                                        ; void
Prototype   Proto_HPDF_FreeDocAll(pdf.i)                                     ; void
Prototype.l Proto_HPDF_HasDoc(pdf.i)                                         ; HPDF_BOOL
Prototype.l Proto_HPDF_NewDoc(pdf.i)                                         ; HPDF_STATUS
Prototype.l Proto_HPDF_SaveToStream(pdf.i)                                   ; HPDF_STATUS
Prototype.l Proto_HPDF_GetStreamSize(pdf.i)                                  ; HPDF_UINT32
Prototype.l Proto_HPDF_ReadFromStream(pdf.i, *buf, *size)                    ; HPDF_STATUS; *size = HPDF_UINT32* in/out
Prototype.l Proto_HPDF_ResetStream(pdf.i)                                    ; HPDF_STATUS
Prototype.l Proto_HPDF_SaveToFile(pdf.i, file_name.p-ascii)                  ; HPDF_STATUS

Prototype.l Proto_HPDF_GetError(pdf.i)                                       ; HPDF_STATUS
Prototype.l Proto_HPDF_GetErrorDetail(pdf.i)                                 ; HPDF_STATUS
Prototype   Proto_HPDF_ResetError(pdf.i)                                     ; void
Prototype.l Proto_HPDF_CheckError(error.i)                                   ; HPDF_STATUS; arg = HPDF_Error
Prototype.i Proto_HPDF_GetVersion()                                          ; const char* -> .i; PeekS(*p, -1, #PB_Ascii)

Prototype.i Proto_HPDF_AddPage(pdf.i)                                        ; HPDF_Page
Prototype.i Proto_HPDF_InsertPage(pdf.i, page.i)                             ; HPDF_Page
Prototype.i Proto_HPDF_GetCurrentPage(pdf.i)                                 ; HPDF_Page
Prototype.i Proto_HPDF_GetPageByIndex(pdf.i, index.l)                        ; HPDF_Page
Prototype.l Proto_HPDF_SetPagesConfiguration(pdf.i, page_per_pages.l)        ; HPDF_STATUS
Prototype.l Proto_HPDF_Page_SetWidth(page.i, value.f)                        ; HPDF_STATUS
Prototype.l Proto_HPDF_Page_SetHeight(page.i, value.f)                       ; HPDF_STATUS
Prototype.l Proto_HPDF_Page_SetSize(page.i, size.l, direction.l)             ; HPDF_STATUS
Prototype.l Proto_HPDF_Page_SetRotate(page.i, angle.w)                       ; HPDF_STATUS

Prototype.l Proto_HPDF_SetCompressionMode(pdf.i, mode.l)                     ; HPDF_STATUS
Prototype.l Proto_HPDF_SetInfoAttr(pdf.i, infoType.l, value.p-ascii)         ; HPDF_STATUS; C param "type" renamed (PB keyword)

Prototype.l Proto_HPDF_Page_BeginText(page.i)                                ; HPDF_STATUS; BT
Prototype.l Proto_HPDF_Page_EndText(page.i)                                  ; HPDF_STATUS; ET
Prototype.l Proto_HPDF_Page_SetFontAndSize(page.i, font.i, size.f)           ; HPDF_STATUS; Tf
Prototype.l Proto_HPDF_Page_TextOut(page.i, xpos.f, ypos.f, text.p-utf8)     ; HPDF_STATUS; Td + Tj; display text = UTF-8
Prototype.l Proto_HPDF_Page_TextOutRaw(page.i, xpos.f, ypos.f, *bytes)       ; = HPDF_Page_TextOut, char* als RAW pointer: base-14 fonts doen
                                                                             ; GEEN conversie (byte-pass-through, probe-proven) - voor
                                                                             ; vooraf gecodeerde WinAnsi-bytes (HaruWinAnsiMem)
Prototype.f Proto_HPDF_Page_TextWidthRaw(page.i, *bytes)                     ; = HPDF_Page_TextWidth, idem raw (breedte per byte + AFM-metrie)
Prototype.l Proto_HPDF_Page_ShowText(page.i, text.p-utf8)                    ; HPDF_STATUS; Tj; display text = UTF-8
Prototype.l Proto_HPDF_Page_ShowTextNextLine(page.i, text.p-utf8)            ; HPDF_STATUS; TD + Tj; display text = UTF-8
Prototype.l Proto_HPDF_Page_MoveTextPos(page.i, x.f, y.f)                    ; HPDF_STATUS; TD
Prototype.l Proto_HPDF_Page_MoveTextPos2(page.i, x.f, y.f)                   ; HPDF_STATUS; TD (no leading update)
Prototype.f Proto_HPDF_Page_TextWidth(page.i, text.p-utf8)                   ; HPDF_REAL (2.4.6: returns REAL, not UINT); UTF-8
Prototype.l Proto_HPDF_Page_MeasureText(page.i, text.p-utf8, width.f, wordwrap.l, *real_width) ; HPDF_UINT; *real_width = HPDF_REAL* out, may be 0/NULL
Prototype.l Proto_HPDF_Page_TextRect(page.i, left.f, top.f, right.f, bottom.f, text.p-utf8, align.l, *len) ; HPDF_STATUS; arg order left,top,right,bottom (2.4.6); UTF-8; *len = HPDF_UINT* out
Prototype.l Proto_HPDF_Page_SetCharSpace(page.i, value.f)                    ; HPDF_STATUS; Tc
Prototype.l Proto_HPDF_Page_SetWordSpace(page.i, value.f)                    ; HPDF_STATUS; Tw
Prototype.l Proto_HPDF_Page_SetTextLeading(page.i, value.f)                  ; HPDF_STATUS; TL
Prototype.l Proto_HPDF_Page_SetHorizontalScalling(page.i, value.f)           ; HPDF_STATUS; Tz (sic - libharu spelling)
Prototype.l Proto_HPDF_Page_SetTextRenderingMode(page.i, mode.l)             ; HPDF_STATUS; Tr
Prototype.l Proto_HPDF_Page_SetTextMatrix(page.i, a.f, b.f, c.f, d.f, x.f, y.f) ; HPDF_STATUS; Tm (text object only)

Prototype.l Proto_HPDF_Page_SetLineWidth(page.i, line_width.f)               ; HPDF_STATUS; w
Prototype.l Proto_HPDF_Page_SetLineCap(page.i, line_cap.l)                   ; HPDF_STATUS; J
Prototype.l Proto_HPDF_Page_SetLineJoin(page.i, line_join.l)                 ; HPDF_STATUS; j
Prototype.l Proto_HPDF_Page_SetDash(page.i, *dash_ptn, num_param.l, phase.f) ; HPDF_STATUS; d - 2.4.6: dash_ptn = const HPDF_REAL* (stale .bi says UINT16)
Prototype.l Proto_HPDF_Page_SetFlat(page.i, flatness.f)                      ; HPDF_STATUS

Prototype.l Proto_HPDF_Page_MoveTo(page.i, x.f, y.f)                         ; HPDF_STATUS; m
Prototype.l Proto_HPDF_Page_LineTo(page.i, x.f, y.f)                         ; HPDF_STATUS; l
Prototype.l Proto_HPDF_Page_CurveTo(page.i, x1.f, y1.f, x2.f, y2.f, x3.f, y3.f)   ; HPDF_STATUS; c
Prototype.l Proto_HPDF_Page_CurveTo2(page.i, x2.f, y2.f, x3.f, y3.f)         ; HPDF_STATUS; v
Prototype.l Proto_HPDF_Page_CurveTo3(page.i, x1.f, y1.f, x3.f, y3.f)         ; HPDF_STATUS; y
Prototype.l Proto_HPDF_Page_ClosePath(page.i)                                ; HPDF_STATUS; h
Prototype.l Proto_HPDF_Page_Rectangle(page.i, x.f, y.f, width.f, height.f)   ; HPDF_STATUS; re
Prototype.l Proto_HPDF_Page_Circle(page.i, x.f, y.f, ray.f)                  ; HPDF_STATUS
Prototype.l Proto_HPDF_Page_Ellipse(page.i, x.f, y.f, xray.f, yray.f)        ; HPDF_STATUS
Prototype.l Proto_HPDF_Page_Arc(page.i, x.f, y.f, ray.f, ang1.f, ang2.f)     ; HPDF_STATUS

Prototype.l Proto_HPDF_Page_Stroke(page.i)                                   ; HPDF_STATUS; S
Prototype.l Proto_HPDF_Page_Fill(page.i)                                     ; HPDF_STATUS; f
Prototype.l Proto_HPDF_Page_Eofill(page.i)                                   ; HPDF_STATUS; f*
Prototype.l Proto_HPDF_Page_FillStroke(page.i)                               ; HPDF_STATUS; B
Prototype.l Proto_HPDF_Page_EofillStroke(page.i)                             ; HPDF_STATUS; B*
Prototype.l Proto_HPDF_Page_ClosePathStroke(page.i)                          ; HPDF_STATUS; s
Prototype.l Proto_HPDF_Page_ClosePathFillStroke(page.i)                      ; HPDF_STATUS; b
Prototype.l Proto_HPDF_Page_ClosePathEofillStroke(page.i)                    ; HPDF_STATUS; b*
Prototype.l Proto_HPDF_Page_EndPath(page.i)                                  ; HPDF_STATUS; n
Prototype.l Proto_HPDF_Page_Clip(page.i)                                     ; HPDF_STATUS; W n
Prototype.l Proto_HPDF_Page_Eoclip(page.i)                                   ; HPDF_STATUS; W* n

Prototype.l Proto_HPDF_Page_SetGrayFill(page.i, gray.f)                      ; HPDF_STATUS; g
Prototype.l Proto_HPDF_Page_SetGrayStroke(page.i, gray.f)                    ; HPDF_STATUS; G
Prototype.l Proto_HPDF_Page_SetRGBFill(page.i, r.f, g.f, b.f)                ; HPDF_STATUS; rg
Prototype.l Proto_HPDF_Page_SetRGBStroke(page.i, r.f, g.f, b.f)              ; HPDF_STATUS; RG
Prototype.l Proto_HPDF_Page_SetCMYKFill(page.i, c.f, m.f, y.f, k.f)          ; HPDF_STATUS; k
Prototype.l Proto_HPDF_Page_SetCMYKStroke(page.i, c.f, m.f, y.f, k.f)        ; HPDF_STATUS; K

Prototype.l Proto_HPDF_Page_GSave(page.i)                                    ; HPDF_STATUS; q
Prototype.l Proto_HPDF_Page_GRestore(page.i)                                 ; HPDF_STATUS; Q
Prototype.l Proto_HPDF_Page_Concat(page.i, a.f, b.f, c.f, d.f, x.f, y.f)     ; HPDF_STATUS; cm

Prototype.i Proto_HPDF_GetFont(pdf.i, font_name.p-ascii, encoding_name.p-ascii)          ; HPDF_Font
Prototype.i Proto_HPDF_LoadTTFontFromFile(pdf.i, file_name.p-ascii, embedding.l)         ; const char* -> .i (font name; PeekS ascii)
Prototype.i Proto_HPDF_LoadTTFontFromFile2(pdf.i, file_name.p-ascii, index.l, embedding.l) ; const char* -> .i (font name; PeekS ascii)
Prototype.l Proto_HPDF_Font_GetAscent(font.i)                                 ; HPDF_INT
Prototype.l Proto_HPDF_Font_GetDescent(font.i)                                ; HPDF_INT
Prototype.l Proto_HPDF_UseUTFEncodings(pdf.i)                                 ; HPDF_STATUS
Prototype.l Proto_HPDF_SetCurrentEncoder(pdf.i, encoding_name.p-ascii)        ; HPDF_STATUS

Prototype.i Proto_HPDF_LoadPngImageFromFile2(pdf.i, filename.p-ascii)         ; HPDF_Image
Prototype.i Proto_HPDF_LoadJpegImageFromFile(pdf.i, filename.p-ascii)         ; HPDF_Image
Prototype.l Proto_HPDF_Image_GetWidth(image.i)                                ; HPDF_UINT
Prototype.l Proto_HPDF_Image_GetHeight(image.i)                               ; HPDF_UINT
Prototype.l Proto_HPDF_Image_GetSize2(image.i, *size)                         ; HPDF_STATUS; *size = HPDF_Point* out (struct-by-value GetSize banned)
Prototype.l Proto_HPDF_Page_DrawImage(page.i, image.i, x.f, y.f, width.f, height.f) ; HPDF_STATUS; cm + Do

Prototype.i Proto_HPDF_CreateExtGState(pdf.i)                                 ; HPDF_ExtGState
Prototype.l Proto_HPDF_ExtGState_SetAlphaFill(ext_gstate.i, value.f)          ; HPDF_STATUS; ca
Prototype.l Proto_HPDF_ExtGState_SetAlphaStroke(ext_gstate.i, value.f)        ; HPDF_STATUS; CA
Prototype.l Proto_HPDF_ExtGState_SetBlendMode(ext_gstate.i, mode.l)           ; HPDF_STATUS; BM
Prototype.l Proto_HPDF_Page_SetExtGState(page.i, ext_gstate.i)                ; HPDF_STATUS; gs

; --- page/document state queries (samples: geometry, grid, position) -------
Prototype.f Proto_HPDF_Page_GetWidth(page.i)                       ; HPDF_REAL
Prototype.f Proto_HPDF_Page_GetHeight(page.i)                      ; HPDF_REAL
Prototype.f Proto_HPDF_Page_GetLineWidth(page.i)                   ; HPDF_REAL
Prototype.l Proto_HPDF_Page_GetCurrentPos2(page.i, *pos)           ; HPDF_Point* out (by-value GetPos banned)
Prototype.l Proto_HPDF_Page_GetCurrentTextPos2(page.i, *pos)       ; HPDF_Point* out
Prototype.i Proto_HPDF_Page_GetCurrentFont(page.i)                 ; HPDF_Font

; --- destinations / page mode ----------------------------------------------
Prototype.l Proto_HPDF_SetOpenAction(pdf.i, open_action.i)         ; HPDF_Destination
Prototype.l Proto_HPDF_SetPageMode(pdf.i, mode.l)                  ; HPDF_PageMode
Prototype.i Proto_HPDF_Page_CreateDestination(page.i)              ; HPDF_Destination
Prototype.l Proto_HPDF_Destination_SetXYZ(dst.i, left.f, top.f, zoom.f)
Prototype.l Proto_HPDF_Destination_SetFit(dst.i)

; --- outlines / encoders (CJK titles/labels arrive as raw bytes) -----------
Prototype.i Proto_HPDF_CreateOutlineRaw(pdf.i, parent.i, *title, encoder.i) ; = HPDF_CreateOutline, raw char*
Prototype.l Proto_HPDF_Outline_SetOpened(outline.i, opened.l)      ; HPDF_BOOL
Prototype.l Proto_HPDF_Outline_SetDestination(outline.i, dst.i)
Prototype.i Proto_HPDF_GetEncoder(pdf.i, encoding_name.p-ascii)    ; HPDF_Encoder
Prototype.l Proto_HPDF_UseJPEncodings(pdf.i)
Prototype.l Proto_HPDF_UseJPFonts(pdf.i)
Prototype.l Proto_HPDF_UseKREncodings(pdf.i)
Prototype.l Proto_HPDF_UseKRFonts(pdf.i)
Prototype.l Proto_HPDF_UseCNSEncodings(pdf.i)
Prototype.l Proto_HPDF_UseCNSFonts(pdf.i)
Prototype.l Proto_HPDF_UseCNTEncodings(pdf.i)
Prototype.l Proto_HPDF_UseCNTFonts(pdf.i)
Prototype.l Proto_HPDF_Encoder_GetType(encoder.i)                  ; HPDF_EncoderType
Prototype.l Proto_HPDF_Encoder_GetByteType(encoder.i, *text, index.l) ; HPDF_ByteType; text = raw MBCS bytes
Prototype.w Proto_HPDF_Encoder_GetUnicode(encoder.i, code.w)       ; HPDF_UNICODE (UINT16)

; --- fonts ------------------------------------------------------------------
Prototype.i Proto_HPDF_GetFontN(pdf.i, *font_name, *encoding_name) ; = HPDF_GetFont, raw; *encoding_name = 0 -> C NULL (font default)
Prototype.i Proto_HPDF_LoadType1FontFromFile(pdf.i, afm_file_name.p-ascii, data_file_name.p-ascii) ; const char*
Prototype.i Proto_HPDF_Font_GetFontName(font.i)                    ; const char* -> .i
Prototype.i Proto_HPDF_Font_GetEncodingName(font.i)                ; const char* -> .i

; --- images ------------------------------------------------------------------
Prototype.i Proto_HPDF_LoadPngImageFromFile(pdf.i, filename.p-ascii)   ; (FromFile2 is the keep-file-around variant)
Prototype.i Proto_HPDF_LoadRawImageFromFile(pdf.i, filename.p-ascii, width.l, height.l, color_space.l)
Prototype.i Proto_HPDF_LoadRawImageFromMem(pdf.i, *buf, width.l, height.l, color_space.l, bits_per_component.l)
Prototype.l Proto_HPDF_Image_SetMaskImage(image.i, mask_image.i)
Prototype.l Proto_HPDF_Image_SetColorMask(image.i, rmin.l, rmax.l, gmin.l, gmax.l, bmin.l, bmax.l)
Prototype.l Proto_HPDF_Image_GetBitsPerComponent(image.i)          ; HPDF_UINT
Prototype.i Proto_HPDF_Image_GetColorSpace(image.i)                ; const char* -> .i
Prototype.l Proto_HPDF_Page_ExecuteXObject(page.i, obj.i)          ; Do (transform via Concat + GSave/GRestore)

; --- annotations (HPDF_Rect/HPDF_Date structs >8 bytes pass BY REF on Win64) --
Prototype.i Proto_HPDF_Page_CreateLinkAnnot(page.i, *rect, dst.i)          ; HPDF_Rect by ref
Prototype.i Proto_HPDF_Page_CreateURILinkAnnot(page.i, *rect, uri.p-ascii) ; HPDF_Rect by ref
Prototype.i Proto_HPDF_Page_CreateTextAnnotRaw(page.i, *rect, *text, encoder.i) ; = CreateTextAnnot; raw contents; encoder 0 = NULL
Prototype.l Proto_HPDF_LinkAnnot_SetHighlightMode(annot.i, mode.l)         ; HPDF_AnnotHighlightMode
Prototype.l Proto_HPDF_LinkAnnot_SetBorderStyle(annot.i, width.f, dash_on.w, dash_off.w)
Prototype.l Proto_HPDF_TextAnnot_SetIcon(annot.i, icon.l)                  ; HPDF_AnnotIcon
Prototype.l Proto_HPDF_TextAnnot_SetOpened(annot.i, opened.l)              ; HPDF_BOOL
Prototype.l Proto_HPDF_Page_MoveToNextLine(page.i)                         ; TD

; --- slide show ---------------------------------------------------------------
Prototype.l Proto_HPDF_Page_SetSlideShow(page.i, trans_style.l, disp_time.f, trans_time.f)

; --- raw text variant for CJK/MBCS (double-byte) fonts -----------------------
Prototype.l Proto_HPDF_Page_ShowTextRaw(page.i, *bytes)            ; = HPDF_Page_ShowText, raw char*

; --- attachments / encryption / PDF-A ----------------------------------------
Prototype.i Proto_HPDF_AttachFile(pdf.i, file.p-ascii)             ; HPDF_EmbeddedFile (2.4.6 returns the handle)
Prototype.l Proto_HPDF_EmbeddedFile_SetName(emfile.i, name.p-ascii)
Prototype.l Proto_HPDF_EmbeddedFile_SetDescription(emfile.i, new_description.p-ascii)
Prototype.l Proto_HPDF_EmbeddedFile_SetSubtype(emfile.i, subtype.p-ascii)
Prototype.l Proto_HPDF_EmbeddedFile_SetAFRelationship(emfile.i, relationship.l)
Prototype.l Proto_HPDF_EmbeddedFile_SetSize(emfile.i, size.q)      ; HPDF_UINT64 -> .q
Prototype.l Proto_HPDF_EmbeddedFile_SetCreationDate(emfile.i, *date)          ; HPDF_Date by ref
Prototype.l Proto_HPDF_EmbeddedFile_SetLastModificationDate(emfile.i, *date)  ; HPDF_Date by ref
Prototype.l Proto_HPDF_SetPassword(pdf.i, owner_passwd.p-ascii, user_passwd.p-ascii)
Prototype.l Proto_HPDF_SetPermission(pdf.i, permission.l)          ; HPDF_ENABLE_* flags
Prototype.l Proto_HPDF_SetEncryptionMode(pdf.i, mode.l, key_len.l) ; HPDF_ENCRYPT_R2/R3
Prototype.l Proto_HPDF_SetInfoDateAttr(pdf.i, infoType.l, *date)   ; "type" renamed (PB keyword); HPDF_Date by ref
Prototype.l Proto_HPDF_SetPDFAConformance(pdf.i, pdfa_type.l)      ; HPDF_PDFAType
Prototype.l Proto_HPDF_AddPDFAXmpExtension(pdf.i, xmp_description.p-ascii)
Prototype.l Proto_HPDF_AppendOutputIntents(pdf.i, iccname.p-ascii, iccdict.i)  ; iccdict = HPDF_OutputIntent
Prototype.i Proto_HPDF_LoadIccProfileFromFile(pdf.i, icc_file_name.p-ascii, numcomponent.l) ; HPDF_OutputIntent

; --- streams (raw image/asset dumping, e.g. make_rawimage) --------------------
Prototype.i Proto_HPDF_GetPageMMgr(page.i)                         ; HPDF_MMgr (the doc's mmgr)
Prototype.i Proto_HPDF_FileWriter_New(mmgr.i, file_name.p-ascii)   ; HPDF_Stream
Prototype.l Proto_HPDF_Stream_WriteToStream(in_stream.i, out_stream.i, filter.l, e.i) ; filter 0 = raw, e = NULL
Prototype   Proto_HPDF_Stream_Free(stream.i)

; ----------------------------------------------------------------------------
; Function-pointer globals - the HPDF_* names used by callers. Assigned by
; HaruInit(); null until then (see usage contract at top).
; ----------------------------------------------------------------------------

Global HPDF_Free.Proto_HPDF_Free
Global HPDF_New.Proto_HPDF_New
Global HPDF_NewEx.Proto_HPDF_NewEx
Global HPDF_SetErrorHandler.Proto_HPDF_SetErrorHandler

Global HPDF_FreeDoc.Proto_HPDF_FreeDoc
Global HPDF_FreeDocAll.Proto_HPDF_FreeDocAll
Global HPDF_HasDoc.Proto_HPDF_HasDoc
Global HPDF_NewDoc.Proto_HPDF_NewDoc
Global HPDF_SaveToStream.Proto_HPDF_SaveToStream
Global HPDF_GetStreamSize.Proto_HPDF_GetStreamSize
Global HPDF_ReadFromStream.Proto_HPDF_ReadFromStream
Global HPDF_ResetStream.Proto_HPDF_ResetStream
Global HPDF_SaveToFile.Proto_HPDF_SaveToFile

Global HPDF_GetError.Proto_HPDF_GetError
Global HPDF_GetErrorDetail.Proto_HPDF_GetErrorDetail
Global HPDF_ResetError.Proto_HPDF_ResetError
Global HPDF_CheckError.Proto_HPDF_CheckError
Global HPDF_GetVersion.Proto_HPDF_GetVersion

Global HPDF_AddPage.Proto_HPDF_AddPage
Global HPDF_InsertPage.Proto_HPDF_InsertPage
Global HPDF_GetCurrentPage.Proto_HPDF_GetCurrentPage
Global HPDF_GetPageByIndex.Proto_HPDF_GetPageByIndex
Global HPDF_SetPagesConfiguration.Proto_HPDF_SetPagesConfiguration
Global HPDF_Page_SetWidth.Proto_HPDF_Page_SetWidth
Global HPDF_Page_SetHeight.Proto_HPDF_Page_SetHeight
Global HPDF_Page_SetSize.Proto_HPDF_Page_SetSize
Global HPDF_Page_SetRotate.Proto_HPDF_Page_SetRotate

Global HPDF_SetCompressionMode.Proto_HPDF_SetCompressionMode
Global HPDF_SetInfoAttr.Proto_HPDF_SetInfoAttr

Global HPDF_Page_BeginText.Proto_HPDF_Page_BeginText
Global HPDF_Page_EndText.Proto_HPDF_Page_EndText
Global HPDF_Page_SetFontAndSize.Proto_HPDF_Page_SetFontAndSize
Global HPDF_Page_TextOut.Proto_HPDF_Page_TextOut
Global HPDF_Page_TextOutRaw.Proto_HPDF_Page_TextOutRaw
Global HPDF_Page_TextWidthRaw.Proto_HPDF_Page_TextWidthRaw
Global HPDF_Page_ShowText.Proto_HPDF_Page_ShowText
Global HPDF_Page_ShowTextNextLine.Proto_HPDF_Page_ShowTextNextLine
Global HPDF_Page_MoveTextPos.Proto_HPDF_Page_MoveTextPos
Global HPDF_Page_MoveTextPos2.Proto_HPDF_Page_MoveTextPos2
Global HPDF_Page_TextWidth.Proto_HPDF_Page_TextWidth
Global HPDF_Page_MeasureText.Proto_HPDF_Page_MeasureText
Global HPDF_Page_TextRect.Proto_HPDF_Page_TextRect
Global HPDF_Page_SetCharSpace.Proto_HPDF_Page_SetCharSpace
Global HPDF_Page_SetWordSpace.Proto_HPDF_Page_SetWordSpace
Global HPDF_Page_SetTextLeading.Proto_HPDF_Page_SetTextLeading
Global HPDF_Page_SetHorizontalScalling.Proto_HPDF_Page_SetHorizontalScalling
Global HPDF_Page_SetTextRenderingMode.Proto_HPDF_Page_SetTextRenderingMode
Global HPDF_Page_SetTextMatrix.Proto_HPDF_Page_SetTextMatrix

Global HPDF_Page_SetLineWidth.Proto_HPDF_Page_SetLineWidth
Global HPDF_Page_SetLineCap.Proto_HPDF_Page_SetLineCap
Global HPDF_Page_SetLineJoin.Proto_HPDF_Page_SetLineJoin
Global HPDF_Page_SetDash.Proto_HPDF_Page_SetDash
Global HPDF_Page_SetFlat.Proto_HPDF_Page_SetFlat

Global HPDF_Page_MoveTo.Proto_HPDF_Page_MoveTo
Global HPDF_Page_LineTo.Proto_HPDF_Page_LineTo
Global HPDF_Page_CurveTo.Proto_HPDF_Page_CurveTo
Global HPDF_Page_CurveTo2.Proto_HPDF_Page_CurveTo2
Global HPDF_Page_CurveTo3.Proto_HPDF_Page_CurveTo3
Global HPDF_Page_ClosePath.Proto_HPDF_Page_ClosePath
Global HPDF_Page_Rectangle.Proto_HPDF_Page_Rectangle
Global HPDF_Page_Circle.Proto_HPDF_Page_Circle
Global HPDF_Page_Ellipse.Proto_HPDF_Page_Ellipse
Global HPDF_Page_Arc.Proto_HPDF_Page_Arc

Global HPDF_Page_Stroke.Proto_HPDF_Page_Stroke
Global HPDF_Page_Fill.Proto_HPDF_Page_Fill
Global HPDF_Page_Eofill.Proto_HPDF_Page_Eofill
Global HPDF_Page_FillStroke.Proto_HPDF_Page_FillStroke
Global HPDF_Page_EofillStroke.Proto_HPDF_Page_EofillStroke
Global HPDF_Page_ClosePathStroke.Proto_HPDF_Page_ClosePathStroke
Global HPDF_Page_ClosePathFillStroke.Proto_HPDF_Page_ClosePathFillStroke
Global HPDF_Page_ClosePathEofillStroke.Proto_HPDF_Page_ClosePathEofillStroke
Global HPDF_Page_EndPath.Proto_HPDF_Page_EndPath
Global HPDF_Page_Clip.Proto_HPDF_Page_Clip
Global HPDF_Page_Eoclip.Proto_HPDF_Page_Eoclip

Global HPDF_Page_SetGrayFill.Proto_HPDF_Page_SetGrayFill
Global HPDF_Page_SetGrayStroke.Proto_HPDF_Page_SetGrayStroke
Global HPDF_Page_SetRGBFill.Proto_HPDF_Page_SetRGBFill
Global HPDF_Page_SetRGBStroke.Proto_HPDF_Page_SetRGBStroke
Global HPDF_Page_SetCMYKFill.Proto_HPDF_Page_SetCMYKFill
Global HPDF_Page_SetCMYKStroke.Proto_HPDF_Page_SetCMYKStroke

Global HPDF_Page_GSave.Proto_HPDF_Page_GSave
Global HPDF_Page_GRestore.Proto_HPDF_Page_GRestore
Global HPDF_Page_Concat.Proto_HPDF_Page_Concat

Global HPDF_GetFont.Proto_HPDF_GetFont
Global HPDF_LoadTTFontFromFile.Proto_HPDF_LoadTTFontFromFile
Global HPDF_LoadTTFontFromFile2.Proto_HPDF_LoadTTFontFromFile2
Global HPDF_Font_GetAscent.Proto_HPDF_Font_GetAscent
Global HPDF_Font_GetDescent.Proto_HPDF_Font_GetDescent
Global HPDF_UseUTFEncodings.Proto_HPDF_UseUTFEncodings
Global HPDF_SetCurrentEncoder.Proto_HPDF_SetCurrentEncoder

Global HPDF_LoadPngImageFromFile2.Proto_HPDF_LoadPngImageFromFile2
Global HPDF_LoadJpegImageFromFile.Proto_HPDF_LoadJpegImageFromFile
Global HPDF_Image_GetWidth.Proto_HPDF_Image_GetWidth
Global HPDF_Image_GetHeight.Proto_HPDF_Image_GetHeight
Global HPDF_Image_GetSize2.Proto_HPDF_Image_GetSize2
Global HPDF_Page_DrawImage.Proto_HPDF_Page_DrawImage

Global HPDF_CreateExtGState.Proto_HPDF_CreateExtGState
Global HPDF_ExtGState_SetAlphaFill.Proto_HPDF_ExtGState_SetAlphaFill
Global HPDF_ExtGState_SetAlphaStroke.Proto_HPDF_ExtGState_SetAlphaStroke
Global HPDF_ExtGState_SetBlendMode.Proto_HPDF_ExtGState_SetBlendMode
Global HPDF_Page_SetExtGState.Proto_HPDF_Page_SetExtGState

Global HPDF_Page_GetWidth.Proto_HPDF_Page_GetWidth
Global HPDF_Page_GetHeight.Proto_HPDF_Page_GetHeight
Global HPDF_Page_GetLineWidth.Proto_HPDF_Page_GetLineWidth
Global HPDF_Page_GetCurrentPos2.Proto_HPDF_Page_GetCurrentPos2
Global HPDF_Page_GetCurrentTextPos2.Proto_HPDF_Page_GetCurrentTextPos2
Global HPDF_Page_GetCurrentFont.Proto_HPDF_Page_GetCurrentFont

Global HPDF_SetOpenAction.Proto_HPDF_SetOpenAction
Global HPDF_SetPageMode.Proto_HPDF_SetPageMode
Global HPDF_Page_CreateDestination.Proto_HPDF_Page_CreateDestination
Global HPDF_Destination_SetXYZ.Proto_HPDF_Destination_SetXYZ
Global HPDF_Destination_SetFit.Proto_HPDF_Destination_SetFit

Global HPDF_CreateOutlineRaw.Proto_HPDF_CreateOutlineRaw
Global HPDF_Outline_SetOpened.Proto_HPDF_Outline_SetOpened
Global HPDF_Outline_SetDestination.Proto_HPDF_Outline_SetDestination
Global HPDF_GetEncoder.Proto_HPDF_GetEncoder
Global HPDF_UseJPEncodings.Proto_HPDF_UseJPEncodings
Global HPDF_UseJPFonts.Proto_HPDF_UseJPFonts
Global HPDF_UseKREncodings.Proto_HPDF_UseKREncodings
Global HPDF_UseKRFonts.Proto_HPDF_UseKRFonts
Global HPDF_UseCNSEncodings.Proto_HPDF_UseCNSEncodings
Global HPDF_UseCNSFonts.Proto_HPDF_UseCNSFonts
Global HPDF_UseCNTEncodings.Proto_HPDF_UseCNTEncodings
Global HPDF_UseCNTFonts.Proto_HPDF_UseCNTFonts
Global HPDF_Encoder_GetType.Proto_HPDF_Encoder_GetType
Global HPDF_Encoder_GetByteType.Proto_HPDF_Encoder_GetByteType
Global HPDF_Encoder_GetUnicode.Proto_HPDF_Encoder_GetUnicode

Global HPDF_GetFontN.Proto_HPDF_GetFontN
Global HPDF_LoadType1FontFromFile.Proto_HPDF_LoadType1FontFromFile
Global HPDF_Font_GetFontName.Proto_HPDF_Font_GetFontName
Global HPDF_Font_GetEncodingName.Proto_HPDF_Font_GetEncodingName

Global HPDF_LoadPngImageFromFile.Proto_HPDF_LoadPngImageFromFile
Global HPDF_LoadRawImageFromFile.Proto_HPDF_LoadRawImageFromFile
Global HPDF_LoadRawImageFromMem.Proto_HPDF_LoadRawImageFromMem
Global HPDF_Image_SetMaskImage.Proto_HPDF_Image_SetMaskImage
Global HPDF_Image_SetColorMask.Proto_HPDF_Image_SetColorMask
Global HPDF_Image_GetBitsPerComponent.Proto_HPDF_Image_GetBitsPerComponent
Global HPDF_Image_GetColorSpace.Proto_HPDF_Image_GetColorSpace
Global HPDF_Page_ExecuteXObject.Proto_HPDF_Page_ExecuteXObject

Global HPDF_Page_CreateLinkAnnot.Proto_HPDF_Page_CreateLinkAnnot
Global HPDF_Page_CreateURILinkAnnot.Proto_HPDF_Page_CreateURILinkAnnot
Global HPDF_Page_CreateTextAnnotRaw.Proto_HPDF_Page_CreateTextAnnotRaw
Global HPDF_LinkAnnot_SetHighlightMode.Proto_HPDF_LinkAnnot_SetHighlightMode
Global HPDF_LinkAnnot_SetBorderStyle.Proto_HPDF_LinkAnnot_SetBorderStyle
Global HPDF_TextAnnot_SetIcon.Proto_HPDF_TextAnnot_SetIcon
Global HPDF_TextAnnot_SetOpened.Proto_HPDF_TextAnnot_SetOpened
Global HPDF_Page_MoveToNextLine.Proto_HPDF_Page_MoveToNextLine

Global HPDF_Page_SetSlideShow.Proto_HPDF_Page_SetSlideShow

Global HPDF_Page_ShowTextRaw.Proto_HPDF_Page_ShowTextRaw

Global HPDF_AttachFile.Proto_HPDF_AttachFile
Global HPDF_EmbeddedFile_SetName.Proto_HPDF_EmbeddedFile_SetName
Global HPDF_EmbeddedFile_SetDescription.Proto_HPDF_EmbeddedFile_SetDescription
Global HPDF_EmbeddedFile_SetSubtype.Proto_HPDF_EmbeddedFile_SetSubtype
Global HPDF_EmbeddedFile_SetAFRelationship.Proto_HPDF_EmbeddedFile_SetAFRelationship
Global HPDF_EmbeddedFile_SetSize.Proto_HPDF_EmbeddedFile_SetSize
Global HPDF_EmbeddedFile_SetCreationDate.Proto_HPDF_EmbeddedFile_SetCreationDate
Global HPDF_EmbeddedFile_SetLastModificationDate.Proto_HPDF_EmbeddedFile_SetLastModificationDate
Global HPDF_SetPassword.Proto_HPDF_SetPassword
Global HPDF_SetPermission.Proto_HPDF_SetPermission
Global HPDF_SetEncryptionMode.Proto_HPDF_SetEncryptionMode
Global HPDF_SetInfoDateAttr.Proto_HPDF_SetInfoDateAttr
Global HPDF_SetPDFAConformance.Proto_HPDF_SetPDFAConformance
Global HPDF_AddPDFAXmpExtension.Proto_HPDF_AddPDFAXmpExtension
Global HPDF_AppendOutputIntents.Proto_HPDF_AppendOutputIntents
Global HPDF_LoadIccProfileFromFile.Proto_HPDF_LoadIccProfileFromFile

Global HPDF_GetPageMMgr.Proto_HPDF_GetPageMMgr
Global HPDF_FileWriter_New.Proto_HPDF_FileWriter_New
Global HPDF_Stream_WriteToStream.Proto_HPDF_Stream_WriteToStream
Global HPDF_Stream_Free.Proto_HPDF_Stream_Free

; ----------------------------------------------------------------------------
; Library load / bind
; ----------------------------------------------------------------------------

Global HaruLib.i      ; OpenLibrary(#PB_Any) id, 0 = not loaded
Global HaruBound.i    ; functions successfully bound by HaruInit()
Global HaruMissing$   ; functions that failed to bind ("" = all bound)

; Binds one export; the name must be given twice because PB macro arguments
; are NOT substituted inside string literals.
Macro HaruBind(fn, fns)
  fn = GetFunction(HaruLib, fns)
  If fn = 0
    HaruMissing$ = HaruMissing$ + fns + " "
  Else
    HaruBound + 1
  EndIf
EndMacro

; Dependency handles preloaded by HaruInit(dir$) (zlib/libpng16 must be
; loaded before hpdf.dll's imports are resolved when the DLLs live outside
; the default search path, e.g. a dev layout). Closed by HaruShutdown().
Global HaruDepZlib.i = 0
Global HaruDepPng.i  = 0

; Loads the libharu shared library and binds the full export set. Returns 1
; on success. On failure (library or a dependency missing, or an export not
; found - i.e. a wrong library version), returns 0; HaruMissing$ / HaruBound
; carry diagnostics. Call once before any HPDF_* / Haru* use; pair with
; HaruShutdown().
; Windows: plain-name search (exe dir / PATH) is the OS default when
; dir$ = "" (shipped layout: hpdf.dll + zlib.dll + libpng16.dll beside the
; exe). dir$ (directory WITH trailing slash, "C:/.../libharu/") opens
; zlib.dll + libpng16.dll FIRST (the loader reuses already-loaded modules
; by name when it resolves hpdf.dll's imports), then hpdf.dll from dir$.
; Linux: dlopen has NO exe-directory search, so dir$ = "" resolves the exe
; directory via ProgramFilename() and tries, in order: exeDir +
; "libhpdf.so", exeDir + "libhpdf.so.2", "./libhpdf.so", then the bare names
; through the normal ld.so search (DT_RPATH, LD_LIBRARY_PATH, DT_RUNPATH,
; ld.so.cache, /lib, /usr/lib). zlib/libpng need no preload there: ld.so
; resolves the dependencies at dlopen time (system packages) or they are
; statically linked into libhpdf.so. dir$ given -> dir$ + "libhpdf.so[.2]"
; only (an explicit dir is trusted, no fallbacks).
Procedure.i HaruInit(dir$ = "")
  HaruMissing$ = ""
  HaruBound = 0
  HaruDepZlib = 0
  HaruDepPng = 0
  CompilerIf #PB_Compiler_OS = #PB_OS_Linux
    ; dlopen has NO exe-directory search (Windows OpenLibrary does), so the
    ; shipped layout (lib beside exe) is resolved from ProgramFilename().
    ; Fallbacks: './' + name (PB doc: cwd needs an explicit ./ prefix), then
    ; the bare name through the ld.so search. The ".so.2" variants cover
    ; distro runtime packages that install only the versioned soname (the
    ; plain libhpdf.so lives only in dev packages / the build tree).
    ; zlib/libpng need NO preload on this OS: ld.so resolves the deps at
    ; dlopen time (system packages) or they are baked into libhpdf.so
    ; statically - the Windows module-reuse preload trick is meaningless
    ; here (and the names differ: libz.so.1 / libpng16.so.16).
    Protected exeDir$ = GetPathPart(ProgramFilename())
    Protected i.i, n.i
    Protected Dim cand.s(4)
    If dir$ <> ""
      cand(0) = dir$ + "libhpdf.so"
      cand(1) = dir$ + "libhpdf.so.2"
      n = 1
    Else
      cand(0) = exeDir$ + "libhpdf.so"
      cand(1) = exeDir$ + "libhpdf.so.2"
      cand(2) = "./libhpdf.so"
      cand(3) = "libhpdf.so"
      cand(4) = "libhpdf.so.2"
      n = 4
    EndIf
    HaruLib = 0
    For i = 0 To n
      HaruLib = OpenLibrary(#PB_Any, cand(i))
      If HaruLib
        Break
      EndIf
    Next
  CompilerElse
    If dir$ <> ""
      HaruDepZlib = OpenLibrary(#PB_Any, dir$ + "zlib.dll")
      HaruDepPng = OpenLibrary(#PB_Any, dir$ + "libpng16.dll")
      HaruLib = OpenLibrary(#PB_Any, dir$ + "hpdf.dll")
    Else
      HaruLib = OpenLibrary(#PB_Any, "hpdf.dll")
    EndIf
  CompilerEndIf
  If HaruLib = 0
    ; partial-failure cleanup: close what was opened here before bailing out
    If HaruDepZlib
      CloseLibrary(HaruDepZlib)
      HaruDepZlib = 0
    EndIf
    If HaruDepPng
      CloseLibrary(HaruDepPng)
      HaruDepPng = 0
    EndIf
    ProcedureReturn 0
  EndIf

  HaruBind(HPDF_New, "HPDF_New")
  HaruBind(HPDF_NewEx, "HPDF_NewEx")
  HaruBind(HPDF_SetErrorHandler, "HPDF_SetErrorHandler")
  HaruBind(HPDF_Free, "HPDF_Free")

  HaruBind(HPDF_NewDoc, "HPDF_NewDoc")
  HaruBind(HPDF_FreeDoc, "HPDF_FreeDoc")
  HaruBind(HPDF_HasDoc, "HPDF_HasDoc")
  HaruBind(HPDF_FreeDocAll, "HPDF_FreeDocAll")
  HaruBind(HPDF_SaveToStream, "HPDF_SaveToStream")
  HaruBind(HPDF_GetStreamSize, "HPDF_GetStreamSize")
  HaruBind(HPDF_ReadFromStream, "HPDF_ReadFromStream")
  HaruBind(HPDF_ResetStream, "HPDF_ResetStream")
  HaruBind(HPDF_SaveToFile, "HPDF_SaveToFile")

  HaruBind(HPDF_GetError, "HPDF_GetError")
  HaruBind(HPDF_GetErrorDetail, "HPDF_GetErrorDetail")
  HaruBind(HPDF_ResetError, "HPDF_ResetError")
  HaruBind(HPDF_CheckError, "HPDF_CheckError")
  HaruBind(HPDF_GetVersion, "HPDF_GetVersion")

  HaruBind(HPDF_AddPage, "HPDF_AddPage")
  HaruBind(HPDF_InsertPage, "HPDF_InsertPage")
  HaruBind(HPDF_GetCurrentPage, "HPDF_GetCurrentPage")
  HaruBind(HPDF_GetPageByIndex, "HPDF_GetPageByIndex")
  HaruBind(HPDF_SetPagesConfiguration, "HPDF_SetPagesConfiguration")
  HaruBind(HPDF_Page_SetWidth, "HPDF_Page_SetWidth")
  HaruBind(HPDF_Page_SetHeight, "HPDF_Page_SetHeight")
  HaruBind(HPDF_Page_SetSize, "HPDF_Page_SetSize")
  HaruBind(HPDF_Page_SetRotate, "HPDF_Page_SetRotate")

  HaruBind(HPDF_SetCompressionMode, "HPDF_SetCompressionMode")
  HaruBind(HPDF_SetInfoAttr, "HPDF_SetInfoAttr")

  HaruBind(HPDF_Page_BeginText, "HPDF_Page_BeginText")
  HaruBind(HPDF_Page_EndText, "HPDF_Page_EndText")
  HaruBind(HPDF_Page_SetFontAndSize, "HPDF_Page_SetFontAndSize")
  HaruBind(HPDF_Page_TextOut, "HPDF_Page_TextOut")
  HaruBind(HPDF_Page_TextOutRaw, "HPDF_Page_TextOut")       ; zelfde export, raw char*
  HaruBind(HPDF_Page_TextWidthRaw, "HPDF_Page_TextWidth")   ; zelfde export, raw char*
  HaruBind(HPDF_Page_ShowText, "HPDF_Page_ShowText")
  HaruBind(HPDF_Page_ShowTextNextLine, "HPDF_Page_ShowTextNextLine")
  HaruBind(HPDF_Page_MoveTextPos, "HPDF_Page_MoveTextPos")
  HaruBind(HPDF_Page_MoveTextPos2, "HPDF_Page_MoveTextPos2")
  HaruBind(HPDF_Page_TextWidth, "HPDF_Page_TextWidth")
  HaruBind(HPDF_Page_MeasureText, "HPDF_Page_MeasureText")
  HaruBind(HPDF_Page_TextRect, "HPDF_Page_TextRect")
  HaruBind(HPDF_Page_SetCharSpace, "HPDF_Page_SetCharSpace")
  HaruBind(HPDF_Page_SetWordSpace, "HPDF_Page_SetWordSpace")
  HaruBind(HPDF_Page_SetTextLeading, "HPDF_Page_SetTextLeading")
  HaruBind(HPDF_Page_SetHorizontalScalling, "HPDF_Page_SetHorizontalScalling")
  HaruBind(HPDF_Page_SetTextRenderingMode, "HPDF_Page_SetTextRenderingMode")
  HaruBind(HPDF_Page_SetTextMatrix, "HPDF_Page_SetTextMatrix")

  HaruBind(HPDF_Page_SetLineWidth, "HPDF_Page_SetLineWidth")
  HaruBind(HPDF_Page_SetLineCap, "HPDF_Page_SetLineCap")
  HaruBind(HPDF_Page_SetLineJoin, "HPDF_Page_SetLineJoin")
  HaruBind(HPDF_Page_SetDash, "HPDF_Page_SetDash")
  HaruBind(HPDF_Page_SetFlat, "HPDF_Page_SetFlat")

  HaruBind(HPDF_Page_MoveTo, "HPDF_Page_MoveTo")
  HaruBind(HPDF_Page_LineTo, "HPDF_Page_LineTo")
  HaruBind(HPDF_Page_CurveTo, "HPDF_Page_CurveTo")
  HaruBind(HPDF_Page_CurveTo2, "HPDF_Page_CurveTo2")
  HaruBind(HPDF_Page_CurveTo3, "HPDF_Page_CurveTo3")
  HaruBind(HPDF_Page_ClosePath, "HPDF_Page_ClosePath")
  HaruBind(HPDF_Page_Rectangle, "HPDF_Page_Rectangle")
  HaruBind(HPDF_Page_Circle, "HPDF_Page_Circle")
  HaruBind(HPDF_Page_Ellipse, "HPDF_Page_Ellipse")
  HaruBind(HPDF_Page_Arc, "HPDF_Page_Arc")

  HaruBind(HPDF_Page_Stroke, "HPDF_Page_Stroke")
  HaruBind(HPDF_Page_Fill, "HPDF_Page_Fill")
  HaruBind(HPDF_Page_Eofill, "HPDF_Page_Eofill")
  HaruBind(HPDF_Page_FillStroke, "HPDF_Page_FillStroke")
  HaruBind(HPDF_Page_EofillStroke, "HPDF_Page_EofillStroke")
  HaruBind(HPDF_Page_ClosePathStroke, "HPDF_Page_ClosePathStroke")
  HaruBind(HPDF_Page_ClosePathFillStroke, "HPDF_Page_ClosePathFillStroke")
  HaruBind(HPDF_Page_ClosePathEofillStroke, "HPDF_Page_ClosePathEofillStroke")
  HaruBind(HPDF_Page_EndPath, "HPDF_Page_EndPath")
  HaruBind(HPDF_Page_Clip, "HPDF_Page_Clip")
  HaruBind(HPDF_Page_Eoclip, "HPDF_Page_Eoclip")

  HaruBind(HPDF_Page_SetGrayFill, "HPDF_Page_SetGrayFill")
  HaruBind(HPDF_Page_SetGrayStroke, "HPDF_Page_SetGrayStroke")
  HaruBind(HPDF_Page_SetRGBFill, "HPDF_Page_SetRGBFill")
  HaruBind(HPDF_Page_SetRGBStroke, "HPDF_Page_SetRGBStroke")
  HaruBind(HPDF_Page_SetCMYKFill, "HPDF_Page_SetCMYKFill")
  HaruBind(HPDF_Page_SetCMYKStroke, "HPDF_Page_SetCMYKStroke")

  HaruBind(HPDF_Page_GSave, "HPDF_Page_GSave")
  HaruBind(HPDF_Page_GRestore, "HPDF_Page_GRestore")
  HaruBind(HPDF_Page_Concat, "HPDF_Page_Concat")

  HaruBind(HPDF_GetFont, "HPDF_GetFont")
  HaruBind(HPDF_LoadTTFontFromFile, "HPDF_LoadTTFontFromFile")
  HaruBind(HPDF_LoadTTFontFromFile2, "HPDF_LoadTTFontFromFile2")
  HaruBind(HPDF_Font_GetAscent, "HPDF_Font_GetAscent")
  HaruBind(HPDF_Font_GetDescent, "HPDF_Font_GetDescent")
  HaruBind(HPDF_UseUTFEncodings, "HPDF_UseUTFEncodings")
  HaruBind(HPDF_SetCurrentEncoder, "HPDF_SetCurrentEncoder")

  HaruBind(HPDF_LoadPngImageFromFile2, "HPDF_LoadPngImageFromFile2")
  HaruBind(HPDF_LoadJpegImageFromFile, "HPDF_LoadJpegImageFromFile")
  HaruBind(HPDF_Image_GetWidth, "HPDF_Image_GetWidth")
  HaruBind(HPDF_Image_GetHeight, "HPDF_Image_GetHeight")
  HaruBind(HPDF_Image_GetSize2, "HPDF_Image_GetSize2")
  HaruBind(HPDF_Page_DrawImage, "HPDF_Page_DrawImage")

  HaruBind(HPDF_CreateExtGState, "HPDF_CreateExtGState")
  HaruBind(HPDF_ExtGState_SetAlphaFill, "HPDF_ExtGState_SetAlphaFill")
  HaruBind(HPDF_ExtGState_SetAlphaStroke, "HPDF_ExtGState_SetAlphaStroke")
  HaruBind(HPDF_ExtGState_SetBlendMode, "HPDF_ExtGState_SetBlendMode")
  HaruBind(HPDF_Page_SetExtGState, "HPDF_Page_SetExtGState")

  HaruBind(HPDF_Page_GetWidth, "HPDF_Page_GetWidth")
  HaruBind(HPDF_Page_GetHeight, "HPDF_Page_GetHeight")
  HaruBind(HPDF_Page_GetLineWidth, "HPDF_Page_GetLineWidth")
  HaruBind(HPDF_Page_GetCurrentPos2, "HPDF_Page_GetCurrentPos2")
  HaruBind(HPDF_Page_GetCurrentTextPos2, "HPDF_Page_GetCurrentTextPos2")
  HaruBind(HPDF_Page_GetCurrentFont, "HPDF_Page_GetCurrentFont")

  HaruBind(HPDF_SetOpenAction, "HPDF_SetOpenAction")
  HaruBind(HPDF_SetPageMode, "HPDF_SetPageMode")
  HaruBind(HPDF_Page_CreateDestination, "HPDF_Page_CreateDestination")
  HaruBind(HPDF_Destination_SetXYZ, "HPDF_Destination_SetXYZ")
  HaruBind(HPDF_Destination_SetFit, "HPDF_Destination_SetFit")

  HaruBind(HPDF_CreateOutlineRaw, "HPDF_CreateOutline")     ; same export, raw char* title
  HaruBind(HPDF_Outline_SetOpened, "HPDF_Outline_SetOpened")
  HaruBind(HPDF_Outline_SetDestination, "HPDF_Outline_SetDestination")
  HaruBind(HPDF_GetEncoder, "HPDF_GetEncoder")
  HaruBind(HPDF_UseJPEncodings, "HPDF_UseJPEncodings")
  HaruBind(HPDF_UseJPFonts, "HPDF_UseJPFonts")
  HaruBind(HPDF_UseKREncodings, "HPDF_UseKREncodings")
  HaruBind(HPDF_UseKRFonts, "HPDF_UseKRFonts")
  HaruBind(HPDF_UseCNSEncodings, "HPDF_UseCNSEncodings")
  HaruBind(HPDF_UseCNSFonts, "HPDF_UseCNSFonts")
  HaruBind(HPDF_UseCNTEncodings, "HPDF_UseCNTEncodings")
  HaruBind(HPDF_UseCNTFonts, "HPDF_UseCNTFonts")
  HaruBind(HPDF_Encoder_GetType, "HPDF_Encoder_GetType")
  HaruBind(HPDF_Encoder_GetByteType, "HPDF_Encoder_GetByteType")
  HaruBind(HPDF_Encoder_GetUnicode, "HPDF_Encoder_GetUnicode")

  HaruBind(HPDF_GetFontN, "HPDF_GetFont")                   ; same export, raw/NULL encoder
  HaruBind(HPDF_LoadType1FontFromFile, "HPDF_LoadType1FontFromFile")
  HaruBind(HPDF_Font_GetFontName, "HPDF_Font_GetFontName")
  HaruBind(HPDF_Font_GetEncodingName, "HPDF_Font_GetEncodingName")

  HaruBind(HPDF_LoadPngImageFromFile, "HPDF_LoadPngImageFromFile")
  HaruBind(HPDF_LoadRawImageFromFile, "HPDF_LoadRawImageFromFile")
  HaruBind(HPDF_LoadRawImageFromMem, "HPDF_LoadRawImageFromMem")
  HaruBind(HPDF_Image_SetMaskImage, "HPDF_Image_SetMaskImage")
  HaruBind(HPDF_Image_SetColorMask, "HPDF_Image_SetColorMask")
  HaruBind(HPDF_Image_GetBitsPerComponent, "HPDF_Image_GetBitsPerComponent")
  HaruBind(HPDF_Image_GetColorSpace, "HPDF_Image_GetColorSpace")
  HaruBind(HPDF_Page_ExecuteXObject, "HPDF_Page_ExecuteXObject")

  HaruBind(HPDF_Page_CreateLinkAnnot, "HPDF_Page_CreateLinkAnnot")
  HaruBind(HPDF_Page_CreateURILinkAnnot, "HPDF_Page_CreateURILinkAnnot")
  HaruBind(HPDF_Page_CreateTextAnnotRaw, "HPDF_Page_CreateTextAnnot") ; same export, raw contents
  HaruBind(HPDF_LinkAnnot_SetHighlightMode, "HPDF_LinkAnnot_SetHighlightMode")
  HaruBind(HPDF_LinkAnnot_SetBorderStyle, "HPDF_LinkAnnot_SetBorderStyle")
  HaruBind(HPDF_TextAnnot_SetIcon, "HPDF_TextAnnot_SetIcon")
  HaruBind(HPDF_TextAnnot_SetOpened, "HPDF_TextAnnot_SetOpened")
  HaruBind(HPDF_Page_MoveToNextLine, "HPDF_Page_MoveToNextLine")

  HaruBind(HPDF_Page_SetSlideShow, "HPDF_Page_SetSlideShow")

  HaruBind(HPDF_Page_ShowTextRaw, "HPDF_Page_ShowText")     ; same export, raw char*

  HaruBind(HPDF_AttachFile, "HPDF_AttachFile")
  HaruBind(HPDF_EmbeddedFile_SetName, "HPDF_EmbeddedFile_SetName")
  HaruBind(HPDF_EmbeddedFile_SetDescription, "HPDF_EmbeddedFile_SetDescription")
  HaruBind(HPDF_EmbeddedFile_SetSubtype, "HPDF_EmbeddedFile_SetSubtype")
  HaruBind(HPDF_EmbeddedFile_SetAFRelationship, "HPDF_EmbeddedFile_SetAFRelationship")
  HaruBind(HPDF_EmbeddedFile_SetSize, "HPDF_EmbeddedFile_SetSize")
  HaruBind(HPDF_EmbeddedFile_SetCreationDate, "HPDF_EmbeddedFile_SetCreationDate")
  HaruBind(HPDF_EmbeddedFile_SetLastModificationDate, "HPDF_EmbeddedFile_SetLastModificationDate")
  HaruBind(HPDF_SetPassword, "HPDF_SetPassword")
  HaruBind(HPDF_SetPermission, "HPDF_SetPermission")
  HaruBind(HPDF_SetEncryptionMode, "HPDF_SetEncryptionMode")
  HaruBind(HPDF_SetInfoDateAttr, "HPDF_SetInfoDateAttr")
  HaruBind(HPDF_SetPDFAConformance, "HPDF_SetPDFAConformance")
  HaruBind(HPDF_AddPDFAXmpExtension, "HPDF_AddPDFAXmpExtension")
  HaruBind(HPDF_AppendOutputIntents, "HPDF_AppendOutputIntents")
  HaruBind(HPDF_LoadIccProfileFromFile, "HPDF_LoadIccProfileFromFile")

  HaruBind(HPDF_GetPageMMgr, "HPDF_GetPageMMgr")
  HaruBind(HPDF_FileWriter_New, "HPDF_FileWriter_New")
  HaruBind(HPDF_Stream_WriteToStream, "HPDF_Stream_WriteToStream")
  HaruBind(HPDF_Stream_Free, "HPDF_Stream_Free")

  If HaruMissing$ <> ""
    CloseLibrary(HaruLib)
    HaruLib = 0
    If HaruDepZlib
      CloseLibrary(HaruDepZlib)
      HaruDepZlib = 0
    EndIf
    If HaruDepPng
      CloseLibrary(HaruDepPng)
      HaruDepPng = 0
    EndIf
    ProcedureReturn 0
  EndIf
  ProcedureReturn 1
EndProcedure

; Closes the library. After this, HPDF_* pointers are stale - HaruInit()
; must be called again before further use. Also closes the dependency
; handles opened by HaruInit(dir$) (no-op when they were not opened here).
Procedure HaruShutdown()
  If HaruLib
    CloseLibrary(HaruLib)
    HaruLib = 0
  EndIf
  If HaruDepZlib
    CloseLibrary(HaruDepZlib)
    HaruDepZlib = 0
  EndIf
  If HaruDepPng
    CloseLibrary(HaruDepPng)
    HaruDepPng = 0
  EndIf
EndProcedure

; ----------------------------------------------------------------------------
; Haru* thin helpers. All helpers require HaruInit() success and expect a doc
; created by HaruNew() so the UTF-8 pipeline is guaranteed
; (HPDF_UseUTFEncodings + current encoder "UTF-8").
;
; Per-doc caches are plain global maps keyed "<doc>|<...>"; HaruFree purges
; its doc's entries (doc pointers can be reused by a later HPDF_New - stale
; cache hits would hand out foreign handles). Strings are never stored as C
; pointers across calls: PB converts PB-string args per call (.p-ascii /
; .p-utf8), matching the call-duration-only pointer rule of the prototypes.
;
; ----------------------------------------------------------------------------

Global NewMap HaruFontCache.i() ; "<doc>|<ttf path>" -> HPDF_Font handle
Global NewMap HaruGsCache.i()   ; "<doc>|<alpha>"     -> HPDF_ExtGState handle

; Creates a doc with the UTF-8 pipeline enabled. Returns doc handle, 0 on
; failure. Guards against a skipped HaruInit().
Procedure.i HaruNew()
  If HaruLib = 0
    ProcedureReturn 0
  EndIf
  Protected pdf.i = HPDF_New(0, 0)
  If pdf = 0
    ProcedureReturn 0
  EndIf
  If HPDF_UseUTFEncodings(pdf) <> #HPDF_OK
    HPDF_Free(pdf)
    ProcedureReturn 0
  EndIf
  If HPDF_SetCurrentEncoder(pdf, "UTF-8") <> #HPDF_OK
    HPDF_Free(pdf)
    ProcedureReturn 0
  EndIf
  ProcedureReturn pdf
EndProcedure

; Frees the doc and purges its per-doc cache entries.
Procedure HaruFree(pdf.i)
  Protected prefix$ = Str(pdf) + "|"
  ForEach HaruFontCache()
    If Left(MapKey(HaruFontCache()), Len(prefix$)) = prefix$
      DeleteMapElement(HaruFontCache())
    EndIf
  Next
  ForEach HaruGsCache()
    If Left(MapKey(HaruGsCache()), Len(prefix$)) = prefix$
      DeleteMapElement(HaruGsCache())
    EndIf
  Next
  HPDF_Free(pdf)
EndProcedure

; "err <error-code-hex>/<detail-hex>" for the doc's latched error - for FAIL
; diagnostics. Zero error reads as "err 0/0".
Procedure.s HaruErrorText(pdf.i)
  ProcedureReturn "err " + Hex(HPDF_GetError(pdf)) + "/" + Hex(HPDF_GetErrorDetail(pdf))
EndProcedure

; Loads a TrueType font, embeds the font program, fetches it with the
; "UTF-8" encoding, caches it per doc+path so repeated calls return the same
; HPDF_Font instead of embedding the program twice. Returns the HPDF_Font
; handle, 0 on failure.
; Loader choice: in 2.4.6 HPDF_LoadTTFontFromFile2 is TTC-only (a plain
; single-face TTF raises HPDF_INVALID_TTC_FILE $103F), so try the plain
; loader first and only retry through FromFile2(index 0) when libharu latched
; exactly that error. 
Procedure.i HaruTTFFont(pdf.i, path$)
  Protected key$ = Str(pdf) + "|" + path$
  Protected namePtr.i, name$, font.i
  If FindMapElement(HaruFontCache(), key$)
    ProcedureReturn HaruFontCache()
  EndIf
  namePtr = HPDF_LoadTTFontFromFile(pdf, path$, #HPDF_TRUE)
  If namePtr = 0
    If HPDF_GetError(pdf) = #HPDF_INVALID_TTC_FILE ; collection file -> retry as TTC subfont 0
      HPDF_ResetError(pdf)
      namePtr = HPDF_LoadTTFontFromFile2(pdf, path$, 0, #HPDF_TRUE)
    EndIf
  EndIf
  If namePtr = 0
    ProcedureReturn 0
  EndIf
  name$ = PeekS(namePtr, -1, #PB_Ascii) ; libharu returns the (internal) font name
  font = HPDF_GetFont(pdf, name$, "UTF-8")
  If font = 0
    ProcedureReturn 0
  EndIf
  HaruFontCache(key$) = font
  ProcedureReturn font
EndProcedure

; Adds a page configured A4 portrait. Returns page handle, 0 on failure.
Procedure.i HaruAddPage(pdf.i)
  Protected page.i = HPDF_AddPage(pdf)
  If page = 0
    ProcedureReturn 0
  EndIf
  If HPDF_Page_SetSize(page, #HPDF_PAGE_SIZE_A4, #HPDF_PAGE_PORTRAIT) <> #HPDF_OK
    ProcedureReturn 0
  EndIf
  ProcedureReturn page
EndProcedure

; Loads a PNG image from file. Returns the HPDF_Image handle, 0 on failure.
; (Deliberately thin - image handles are cheap and libharu attaches them to
; the doc; drawing the same handle N times reuses one XObject.)
Procedure.i HaruPngFromFile(pdf.i, path$)
  ProcedureReturn HPDF_LoadPngImageFromFile2(pdf, path$)
EndProcedure

; Returns a cached ExtGState with both fill (ca) and stroke (CA) alpha set,
; one per doc+alpha. Cache before creating: repeated HaruAlpha calls with
; the same alpha reuse one ExtGState. Returns handle, 0 on failure.
Procedure.i HaruAlpha(pdf.i, alpha.f)
  Protected key$ = Str(pdf) + "|" + StrF(alpha)
  Protected gs.i
  If FindMapElement(HaruGsCache(), key$)
    ProcedureReturn HaruGsCache()
  EndIf
  gs = HPDF_CreateExtGState(pdf)
  If gs = 0
    ProcedureReturn 0
  EndIf
  HPDF_ExtGState_SetAlphaFill(gs, alpha)
  HPDF_ExtGState_SetAlphaStroke(gs, alpha)
  HaruGsCache(key$) = gs
  ProcedureReturn gs
EndProcedure

; Draws UTF-8 text at (x, y) - requires the font set via
; HPDF_Page_SetFontAndSize and the UTF-8 encoder from HaruNew. Returns the
; HPDF_STATUS of the underlying text operation.
; NOTE: libharu's HPDF_Page_TextOut demands TEXT_OBJECT mode (CheckState
; gmode & TEXT_OBJECT - raises HPDF_PAGE_INVALID_GMODE otherwise; verified
; against hpdf_page_operator.c 2.4.6 and at runtime), so this helper brackets
; with BeginText/EndText itself and stays a one-call API.
Procedure.i HaruTextOut(page.i, xpos.f, ypos.f, s$)
  Protected ret.i = HPDF_Page_BeginText(page)
  If ret <> #HPDF_OK
    ProcedureReturn ret
  EndIf
  ret = HPDF_Page_TextOut(page, xpos, ypos, s$)
  HPDF_Page_EndText(page) ; always close the text object; stream errors latch on the doc
  ProcedureReturn ret
EndProcedure

; ---------------------------------------------------------------------------
; Base-14 (non-embedded) fonts: WinAnsi-byte pipeline
;
; libharu's single-byte fonts do NO text conversion: HPDF_Page_TextOut
; escapes the input bytes 1:1 into the content stream; the /Encoding entry
; (e.g. /WinAnsiEncoding) only tells the VIEWER how to read those bytes
; with AND without UseUTFEncodings). The p-utf8 prototypes above therefore
; only fit the UTF-8/TTF pipeline. For base-14 fonts the caller must hand
; over pre-encoded WinAnsi bytes: build them with HaruWinAnsiMem, draw with
; HaruTextOutRaw, measure with HPDF_Page_TextWidthRaw, free with FreeMemory.
; ---------------------------------------------------------------------------

; Converts a PB string (UTF-16) to a NUL-terminated WinAnsi/CP1252 byte
; buffer (AllocateMemory; caller frees). CP1252 specials 0x80-0x9F mapped
; explicitly, Latin-1 range 1:1, anything unmappable -> '?'. Deterministic
; and locale-independent (no #PB_Ascii system-codepage dependency).
Procedure.i HaruWinAnsiMem(s$)
  Protected n.i = Len(s$)
  Protected *mem = AllocateMemory(n + 1)
  If *mem = 0
    ProcedureReturn 0
  EndIf
  Protected i.i, c.i, b.i, pos.i = 0
  For i = 1 To n
    c = Asc(Mid(s$, i, 1))
    Select c
      Case 32 To 126, 160 To 255
        b = c
      Case $20AC : b = $80                  ; EURO SIGN
      Case $201A : b = $82                  ; SINGLE LOW-9 QUOTE
      Case $0192 : b = $83                  ; LATIN SMALL LETTER F HOOK
      Case $201E : b = $84                  ; DOUBLE LOW-9 QUOTE
      Case $2026 : b = $85                  ; HORIZONTAL ELLIPSIS
      Case $2020 : b = $86                  ; DAGGER
      Case $2021 : b = $87                  ; DOUBLE DAGGER
      Case $02C6 : b = $88                  ; MODIFIER CIRCUMFLEX
      Case $2030 : b = $89                  ; PER MILLE
      Case $0160 : b = $8A                  ; LATIN CAPITAL S CARON
      Case $2039 : b = $8B                  ; SINGLE LEFT ANGLE QUOTE
      Case $0152 : b = $8C                  ; LATIN CAPITAL LIGATURE OE
      Case $017D : b = $8E                  ; LATIN CAPITAL Z CARON
      Case $2018 : b = $91                  ; LEFT SINGLE QUOTE
      Case $2019 : b = $92                  ; RIGHT SINGLE QUOTE
      Case $201C : b = $93                  ; LEFT DOUBLE QUOTE
      Case $201D : b = $94                  ; RIGHT DOUBLE QUOTE
      Case $2022 : b = $95                  ; BULLET
      Case $2013 : b = $96                  ; EN DASH
      Case $2014 : b = $97                  ; EM DASH
      Case $02DC : b = $98                  ; SMALL TILDE
      Case $2122 : b = $99                  ; TRADE MARK
      Case $0161 : b = $9A                  ; LATIN SMALL S CARON
      Case $203A : b = $9B                  ; SINGLE RIGHT ANGLE QUOTE
      Case $0153 : b = $9C                  ; LATIN SMALL LIGATURE OE
      Case $017E : b = $9E                  ; LATIN SMALL Z CARON
      Case $0178 : b = $9F                  ; LATIN CAPITAL Y DIAERESIS
      Default
        b = 63                              ; '?' - niet in WinAnsi
    EndSelect
    PokeA(*mem + pos, b)
    pos + 1
  Next i
  PokeA(*mem + pos, 0)
  ProcedureReturn *mem
EndProcedure

; Draws pre-encoded WinAnsi bytes (HaruWinAnsiMem) at (x, y) - same BT/ET
; bracketing as HaruTextOut. *bytes must be NUL-terminated; libharu consumes
; synchronously, so freeing right after the call is safe.
Procedure.i HaruTextOutRaw(page.i, xpos.f, ypos.f, *bytes)
  Protected ret.i = HPDF_Page_BeginText(page)
  If ret <> #HPDF_OK
    ProcedureReturn ret
  EndIf
  ret = HPDF_Page_TextOutRaw(page, xpos, ypos, *bytes)
  HPDF_Page_EndText(page)
  ProcedureReturn ret
EndProcedure

; ---------------------------------------------------------------------------
; Raw single-byte / MBCS helpers (samples with byte-exact text)
;
; HaruAsciiMem builds a NUL-terminated single-byte buffer 1:1 from the PB
; string (chars 1-255 pass through, anything else -> '?'). Unlike
; HaruWinAnsiMem it does NO CP1252 remapping: it is the bridge for CJK
; double-byte codes assembled with Chr() and for byte strings whose meaning
; is fixed by the encoder passed to libharu (ISO8859-x, SJIS, GBK, ...).
; ---------------------------------------------------------------------------

; NUL-terminated byte buffer of s$ (AllocateMemory; caller frees).
Procedure.i HaruAsciiMem(s$)
  Protected n.i = Len(s$)
  Protected *mem = AllocateMemory(n + 1)
  If *mem = 0
    ProcedureReturn 0
  EndIf
  Protected i.i, c.i, pos.i = 0
  For i = 1 To n
    c = Asc(Mid(s$, i, 1))
    If c < 1 Or c > 255
      c = 63                                 ; '?' - not a single byte
    EndIf
    PokeA(*mem + pos, c)
    pos + 1
  Next i
  PokeA(*mem + pos, 0)
  ProcedureReturn *mem
EndProcedure

; HPDF_GetFont with optional C-NULL encoding (the font's built-in default;
; HPDF_GetFont's p-ascii prototype cannot pass NULL): encoding$ = "" -> NULL.
; All other cases behave exactly like HPDF_GetFont(pdf, font, enc).
Procedure.i HaruGetFont(pdf.i, fontName$, encodingName$ = "")
  Protected *fn = HaruAsciiMem(fontName$)
  Protected *fe = 0
  Protected font.i
  If *fn = 0
    ProcedureReturn 0
  EndIf
  If encodingName$ <> ""
    *fe = HaruAsciiMem(encodingName$)
    If *fe = 0
      FreeMemory(*fn)
      ProcedureReturn 0
    EndIf
  EndIf
  font = HPDF_GetFontN(pdf, *fn, *fe)
  FreeMemory(*fn)
  If *fe
    FreeMemory(*fe)
  EndIf
  ProcedureReturn font
EndProcedure

; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 852
; FirstLine = 814
; Folding = ---
; EnableXP
; DPIAware