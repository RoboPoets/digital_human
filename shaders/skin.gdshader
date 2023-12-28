shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx,sss_mode_skin;

group_uniforms skin;
uniform float hue: hint_range(-0.02, 0.02) = 0.0;
uniform float brightness: hint_range(0.5, 1.5) = 1.0;
uniform float specularity: hint_range(0.2, 0.7, 0.01) = 0.35;
uniform float normal_depth: hint_range(0.0, 1.0) = 0.7;

group_uniforms subsurface_scattering;
uniform float sss_strength : hint_range(0.0, 1.0) = 1.0;
uniform float transmission_boost : hint_range(0.0, 1.0) = 0.0;
uniform float transmission_depth = 2.0;

group_uniforms textures;
uniform sampler2D diffuse_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D roughness_texture : hint_roughness_r, filter_linear_mipmap, repeat_disable;
uniform sampler2D specular_texture : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform sampler2D normal_texture :  hint_normal, filter_linear_mipmap, repeat_disable;
uniform sampler2D sss_texture : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform sampler2D transmission_texture : hint_default_white, filter_linear_mipmap, repeat_disable;

/*
 * We use fresnel on the skin to limit the specularity at the edges of the
 * mesh. This can reduce specular artifacts and improve realism, noticeable
 * especially around the lips and eyes.
 */
float fresnel(float exponent, vec3 normal, vec3 view)
{
	return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0)), exponent);
}

/*
 * Algorithm adapted from https://www.shadertoy.com/view/XljGzV. We use
 * this to allow subtle shifts in skin color. The amount of hue shifting
 * is limited to stay within realistic skin tones; larger changes can be
 * achieved by replacing the base albedo texture and working from there.
 */
vec3 shift_hue(vec3 color, float shift) {
	vec3 p = vec3(0.55735) * dot(vec3(0.55735), color);
	vec3 u = color-p;
	vec3 v = cross(vec3(0.55735), u);
	color = u * cos(shift * 6.2832) + v * sin(shift * 6.2832) + p;
	return color;
}

void fragment() {
	vec3 albedo = texture(diffuse_texture,UV).rgb;
	ALBEDO = shift_hue(albedo, hue) * brightness;
	ROUGHNESS = texture(roughness_texture,UV).r * 0.6;

	float specular = mix(0.15, 1.0, pow(texture(specular_texture,UV).r, 0.65));
	specular = mix(specular, pow(specular, 0.5), fresnel(5.0, NORMAL, VIEW));
	SPECULAR = specularity * specular;
	NORMAL_MAP = texture(normal_texture,UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth;

	SSS_STRENGTH= texture(sss_texture,UV).r * sss_strength;
	SSS_TRANSMITTANCE_DEPTH=transmission_depth*texture(transmission_texture,UV).r;
	SSS_TRANSMITTANCE_BOOST=transmission_boost;
	SSS_TRANSMITTANCE_COLOR=vec4(ALBEDO, 1.0);
}
