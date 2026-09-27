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

// --- Overlay: makes the flat art sit in the painted room (no extra asset).
// Film grain like the specks baked into the desk slices.
uniform float grain_strength : hint_range(0.0, 0.2) = 0.05;
// Darkens toward the paper's edges, like the soft falloff on the props.
uniform float edge_shade : hint_range(0.0, 1.0) = 0.25;
// The lamp is up and to the left: the far-left corner is a little brighter.
uniform float lamp_falloff : hint_range(0.0, 1.0) = 0.18;
// Which corner of the art (0..1) faces the lamp. Art drawn rotated on the
// desk (the envelope lying sideways in the case tray) points it elsewhere.
uniform vec2 lamp_corner = vec2(0.0, 0.0);
// 1 = lights on, 0 = the dark room (set by FileEntity.set_lights).
uniform float room_light : hint_range(0.0, 1.0) = 1.0;
// What the dark room does to a lit colour: matched to the *_off desk slices
// (about a fifth of the brightness, slightly cool, flattened contrast).
uniform vec3 dark_multiply : source_color = vec3(0.21, 0.22, 0.24);
uniform float dark_gamma : hint_range(0.3, 1.0) = 0.7;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

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
		graded *= brightness;

		// Overlay: lamp light, edge falloff and grain, all procedural.
		vec2 centred = vec2(x, local.y) - 0.5;
		float edge = 1.0 - edge_shade * smoothstep(0.25, 0.75, length(centred * vec2(1.3, 1.0)));
		vec2 from_lamp = abs(vec2(x, local.y) - lamp_corner);
		float lamp = 1.0 + lamp_falloff * (0.5 - 0.5 * (from_lamp.x + from_lamp.y));
		graded *= edge * lamp;
		graded += (hash(floor(UV * 900.0)) - 0.5) * grain_strength;

		// The dark room: scaled down like the *_off slices, contrast flattened.
		vec3 dark = pow(max(graded, vec3(0.0)), vec3(dark_gamma)) * dark_multiply;
		graded = mix(dark, graded, room_light);
		COLOR = vec4(clamp(graded, 0.0, 1.0), colour.a);
	}
}
