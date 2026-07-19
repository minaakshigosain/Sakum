#include <stdio.h>
extern int img_bpp(int f);
extern int img_get_pixel32(void* img,int x,int y);
int main(void){ printf("bpp=%d\n", img_bpp(0)); return 0; }
