#include <stdio.h>
#include <stdint.h>
typedef struct { void* data; int32_t w,h,fmt,stride; } sakum_img;
extern void img_fill(sakum_img* img,int rgba);
extern void img_set_pixel32(sakum_img* img,int x,int y,int rgba);
extern void img_get_pixel32(sakum_img* img,int x,int y);
extern void img_convert(sakum_img* d,sakum_img* s);
int main(void){
    static uint8_t buf[4*4*4];
    sakum_img img = { buf, 4,4, 0, 0 };
    img_fill(&img, 0x80FF0000u);
    img_set_pixel32(&img,2,3,0xFFFFFFFFu);
    static uint8_t gbuf[4*4];
    sakum_img gimg = { gbuf, 4,4, 2, 0 };
    img_convert(&gimg,&img);
    for(int i=0;i<16;i++) printf("%3d", gbuf[i]); printf("\n");
    return 0;
}
