#include <stdio.h>
#include <stdint.h>
#include <string.h>
typedef struct { void* data; int32_t w,h,fmt,stride; } sakum_img;
extern void img_fill(sakum_img* img,int rgba);
extern void img_convert(sakum_img* d,sakum_img* s);
extern int  img_get_pixel32(sakum_img* img,int x,int y);
int main(void){
    static uint8_t buf[4*4*4];
    sakum_img img = { buf, 4,4, 0, 0 };
    img_fill(&img, 0x80FF0000u);
    static uint8_t gbuf[4*4];
    sakum_img gimg = { gbuf, 4,4, 2, 0 };
    printf("before convert px(0,0)=%08X\n", img_get_pixel32(&img,0,0));
    img_convert(&gimg,&img);
    printf("after convert g(0,0)=%d g(3,3)=%d\n", gbuf[0], gbuf[3*4+3]);
    return 0;
}
