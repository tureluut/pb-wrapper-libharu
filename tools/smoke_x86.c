/* smoke_x86.c - C-ABI smoke test for the 32-bit libhpdf.so.
 *
 * Compiled and run by tools/verify_x86_all.sh (WSL):
 *     gcc -m32 smoke_x86.c -I<checkout> -L<build32> -lhpdf ...
 *
 * Produces /tmp/m32out.pdf containing one line of text and a 32x32 PNG
 * image (samples/pngsuite/basn3p08.png). The verifier greps the PDF for:
 *   %PDF- header, a /FlateDecode stream (the embedded PNG), the text,
 *   /Width 32 /Height 32, and the %%EOF marker.
 *
 * Exit code 0 = smoke passed.
 */

#include <stdio.h>
#include <stdlib.h>
#include "hpdf.h"

#define PNG32 "/mnt/c/docs/DONE/pb-wrapper-libharu/samples/pngsuite/basn3p08.png"
#define TTF   "/mnt/c/docs/DONE/pb-wrapper-libharu/samples/ttfont/PenguinAttack.ttf"
#define OUT   "/tmp/m32out.pdf"

static void err_cb(HPDF_STATUS error_no, HPDF_STATUS detail_no, void *user_data)
{
    (void)user_data;
    printf("ERROR: error_no=%04X detail_no=%04X\n",
           (HPDF_UINT)error_no, (HPDF_UINT)detail_no);
    exit(1);
}

int main(void)
{
    HPDF_Doc  pdf;
    HPDF_Page page;
    HPDF_Font font;
    HPDF_Image img;

    pdf = HPDF_New(err_cb, NULL);
    if (!pdf) {
        printf("ERROR: HPDF_New failed\n");
        return 1;
    }

    /* compress image streams only -> /Filter /FlateDecode, while the page
       content stream stays plain so the verifier can grep the text */
    HPDF_SetCompressionMode(pdf, HPDF_COMP_IMAGE);

    page = HPDF_AddPage(pdf);
    HPDF_Page_SetSize(page, HPDF_PAGE_SIZE_A4, HPDF_PAGE_PORTRAIT);

    const char *fname = HPDF_LoadTTFontFromFile(pdf, TTF, HPDF_TRUE);
    if (!fname) {
        printf("ERROR: TTF load failed\n");
        return 1;
    }
    font = HPDF_GetFont(pdf, fname, NULL);
    HPDF_Page_BeginText(page);
    HPDF_Page_SetFontAndSize(page, font, 18);
    HPDF_Page_TextOut(page, 60, 780, "Hello from 32-bit");
    HPDF_Page_EndText(page);

    img = HPDF_LoadPngImageFromFile(pdf, PNG32);
    if (!img) {
        printf("ERROR: PNG load failed\n");
        return 1;
    }
    HPDF_Page_DrawImage(page, img, 60, 600, 128, 128);

    if (HPDF_SaveToFile(pdf, OUT) != HPDF_OK) {
        printf("ERROR: SaveToFile failed\n");
        return 1;
    }

    HPDF_Free(pdf);
    printf("smoke_x86: wrote %s\n", OUT);
    return 0;
}
