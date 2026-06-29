shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_always, shadows_disabled;

uniform sampler2D card_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 card_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float clip_min_x = -6.60;
uniform float clip_max_x = 1.78;
uniform float fade_width = 0.28;
uniform bool clip_enabled = true;

varying float world_x;

void vertex() {
	world_x = (MODEL_MATRIX * vec4(VERTEX, 1.0)).x;
}

void fragment() {
	vec4 tex = texture(card_texture, UV) * card_color;

	float clip_alpha = 1.0;

	if (clip_enabled) {
		float left_alpha = smoothstep(clip_min_x, clip_min_x + fade_width, world_x);
		float right_alpha = 1.0 - smoothstep(clip_max_x - fade_width, clip_max_x, world_x);
		clip_alpha = clamp(min(left_alpha, right_alpha), 0.0, 1.0);
	}

	if (clip_alpha <= 0.01) {
		discard;
	}

	ALBEDO = tex.rgb;
	ALPHA = tex.a * clip_alpha;
}