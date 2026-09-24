shader_type canvas_item;

// For desk props cut out of MAIN.psd as Affinity slices (container, clipboard,
// ...). Those slices carry the scene's grain/grade over the WHOLE slice
// rectangle, so the "empty" padding around each object is a ~40-50% opaque
// dark tint, not real transparency. Drawn as-is, every prop would sit in a
// murky box, and a plain alpha outline would trace that box.
//
// So this shader:
//   1. re-cuts the alpha: below alpha_floor is dropped, alpha_floor ->
//      alpha_ceiling is feathered, above is solid;
//   2. when outline_enabled, rings what is left with outline_color. The quad
//      is grown by the outline width so the ring is not clipped where an
//      object touches the edge of its own slice.
//
// DeskProp builds its touch mask from the same cut-off, so what you see
// outlined is exactly what you can touch.

uniform float alpha_floor : hint_range(0.0, 1.0) = 0.55;
uniform float alpha_ceiling : hint_range(0.0, 1.0) = 0.8;
uniform vec4 outline_color : source_color = vec4(0.96, 0.93, 0.82, 1.0);
uniform float outline_width = 10.0; // in source-art pixels
uniform bool outline_enabled = false;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
	vec2 grow = sign(UV - 0.5) * (outline_width + 2.0);
	VERTEX += grow;
	UV += grow * TEXTURE_PIXEL_SIZE;
}

float inside(vec2 uv) {
	return step(0.0, uv.x) * step(0.0, uv.y) * step(uv.x, 1.0) * step(uv.y, 1.0);
}

float cut(float a) {
	return smoothstep(alpha_floor, alpha_ceiling, a);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float a = cut(tex.a) * inside(UV);
	vec4 result = vec4(tex.rgb, a);

	if (outline_enabled) {
		float ring = 0.0;
		for (int i = 0; i < 12; i++) {
			float angle = float(i) * 6.2831853 / 12.0;
			vec2 dir = vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE;
			vec2 far_uv = UV + dir * outline_width;
			vec2 near_uv = UV + dir * outline_width * 0.5;
			ring = max(ring, cut(texture(TEXTURE, far_uv).a) * inside(far_uv));
			ring = max(ring, cut(texture(TEXTURE, near_uv).a) * inside(near_uv));
		}
		float ring_a = outline_color.a * ring;
		// The object sits on top of its own ring.
		float out_a = a + ring_a * (1.0 - a);
		vec3 out_rgb = (tex.rgb * a + outline_color.rgb * ring_a * (1.0 - a)) / max(out_a, 0.0001);
		result = vec4(out_rgb, out_a);
	}

	COLOR = result * v_modulate;
}
