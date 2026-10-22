shader_type canvas_item;
// Old-cartoon look (Cuphead-ish): warm tint, vignette, flickering film grain and soft scanlines.
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float vignette = 0.45;
uniform float grain = 0.05;
uniform float warmth = 0.06;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	col = mix(col, col * vec3(1.06, 1.0, 0.86), warmth / 0.06 * 0.5);
	vec2 d = SCREEN_UV - 0.5;
	col *= 1.0 - dot(d, d) * vignette * 1.6;
	float t = floor(TIME * 12.0);
	col += (hash(floor(FRAGCOORD.xy / 2.0) + t) - 0.5) * grain;
	col *= 0.97 + 0.03 * sin(FRAGCOORD.y * 1.5);
	COLOR = vec4(col, 1.0);
}
