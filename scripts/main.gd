# main.gd
extends Node3D
class_name MainClass

# Defaults noise parameters
const DEFAULT_MAP_SIZE = 256
const DEFAULT_HEIGHT_SCALE = 200.0
const DEFAULT_SEED = 0
const DEFAULT_RANDOMIZE_SEED = true
const DEFAULT_NOISE_TYPE = FastNoiseLite.TYPE_PERLIN
const DEFAULT_FRACTAL_TYPE = FastNoiseLite.FRACTAL_FBM
const DEFAULT_NUM_OCTAVES = 7
const DEFAULT_GAIN = 0.4
const DEFAULT_LACUNARITY = 2.0
const DEFAULT_FREQUENCY = 2.0
const DEFAULT_ANIMATION_DURATION = 4.0

# Nodes
@onready var hydraulic_erosion_node: Node = $Erosion/Hydraulic
@onready var thermal_erosion_node: Node = $Erosion/Thermal
@onready var heightmap_mesh: MeshInstance3D = $HeightmapMesh
@onready var ui_manager: ErosionUiManager = $UI

# Variables for the heightmap
@export var map_size = DEFAULT_MAP_SIZE
@export var height_scale = DEFAULT_HEIGHT_SCALE
@export var Seed: int = DEFAULT_SEED
@export var randomize_seed: bool = DEFAULT_RANDOMIZE_SEED
@export var noise_type = DEFAULT_NOISE_TYPE
@export var fractal_type = DEFAULT_FRACTAL_TYPE
@export var num_octaves: int = DEFAULT_NUM_OCTAVES
@export var gain: float = DEFAULT_GAIN
@export var lacunarity: float = DEFAULT_LACUNARITY
@export var frequency : float = DEFAULT_FREQUENCY

var orignal_map_data : PackedFloat32Array = PackedFloat32Array()
var eroded_map_data : PackedFloat32Array = PackedFloat32Array()

var have_eroded : bool = false
var showing_erosion_heatmap : bool = false

var mapSizeWithBorder : int
var material : Material
var rng : RandomNumberGenerator
var noise : FastNoiseLite

# Track cumulative erosion/deposition for heatmap
var erosion_heatmap : PackedFloat32Array = PackedFloat32Array()

# Animation variables
var animation_running := false
var animation_start_time_sec : float = 0.0 # Store time in seconds
var animation_duration_sec : float = DEFAULT_ANIMATION_DURATION
var map_for_animation : PackedFloat32Array

func _ready():
	# initialize variables
	material = heightmap_mesh.get_active_material(0)
	rng = RandomNumberGenerator.new()
	noise = FastNoiseLite.new()
	# Generate the initial map
	generate()
	have_eroded = false


func _process(_delta):

	if animation_running and have_eroded:
		var current_time_sec = float(Time.get_ticks_msec()) / 1000.0
		var elapsed_time = current_time_sec - animation_start_time_sec
		var progress = clamp(elapsed_time / animation_duration_sec, 0.0, 1.0)

		for i in range(orignal_map_data.size()):
			map_for_animation[i] = lerp(orignal_map_data[i], eroded_map_data[i], progress)

		create_mesh(map_for_animation)

		if progress >= 1.0:
			print("erosion animation finished.")
			animation_running = false
			map_for_animation.clear()

func generate():
	have_eroded = false
	showing_erosion_heatmap = false
	clear_visual_overlay()

	mapSizeWithBorder = map_size + hydraulic_erosion_node.erosion_brush_radius * 2
	orignal_map_data = create_map(mapSizeWithBorder)

	create_mesh(orignal_map_data)
	eroded_map_data = orignal_map_data.duplicate()

	erosion_heatmap = PackedFloat32Array()
	erosion_heatmap.resize(mapSizeWithBorder * mapSizeWithBorder)
	for i in range(mapSizeWithBorder * mapSizeWithBorder):
		erosion_heatmap[i] = 0.0



# -- Erosion functions --
# Hydraulic erosion
func hydraulic_erode():
	var time_start_erode = Time.get_ticks_usec()

	if not have_eroded:
		eroded_map_data = hydraulic_erosion_node.hydraulic_erode(orignal_map_data, mapSizeWithBorder)
	else:
		eroded_map_data = hydraulic_erosion_node.hydraulic_erode(eroded_map_data, mapSizeWithBorder)

	update_erosion_heatmap()

	have_eroded = true

	var time_end_erode = Time.get_ticks_usec()
	print("erosion process took ",(time_end_erode - time_start_erode)/ 1000000.0," seconds")

# Thermal erosion
func thermal_erode():
	var time_start_erode = Time.get_ticks_usec()

	if not have_eroded:
		eroded_map_data = thermal_erosion_node.thermal_erode(orignal_map_data, mapSizeWithBorder, height_scale)
	else:
		eroded_map_data = thermal_erosion_node.thermal_erode(eroded_map_data, mapSizeWithBorder, height_scale)
	
	update_erosion_heatmap()

	have_eroded = true

	var time_end_erode = Time.get_ticks_usec()
	print("thermal process took ",(time_end_erode - time_start_erode)/ 1000000.0," seconds")

func update_erosion_heatmap():
	# Clear the heatmap before updating for the current step
	for i in range(erosion_heatmap.size()):
		erosion_heatmap[i] = 0.0
	for i in range(orignal_map_data.size()):
		erosion_heatmap[i] += eroded_map_data[i] - orignal_map_data[i]

func play_lerp_animation():
	if animation_running:
		print("Animation already in progress.")
		return

	print("Starting animated hydraulic_erosion_node...")
	animation_running = true

	if not have_eroded:
		hydraulic_erode()

	map_for_animation = orignal_map_data.duplicate()

	animation_start_time_sec = float(Time.get_ticks_msec()) / 1000.0

	create_mesh(orignal_map_data)

func create_mesh(heightmap_data : PackedFloat32Array):
	# Generating the mesh
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(map_size, map_size)
	plane_mesh.subdivide_width = map_size - 1
	plane_mesh.subdivide_depth = map_size - 1
	
	heightmap_mesh.set_mesh(plane_mesh)
	
	# Converting heightmap data to a Texture
	var image = create_image(heightmap_data)
	var heightmap_texture = ImageTexture.create_from_image(image)
	
	# Set Shader Parameters
	material.set_shader_parameter("heightmap_texture", heightmap_texture)
	material.set_shader_parameter("height_scale", height_scale)
	material.set_shader_parameter("pixel_size", Vector2(1.0 / float(map_size), 1.0 / float(map_size)))
	material.set_shader_parameter("map_size_uniform", float(map_size))

	# Position the mesh correctly based on its size
	heightmap_mesh.position = Vector3(int(map_size/2.0),0,int(map_size/2.0))

func create_map(map_size_in : int) -> PackedFloat32Array:
	var time_start_erode = Time.get_ticks_usec()
	# Configure noise once
	if randomize_seed:
		rng.randomize()
		Seed = rng.randi_range(-100000, 100000)

	ui_manager.ui_seed.value = Seed
	noise.seed               = Seed 
	noise.noise_type         = noise_type
	noise.fractal_type       = fractal_type
	noise.fractal_octaves    = num_octaves
	noise.fractal_gain       = gain
	noise.fractal_lacunarity = lacunarity
	noise.frequency          = frequency
	
	var map = PackedFloat32Array()
	map.resize(map_size_in * map_size_in)
	for y in range(map_size_in):
		for x in range(map_size_in):
			# Sample at normalized coords
			var v = noise.get_noise_2d(x / float(map_size_in), y / float(map_size_in))
			# Remap from [-1,1] to [0,1]
			map[y * map_size_in + x] = v * 0.5 + 0.5
	
	var time_end_erode = Time.get_ticks_usec()
	print("Map create from noise in ",(time_end_erode - time_start_erode)/ 1000000.0," seconds")
	return map
	

func create_image(heightmap_data : PackedFloat32Array ,save_png : bool = false, save_path : String = "") -> Image:
	var image = Image.create_empty(map_size, map_size, false, Image.FORMAT_RF)
	for y in range(map_size):
		for x in range(map_size):
			var n_x = clamp(x + hydraulic_erosion_node.erosion_brush_radius, 0 , mapSizeWithBorder - 1)
			var n_y = clamp(y + hydraulic_erosion_node.erosion_brush_radius, 0 , mapSizeWithBorder - 1)
			var index =  (n_y) * mapSizeWithBorder + (n_x)
			var height_val = heightmap_data[index]
			# Store the float height value in the Red channel of the Color
			image.set_pixel(x, y, Color(height_val, 0.0, 0.0))
	
	if save_png:
		image.save_png(save_path)
		print("Image saved to ", save_path)
	return image

# Visualize the erosion/deposition heatmap
func show_erosion_heatmap():
	if not have_eroded or animation_running:
		return

	showing_erosion_heatmap = true

	var image = Image.create_empty(map_size, map_size, false, Image.FORMAT_RGBA8)
	var max_abs = 0.0
	for i in range(erosion_heatmap.size()):
		max_abs = max(max_abs, abs(erosion_heatmap[i]))
	if max_abs < 1e-6:
		max_abs = 1.0
	for y in range(map_size):
		for x in range(map_size):
			var n_x = clamp(x + hydraulic_erosion_node.erosion_brush_radius, 0, mapSizeWithBorder - 1)
			var n_y = clamp(y + hydraulic_erosion_node.erosion_brush_radius, 0, mapSizeWithBorder - 1)
			var index = (n_y) * mapSizeWithBorder + (n_x)
			var v = erosion_heatmap[index] / max_abs
			# Red = erosion, Blue = deposition, Black = none
			var color = Color(0,0,0,1)
			if v > 0.0:
				color = Color(0.0, 0.0, min(1.0, v), 1.0) # Blue for deposition
			elif v < 0.0:
				color = Color(min(1.0, -v), 0.0, 0.0, 1.0) # Red for erosion
			image.set_pixel(x, y, color)
	var tex = ImageTexture.create_from_image(image)
	material.set_shader_parameter("visual_texture", tex)
	material.set_shader_parameter("use_visual_texture", true)

func clear_visual_overlay():
	material.set_shader_parameter("use_visual_texture", false)
	showing_erosion_heatmap = false
