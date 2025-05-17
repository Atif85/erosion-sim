# main.gd
extends Node3D
class_name MainClass

# Defaults parameters
# These are the default parameters for the heightmap generation
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
@onready var ui_class: UiClass = $UI
@onready var erosion_node: Node = $Erosion
@onready var heightmap_mesh: MeshInstance3D = $HeightmapMesh

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
var mapSizeWithBorder : int
var material : Material
var rng : RandomNumberGenerator
var noise : FastNoiseLite

# Erosion animation variables
var is_eroding_animated := false
var animation_start_time_sec : float = 0.0 # Store time in seconds
var animation_duration_sec : float = DEFAULT_ANIMATION_DURATION
var map_for_animation : PackedFloat32Array

func _ready():
	initialize()
	generate()

func _process(_delta):

	if is_eroding_animated:
		var current_time_sec = float(Time.get_ticks_msec()) / 1000.0
		var elapsed_time = current_time_sec - animation_start_time_sec
		var progress = clamp(elapsed_time / animation_duration_sec, 0.0, 1.0)


		for i in range(orignal_map_data.size()):
			map_for_animation[i] = lerp(orignal_map_data[i], eroded_map_data[i], progress)

		create_mesh(map_for_animation)

		if progress >= 1.0:
			print("erosion animation finished.")
			is_eroding_animated = false
			map_for_animation.clear()

func initialize():
	material = heightmap_mesh.get_active_material(0)
	rng = RandomNumberGenerator.new()
	noise = FastNoiseLite.new()

func generate():
	mapSizeWithBorder = map_size + erosion_node.erosion_brush_radius * 2
	orignal_map_data = create_map(mapSizeWithBorder)

	create_mesh(orignal_map_data)
	eroded_map_data = orignal_map_data.duplicate()

func erode():
	var time_start_erode = Time.get_ticks_usec()

	ui_class.set_erosion_vars_from_ui()
	eroded_map_data = erosion_node.erode_with_gpu(orignal_map_data, mapSizeWithBorder)
	
	var time_end_erode = Time.get_ticks_usec()
	print("erosion process took ",(time_end_erode - time_start_erode)/ 1000000.0," seconds")

func animated_erosion():
	if is_eroding_animated:
		print("Animation already in progress.")
		return

	print("Starting animated erosion_node...")
	is_eroding_animated = true

	erode()

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
			map[y * map_size_in + x] = (v + 1.0) * 0.5
	
	var time_end_erode = Time.get_ticks_usec()
	print("Map create from noise in ",(time_end_erode - time_start_erode)/ 1000000.0," seconds")
	return map
	

func create_image(heightmap_data : PackedFloat32Array ,save_png : bool = false, save_path : String = "") -> Image:
	var image = Image.create_empty(map_size, map_size, false, Image.FORMAT_RF)
	for y in range(map_size):
		for x in range(map_size):
			var n_x = clamp(x + erosion_node.erosion_brush_radius, 0 , mapSizeWithBorder - 1)
			var n_y = clamp(y + erosion_node.erosion_brush_radius, 0 , mapSizeWithBorder - 1)
			var index =  (n_y) * mapSizeWithBorder + (n_x)
			var height_val = heightmap_data[index]
			# Store the float height value in the Red channel of the Color
			image.set_pixel(x, y, Color(height_val, 0.0, 0.0))
	
	if save_png:
		image.save_png(save_path)
		print("Image saved to ", save_path)
	return image
