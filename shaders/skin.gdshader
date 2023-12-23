shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx,sss_mode_skin;

group_uniforms skin;
uniform vec3 skin_color: source_color;

group_uniforms subsurface_scattering;
uniform float sss_strength : hint_range(0, 1) = 1;

group_uniforms textures;
uniform sampler2D roughness_texture : hint_roughness_r, filter_linear_mipmap, repeat_disable;
uniform sampler2D specular_texture : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform sampler2D normal_texture :  hint_normal, filter_linear_mipmap, repeat_disable;
uniform sampler2D sss_texture : hint_default_white, filter_linear_mipmap, repeat_disable;

const float specular = 0.35;

void fragment() {
	ALBEDO = skin_color;
	ROUGHNESS = texture(roughness_texture,UV).r;
	SPECULAR = specular;
	NORMAL_MAP = texture(normal_texture,UV).rgb;
	NORMAL_MAP_DEPTH = 1.0;
	SSS_STRENGTH= texture(sss_texture,UV).r * sss_strength;
}
