shader_type canvas_item;

// Puts a flat, straight-on piece of art onto the painted desk so it matches
// the props that were drawn there: the same three-quarter view from above
// (the far edge narrower than the near edge — the sprite's own scale does the
// vertical foreshortening) and the same muted, sepia grade under the lamp.

// The part of the texture the sprite shows (its region), in 0..1 texture
// coordinates, so the taper is applied to the object and not the padding.
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
// Width of the far (top) edge relative to the near (bottom) edge.
uniform float top_width : hint_range(0.5, 1.0) = 0.86;

// Grade, matched by eye to the desk art.
uniform float saturation : hint_range(0.0, 1.0) = 0.4;
uniform vec4 tint : source_color = vec4(0.86, 0.78, 0.62, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.55;
uniform float brightness : hint_range(0.0, 1.5) = 0.85;

// Draw this sprite as the object's soft shadow on the desk instead.
uniform bool as_shadow = false;
uniform float shadow_opacity : hint_range(0.0, 1.0) = 0.32;

void fragment() {
	// Where this pixel sits on the object, 0..1 across and down.
	vec2 local = (UV - region.xy) / region.zw;
	// Squeeze each row toward the centre, more at the top: a trapezoid.
	float row_width = mix(top_width, 1.0, local.y);
	float x = (local.x - 0.5) / row_width + 0.5;
	// Anti-aliased side edges, so the slanted sides stay smooth.
	float edge = fwidth(x) * 1.5;
	float inside = smoothstep(0.0, edge, x) * smoothstep(1.0, 1.0 - edge, x);

	vec4 colour = texture(TEXTURE, region.xy + vec2(clamp(x, 0.0, 1.0), local.y) * region.zw);
	colour.a *= inside;

	if (as_shadow) {
		COLOR = vec4(0.0, 0.0, 0.0, colour.a * shadow_opacity);
	} else {
		float luma = dot(colour.rgb, vec3(0.299, 0.587, 0.114));
		vec3 graded = mix(vec3(luma), colour.rgb, saturation);
		graded = mix(graded, graded * tint.rgb, tint_strength);
		COLOR = vec4(graded * brightness, colour.a);
	}
}
