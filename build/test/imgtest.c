#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct { void* data; int32_t w,h,fmt,stride; } sakum_img;
typedef struct { int32_t x0,y0,x1,y1; } sakum_sel;
typedef struct { int32_t ix,iy,ux0,uy0,ux1,uy1; } sakum_it;

extern int  img_bpp(int fmt);
extern int  img_index(sakum_img* img,int x,int y);
extern int  img_get_pixel32(sakum_img* img,int x,int y);
extern void img_set_pixel32(sakum_img* img,int x,int y,int rgba);
extern void img_fill(sakum_img* img,int rgba);
extern void img_copy(sakum_img* d,sakum_img* s);
extern void sel_make(int x0,int y0,int x1,int y1,sakum_sel* o);
extern void sel_clamp(sakum_sel* s,sakum_img* img);
extern void sel_iter_init(sakum_sel* s,sakum_it* it);
extern int  sel_iter_next(sakum_it* it,int* x,int* y);
extern int  img_sample_at(sakum_img* img,int x,int y);
extern void img_align_fix(sakum_img* img,sakum_sel* sel,int anchor);
extern void img_fix_next_pixel(sakum_img* img,int x,int y,int ref);
extern void img_convert(sakum_img* d,sakum_img* s);
extern void img_editor_invert(sakum_img* img);
extern void img_editor_grayscale(sakum_img* img);
extern int  img_reader_load_raw(void* buf,int len,int w,int h,int fmt,sakum_img* o);

static int fails=0;
#define CHECK(c,msg) do{ if(!(c)){ printf("FAIL: %s\n",msg); fails++; } }while(0)

int main(void){
    static uint8_t buf[4*4*4];
    sakum_img img = { buf, 4,4, 0, 0 };
    CHECK(img_bpp(0)==4 && img_bpp(1)==3 && img_bpp(2)==1 && img_bpp(3)==3 && img_bpp(4)==4, "bpp");
    CHECK(img_index(&img,1,2)==(2*4+1)*4, "index");

    img_fill(&img, 0x80FF0000u);
    for(int y=0;y<4;y++) for(int x=0;x<4;x++)
        CHECK(img_get_pixel32(&img,x,y)==(int)0x80FF0000u, "fill/get");

    img_set_pixel32(&img,2,3,0xFFFFFFFFu);
    CHECK(img_get_pixel32(&img,2,3)==(int)0xFFFFFFFFu, "set/get32");

    static uint8_t gbuf[4*4];
    sakum_img gimg = { gbuf, 4,4, 2, 0 };
    img_convert(&gimg,&img);
    CHECK(gbuf[0]==28, "convert gray");
    CHECK(gbuf[3*4+2]==255, "convert gray white");

    sakum_img back = { buf, 4,4, 0, 0 };
    img_convert(&back,&gimg);
    CHECK(img_get_pixel32(&back,0,0)==(int)0xFF1C1C1Cu, "gray->rgba roundtrip");

    sakum_sel sel; sel_make(1,1,3,3,&sel);
    CHECK(sel.x0==1&&sel.y0==1&&sel.x1==3&&sel.y1==3,"sel_make");
    sel_clamp(&sel,&img);
    sakum_it it; sel_iter_init(&sel,&it);
    int cnt=0,x,y;
    while(sel_iter_next(&it,&x,&y)) cnt++;
    CHECK(cnt==9,"sel_iter count==9");

    int anchor = img_sample_at(&img,1,1);
    void* save = malloc(4*4*4);
    memcpy(save, buf, 4*4*4);
    img_align_fix(&img,&sel,0x00FFFFFFu);
    CHECK(img_get_pixel32(&img,1,1)==(int)0x00FFFFFFu, "align_fix first pixel == anchor");
    memcpy(buf,save,4*4*4); free(save);

    img_set_pixel32(&img,0,0,0x0000FF00u);
    int before = img_get_pixel32(&img,1,0);
    img_fix_next_pixel(&img,0,0,0x0000FF00u);
    int after = img_get_pixel32(&img,1,0);
    CHECK((after & 0x0000FF00u) > (before & 0x0000FF00u), "fix_next_pixel blends neighbour toward green");

    sakum_img inv = { buf, 4,4, 0, 0 };
    img_fill(&inv, 0xFFFFFFFFu);
    img_editor_invert(&inv);
    CHECK(img_get_pixel32(&inv,0,0)==(int)0x00000000u, "invert white->black");

    sakum_img gs = { buf, 4,4, 0, 0 };
    img_fill(&gs, 0xFFFFFFFFu);
    img_editor_grayscale(&gs);
    CHECK(img_get_pixel32(&gs,0,0)==(int)0xFFFFFFFFu, "grayscale white->white");

    static uint8_t raw[2*2*4];
    memset(raw, 0xAB, sizeof raw);
    sakum_img rimg; int rc=img_reader_load_raw(raw,sizeof raw,2,2,0,&rimg);
    CHECK(rc==0, "reader ok");
    CHECK(img_get_pixel32(&rimg,0,0)==(int)0xABABABABu, "reader pixel");
    int rc2=img_reader_load_raw(raw,3,2,2,0,&rimg);
    CHECK(rc2==-1, "reader undersize -> -1");

    if(fails==0) printf("ALL IMAGE LIB TESTS PASSED\n");
    else printf("%d FAILURES\n", fails);
    return fails?1:0;
}
