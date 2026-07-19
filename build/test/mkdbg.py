src=open("build/test/imgtest.c").read()
stages=["img_fill","img_set_pixel32","img_convert","sel_make","sel_clamp",
        "sel_iter_init","sel_iter_next","img_sample_at","img_align_fix",
        "img_fix_next_pixel","img_editor_invert","img_editor_grayscale",
        "img_reader_load_raw","img_get_pixel32","img_copy"]
out=[]
for ln in src.split("\n"):
    for s in stages:
        if (s in ln) and ("printf" not in ln) and ("extern" not in ln) and ("CHECK" not in ln) and ("->" not in ln):
            out.append('    fprintf(stderr,"STAGE:%s\\n");' % s)
            break
    out.append(ln)
open("build/test/imgtest_dbg.c","w").write("\n".join(out))
print("ok")
