#include <stdio.h>
typedef struct { void* data; int32_t w,h,fmt,stride; } sakum_img;
extern int img_bpp(int f);
extern int img_index(sakum_img* img,int x,int y);
extern int img_get_pixel32(sakum_img* img,int x,int y);
extern void img_set_pixel32(sakum_img* img,int x,int y,int rgba);
extern void img_fill(sakum_img* img,int rgba);
int main(void){
    static unsigned char buf[4*4*4];
    sakum_img img={buf,4,4,0,0};
    printf("bpp0=%d\n", img_bpp(0));
    printf("idx=%d\n", img_index(&img,1,2));
    img_fill(&img, 0x11223344);
    printf("px=%08X\n", img_get_pixel32(&img,0,0));
    printf("px12=%08X\n", img_get_pixel32(&img,1,2));
    return 0;
}
