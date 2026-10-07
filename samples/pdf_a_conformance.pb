; ---------------------------------------------------------------------------
; pdf_a_conformance.pb - PureBasic port of libharu's pdf_a_conformance.c
; (<< Haru Free PDF Library 2.0.0 >>, Copyright (c) 1999-2006 Takeshi Kanno,
; ZLIB license - see ../THIRD-PARTY-NOTICES.md).
; PDF/A-3B conformance demo: embeds PenguinAttack.ttf (WinAnsiEncoding), two
; centered text lines on a LETTER portrait page, attaches pdf_a/factur-x.xml
; as an associated file (AFRelationship DATA, size/name/description/subtype/
; dates set), sets info-dictionary attributes, switches the document to
; PDF/A-3B, appends an sRGB output intent from pdf_a/device_rgb.icc and adds
; the two Factur-X XMP extension schemas.
;
; Deviations from the C original (wrapper subset, see ../hpdf.pbi):
;  - no setjmp/longjmp error handler: one latched-error gate before the save;
;  - the C's HPDF_Date-returning helpers become procedures filling a
;    caller-provided HPDFDate (PB structures cannot be returned by value);
;  - UPSTREAM QUIRK, PORTED FAITHFULLY: the C calls
;    HPDF_EmbeddedFile_SetCreationDate twice - the second call passes the
;    modification date, so the embedded file's CreationDate ends up holding
;    the modification date (libharu then overwrites ModDate from it). The
;    port keeps the identical double call;
;  - the C's string-literal concatenation for the two FactureX_* XMP blocks
;    becomes PB escaped strings (~"...") joined with + (the C's "FactureX"
;    spelling is the sample's, not FacturX - kept in comments only);
;  - argv[0] + ".pdf" output replaced with the stable filename
;    pdf_a_conformance.pdf.
;
; Build (from samples/):
;   MSYS2_ARG_CONV_EXCL='*' "$PUREBASIC_HOME/Compilers/pbcompilerc.exe" \
;     /CONSOLE /THREAD /EXE pdf_a_conformance.exe pdf_a_conformance.pb
; ---------------------------------------------------------------------------

EnableExplicit

XIncludeFile "../hpdf.pbi"

#TEXT1 = "This PDF should have an attachment named factur-x.xml"
#TEXT2 = "and should be PDF-A/3 compliant."

; Some hard coded PDF dates (the C's creation_date()/modification_date()).
Procedure FillCreationDate(*date.HPDFDate)
  *date\year = 2024
  *date\month = 1
  *date\day = 20
  *date\hour = 17
  *date\minutes = 10
  *date\seconds = 30
  *date\ind = Asc("+")
  *date\off_hour = 1
  *date\off_minutes = 0
EndProcedure

Procedure FillModificationDate(*date.HPDFDate)
  *date\year = 2024
  *date\month = 2
  *date\day = 5
  *date\hour = 11
  *date\minutes = 14
  *date\seconds = 45
  *date\ind = Asc("+")
  *date\off_hour = 1
  *date\off_minutes = 0
EndProcedure

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

; create default-font (embedded TTF, WinAnsiEncoding)
Define namePtr.i = HPDF_LoadTTFontFromFile(pdf, "ttfont/PenguinAttack.ttf", 1)
If namePtr = 0
  PrintN("FAIL font (LoadTTFontFromFile ttfont/PenguinAttack.ttf) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
Define fontName$ = PeekS(namePtr, -1, #PB_Ascii)
Define hfont.i = HaruGetFont(pdf, fontName$, "WinAnsiEncoding")
If hfont = 0
  PrintN("FAIL font (GetFont " + fontName$ + ") " + HaruErrorText(pdf))
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

HPDF_Page_SetSize(page, #HPDF_PAGE_SIZE_LETTER, #HPDF_PAGE_PORTRAIT)

HPDF_Page_BeginText(page)
HPDF_Page_SetFontAndSize(page, hfont, 20)
Define tw.f = HPDF_Page_TextWidth(page, #TEXT1)
HPDF_Page_MoveTextPos(page, (HPDF_Page_GetWidth(page) - tw) / 2, HPDF_Page_GetHeight(page) / 2)
HPDF_Page_ShowText(page, #TEXT1)
tw - HPDF_Page_TextWidth(page, #TEXT2)
HPDF_Page_MoveTextPos(page, tw / 2, -20)
HPDF_Page_ShowText(page, #TEXT2)
HPDF_Page_EndText(page)

; attach a file to the document, with some info
Define embeddedFile.i = HPDF_AttachFile(pdf, "pdf_a/factur-x.xml")
If embeddedFile = 0
  PrintN("FAIL attach (AttachFile pdf_a/factur-x.xml) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
HPDF_EmbeddedFile_SetAFRelationship(embeddedFile, #HPDF_AFRELATIONSHIP_DATA)
HPDF_EmbeddedFile_SetSize(embeddedFile, 17167)
HPDF_EmbeddedFile_SetName(embeddedFile, "factur-x.xml")
HPDF_EmbeddedFile_SetDescription(embeddedFile, "Factur-X invoice")
HPDF_EmbeddedFile_SetSubtype(embeddedFile, "text/xml")

; UPSTREAM QUIRK kept: the C sets the creation date and then overwrites the
; same attribute with the modification date (it never calls
; HPDF_EmbeddedFile_SetLastModificationDate)
Define aDate.HPDFDate
FillCreationDate(@aDate)
HPDF_EmbeddedFile_SetCreationDate(embeddedFile, @aDate)
FillModificationDate(@aDate)
HPDF_EmbeddedFile_SetCreationDate(embeddedFile, @aDate)

; some PDF info
HPDF_SetInfoAttr(pdf, #HPDF_INFO_TITLE, "PDF-A Title")
HPDF_SetInfoAttr(pdf, #HPDF_INFO_SUBJECT, "PDF-A Subject")
HPDF_SetInfoAttr(pdf, #HPDF_INFO_AUTHOR, "PDF-A Author")
HPDF_SetInfoAttr(pdf, #HPDF_INFO_CREATOR, "libharu")
FillCreationDate(@aDate)
HPDF_SetInfoDateAttr(pdf, #HPDF_INFO_CREATION_DATE, @aDate)
FillModificationDate(@aDate)
HPDF_SetInfoDateAttr(pdf, #HPDF_INFO_MOD_DATE, @aDate)

; PDF-A/3 conformance
HPDF_SetPDFAConformance(pdf, #HPDF_PDFA_3B)

; append outputintents
Define outputIntents.i = HPDF_LoadIccProfileFromFile(pdf, "pdf_a/device_rgb.icc", 3)
If outputIntents = 0
  PrintN("FAIL icc (LoadIccProfileFromFile pdf_a/device_rgb.icc) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
HPDF_AppendOutputIntents(pdf, "sRGB", outputIntents)

; XMP extensions (the C's FactureX_1 / FactureX_2, verbatim)
Define FactureX_1$ = ~"<rdf:Description xmlns:pdfaExtension=\"http://www.aiim.org/pdfa/ns/extension/\" xmlns:pdfaSchema=\"http://www.aiim.org/pdfa/ns/schema#\" xmlns:pdfaProperty=\"http://www.aiim.org/pdfa/ns/property#\" rdf:about=\"\">" +
  ~"  <pdfaExtension:schemas>" +
  ~"    <rdf:Bag>" +
  ~"      <rdf:li rdf:parseType=\"Resource\">" +
  ~"        <pdfaSchema:schema>Factur-X PDFA Extension Schema</pdfaSchema:schema>" +
  ~"        <pdfaSchema:namespaceURI>urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#</pdfaSchema:namespaceURI>" +
  ~"        <pdfaSchema:prefix>fx</pdfaSchema:prefix>" +
  ~"        <pdfaSchema:property>" +
  ~"          <rdf:Seq>" +
  ~"            <rdf:li rdf:parseType=\"Resource\">" +
  ~"              <pdfaProperty:name>DocumentFileName</pdfaProperty:name>" +
  ~"              <pdfaProperty:valueType>Text</pdfaProperty:valueType>" +
  ~"              <pdfaProperty:category>external</pdfaProperty:category>" +
  ~"              <pdfaProperty:description>The name of the embedded XML document</pdfaProperty:description>" +
  ~"            </rdf:li>" +
  ~"            <rdf:li rdf:parseType=\"Resource\">" +
  ~"              <pdfaProperty:name>DocumentType</pdfaProperty:name>" +
  ~"              <pdfaProperty:valueType>Text</pdfaProperty:valueType>" +
  ~"              <pdfaProperty:category>external</pdfaProperty:category>" +
  ~"              <pdfaProperty:description>The type of the hybrid document in capital letters, e.g. INVOICE or ORDER</pdfaProperty:description>" +
  ~"            </rdf:li>" +
  ~"            <rdf:li rdf:parseType=\"Resource\">" +
  ~"              <pdfaProperty:name>Version</pdfaProperty:name>" +
  ~"              <pdfaProperty:valueType>Text</pdfaProperty:valueType>" +
  ~"              <pdfaProperty:category>external</pdfaProperty:category>" +
  ~"              <pdfaProperty:description>The actual version of the standard applying to the embedded XML document</pdfaProperty:description>" +
  ~"            </rdf:li>" +
  ~"            <rdf:li rdf:parseType=\"Resource\">" +
  ~"              <pdfaProperty:name>ConformanceLevel</pdfaProperty:name>" +
  ~"              <pdfaProperty:valueType>Text</pdfaProperty:valueType>" +
  ~"              <pdfaProperty:category>external</pdfaProperty:category>" +
  ~"              <pdfaProperty:description>The conformance level of the embedded XML document</pdfaProperty:description>" +
  ~"            </rdf:li>" +
  ~"          </rdf:Seq>" +
  ~"        </pdfaSchema:property>" +
  ~"      </rdf:li>" +
  ~"    </rdf:Bag>" +
  ~"  </pdfaExtension:schemas>" +
  ~"</rdf:Description>"
Define FactureX_2$ = ~"<rdf:Description xmlns:fx=\"urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#\" rdf:about=\"\">" +
  ~"  <fx:DocumentType>INVOICE</fx:DocumentType>" +
  ~"  <fx:DocumentFileName>factur-x.xml</fx:DocumentFileName>" +
  ~"  <fx:Version>1.0</fx:Version>" +
  ~"  <fx:ConformanceLevel>EN 16931</fx:ConformanceLevel>" +
  ~"</rdf:Description>"
HPDF_AddPDFAXmpExtension(pdf, FactureX_1$)
HPDF_AddPDFAXmpExtension(pdf, FactureX_2$)

; --- gate + save ---------------------------------------------------------------
If HPDF_GetError(pdf) <> #HPDF_OK
  PrintN("FAIL draw (latched error) " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf

If HPDF_SaveToFile(pdf, "pdf_a_conformance.pdf") <> #HPDF_OK
  PrintN("FAIL save " + HaruErrorText(pdf))
  HaruFree(pdf)
  End 1
EndIf
HaruFree(pdf)
PrintN("PASS pdf_a_conformance -> pdf_a_conformance.pdf")

HaruShutdown()
CloseConsole()
End 0

; IDE Options = PureBasic 6.40 (Windows - x64)
; ExecutableFormat = Console
; EnableXP
; DPIAware
