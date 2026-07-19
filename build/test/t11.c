#include <stdio.h>
#include <stdint.h>
typedef struct { void* data; int32_t w,h,fmt,stride; } sakum_img;
extern void img_fill(sakum_img* img,int rgba);
extern void img_editor_invert(sakum_img* img);
extern int  img_get_pixel32(sakum_img* img,int x,int y);
int main(void){
    static uint8_t buf[4*4*4];
    sakum_img img = { buf, 4,4, 0, 0 };
    img_fill(&img, 0xFFFFFFFFu);
    img_editor_invert(&img);
    printf("px(0,0)=%08X (want 00000000)\n", (unsigned)img_get_pixel32(&img,0,0));
    printf("px(2,3)=%08X (want 00000000)\n", (unsigned)img_get_pixel32(&img,2,3));
    return 0;
}
