shader_type canvas_item;
render_mode unshaded;

void fragment() {
	float revealed = smoothstep(0.1, 0.95, texture(TEXTURE, UV).r);
	vec2 drift = UV * vec2(18.0, 9.0);
	float haze = sin(drift.x + sin(drift.y * 1.8) + TIME * 0.3)
		* cos(drift.y - drift.x * 0.5 - TIME * 0.2);
	vec3 color = mix(vec3(0.065, 0.10, 0.13), vec3(0.16, 0.23, 0.26), haze * 0.5 + 0.5);
	COLOR = vec4(color, (1.0 - revealed) * 0.97);
}
