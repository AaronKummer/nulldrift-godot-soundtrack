// Animated sewer water — canvas_item shader for the dungeon's water layer.
// The layer draws plain white rects in board space; this shader replaces
// them with layered flowing noise, glints, and drifting scum patches.
// Colors are uniforms so other dungeons (flooded office, coolant pools)
// can re-theme the same shader.
shader_type canvas_item;

uniform vec4 deep : source_color = vec4(0.016, 0.05, 0.075, 1.0);
uniform vec4 shallow : source_color = vec4(0.05, 0.13, 0.15, 1.0);
uniform vec4 glint : source_color = vec4(0.35, 0.9, 1.0, 1.0);
uniform vec4 scum : source_color = vec4(0.10, 0.16, 0.07, 1.0);
uniform float flow_speed : hint_range(0.0, 2.0) = 0.35;

varying vec2 wpos;

void vertex() {
	wpos = VERTEX;
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 p = wpos * 0.018;
	float t = TIME * flow_speed;
	// Two flowing noise layers moving different directions
	float w1 = vnoise(p * 1.0 + vec2(t * 0.7, t * 0.25));
	float w2 = vnoise(p * 2.4 - vec2(t * 0.5, t * 0.9));
	float w = w1 * 0.62 + w2 * 0.38;
	vec3 col = mix(deep.rgb, shallow.rgb, w);
	// Drifting scum patches
	float s = vnoise(p * 0.55 + vec2(t * 0.18, -t * 0.06));
	col = mix(col, scum.rgb, smoothstep(0.68, 0.80, s) * 0.45);
	// Ripple glints along noise ridges (feeds the glow pass)
	float ridge = smoothstep(0.55, 0.62, w) - smoothstep(0.62, 0.70, w);
	float sparkle = pow(vnoise(p * 6.0 + vec2(t * 1.6, t * 1.1)), 9.0);
	col += glint.rgb * (ridge * 0.5 + sparkle * 1.6)
		* (0.65 + 0.35 * sin(TIME * 1.7 + wpos.x * 0.03 + wpos.y * 0.05));
	COLOR = vec4(col, 1.0);
}
