extends "res://scripts/erosion_helper.gd"

# Default parameters
const DEFAULT_NUM_DROPLETS = 70000
const DEFAULT_MAX_STEPS = 30
const DEFAULT_INERTIA = 0.05
const DEFAULT_CAPACITY_FACTOR = 5.0
const DEFAULT_MIN_CAPACITY = 0.01
const DEFAULT_ERODE_RATE = 0.3
const DEFAULT_DEPOSIT_RATE = 0.3
const DEFAULT_EVAPORATE_RATE = 0.01
const DEFAULT_GRAVITY = 4
const DEFAULT_START_SPEED = 1
const DEFAULT_START_WATER = 1
const DEFAULT_EROSION_BRUSH_RADIUS = 3
const DEFAULT_SHADER_PATH = "res://shaders/hydraulic_erode.glsl"

# Erosion vars
@export var num_droplets: int = 70000
@export var max_steps: int = 25
@export var inertia: float = 0.05
@export var capacity_factor: float = 5.0
@export var min_capacity: float = 0.01
@export var erode_rate: float = 0.3
@export var deposit_rate: float = 0.3
@export var evaporate_rate: float = 0.01
@export var gravity: float = 4
@export var start_speed: float = 1
@export var start_water: float = 1
@export var erosion_brush_radius = 3


# Shader vars
var shader_rid: RID     
var pipeline_rid: RID
var push_constant_size = 64
var shader_path := DEFAULT_SHADER_PATH

var brush_indices_buffer_rid: RID
var brush_weights_buffer_rid: RID
var last_brush_radius_processed = -1
var brush_length = 0

func _ready() -> void:
	init_shader()

func init_shader():
	# Initialize the RenderingDevice
	rd = RenderingServer.get_rendering_device()
	if not rd:
		printerr("Erosion Node: Failed to get RenderingDevice.")
		return
	
	# Load the shader
	var shader_file: Resource = load(shader_path)
	# Create the shader_rid from the shader file
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()

	shader_rid = rd.shader_create_from_spirv(shader_spirv)
	pipeline_rid = rd.compute_pipeline_create(shader_rid)

# Function to precompute erosion brush and create/update GPU buffers
func _update_erosion_brush(current_radius: int, map_size_for_offsets: int):
	if current_radius == last_brush_radius_processed and \
	   brush_indices_buffer_rid.is_valid() and brush_weights_buffer_rid.is_valid():
		return

	# Free old buffers if they exist
	if brush_indices_buffer_rid.is_valid(): rd.free_rid(brush_indices_buffer_rid)
	if brush_weights_buffer_rid.is_valid(): rd.free_rid(brush_weights_buffer_rid)

	var brush_idx_offsets = PackedInt32Array()
	var brush_wts = PackedFloat32Array()
	var weight_sum : float = 0.0

	for r_y in range(-current_radius, current_radius + 1):
		for r_x in range(-current_radius, current_radius + 1):
			var sqr_dst = float(r_x * r_x + r_y * r_y)
			if sqr_dst < float(current_radius * current_radius):
				# Offset is relative to droplet's integer cell, using internal map width
				var offset = r_y * map_size_for_offsets + r_x
				brush_idx_offsets.append(offset)
				var brush_weight = 1.0 - sqrt(sqr_dst) / float(current_radius)
				weight_sum += brush_weight
				brush_wts.append(brush_weight)

	brush_length = brush_idx_offsets.size()
	if brush_length == 0: # Should not happen with radius > 0
		printerr("Warning: Erosion brush is empty for radius ", current_radius)
		last_brush_radius_processed = current_radius
		brush_indices_buffer_rid = RID()
		brush_weights_buffer_rid = RID()
		return

	# Normalize weights
	if weight_sum > 0.0001:
		for i in range(brush_wts.size()):
			brush_wts[i] /= weight_sum
	
	# Create GPU buffers
	var brush_idx_bytes = brush_idx_offsets.to_byte_array()
	brush_indices_buffer_rid = rd.storage_buffer_create(brush_idx_bytes.size(), brush_idx_bytes)

	var brush_wts_bytes = brush_wts.to_byte_array()
	brush_weights_buffer_rid = rd.storage_buffer_create(brush_wts_bytes.size(), brush_wts_bytes)

	last_brush_radius_processed = current_radius

func hydraulic_erode(heightmap_in: PackedFloat32Array, map_size_in: int, droplets_in:int = num_droplets) -> PackedFloat32Array:

	# Creating storage buffers
	var hm_bytes := heightmap_in.to_byte_array()
	var hm_buffer = rd.storage_buffer_create(hm_bytes.size(), hm_bytes)

	_update_erosion_brush(erosion_brush_radius, map_size_in)

	# --- Uniform Set Creation ---
	var uniforms : Array[RDUniform] = []

	# Binding 0: Heightmap
	var hm_uniform = RDUniform.new()
	hm_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	hm_uniform.binding = 0
	hm_uniform.add_id(hm_buffer)
	uniforms.append(hm_uniform)
	# Binding 1: Brush Indices
	var brush_idx_uniform = RDUniform.new()
	brush_idx_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	brush_idx_uniform.binding = 1; brush_idx_uniform.add_id(brush_indices_buffer_rid)
	uniforms.append(brush_idx_uniform)
	# Binding 2: Brush Weights
	var brush_wts_uniform = RDUniform.new()
	brush_wts_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	brush_wts_uniform.binding = 2; brush_wts_uniform.add_id(brush_weights_buffer_rid)
	uniforms.append(brush_wts_uniform)

	# Create the set
	var uniform_set_rid = rd.uniform_set_create(uniforms, shader_rid, 0)
	
	# --- Prepare Push Constant Data ---
	# MUST match the order and types in the GLSL push_constant block exactly
	var push_constant_data = PackedByteArray()
	push_constant_data.resize(push_constant_size)
	push_constant_data.encode_s32(0, map_size_in)
	push_constant_data.encode_s32(4, brush_length) 
	push_constant_data.encode_s32(8, erosion_brush_radius) 
	push_constant_data.encode_s32(12, max_steps)
	push_constant_data.encode_float(16, inertia)
	push_constant_data.encode_float(20, capacity_factor)
	push_constant_data.encode_float(24, min_capacity)
	push_constant_data.encode_float(28, deposit_rate)
	push_constant_data.encode_float(32, erode_rate)
	push_constant_data.encode_float(36, evaporate_rate)
	push_constant_data.encode_float(40, gravity)
	push_constant_data.encode_float(44, start_speed)
	push_constant_data.encode_float(48, start_water)
	push_constant_data.encode_float(52, float(Time.get_ticks_usec()) / 1_000_000.0)

	# ---  Dispatch Compute shader_rid ---
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline_rid)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set_rid, 0)
	rd.compute_list_set_push_constant(compute_list, push_constant_data, push_constant_size)
	
	# Calculate number of work groups needed
	var local_group_size = 1024
	@warning_ignore("integer_division")
	var num_groups = (droplets_in + local_group_size - 1) / local_group_size # Ceiling division
	
	rd.compute_list_dispatch(compute_list, num_groups, 1, 1) # Dispatch groups
	rd.compute_list_end()

	# Retrieving new map data 
	var result_hm_bytes : PackedByteArray = rd.buffer_get_data(hm_buffer)

	# Cleanup
	rd.free_rid(uniform_set_rid)
	rd.free_rid(hm_buffer)
	
	return(result_hm_bytes.to_float32_array())

func _exit_tree():
	if rd:
		if pipeline_rid.is_valid():
			rd.free_rid(pipeline_rid)
			pipeline_rid = RID()
		if shader_rid.is_valid():
			rd.free_rid(shader_rid)
			shader_rid = RID()
		if brush_indices_buffer_rid.is_valid():
			rd.free_rid(brush_indices_buffer_rid)
			brush_indices_buffer_rid = RID()
		if brush_weights_buffer_rid.is_valid():
			rd.free_rid(brush_weights_buffer_rid)
			brush_weights_buffer_rid = RID()
