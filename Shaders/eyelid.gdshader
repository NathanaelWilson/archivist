shader_type canvas_item;

// The archivist's upper eyelid, seen from behind the eye. Not a fade: a
// straight, full-width edge that rises from the bottom of the screen as the
// eye opens and drops from the top as it closes. Whatever is still
// visible under the lid is redrawn from the screen, out of focus while the
// eye is heavy, so it works over the desk, a document or the clipboard alike.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// 0 = shut, 1 = wide open (the lid is fully off screen).
uniform float openness : hint_range(0.0, 1.0) = 1.0;
// In mip levels: how unfocused the visible part is.
uniform float blur : hint_range(0.0, 6.0) = 0.0;
// Width of the soft lash line along the lid edge, in screen heights.
uniform float softness : hint_range(0.001, 0.2) = 0.035;
// The inside of a lid: not pure black — blood-warm, barely lit.
uniform vec4 lid_colour : source_color = vec4(0.05, 0.012, 0.012, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	// A straight edge across the whole width: at openness 0 it sits at the
	// bottom of the screen (all lid), at 1 at the top (all eye). The soft
	// band is pushed just past each end so fully shut and fully open are clean.
	float edge = mix(1.0 + softness, -softness, openness);
	// 0 under the lid, 1 in the open part of the eye.
	float seen = smoothstep(edge - softness, edge + softness, uv.y);
	// The lid casts a shadow just below its edge.
	float shade = mix(0.45, 1.0, smoothstep(edge, edge + 0.14, uv.y));
	vec3 scene = textureLod(screen_texture, uv, blur).rgb * shade;
	COLOR = vec4(mix(lid_colour.rgb, scene, seen), 1.0);
}
