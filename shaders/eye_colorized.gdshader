shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#define USE_COLOR_MASK 1
#define USE_REFRACTION 1
#define USE_POM 1
#define USE_SSS 1

#include "eye.gdshaderinc"
