// Stylised-real ocean: deep/shallow colour by distance from the island, a fixed
// sky-blue Fresnel (so a bright HDRI horizon can't wash it white), two scrolling
// normal layers for sun glints, gentle vertex swell and a soft foam band at the beach.
shader_type spatial;
render_mode ambient_light_disabled, cull_back, depth_draw_opaque;

uniform vec3 deep_col : source_color = vec3(0.01, 0.10, 0.24);
uniform vec3 shallow_col : source_color = vec3(0.06, 0.40, 0.46);
uniform vec3 sky_col : source_color = vec3(0.42, 0.62, 0.80);
uniform vec3 foam_col : source_color = vec3(0.85, 0.92, 0.95);
uniform sampler2D nmap : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float scale1 = 24.0;
uniform float scale2 = 55.0;
uniform vec2 off1 = vec2(0.0);
uniform vec2 off2 = vec2(0.0);
uniform float nstr = 0.55;
uniform float half_w = 100.0;
uniform float half_d = 100.0;
uniform float time_s = 0.0;
uniform float lift = 0.6;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sw = sin(wpos.x * 0.06 + time_s * 0.8) * 0.22 + cos(wpos.z * 0.09 - time_s * 0.6) * 0.18;
	VERTEX.y += sw;
}

void fragment() {
	vec3 n1 = texture(nmap, UV * scale1 + off1).rgb * 2.0 - 1.0;
	vec3 n2 = texture(nmap, UV * scale2 + off2).rgb * 2.0 - 1.0;
	vec2 nxy = (n1.xy + n2.xy) * nstr;
	NORMAL_MAP = normalize(vec3(nxy, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
	// distance outside the island rectangle -> shallow tint + foam near the beach
	float dx = max(abs(wpos.x) - half_w, 0.0);
	float dz = max(abs(wpos.z) - half_d, 0.0);
	float ds = length(vec2(dx, dz));
	float shallow = 1.0 - smoothstep(4.0, 60.0, ds);
	vec3 base = mix(deep_col, shallow_col, shallow);
	float fr = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 3.0);
	vec3 col = mix(base, sky_col, fr * 0.65);
	float foamn = texture(nmap, wpos.xz * 0.05 + vec2(time_s * 0.02, -time_s * 0.015)).r;
	float band = (1.0 - smoothstep(2.0, 14.0, ds)) * smoothstep(0.35, 0.8, foamn + 0.15 * sin(time_s * 1.3 + ds * 0.6));
	col = mix(col, foam_col, band * 0.85);
	ALBEDO = col;
	EMISSION = col * lift;
	ROUGHNESS = mix(0.12, 0.35, band);
	SPECULAR = 0.55;
	METALLIC = 0.0;
}
