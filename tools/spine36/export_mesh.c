/* TWILIGHT Spine 3.6 mesh sampler.
 * Uses the separately installed Spine C runtime. No SDK source is bundled.
 * Geometry enumeration follows the official spine-sfml rendering contract.
 * See SPINE_RUNTIME_LICENSE.txt and README.md for Esoteric notices and terms.
 */
#include <spine/spine.h>
#include <spine/extension.h>
#include <spine/SkeletonClipping.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include <locale.h>
#include <limits.h>

#define MAX_WORLD_FLOATS 1048576
#define MAX_FRAMES 18001
static int texture_errors = 0;
static const char *page_prefix = "UI/Spine/";
static unsigned long exported_batches = 0, exported_triangles = 0;
static unsigned long exported_mesh_batches = 0, exported_region_batches = 0;
static const char *skip_unreachable_paths[64];
static int skip_path_count = 0, skipped_unreachable = 0;
/* The Python driver proves these missing paths unreachable from setup,
 * declared animation attachments/deforms and linked-mesh parents. This uses
 * the SDK's documented return-NULL-without-error attachment skip contract. */
typedef struct AuditLoader { spAttachmentLoader super; spAtlas *atlas; spAttachmentLoader *delegate; } AuditLoader;
static spAttachment *audit_create(spAttachmentLoader *base, spSkin *skin, spAttachmentType type, const char *name, const char *path) {
    AuditLoader *self=(AuditLoader *)base;
    if((type==SP_ATTACHMENT_REGION || type==SP_ATTACHMENT_MESH || type==SP_ATTACHMENT_LINKED_MESH) && !spAtlas_findRegion(self->atlas,path)) {
        for(int i=0;i<skip_path_count;i++)if(!strcmp(path,skip_unreachable_paths[i])) { skipped_unreachable++; return NULL; }
    }
    spAttachment *attachment=spAttachmentLoader_createAttachment(self->delegate,skin,type,name,path);
    if(!attachment && self->delegate->error1)_spAttachmentLoader_setError(base,self->delegate->error1,self->delegate->error2?self->delegate->error2:"");
    return attachment;
}
static void audit_configure(spAttachmentLoader *base,spAttachment *attachment) { spAttachmentLoader_configureAttachment(((AuditLoader *)base)->delegate,attachment); }
static void audit_dispose_attachment(spAttachmentLoader *base,spAttachment *attachment) { spAttachmentLoader_disposeAttachment(((AuditLoader *)base)->delegate,attachment); }
static void audit_dispose(spAttachmentLoader *base) { spAttachmentLoader_dispose(((AuditLoader *)base)->delegate);_spAttachmentLoader_deinit(base); }
static spAttachmentLoader *audit_loader(spAtlas *atlas) {
    AuditLoader *self=(AuditLoader *)calloc(1,sizeof(AuditLoader));if(!self)return NULL;
    self->atlas=atlas;self->delegate=(spAttachmentLoader *)spAtlasAttachmentLoader_create(atlas);
    _spAttachmentLoader_init(&self->super,audit_dispose,audit_create,audit_configure,audit_dispose_attachment);return &self->super;
}


static void fail(const char *message) { fprintf(stderr, "SPINE36_EXPORT_ERROR %s\n", message); exit(2); }
static uint32_t be32(const unsigned char *p) { return ((uint32_t)p[0]<<24)|((uint32_t)p[1]<<16)|((uint32_t)p[2]<<8)|p[3]; }
void _spAtlasPage_createTexture(spAtlasPage *self, const char *path) {
    unsigned char head[24]; FILE *f=fopen(path,"rb");
    if (!f || fread(head,1,sizeof(head),f)!=sizeof(head)) { if(f)fclose(f); texture_errors++; return; }
    fclose(f);
    if (memcmp(head,"\x89PNG\r\n\x1a\n",8) || memcmp(head+12,"IHDR",4)) { texture_errors++; return; }
    int width=(int)be32(head+16), height=(int)be32(head+20);
    if (width<=0 || height<=0 || (self->width && self->width!=width) || (self->height && self->height!=height)) { texture_errors++; return; }
    self->width=width; self->height=height; self->rendererObject=NULL;
}
void _spAtlasPage_disposeTexture(spAtlasPage *self) { (void)self; }
char *_spUtil_readFile(const char *path, int *length) { return _spReadFile(path,length); }

static void string_value(const char *s) {
    const unsigned char *p=(const unsigned char *)(s?s:""); putchar('"');
    for(;*p;p++) {
        switch(*p) { case '"':fputs("\\\"",stdout);break;case '\\':fputs("\\\\",stdout);break;case '\n':fputs("\\n",stdout);break;case '\r':fputs("\\r",stdout);break;case '\t':fputs("\\t",stdout);break;
            default:if(*p<32)printf("\\u%04x",*p);else putchar(*p); }
    }
    putchar('"');
}
static void number(float v) { if(!isfinite(v))fail("non_finite_sdk_output"); if(v==0)v=0; printf("%.9g",(double)v); }
static void float_array(float *values,int count) { putchar('[');for(int i=0;i<count;i++){if(i)putchar(',');number(values[i]);}putchar(']'); }
static void color_value(float r,float g,float b,float a) { putchar('[');number(r);putchar(',');number(g);putchar(',');number(b);putchar(',');number(a);putchar(']'); }
static const char *blend_name(spBlendMode blend) {
    switch(blend) {case SP_BLEND_MODE_NORMAL:return "normal";case SP_BLEND_MODE_ADDITIVE:return "additive";case SP_BLEND_MODE_MULTIPLY:return "multiply";case SP_BLEND_MODE_SCREEN:return "screen";default:fail("unknown_blend_mode");}
    return "normal";
}

static void write_batches(spSkeleton *s,spSkeletonClipping *clipper,float **buffer,int *capacity) {
    int first=1;putchar('[');spSkeletonClipping_clipEnd2(clipper);
    for(int order=0;order<s->slotsCount;order++) {
        spSlot *slot=s->drawOrder[order];spAttachment *a=slot->attachment;
        if(!a) {spSkeletonClipping_clipEnd(clipper,slot);continue;}
        if(a->type==SP_ATTACHMENT_CLIPPING) {spSkeletonClipping_clipStart(clipper,slot,(spClippingAttachment *)a);continue;}
        if(a->type!=SP_ATTACHMENT_REGION && a->type!=SP_ATTACHMENT_MESH && a->type!=SP_ATTACHMENT_LINKED_MESH) {spSkeletonClipping_clipEnd(clipper,slot);continue;}
        float *uvs=NULL;unsigned short *indices=NULL;int index_count=0,world_count=0;spColor *ac=NULL;spAtlasRegion *region=NULL;
        unsigned short quad[6]={0,1,2,2,3,0};
        if(a->type==SP_ATTACHMENT_REGION) {
            spRegionAttachment *r=(spRegionAttachment *)a;world_count=8;uvs=r->uvs;indices=quad;index_count=6;ac=&r->color;region=(spAtlasRegion *)r->rendererObject;
        } else {
            spMeshAttachment *m=(spMeshAttachment *)a;world_count=m->super.worldVerticesLength;uvs=m->uvs;indices=m->triangles;index_count=m->trianglesCount;ac=&m->color;region=(spAtlasRegion *)m->rendererObject;
        }
        if(world_count<6 || world_count%2 || world_count>MAX_WORLD_FLOATS || index_count<3 || index_count%3 || !region || !region->page || !uvs || !indices)fail("invalid_attachment_geometry");
        float alpha=s->color.a*slot->color.a*ac->a;
        if(alpha<=0) {spSkeletonClipping_clipEnd(clipper,slot);continue;}
        if(world_count>*capacity) {float *grown=(float *)realloc(*buffer,(size_t)world_count*sizeof(float));if(!grown)fail("world_vertex_allocation");*buffer=grown;*capacity=world_count;}
        if(a->type==SP_ATTACHMENT_REGION)spRegionAttachment_computeWorldVertices((spRegionAttachment *)a,slot->bone,*buffer,0,2);
        else spVertexAttachment_computeWorldVertices((spVertexAttachment *)a,slot,0,world_count,*buffer,0,2);
        float *vertices=*buffer;
        if(spSkeletonClipping_isClipping(clipper)) {
            spSkeletonClipping_clipTriangles(clipper,vertices,world_count,indices,index_count,uvs,2);
            vertices=clipper->clippedVertices->items;world_count=clipper->clippedVertices->size;
            uvs=clipper->clippedUVs->items;indices=clipper->clippedTriangles->items;index_count=clipper->clippedTriangles->size;
        }
        if(index_count) {
            if(world_count<6 || world_count%2 || index_count%3)fail("invalid_clipped_geometry");
            for(int i=0;i<index_count;i++)if(indices[i]>=world_count/2)fail("triangle_out_of_range");
            if(!first)putchar(',');
            first=0;
            fputs("{\"page\":",stdout);char page[4096];
            if(snprintf(page,sizeof(page),"%s%s",page_prefix,region->page->name)>=(int)sizeof(page))fail("page_path_too_long");
            string_value(page);
            fputs(",\"slot\":",stdout);string_value(slot->data->name);fputs(",\"attachment\":",stdout);string_value(a->name);
            fputs(",\"blend\":",stdout);string_value(blend_name(slot->data->blendMode));
            fputs(",\"color\":",stdout);color_value(s->color.r*slot->color.r*ac->r,s->color.g*slot->color.g*ac->g,s->color.b*slot->color.b*ac->b,alpha);
            if(slot->darkColor) {
                fputs(",\"dark_color\":",stdout);
                color_value(s->color.r*ac->r*slot->darkColor->r,s->color.g*ac->g*slot->darkColor->g,s->color.b*ac->b*slot->darkColor->b,0); /* Dark A is the shader PMA flag, not the SDK -1 sentinel for six-digit RGB. */
            }
            fputs(",\"positions\":",stdout);float_array(vertices,world_count);fputs(",\"uvs\":",stdout);float_array(uvs,world_count);
            fputs(",\"indices\":[",stdout);for(int i=0;i<index_count;i++){if(i)putchar(',');printf("%u",indices[i]);}fputs("]}",stdout);
            exported_batches++;exported_triangles+=(unsigned long)(index_count/3);
            if(a->type==SP_ATTACHMENT_REGION)exported_region_batches++;else exported_mesh_batches++;
        }
        spSkeletonClipping_clipEnd(clipper,slot);
    }
    spSkeletonClipping_clipEnd2(clipper);putchar(']');
}
static void apply_time(spSkeleton *s,spAnimationState *state,float dt) {spSkeleton_update(s,dt);spAnimationState_update(state,dt);spAnimationState_apply(state,s);spSkeleton_updateWorldTransform(s);}

int main(int argc,char **argv) {
    const char *json_path=NULL,*atlas_path=NULL,*only_clip=NULL;int fps=60;
    for(int i=1;i<argc;i++) {
        if(!strcmp(argv[i],"--json") && i+1<argc)json_path=argv[++i];else if(!strcmp(argv[i],"--atlas") && i+1<argc)atlas_path=argv[++i];
        else if(!strcmp(argv[i],"--page-prefix") && i+1<argc)page_prefix=argv[++i];else if(!strcmp(argv[i],"--fps") && i+1<argc)fps=atoi(argv[++i]);
        else if(!strcmp(argv[i],"--clip") && i+1<argc)only_clip=argv[++i];
        else if(!strcmp(argv[i],"--skip-unreachable-path") && i+1<argc && skip_path_count<64)skip_unreachable_paths[skip_path_count++]=argv[++i];else fail("usage: --json FILE --atlas FILE [--page-prefix UI/Spine/] [--fps 60] [--clip exact_name]");
    }
    if(!json_path || !atlas_path || fps<1 || fps>120)fail("invalid_arguments");
    setlocale(LC_NUMERIC,"C");setvbuf(stdout,NULL,_IOFBF,1048576);spBone_setYDown(1);
    spAtlas *atlas=spAtlas_createFromFile(atlas_path,NULL);if(!atlas || texture_errors)fail("atlas_or_original_png_dimensions");
    spAttachmentLoader *loader=audit_loader(atlas);if(!loader)fail("attachment_loader_allocation");
    spSkeletonJson *reader=spSkeletonJson_createWithLoader(loader);if(!reader)fail("json_reader_allocation");
    spSkeletonData *data=spSkeletonJson_readSkeletonDataFile(reader,json_path);if(!data){fprintf(stderr,"SPINE36_EXPORT_ERROR skeleton_json: %s\n",reader->error?reader->error:"unknown");return 2;}
    if(!data->version || strncmp(data->version,"3.6.",4))fail("source_version_not_3_6");
    if(only_clip && !spSkeletonData_findAnimation(data,only_clip))fail("source_clip_not_found");
    float *world=NULL;int capacity=0;spSkeletonClipping *clipper=spSkeletonClipping_create();
    spSkeleton *s=spSkeleton_create(data);spSkeleton_setToSetupPose(s);spSkeleton_updateWorldTransform(s);
    fputs("{\"schema\":\"twilight.spine36.mesh.v1\",\"coordinate_space\":\"godot_y_down\",\"premultiplied_alpha\":false,\"source\":{\"spine_version\":",stdout);string_value(data->version);fputs("},\"setup\":{\"batches\":",stdout);write_batches(s,clipper,&world,&capacity);putchar('}');spSkeleton_dispose(s);
    fputs(",\"clips\":{",stdout);int first_clip=1,clips=0;unsigned long frames=0;
    for(int index=0;index<data->animationsCount;index++) {
        spAnimation *animation=data->animations[index];if(only_clip && strcmp(only_clip,animation->name))continue;
        if(!isfinite(animation->duration)||animation->duration<0 || animation->duration>300)fail("invalid_source_duration");
        int count=(int)ceil((double)animation->duration*fps)+1;if(count<1 || count>MAX_FRAMES)fail("frame_limit");
        s=spSkeleton_create(data);spAnimationStateData *state_data=spAnimationStateData_create(data);spAnimationState *state=spAnimationState_create(state_data);
        spSkeleton_setToSetupPose(s);if(!spAnimationState_setAnimation(state,0,animation,0))fail("set_source_animation");
        if(!first_clip)putchar(',');
        first_clip=0;string_value(animation->name);fputs(":{\"duration\":",stdout);number(animation->duration);printf(",\"fps\":%d,\"frames\":[",fps);
        float previous=0;int emitted=0;
        for(int frame=0;frame<count;frame++) {
            float time=frame==count-1?animation->duration:(float)((double)frame/fps);if(time>animation->duration)time=animation->duration;
            /* A rounded float32 grid point can already equal duration. Emit that
             * endpoint once, and never evaluate a duplicate zero-delta pose. */
            if(emitted && time<=previous)continue;
            apply_time(s,state,time-previous);previous=time;
            if(emitted)putchar(',');
            emitted++;
            fputs("{\"time\":",stdout);number(time);fputs(",\"batches\":",stdout);
            write_batches(s,clipper,&world,&capacity);putchar('}');frames++;
        }
        fputs("]}",stdout);spAnimationState_dispose(state);spAnimationStateData_dispose(state_data);spSkeleton_dispose(s);clips++;
    }
    fputs("}}\n",stdout);fflush(stdout);
    fprintf(stderr,"SPINE36_EXPORT_RESULT clips=%d frames=%lu batches=%lu triangles=%lu mesh_batches=%lu region_batches=%lu bones=%d slots=%d ik=%d transform=%d path=%d skipped_unreferenced=%d\n",clips,frames,exported_batches,exported_triangles,exported_mesh_batches,exported_region_batches,data->bonesCount,data->slotsCount,data->ikConstraintsCount,data->transformConstraintsCount,data->pathConstraintsCount,skipped_unreachable);
    free(world);spSkeletonClipping_dispose(clipper);spSkeletonData_dispose(data);spSkeletonJson_dispose(reader);spAttachmentLoader_dispose(loader);spAtlas_dispose(atlas);return ferror(stdout)?3:0;
}
