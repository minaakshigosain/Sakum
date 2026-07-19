int img_bpp(int f);
int img_index(void* i,int x,int y);
int ga, gb;
int main(void){ ga = img_bpp(0); gb = img_index((void*)0x100,1,2); return ga+gb; }
