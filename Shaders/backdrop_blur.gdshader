shader_type canvas_item;

// The desk behind an open document: still there, but out of focus and a
// little darker, so the page in front is what the eye lands on. Drawn over
// the whole screen, it redraws whatever is underneath — desk, envelope,
// trays, clipboard — so nothing else has to know about it.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// In mip levels: each step roughly doubles the blur radius.
uniform float blur : hint_range(0.0, 6.0) = 3.0;
// 0 keeps the desk's own brightness, 1 is black.
uniform float dim : hint_range(0.0, 1.0) = 0.45;
// Pulls the colour toward the old backdrop's warm brown so the blurred desk
// still sits in the same mood as the rest of the game.
uniform vec4 tint : source_color = vec4(0.04, 0.035, 0.03, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	vec3 desk = textureLod(screen_texture, SCREEN_UV, blur).rgb;
	desk = mix(desk, tint.rgb, tint_strength);
	COLOR = vec4(desk * (1.0 - dim), 1.0);
}
