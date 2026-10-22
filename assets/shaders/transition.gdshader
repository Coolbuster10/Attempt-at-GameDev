shader_type canvas_item;
// Screen transitions. mode 0 = fade, 1 = Pokemon-style sweeping bars, 2 = iris (circle).
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int mode = 0;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float aspect = 1.7778;

void fragment() {
	float a = 0.0;
	if (mode == 0) {
		a = progress;
	} else if (mode == 1) {
		float rows = 9.0;
		float row = floor(UV.y * rows);
		float x = mod(row, 2.0) < 1.0 ? UV.x : 1.0 - UV.x;
		// stagger each bar slightly for a more dynamic sweep
		float p = progress * 1.3 - row / rows * 0.3;
		a = step(x, p);
	} else {
		vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
		// pixelate the circle edge to keep the pixel-art look
		p = floor(p * 90.0) / 90.0;
		a = step((1.0 - progress) * 1.05, length(p));
	}
	COLOR = vec4(tint.rgb, tint.a * a);
}
