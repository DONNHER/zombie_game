shader_type canvas_item;

uniform int mode = 0; // 0: normal, 1: deuteranopia, 2: protanopia, 3: tritanopia
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	vec4 tex = texture(screen_texture, SCREEN_UV);
	vec3 c = tex.rgb;
	if (mode == 1) {
		// Deuteranopia-friendly high contrast matrix
		c = vec3(
			c.r * 0.625 + c.g * 0.375,
			c.r * 0.700 + c.g * 0.300,
			c.g * 0.300 + c.b * 0.700
		);
	} else if (mode == 2) {
		// Protanopia-friendly high contrast matrix
		c = vec3(
			c.r * 0.567 + c.g * 0.433,
			c.r * 0.558 + c.g * 0.442,
			c.g * 0.242 + c.b * 0.758
		);
	} else if (mode == 3) {
		// Tritanopia-friendly high contrast matrix
		c = vec3(
			c.r * 0.950 + c.g * 0.050,
			c.g * 0.433 + c.b * 0.567,
			c.g * 0.475 + c.b * 0.525
		);
	}
	COLOR = vec4(clamp(c, 0.0, 1.0), tex.a);
}
