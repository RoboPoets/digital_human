shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

group_uniforms textures;
uniform sampler2D eye_tangents : repeat_disable, filter_linear_mipmap;
uniform sampler2D iris_displacement : repeat_disable;
uniform sampler2D iris_color : repeat_disable, filter_linear_mipmap, source_color, hint_default_black;
uniform sampler2D sclera_color : repeat_disable, filter_linear_mipmap, source_color, hint_default_white;
uniform sampler2D normal_map : repeat_disable, filter_linear_mipmap, hint_normal;

group_uniforms iris;
uniform float refraction_strength : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float iris_depth_scale : hint_range(0.0, 4.0, 0.01) = 1.2;
uniform float iris_uv_radius : hint_range(0.1, 0.2, 0.01) = 0.15;
uniform float iris_brightness : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float iris_roughness : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform float iris_specular : hint_range(0.0, 1.0, 0.01) = 0.4;

group_uniforms limbus;
uniform float limbus_uv_width : hint_range(0.02, 0.05, 0.001) = 0.035;
uniform float limbus_darkness : hint_range(2.0, 2.5, 0.01) = 2.1;
uniform float limbus_power : hint_range(4.0, 24.0, 0.1) = 8.0;

group_uniforms pupil;
uniform float pupil_scale : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float pupil_scale_x : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float pupil_scale_y : hint_range(0.0, 2.0, 0.01) = 1.0;

group_uniforms sclera;
uniform float sclera_brightness : hint_range(0.0, 2.0, 0.01) = 0.9;
uniform float sclera_roughness : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform float sclera_specular : hint_range(0.0, 1.0, 0.01) = 0.4;
uniform vec3 eye_shadow_color : source_color = vec3(0.52, 0.32, 0.2);
uniform float eye_shadow_radius : hint_range(0.0, 1.0, 0.01) = 0.45;
uniform float eye_shadow_hardness : hint_range(0.0, 1.0, 0.01) = 0.55;

/*
 * This currently behaves the same as the built-in refract() function.
 * It's spelled out here in case we want to implement future changes
 * to the refraction algorithm.
 */
vec3 refraction(vec3 incidence_vector, vec3 surface_normal) {
	float dot_view = dot(-surface_normal, incidence_vector);
	const float ior = 1.0 / 1.33;
	return ior * incidence_vector + (ior * dot_view - sqrt(1.0 - pow(ior, 2) * (1.0 - pow(dot_view, 2)))) * surface_normal;
}

/*
 * Helper function to keep UVs centered while scaling.
 */
vec2 scale_uv_from_center(vec2 uv, float scale) {
	vec2 scale_vector = vec2(scale);
	return (uv / scale_vector + 0.5) - (0.5 / scale_vector);
}

/*
 * Scale the pupil. A scale value of 1.0 matches the original texture.
 */
vec2 scale_pupils(vec2 uv, vec2 scale) {
	vec2 uv_centered = uv - 0.5;
	float uv_length = length(uv_centered);
	vec2 uv_max = normalize(uv_centered) * 0.5;
	vec2 uv_scaled = mix(uv_max, vec2(0.0), clamp((1.0 - uv_length * 2.0) * scale, 0.0, 1.0));
	return uv_scaled + 0.5;
}

/*
 * Returns the iris mask modified by the values for the eye's limbus
 * area.
 */
float iris_uv_mask(vec2 uv, float iris_radius, float limbus_width) {
	float radius = (length(uv - 0.5) - (iris_radius - limbus_width)) / limbus_width;
	return smoothstep(0.0, 1.0, clamp(1.0 - radius, 0.0, 1.0));
}

float sphere_mask(vec2 uv, vec2 center, float radius, float hardness) {
	float ratio = radius * clamp(hardness, 0.0, 0.999);
	return smoothstep(1.0, 0.0, (distance(uv, center) - ratio) / (radius - ratio));
}

void fragment() {
	const float uv_scale = 1.0;

	vec2 uv_scaled = scale_uv_from_center(UV, uv_scale);
	float iris_mask = iris_uv_mask(uv_scaled, iris_uv_radius, limbus_uv_width);
	vec2 uv_refracted = uv_scaled;

	if (refraction_strength > 0.0) {
		// Compute the direction vectors and surface normals
		vec3 surface_normal_ws = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		vec3 incidence_vector_ws = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
		vec3 refraction_vector_ws = -refraction(incidence_vector_ws, surface_normal_ws);

		// Transform tangent space normal to world space
		mat3 tangent_to_world = mat3(INV_VIEW_MATRIX) * mat3(TANGENT,BINORMAL,NORMAL);
		vec3 tangent_normal = texture(eye_tangents, UV).xyz * 2.0 - 1.0;
		vec3 tangent_normal_ws = tangent_to_world * tangent_normal;

		// Calculate iris depth and refraction offset
		float iris_view_ratio = mix(0.3, 1.0, pow(dot(incidence_vector_ws, tangent_normal_ws), 2.0));
		float depth_plane_offset = texture(iris_displacement, vec2(iris_uv_radius * uv_scale + 0.5, 0.5)).x;
		vec3 iris_depth = max(texture(iris_displacement, UV).xyz - depth_plane_offset, 0.0) * iris_depth_scale;
		vec3 offset = (iris_depth / iris_view_ratio) * refraction_vector_ws;

		// Transform offset back to tangent space
		vec3 tangent_base_u = normalize(tangent_to_world * vec3(1.0, 0.0, 0.0));
		vec3 tangent_project = dot(tangent_base_u, tangent_normal_ws) * tangent_normal_ws;
		vec3 tangent_normalized = normalize(tangent_base_u - tangent_project);
		float offset_x = dot(tangent_normalized, offset);
		float offset_y = dot(cross(tangent_normalized, tangent_normal_ws), offset);
		vec2 uv_offset = vec2(offset_x, offset_y);

		vec2 iris_refraction = uv_scaled + iris_uv_radius * uv_offset;
		vec2 eye_refraction = mix(uv_scaled, iris_refraction, iris_mask);
		uv_refracted = mix(uv_scaled, eye_refraction, refraction_strength);
	}

	// Sample iris texture and apply limbus shading
	vec2 uv_iris = (uv_refracted - 0.5) * (1.0 / (iris_uv_radius * 2.0)) + 0.5;
	uv_iris = scale_pupils(uv_iris, vec2(pupil_scale_x, pupil_scale_y) * pupil_scale) ;
	vec3 iris = texture(iris_color, uv_iris).rgb * iris_brightness;
	iris *= clamp((1.0 - pow(length((uv_iris - 0.5) * limbus_darkness), limbus_power)), 0.0, 1.0);

	// Sample sclera texture and mix with iris
	vec3 sclera = texture(sclera_color, uv_scaled).rgb * sclera_brightness;
	float shadow_mask = sphere_mask(uv_scaled, vec2(0.5), eye_shadow_radius, eye_shadow_hardness);
	ALBEDO = mix(sclera, iris, iris_mask) * mix(eye_shadow_color, vec3(1.0), shadow_mask);
	NORMAL_MAP = texture(normal_map, uv_scaled).rgb;
	ROUGHNESS = mix(sclera_roughness, iris_roughness, iris_mask);
	SPECULAR = mix(sclera_specular, iris_specular, iris_mask);
}
