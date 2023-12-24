shader_type spatial;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform float blur_strength : hint_range(0.0, 4.0, 0.1) = 0.0;
uniform float blur_opacity : hint_range(0.0, 1.0, 0.05) = 1.0;

void fragment() {
	ALBEDO = texture(screen_texture, SCREEN_UV, blur_strength).rgb;
	ALPHA = blur_opacity;
}
