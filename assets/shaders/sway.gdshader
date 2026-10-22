shader_type canvas_item;
// Gentle wind sway for foliage: top of the sprite moves, base stays put.
// The phase comes from the node's world position so neighbouring trees don't move in sync.
uniform float strength = 1.2;
uniform float speed = 1.6;

void vertex() {
	float top = 1.0 - UV.y;
	float phase = MODEL_MATRIX[3].x * 0.07 + MODEL_MATRIX[3].y * 0.05;
	VERTEX.x += sin(TIME * speed + phase) * strength * top * top;
}
