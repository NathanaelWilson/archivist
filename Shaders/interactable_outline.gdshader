shader_type canvas_item;

// Traces the real silhouette of a transparent-background texture (a gear
// icon, a document, a cabinet, a fax machine, ...) instead of drawing a
// plain box/rounded-rect around its bounding rect. Toggle per-instance from
// script with: material.set_shader_parameter("outline_enabled", true/false)

uniform vec4 outline_color : source_color = vec4(0.960784, 0.752941, 0.0, 1.0);
uniform float outline_width : hint_range(0.0, 8.0) = 2.0;
uniform bool outline_enabled = false;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	COLOR = tex_color;

	if (outline_enabled && tex_color.a < 0.5) {
		vec2 texel = outline_width / vec2(textureSize(TEXTURE, 0));
		float neighbor_alpha = 0.0;
		neighbor_alpha += texture(TEXTURE, UV + vec2( texel.x,  0.0)).a;
		neighbor_alpha += texture(TEXTURE, UV + vec2(-texel.x,  0.0)).a;
		neighbor_alpha += texture(TEXTURE, UV + vec2( 0.0,  texel.y)).a;
		neighbor_alpha += texture(TEXTURE, UV + vec2( 0.0, -texel.y)).a;
		neighbor_alpha += texture(TEXTURE, UV + vec2( texel.x,  texel.y)).a;
		neighbor_alpha += texture(TEXTURE, UV + vec2(-texel.x,  texel.y)).a;
		neighbor_alpha += texture(TEXTURE, UV + vec2( texel.x, -texel.y)).a;
		neighbor_alpha += texture(TEXTURE, UV + vec2(-texel.x, -texel.y)).a;

		if (neighbor_alpha > 0.0) {
			COLOR = outline_color;
		}
	}
}
