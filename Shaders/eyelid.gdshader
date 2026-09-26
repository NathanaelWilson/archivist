shader_type canvas_item;

// The archivist's eyelids, seen from behind the eye: an upper lid that comes
// down from the top and a lower lid that comes up from the bottom, meeting in
// the middle when the eye shuts. Their edges bow slightly, like the opening of
// a real eye. Whatever is still visible between them is redrawn from the
// screen, out of focus while the eye is heavy, so it works over the desk, a
// document or the clipboard alike.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// 0 = shut, 1 = wide open (both lids fully off screen).
uniform float openness : hint_range(0.0, 1.0) = 1.0;
// In mip levels: how unfocused the visible part is.
uniform float blur : hint_range(0.0, 6.0) = 0.0;
// Width of the soft lash line along each lid edge, in screen heights.
uniform float softness : hint_range(0.001, 0.2) = 0.03;
// How much the lid edges bow toward the middle at the screen's sides.
uniform float curve : hint_range(0.0, 0.5) = 0.18;
// The inside of a lid: not pure black — blood-warm, barely lit.
uniform vec4 lid_colour : source_color = vec4(0.05, 0.012, 0.012, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	// Half the eye's opening. Past fully open the lids are pushed a little
	// further out so the curved corners clear the screen too.
	float half_open = openness * (0.5 + curve + softness);
	// Towards the sides the lids close in first: an eye-shaped opening.
	float side = uv.x - 0.5;
	float bow = curve * 4.0 * side * side;
	float top_edge = 0.5 - half_open + bow;
	float bottom_edge = 0.5 + half_open - bow;
	// 1 in the open part of the eye, 0 under either lid.
	float seen = smoothstep(top_edge - softness, top_edge + softness, uv.y)
		* (1.0 - smoothstep(bottom_edge - softness, bottom_edge + softness, uv.y));
	// Each lid casts a little shadow onto what is still visible.
	float shade = mix(0.5, 1.0, smoothstep(top_edge, top_edge + 0.12, uv.y))
		* mix(0.5, 1.0, 1.0 - smoothstep(bottom_edge - 0.12, bottom_edge, uv.y));
	vec3 scene = textureLod(screen_texture, uv, blur).rgb * shade;
	COLOR = vec4(mix(lid_colour.rgb, scene, seen), 1.0);
}
