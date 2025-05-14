shader_type spatial;
render_mode depth_draw_opaque, cull_back;

// For Vertex Shader
uniform sampler2D heightmap_texture : hint_default_black, repeat_disable; // Texture containing height data (passed from script)
uniform float height_scale = 10.0;        // Max height displacement (passed from script)
uniform vec2 pixel_size;                  // Size of one pixel in UV space (1/width, 1/height) (passed from script)
uniform float map_size_uniform;           // Actual map size (e.g., 256.0) (passed from script)

// For Fragment Shader (Coloring)
uniform vec4 rock_color  : source_color = vec4(0.06, 0.06, 0.1, 1.0);
uniform vec4 snow_color  : source_color = vec4(0.9, 0.9, 0.85, 1.0);
uniform float snow_slope_threshold : hint_range(0.0, 1.0) = 0.24;
uniform float snow_blend_amount    : hint_range(0.0, 1.0) = 0.3;

// Data passed from vertex to fragment shader
varying vec3 world_pos_varying;
varying vec3 normal_varying;
varying float height_varying;

void vertex() {
	vec2 uv = UV;
	// Sampling height from the texture (value is 0.0 to 1.0)
	float height = texture(heightmap_texture, uv).r;
	height_varying = height * height_scale; // Store actual world height offset

	// Displace the vertex vertically (along the mesh's local Y-axis)
	VERTEX.y = height_varying;

	// --- Normal Calculation ---
	float hL = texture(heightmap_texture, uv - vec2(pixel_size.x, 0.0)).r * height_scale;
	float hR = texture(heightmap_texture, uv + vec2(pixel_size.x, 0.0)).r * height_scale;
	float hD = texture(heightmap_texture, uv - vec2(0.0, pixel_size.y)).r * height_scale;
	float hU = texture(heightmap_texture, uv + vec2(0.0, pixel_size.y)).r * height_scale;

	vec3 tangent   = normalize(vec3(pixel_size.x * map_size_uniform * 2.0, hR - hL, 0.0)); // Vector along X
	vec3 bitangent = normalize(vec3(0.0, hU - hD, pixel_size.y * map_size_uniform * 2.0)); // Vector along Z

	// Calculating the normal in object space
	vec3 calculated_normal = normalize(cross(bitangent, tangent));

	NORMAL = calculated_normal;

	normal_varying = NORMAL;
	world_pos_varying = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Calculating worldspace normal from the interpolated object-space normal
	vec3 world_normal = normalize((MODEL_MATRIX * vec4(normal_varying, 0.0)).xyz);
	// Derive slope factor (0 = flat ~ horizontal normal.y=1, 1 = vertical ~ normal.y=0)
	float slope = 1.0 - clamp(world_normal.y, 0.0, 1.0);

	// Coloring Logic
	float snowBlendHeight = snow_slope_threshold * (1.0 - snow_blend_amount);
	float snowWeight = 1.0 - clamp((slope - snowBlendHeight) / (snow_slope_threshold - snowBlendHeight), 0.0, 1.0);
	ALBEDO = mix(rock_color.rgb, snow_color.rgb, snowWeight);

	// Ambient Occlusion
	float ao = clamp(1.0 - height_varying * 0.01, 0.5, 1.0);
	AO = ao;
}