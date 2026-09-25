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
// outlined is exactly what you can touch. InteractableOutline uses this same
// shader for the main-menu buttons, so every outline in the game matches.
//
// The dark-room (*_off) slices are worse: their padding is ~85-90% opaque,
// so no alpha cut can find the object in them. When use_mask is on, the
// silhouette is taken from mask_texture instead — the lit (*_on) slice of the
// same object, which has the same size and position — and only the colour
// comes from the dark slice.

uniform float alpha_floor : hint_range(0.0, 1.0) = 0.55;
uniform float alpha_ceiling : hint_range(0.0, 1.0) = 0.8;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width = 10.0; // in source-art pixels
uniform bool outline_enabled = false;
// How far the quad is grown, and how much UV one unit of VERTEX covers. Left
// at 0 for a Sprite2D, where one local unit IS one texel. A Control draws its
// texture at whatever size it is laid out at, so InteractableOutline sets
// these from the drawn rect.
uniform float grow_units = 0.0;
uniform vec2 uv_per_unit = vec2(0.0);
uniform bool use_mask = false;
uniform sampler2D mask_texture : filter_linear_mipmap;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
	vec2 per_unit = uv_per_unit.x > 0.0 ? uv_per_unit : TEXTURE_PIXEL_SIZE;
	float amount = grow_units > 0.0 ? grow_units : outline_width + 2.0;
	vec2 grow = sign(UV - 0.5) * amount;
	VERTEX += grow;
	UV += grow * per_unit;
}

float inside(vec2 uv) {
	return step(0.0, uv.x) * step(0.0, uv.y) * step(uv.x, 1.0) * step(uv.y, 1.0);
}

float cut(float a) {
	return smoothstep(alpha_floor, alpha_ceiling, a);
}

// The alpha that decides the silhouette at uv.
float shape_alpha(sampler2D own, vec2 uv) {
	return use_mask ? texture(mask_texture, uv).a : texture(own, uv).a;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float a = cut(shape_alpha(TEXTURE, UV)) * inside(UV);
	vec4 result = vec4(tex.rgb, a);

	if (outline_enabled) {
		float ring = 0.0;
		for (int i = 0; i < 12; i++) {
			float angle = float(i) * 6.2831853 / 12.0;
			vec2 dir = vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE;
			vec2 far_uv = UV + dir * outline_width;
			vec2 near_uv = UV + dir * outline_width * 0.5;
			ring = max(ring, cut(shape_alpha(TEXTURE, far_uv)) * inside(far_uv));
			ring = max(ring, cut(shape_alpha(TEXTURE, near_uv)) * inside(near_uv));
		}
		float ring_a = outline_color.a * ring;
		// The object sits on top of its own ring.
		float out_a = a + ring_a * (1.0 - a);
		vec3 out_rgb = (tex.rgb * a + outline_color.rgb * ring_a * (1.0 - a)) / max(out_a, 0.0001);
		result = vec4(out_rgb, out_a);
	}

	COLOR = result * v_modulate;
}
