// Sci-fi hologram: scanlines, fresnel edge glow, flicker, and alpha.
//
// Good for: holographic projections, ghostly characters, force-field spheres.
shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_back, unshaded;

uniform vec4 color         : source_color = vec4(0.2, 0.8, 1.0, 1.0);
uniform float scanline_freq = 80.0;
uniform float scanline_speed = 2.0;
uniform float scanline_strength = 0.35;
uniform float fresnel_power = 2.5;
uniform float fresnel_boost = 1.5;
uniform float flicker_speed = 12.0;
uniform float flicker_amount = 0.12;
uniform float base_alpha = 0.6;

float hash11(float x) { return fract(sin(x) * 43758.5453); }

void fragment() {
    // Fresnel (edge glow)
    float fres = pow(1.0 - dot(normalize(VIEW), NORMAL), fresnel_power);
    float edge_glow = fres * fresnel_boost;

    // Horizontal scanlines scrolling down
    float scan = sin(UV.y * scanline_freq - TIME * scanline_speed);
    scan = 1.0 - scanline_strength * (0.5 + 0.5 * scan);

    // Flicker
    float flicker = 1.0 - flicker_amount * hash11(floor(TIME * flicker_speed));

    vec3 c = color.rgb * scan * flicker;
    c += edge_glow * color.rgb;

    ALBEDO = c;
    EMISSION = c;
    ALPHA = base_alpha + edge_glow * 0.4;
}
