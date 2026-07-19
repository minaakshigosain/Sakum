#include <stdio.h>
typedef struct { void* data; int32_t w,h,fmt,stride; } sakum_img;
extern int img_index(sakum_img* img,int x,int y);
int main(void){
    static unsigned char buf[4*4*4];
    sakum_img img={buf,4,4,0,0};
    int r = img_index(&img,1,2);
    printf("r=%d\n", r);
    return r;
}
