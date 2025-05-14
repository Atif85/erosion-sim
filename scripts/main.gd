extends Node3D
class_name MainClass

# Nodes
@onready var ui_class: UiClass = $UI
@onready var erosion: Node = $Erosion
@onready var heightmap_mesh: MeshInstance3D = $HeightmapMesh
@onready var camera: Camera3D = $Camera

# Variables for the heightmap
@export var map_size = 256
@export var height_scale = 200.0
@export var Seed: int = 100
@export var randomize_seed: bool = true
@export var num_octaves: int = 7
@export var gain: float = 0.4
@export var lacunarity: float = 2.0
@export var frequency : float = 2.0

var heightmap_data : PackedFloat32Array = PackedFloat32Array()
var material : Material
var rng : RandomNumberGenerator


func _ready():
	material = heightmap_mesh.get_active_material(0)
	rng = RandomNumberGenerator.new()
	generate()

func generate():
	heightmap_data = create_map()
	create_mesh()

func create_mesh():
	# Generating the mesh
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(map_size, map_size)
	plane_mesh.subdivide_width = map_size - 1
	plane_mesh.subdivide_depth = map_size - 1
	
	heightmap_mesh.set_mesh(plane_mesh)
	
	# Converting heightmap data to a Texture
	var image = create_image()
	var heightmap_texture = ImageTexture.create_from_image(image)

	# Set Shader Parameters
	material.set_shader_parameter("heightmap_texture", heightmap_texture)
	material.set_shader_parameter("height_scale", height_scale)
	material.set_shader_parameter("pixel_size", Vector2(1.0 / float(map_size), 1.0 / float(map_size)))
	material.set_shader_parameter("map_size_uniform", float(map_size))

	# Position the mesh correctly based on its size
	heightmap_mesh.position = Vector3(int(map_size/2.0),0,int(map_size/2.0))
	camera.position_cam()

func create_map() -> PackedFloat32Array:
	var time_start_erode = Time.get_ticks_usec()
	# Configure noise once
	if randomize_seed:
		rng.randomize()
		Seed = rng.randi_range(-100000, 100000)

	var noise := FastNoiseLite.new()
	noise.seed               = Seed 
	noise.noise_type         = FastNoiseLite.TYPE_PERLIN
	noise.fractal_type       = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves    = num_octaves
	noise.fractal_gain       = gain
	noise.fractal_lacunarity = lacunarity
	noise.frequency          = frequency
	
	var map = PackedFloat32Array()
	map.resize(map_size * map_size)
	for y in range(map_size):
		for x in range(map_size):
			# Sample at normalized coords
			var v = noise.get_noise_2d(x / float(map_size), y / float(map_size))
			# Remap from [-1,1] to [0,1]
			map[y * map_size + x] = (v + 1.0) * 0.5
	
	var time_end_erode = Time.get_ticks_usec()
	print("Map create from noise in ",(time_end_erode - time_start_erode)/ 1000000.0," seconds")
	return map
	

func create_image(save_png : bool = false, save_path : String = "") -> Image:
	var image = Image.create_empty(map_size, map_size, false, Image.FORMAT_RF)
	for y in range(map_size):
		for x in range(map_size):
			var height_val = heightmap_data[y * map_size + x]
			# Store the float height value in the Red channel of the Color
			image.set_pixel(x, y, Color(height_val, 0.0, 0.0))
	
	if save_png:
		image.save_png(save_path)

	return image
