shader_type spatial;
render_mode unshaded;

group_uniforms textures;
uniform sampler2D eye_tangents : repeat_disable, filter_linear_mipmap, hint_normal;
uniform sampler2D iris_displacement : repeat_disable;
uniform sampler2D iris_color : repeat_disable, filter_linear_mipmap, source_color;

group_uniforms iris;
uniform float refraction_strength : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float pupil_scale : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float iris_depth_scale : hint_range(0.0, 4.0, 0.01) = 1.2;
uniform float iris_uv_radius : hint_range(0.1, 0.2, 0.01) = 0.15;
uniform float limbus_uv_width : hint_range(0.02, 0.05, 0.001) = 0.035;

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
vec2 scale_pupils(vec2 uv, float scale) {
	vec2 uv_centered = uv - 0.5;
	float uv_length = length(uv_centered);
	vec2 uv_max = normalize(uv_centered) * 0.5;
	vec2 uv_scaled = mix(uv_max, vec2(0.0), clamp((1.0 - uv_length * 2.0) * scale, 0.0, 1.0));
	return uv_scaled + 0.5;
}

/*
 * Returns the iris mask modified by the values for the eye's limbus
 * area. TODO: the limbus data can probably be stored in a single float.
 */
vec2 iris_uv_mask(vec2 uv, float iris_radius, vec2 limbus_width) {
	vec2 radius = (length(uv - 0.5) - (iris_radius - limbus_width)) / limbus_width;
	vec2 mask = smoothstep(0.0, 1.0, clamp(1.0 - radius, 0.0, 1.0));
	return mask;
}

void fragment() {
	const float uv_scale = 1.0;
	
	vec2 uv_scaled = scale_uv_from_center(UV, uv_scale);
	vec2 iris_mask = iris_uv_mask(uv_scaled, iris_uv_radius, vec2(limbus_uv_width));
	vec2 uv_refracted = uv_scaled;
	
	if (refraction_strength > 0.0) {
		// Compute the direction vectors and surface normals
		vec3 surface_normal_ws = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		vec3 incidence_vector_ws = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
		vec3 refraction_vector_ws = -refraction(incidence_vector_ws, surface_normal_ws);
		
		// Transform tangent space normal to world space
		mat3 tangent_to_world = mat3(INV_VIEW_MATRIX) * mat3(TANGENT,BINORMAL,NORMAL);
		vec3 tangent_normal = vec3(texture(eye_tangents, UV).xy, 1.0) * 2.0 - 1.0;
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
		vec2 uv_offset = vec2(-offset_x, offset_y);
		
		vec2 iris_refraction = uv_scaled + iris_uv_radius * vec2(-1, 1) * uv_offset;
		vec2 eye_refraction = mix(uv_scaled, iris_refraction, iris_mask.r);
		uv_refracted = mix(uv_scaled, eye_refraction, refraction_strength);
	}

	vec2 uv_iris = (uv_refracted - 0.5) * (1.0 / (iris_uv_radius * 2.0)) + 0.5;
	uv_iris = scale_pupils(uv_iris, pupil_scale);
	
	ALBEDO = texture(iris_color, uv_iris).rgb;
}
