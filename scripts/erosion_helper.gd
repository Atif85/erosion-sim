extends Node

var rd: RenderingDevice

func _ready() -> void:
	call_deferred("init_rendering_device")

func init_rendering_device():
	rd = RenderingServer.get_rendering_device()
	if not rd:
		printerr("Erosion Node: Failed to get RenderingDevice.")
		return

# Ensure RenderingDevice is initialized
func ensure_rd() -> bool:
	if rd == null:
		init_rendering_device()
	return rd != null

# Load and compile a shader, returns [shader_rid, pipeline_rid]
func load_and_compile_shader(shader_path: String) -> Array:
	if not ensure_rd():
		printerr("Erosion Node: RenderingDevice not initialized.")
		return [RID(), RID()]
	var shader_file: Resource = load(shader_path)
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	var shader_rid = rd.shader_create_from_spirv(shader_spirv)
	var pipeline_rid = rd.compute_pipeline_create(shader_rid)
	return [shader_rid, pipeline_rid]

# Create a storage buffer from a PackedFloat32Array
func create_storage_buffer(arr) -> RID:
	var bytes = arr.to_byte_array()
	return rd.storage_buffer_create(bytes.size(), bytes)

# Free a list of RIDs
func cleanup_rids(rids: Array):
	for rid in rids:
		if rid is RID and rid.is_valid():
			rd.free_rid(rid)
