#include <stdio.h>
typedef struct { void* data; int32_t w,h,fmt,stride; } sakum_img;
typedef struct { int32_t x0,y0,x1,y1; } sakum_sel;
typedef struct { int32_t ix,iy,ux0,uy0,ux1,uy1; } sakum_it;
extern void sel_make(int x0,int y0,int x1,int y1,sakum_sel* o);
extern void sel_clamp(sakum_sel* s,sakum_img* img);
extern void sel_iter_init(sakum_sel* s,sakum_it* it);
extern int  sel_iter_next(sakum_it* it,int* x,int* y);
int main(void){
    sakum_sel sel; sel_make(1,1,3,3,&sel);
    printf("sel=%d,%d,%d,%d\n", sel.x0,sel.y0,sel.x1,sel.y1);
    static unsigned char b[64]; sakum_img img={b,4,4,0,0};
    sel_clamp(&sel,&img);
    sakum_it it; sel_iter_init(&sel,&it);
    int cnt=0,x,y;
    while(sel_iter_next(&it,&x,&y)) cnt++;
    printf("cnt=%d\n", cnt);
    return cnt;
}
