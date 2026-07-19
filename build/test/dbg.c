#include <stdio.h>
typedef struct { void* data; int32_t w,h,fmt,stride; } sakum_img;
extern long probe(sakum_img* img);
int main(void){
    static unsigned char buf[4*4*4];
    sakum_img img={buf,4,4,0,0};
    printf("img.data=%p probe=%p\n", (void*)img.data, (void*)probe(&img));
    return 0;
}
