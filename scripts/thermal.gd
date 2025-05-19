extends "res://scripts/erosion_helper.gd"

# Default parameters
const DEFAULT_NUM_ITERATIONS: int = 1000
const DEFAULT_TALUS_ANGLE: float = 0.005
const DEFAULT_THERMAL_FACTOR: float = 0.5
const DEFAULT_SHADER_PATH = "res://shaders/thermal_erode.glsl"

@export var num_iterations: int = DEFAULT_NUM_ITERATIONS
@export var talus_angle: float = DEFAULT_TALUS_ANGLE
@export var thermal_factor: float = DEFAULT_THERMAL_FACTOR

var shader_rid: RID
var pipeline_rid: RID
var push_constant_size = 32 # 16 for previous, +4 for height_scale
var shader_path := DEFAULT_SHADER_PATH

func _ready() -> void:
	init_shader()

func init_shader():
	# Initialize the RenderingDevice
	rd = RenderingServer.get_rendering_device()
	if not rd:
		printerr("Thermal Node: Failed to get RenderingDevice.")
		return
	
	# Load the shader
	var shader_file: Resource = load(shader_path)
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader_rid = rd.shader_create_from_spirv(shader_spirv)
	pipeline_rid = rd.compute_pipeline_create(shader_rid)

func thermal_erode(heightmap_in: PackedFloat32Array, map_size_in: int, height_scale: float, num_iters: int = num_iterations, talus: float = talus_angle, factor: float = thermal_factor) -> PackedFloat32Array:
	# Creating storage buffer
	var hm_bytes := heightmap_in.to_byte_array()
	var hm_buffer = rd.storage_buffer_create(hm_bytes.size(), hm_bytes)

	# --- Uniform Set Creation ---
	var uniforms : Array[RDUniform] = []

	# Binding 0: Heightmap
	var hm_uniform = RDUniform.new()
	hm_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	hm_uniform.binding = 0
	hm_uniform.add_id(hm_buffer)
	uniforms.append(hm_uniform)

	# Create the set
	var uniform_set_rid = rd.uniform_set_create(uniforms, shader_rid, 0)
	
	# --- Prepare Push Constant Data ---
	# Order: map_size, num_iterations, talus_angle, thermal_factor, height_scale
	var push_constant_data = PackedByteArray()
	push_constant_data.resize(push_constant_size)
	push_constant_data.encode_s32(0, map_size_in)
	push_constant_data.encode_s32(4, num_iters)
	push_constant_data.encode_float(8, talus)
	push_constant_data.encode_float(12, factor)
	push_constant_data.encode_float(16, height_scale)

	# ---  Dispatch Compute shader_rid ---
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline_rid)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set_rid, 0)
	rd.compute_list_set_push_constant(compute_list, push_constant_data, push_constant_size)
	
	# Calculate number of work groups needed
	var local_group_size = 1024
	@warning_ignore("integer_division")
	var num_groups = (map_size_in * map_size_in + local_group_size - 1) / local_group_size # Ceiling division
	
	rd.compute_list_dispatch(compute_list, num_groups, 1, 1)
	rd.compute_list_end()

	# Retrieving new map data 
	var result_hm_bytes : PackedByteArray = rd.buffer_get_data(hm_buffer)

	# Cleanup
	rd.free_rid(uniform_set_rid)
	rd.free_rid(hm_buffer)
	
	return(result_hm_bytes.to_float32_array())