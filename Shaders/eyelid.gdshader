shader_type canvas_item;

// Draws the screen back over itself, dimmed and out of focus, so the eyelid
// effect works on whatever is underneath (desk, document, clipboard) without
// any of them knowing about it. darkness 0 / blur 0 is a plain redraw.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float darkness : hint_range(0.0, 1.0) = 0.0;
// In mip levels: every step doubles the smear, which is what a heavy,
// half-open eye looks like.
uniform float blur : hint_range(0.0, 6.0) = 0.0;

void fragment() {
	vec3 seen = textureLod(screen_texture, SCREEN_UV, blur).rgb;
	COLOR = vec4(seen * (1.0 - darkness), 1.0);
}
