# Erosion.gd
extends Node

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
@export var erosionBrushRadius = 3


# Shader vars
var rd: RenderingDevice
var shader_rid: RID     
var pipeline_rid: RID
var push_constant_size = 48
var shader_path := "res://shaders/erode.glsl"

func _ready() -> void:
	call_deferred("init_rendering_device")

func init_rendering_device():
	# Initialize the RenderingDevice
	rd = RenderingServer.get_rendering_device()
	if not rd:
		printerr("Erosion Node: Failed to get RenderingDevice.")
		return
	
	# Load the shader
	var shader_file: Resource = load(shader_path)
	if not shader_file or not shader_file is RDShaderFile:
		printerr("Erosion Node: Failed to load shader_rid file or incorrect type")
		return
	
	# Create the shader_rid from the shader file
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	if not shader_spirv or not shader_spirv is RDShaderSPIRV:
		printerr("Erosion node: Failed to create shader_rid spirv")
	shader_rid = rd.shader_create_from_spirv(shader_spirv)
	pipeline_rid = rd.compute_pipeline_create(shader_rid)

func erode_with_gpu(heightmap_in: PackedFloat32Array, map_size_in: int) -> PackedFloat32Array:

	var mapsize : int = map_size_in
	
	# Creating storage buffers
	var hm_bytes := heightmap_in.to_byte_array()
	var hm_buffer = rd.storage_buffer_create(hm_bytes.size(), hm_bytes)

	# --- Uniform Set Creation ---
	var uniforms : Array[RDUniform] = []
	
	var hm_uniform = RDUniform.new()
	hm_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	hm_uniform.binding = 0
	hm_uniform.add_id(hm_buffer)
	uniforms.append(hm_uniform)

	# Create the set
	var temp_uniform_set = rd.uniform_set_create(uniforms, shader_rid, 0)
	
		# --- Prepare Push Constant Data ---
	# MUST match the order and types in the GLSL push_constant block exactly
	var push_constant_data = PackedByteArray()
	push_constant_data.resize(push_constant_size)
	push_constant_data.encode_s32(0, mapsize)
	push_constant_data.encode_s32(4, max_steps)   
	push_constant_data.encode_float(8, inertia) 
	push_constant_data.encode_float(12, capacity_factor) 
	push_constant_data.encode_float(16, min_capacity) 
	push_constant_data.encode_float(20, deposit_rate) 
	push_constant_data.encode_float(24, erode_rate) 
	push_constant_data.encode_float(28, evaporate_rate) 
	push_constant_data.encode_float(32, gravity)                
	push_constant_data.encode_float(36, start_speed)    
	push_constant_data.encode_float(40, start_water)
	push_constant_data.encode_float(44, Time.get_ticks_usec() / 1000.0)

	# ---  Dispatch Compute shader_rid ---
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline_rid)
	rd.compute_list_bind_uniform_set(compute_list, temp_uniform_set, 0)
	rd.compute_list_set_push_constant(compute_list, push_constant_data, push_constant_size)
	
	# Calculate number of work groups needed
	# Local mapsize is 1024 (from GLSL layout)
	var local_group_size = 1024
	@warning_ignore("integer_division")
	var num_groups = (num_droplets + local_group_size - 1) / local_group_size # Ceiling division
	
	rd.compute_list_dispatch(compute_list, num_groups, 1, 1) # Dispatch groups
	rd.compute_list_end()

	# Retrieving new map data 
	var result_hm_bytes : PackedByteArray = rd.buffer_get_data(hm_buffer)

	# --- Cleanup: Free RenderingDevice Resources ---
	rd.free_rid(temp_uniform_set)
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
