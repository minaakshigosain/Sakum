#include <stdio.h>
typedef struct { void* d; int w,h,f,s; } I;
extern int img_index(I* i,int x,int y);
int main(void){ static char b[64]; I i={b,4,4,0,0}; printf("idx=%d\n", img_index(&i,1,2)); return 0; }
