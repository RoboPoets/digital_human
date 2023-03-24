group_uniforms textures;
uniform sampler2D normal_texture : repeat_disable, filter_linear_mipmap, hint_normal;
#ifdef USE_REFRACTION
uniform sampler2D tangent_texture : repeat_disable, filter_linear_mipmap;
uniform sampler2D depth_texture : repeat_disable, filter_linear_mipmap, hint_default_black;
#endif
#ifdef USE_POM
uniform sampler2D displacement_texture : repeat_disable, filter_linear_mipmap, hint_default_white;
#endif
uniform sampler2D sclera_texture : repeat_disable, filter_linear_mipmap, source_color, hint_default_white;
#ifdef USE_COLOR_MASK
uniform sampler2D iris_texture : repeat_disable, filter_linear_mipmap, hint_default_white;
#else
uniform sampler2D iris_texture : repeat_disable, filter_linear_mipmap, source_color, hint_default_black;
#endif

group_uniforms iris;
#ifdef USE_REFRACTION
uniform float refraction_strength : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float iris_depth_scale : hint_range(0.0, 4.0, 0.01) = 1.2;
#endif
uniform float iris_uv_radius : hint_range(0.1, 0.2, 0.01) = 0.15;
uniform float iris_brightness : hint_range(0.0, 4.0, 0.01) = 1.0;
uniform float iris_roughness : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform float iris_specular : hint_range(0.0, 1.0, 0.01) = 0.4;
#ifdef USE_COLOR_MASK
uniform vec3 iris_color_outer_1 : source_color = vec3(0.67, 0.83, 0.42);
uniform vec3 iris_color_inner_1 : source_color = vec3(0.74, 0.47, 0.32);
uniform vec3 iris_color_outer_2 : source_color = vec3(0.39, 0.65, 0.74);
uniform vec3 iris_color_inner_2 : source_color = vec3(0.96, 1.0, 0.3);
uniform float iris_color_radius : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float iris_color_hardness : hint_range(0.0, 1.0, 0.01) = 0.2;
#endif

group_uniforms limbus;
uniform float limbus_uv_width : hint_range(0.02, 0.05, 0.001) = 0.035;
uniform float limbus_darkness : hint_range(2.0, 2.5, 0.01) = 2.1;
uniform float limbus_power : hint_range(4.0, 24.0, 0.1) = 8.0;
uniform vec3 limbus_color : source_color = vec3(0.0);

group_uniforms pupil;
uniform float pupil_scale : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float pupil_scale_x : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float pupil_scale_y : hint_range(0.0, 2.0, 0.01) = 1.0;

group_uniforms sclera;
uniform float sclera_brightness : hint_range(0.0, 2.0, 0.01) = 0.9;
uniform float sclera_roughness : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform float sclera_specular : hint_range(0.0, 1.0, 0.01) = 0.4;
uniform float veins_power : hint_range(0.0, 3.0, 0.01) = 0.5;
uniform vec3 eye_shadow_color : source_color = vec3(0.52, 0.32, 0.2);
uniform float eye_shadow_radius : hint_range(0.0, 1.0, 0.01) = 0.45;
uniform float eye_shadow_hardness : hint_range(0.0, 1.0, 0.01) = 0.75;

#ifdef USE_POM
group_uniforms displacement;
uniform float displace_strength : hint_range(0.0, 32.0, 0.01) = 10.0;
uniform float displace_min_layers : hint_range(1.0, 32.0, 1.0) = 8.0;
uniform float displace_max_layers : hint_range(1.0, 32.0, 1.0) = 32.0;
uniform float displace_reference_plane : hint_range(0.0, 1.0, 0.01) = 1.0;
#endif

#ifdef USE_SSS
group_uniforms subsurface_scattering;
uniform float sss_strength : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float sss_strength_iris : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float sss_strength_sclera : hint_range(0.0, 1.0, 0.01) = 0.5;
#endif

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
 * Helper function to create a smooth spherical gradient mask.
 */
float sphere_mask(vec2 uv, vec2 center, float radius, float hardness) {
	float ratio = radius * clamp(hardness, 0.0, 0.999);
	return smoothstep(1.0, 0.0, (distance(uv, center) - ratio) / (radius - ratio));
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
 * Return the iris mask modified by the values for the eye's limbus area.
 */
float iris_uv_mask(vec2 uv, float iris_radius, float limbus_width) {
	float radius = (length(uv - 0.5) - (iris_radius - limbus_width)) / limbus_width;
	return smoothstep(0.0, 1.0, clamp(1.0 - radius, 0.0, 1.0));
}

/*
 * Apply parallax occlusion mapping to the UV, given a view direction and a
 * surface normal, both in tangent space. This is a modified version of the
 * implementation at https://learnopengl.com/Advanced-Lighting/Parallax-Mapping.
 * It was changed to work with a regular heightmap texture and it uses a
 * reference plane that allows offsetting the initial depth value. This can be
 * necessary after replacing the default displacement texture with a custom one.
 */
vec2 pom(vec2 uv, vec3 view_dir, vec3 normal) {
#ifdef USE_POM
	// Calculate number of layers and each layer's normalized depth
	float weight = abs(dot(normal, view_dir));
	float num_layers = mix(displace_max_layers, displace_min_layers, weight);
	float layer_depth = 1.0 / num_layers;

	// Loop through the layers to find the best match
	float current_depth = displace_reference_plane;
	float depth = texture(displacement_texture, uv).r;
	vec2 delta = (view_dir.xy * displace_strength * 0.01) / num_layers;
	while(current_depth > depth) {
		uv -= delta;
		depth = texture(displacement_texture, uv).r;
		current_depth -= layer_depth;
	}

	// Interpolate between the two closest layers to get the final UV offset
	vec2 prev_uv = uv + delta;
	float after_depth = depth - current_depth;
	float before_depth = texture(displacement_texture, prev_uv).r - current_depth - layer_depth;
	weight = before_depth / (before_depth - after_depth);
	return mix(prev_uv, uv, weight);
#else
	return uv;
#endif
}

void fragment() {
	const float uv_scale = 1.0;

	vec2 uv_scaled = scale_uv_from_center(UV, uv_scale);
	float iris_mask = iris_uv_mask(uv_scaled, iris_uv_radius, limbus_uv_width);
	vec3 tangent_normal = vec3(0.0, 0.0, 1.0);
	vec2 uv_refracted = uv_scaled;

#ifdef USE_REFRACTION
	if (refraction_strength > 0.0 && iris_mask > 0.0) {
		// Compute the direction vectors and surface normals
		vec3 surface_normal_ws = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		vec3 incidence_vector_ws = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
		vec3 refraction_vector_ws = -refraction(incidence_vector_ws, surface_normal_ws);

		// Transform tangent space normal to world space
		mat3 tangent_to_world = mat3(INV_VIEW_MATRIX) * mat3(TANGENT,BINORMAL,NORMAL);
		tangent_normal = texture(tangent_texture, UV).xyz * 2.0 - 1.0;
		vec3 tangent_normal_ws = tangent_to_world * tangent_normal;

		// Calculate iris depth and refraction offset
		float iris_view_ratio = mix(0.3, 1.0, pow(dot(incidence_vector_ws, tangent_normal_ws), 2.0));
		float depth_plane_offset = texture(depth_texture, vec2(iris_uv_radius * uv_scale + 0.5, 0.5)).x;
		vec3 iris_depth = max(texture(depth_texture, UV).xyz - depth_plane_offset, 0.0) * iris_depth_scale;
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
#endif

	// Calculate iris UVs and apply pupil scale
	vec2 uv_iris = (uv_refracted - 0.5) * (1.0 / (iris_uv_radius * 2.0)) + 0.5;
	uv_iris = scale_pupils(uv_iris, vec2(pupil_scale_x, pupil_scale_y) * pupil_scale) ;

#ifdef USE_POM
	// Apply parallax occlusion mapping to the iris UVs
	if (displace_strength > 0.0 && iris_mask > 0.0) {
		vec3 tangent_view_dir = normalize(normalize(-VERTEX) * mat3(TANGENT,-BINORMAL,NORMAL));
		uv_iris = pom(uv_iris, tangent_view_dir, tangent_normal);
	}
#endif

	// Apply limbus shading and sample iris texture
	float limbus_mask = clamp((1.0 - pow(length((uv_iris - 0.5) * limbus_darkness), limbus_power)), 0.0, 1.0);
	vec3 iris_color = texture(iris_texture, uv_iris).rgb;

#ifdef USE_COLOR_MASK
	float mask = sphere_mask(uv_iris, vec2(0.5), iris_color_radius, iris_color_hardness);
	vec3 col1 = mix(iris_color_outer_1 * iris_color.r, iris_color_inner_1 * iris_color.g, mask);
	vec3 col2 = mix(iris_color_outer_2 * iris_color.r, iris_color_inner_2 * iris_color.g, mask);
	vec3 col3 = mix(col2, col1, iris_color.b);
	iris_color = col3;
#endif

	vec3 iris = mix(limbus_color, iris_color * iris_brightness, limbus_mask);

	// Sample sclera texture and mix with iris
	vec3 sclera = pow(texture(sclera_texture, uv_scaled).rgb, vec3(veins_power)) * sclera_brightness;
	float shadow_mask = sphere_mask(uv_scaled, vec2(0.5), eye_shadow_radius, eye_shadow_hardness);

	// Apply all of it to the shader outputs
	ALBEDO = mix(sclera, iris, iris_mask) * mix(eye_shadow_color, vec3(1.0), shadow_mask);
	NORMAL_MAP = texture(normal_texture, uv_scaled).rgb;
	ROUGHNESS = mix(sclera_roughness, iris_roughness, iris_mask);
	SPECULAR = mix(sclera_specular, iris_specular, iris_mask);
#ifdef USE_SSS
	SSS_STRENGTH = sss_strength * (iris_mask * sss_strength_iris + (1.0 - iris_mask) * sss_strength_sclera);
#endif
}
