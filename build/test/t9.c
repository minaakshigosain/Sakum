#include <stdio.h>
#include <stdint.h>
typedef struct { void* data; int32_t w,h,fmt,stride; } sakum_img;
extern int img_index(sakum_img* img,int x,int y);
int main(void){
    static uint8_t gbuf[16];
    sakum_img gimg = { gbuf, 4,4, 2, 0 };
    for(int y=0;y<4;y++){ for(int x=0;x<4;x++) printf("%3d", img_index(&gimg,x,y)); printf("\n"); }
    return 0;
}
