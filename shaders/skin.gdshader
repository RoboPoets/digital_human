shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, sss_mode_skin;

group_uniforms color;
uniform float hue: hint_range(-0.02, 0.02) = 0.0;
uniform float brightness: hint_range(0.5, 1.5) = 1.0;

group_uniforms normals;
uniform float normal_depth: hint_range(0.0, 1.0) = 0.7;

group_uniforms roughness;
uniform float base_specularity: hint_range(0.2, 0.7, 0.01) = 0.35;
uniform float base_roughness: hint_range(0.0, 1.0) = 0.3;
uniform float edge_roughness: hint_range(0.0, 1.0) = 0.1;
uniform float spec_roughness_min: hint_range(0.5, 1.5) = 0.95;
uniform float spec_roughness_max: hint_range(0.5, 1.5) = 1.05;

group_uniforms subsurface_scattering;
uniform float sss_strength : hint_range(0.0, 1.0) = 1.0;
uniform float transmission_boost : hint_range(0.0, 1.0) = 0.0;
uniform float transmission_depth = 2.0;

group_uniforms tattoos;
uniform float tattoo_opacity : hint_range(0.0, 1.0) = 1.0;
uniform float tattoo_fade : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tattoo_tint : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform sampler2D tattoo_texture : source_color, hint_default_transparent, filter_linear_mipmap, repeat_disable;

group_uniforms makeup;
uniform float makeup_normal_blend_weight: hint_range(0.0, 1.0) = 0.5;
uniform sampler2D makeup_albedo_texture : source_color, hint_default_transparent, filter_linear_mipmap, repeat_disable;
uniform sampler2D makeup_orm_texture : hint_roughness_g, filter_linear_mipmap, repeat_disable;
uniform sampler2D makeup_normal_texture : hint_roughness_normal, filter_linear_mipmap, repeat_disable;

group_uniforms textures;
uniform sampler2D diffuse_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D roughness_texture : hint_roughness_r, filter_linear_mipmap, repeat_disable;
uniform sampler2D specular_texture : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform sampler2D normal_texture : hint_roughness_normal, filter_linear_mipmap, repeat_disable;
uniform sampler2D sss_texture : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform sampler2D transmission_texture : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform sampler2D ao_texture : hint_default_white, filter_linear_mipmap, repeat_disable;

/*
 * We use fresnel for various effects on the skin to tweak attributes at the
 * edges of the mesh and improve realism. Examples are simulating cheap peach
 * fuzz and reducing specular artifacts, especially around the lips and eyes.
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
	vec3 u = color - p;
	vec3 v = cross(vec3(0.55735), u);
	color = u * cos(shift * 6.2832) + v * sin(shift * 6.2832) + p;
	return color;
}

void fragment() {
	vec3 albedo = texture(diffuse_texture, UV).rgb;
	ALBEDO = shift_hue(albedo, hue) * brightness;

	vec4 tattoo = texture(tattoo_texture, UV);
	vec4 tattoo_faded = textureLod(tattoo_texture, UV, 3.0);
	tattoo = mix(tattoo, tattoo_faded, tattoo_fade);
	tattoo.rgb = mix(tattoo.rgb, tattoo_tint.rgb, tattoo_tint.a);
	tattoo.a *= tattoo_opacity;
	ALBEDO = mix(ALBEDO, tattoo.rgb, tattoo.a);

	ALBEDO += fresnel(8.0, NORMAL, VIEW) * edge_roughness;

	// Apply makeup after fresnel because we expect most
	// types of face paint to cover and thus negate peach fuzz.
	vec4 makeup = texture(makeup_albedo_texture, UV);
	ALBEDO = mix(ALBEDO, makeup.rgb, makeup.a);

	vec3 makeup_orm = texture(makeup_orm_texture, UV).rgb;
	AO = texture(ao_texture, UV).r;
	AO = mix(AO, makeup_orm.r, makeup.a);

	float spec_tex = texture(specular_texture, UV).r;
	ROUGHNESS = texture(roughness_texture, UV).r + base_roughness;
	ROUGHNESS *= mix(spec_roughness_min, spec_roughness_max, spec_tex);
	ROUGHNESS += fresnel(3.0, NORMAL, VIEW) * edge_roughness;

	// Same as for albedo, apply makeup after fresnel.
	ROUGHNESS = mix(ROUGHNESS, makeup_orm.g, makeup.a);
	METALLIC = mix(METALLIC, makeup_orm.b, makeup.a);

	float specular = mix(0.15, 1.0, pow(spec_tex, 0.65));
	specular = mix(specular, pow(specular, 0.5), fresnel(5.0, NORMAL, VIEW));
	SPECULAR = base_specularity * specular;
	NORMAL_MAP_DEPTH = normal_depth;
	NORMAL_MAP = texture(normal_texture, UV).rgb;

	vec3 makeup_normal = texture(makeup_normal_texture, UV).rgb;
	NORMAL_MAP = mix(NORMAL_MAP, makeup_normal, makeup.a * makeup_normal_blend_weight);

	SSS_STRENGTH = texture(sss_texture, UV).r * sss_strength * (1.0 - makeup.a);
	SSS_TRANSMITTANCE_DEPTH = transmission_depth * texture(transmission_texture, UV).r;
	SSS_TRANSMITTANCE_BOOST = transmission_boost;
	SSS_TRANSMITTANCE_COLOR = vec4(ALBEDO, 1.0);
}
