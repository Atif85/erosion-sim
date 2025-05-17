# ui.gd
extends CanvasLayer
class_name UiClass

# Noise ui nodes
@onready var ui_mapsize: SpinBox = $Panel/Tabs/Noise/Container/Mapsize
@onready var ui_seed: SpinBox = $Panel/Tabs/Noise/Container/Seed
@onready var ui_rand: CheckBox = $Panel/Tabs/Noise/Container/Rand_seed
@onready var ui_freq_slider: SpinBox = $Panel/Tabs/Noise/Container/Freq_slider
@onready var ui_gain_slider: SpinBox = $Panel/Tabs/Noise/Container/Gain_slider
@onready var ui_lac_slider: SpinBox = $Panel/Tabs/Noise/Container/Lacunarity_slider
@onready var ui_octaves: SpinBox = $Panel/Tabs/Noise/Container/Octaves
@onready var ui_height: SpinBox = $Panel/Tabs/Noise/Container/Height

@onready var noise_type_selector: OptionButton = $Panel/Tabs/Noise/Container/Noise_type
@onready var erosion_anim_length: SpinBox = $Panel/Tabs/Other/Erosion_anim_length

# Erosion ui nodes
@onready var ui_droplets: SpinBox = $Panel/Tabs/Erosion/Container/Droplets
@onready var ui_max_steps: SpinBox = $Panel/Tabs/Erosion/Container/Max_steps
@onready var ui_inertia: SpinBox = $Panel/Tabs/Erosion/Container/Inertia
@onready var ui_capacity: SpinBox = $Panel/Tabs/Erosion/Container/Capacity
@onready var ui_erode_rate: SpinBox = $Panel/Tabs/Erosion/Container/Erode_rate
@onready var ui_deposit_rate: SpinBox = $Panel/Tabs/Erosion/Container/Deposit_rate
@onready var ui_evaporate_rate: SpinBox = $Panel/Tabs/Erosion/Container/Evaporate_rate
@onready var ui_gravity: SpinBox = $Panel/Tabs/Erosion/Container/Gravity
@onready var ui_start_speed: SpinBox = $Panel/Tabs/Erosion/Container/Start_speed
@onready var ui_start_water: SpinBox = $Panel/Tabs/Erosion/Container/Start_water
@onready var ui_erosion_radius: SpinBox = $Panel/Tabs/Erosion/Container/Erosion_radius

# Ui buttons
@onready var regen_button: Button = $Panel/Tabs/Noise/Container/Regenerate
@onready var erode_gpu: Button = $Panel/Tabs/Erosion/Container/Erode_GPU
@onready var erosion_anim: Button = $Panel/Tabs/Erosion/Container/Erosion_Anim
@onready var save: Button = $Panel/Tabs/Other/Save
@onready var set_defaults: Button =  $Panel/Tabs/Other/Set_defaults

# Other ui
@onready var file_dialog: FileDialog = $Panel/FileDialog
@onready var snow_slope: HSlider = $Panel/Tabs/Other/Snow_slope
@onready var snow_blend: HSlider = $Panel/Tabs/Other/Snow_blend
@onready var snow_color: ColorPickerButton = $Panel/Tabs/Other/Snow_color
@onready var rock_color: ColorPickerButton = $Panel/Tabs/Other/Rock_color

# Script Nodes
@onready var main: MainClass = $".."
@onready var erosion: Node = $"../Erosion"

const SNOW_COLOR :=  Color(0.9, 0.9, 0.85, 1.0)
const ROCK_COLOR := Color(0.06, 0.06, 0.1, 1.0)

func _ready() -> void:
	set_vars_to_default()
	
	# Connecting buttons
	regen_button.pressed.connect(regen_button_pressed)
	erode_gpu.pressed.connect(erode_gpu_pressed)
	save.pressed.connect(save_as_png)
	erosion_anim.pressed.connect(main.animated_erosion)
	set_defaults.pressed.connect(_set_defaults)

	snow_slope.value_changed.connect(_on_snow_slope_value_changed)
	snow_blend.value_changed.connect(_on_snow_blend_value_changed)
	snow_color.color_changed.connect(_on_snow_color_changed)
	rock_color.color_changed.connect(_on_rock_color_changed)

	erosion_anim_length.value_changed.connect(set_animation_duration)
	noise_type_selector.item_selected.connect(on_noise_type_changed)
	
	# Getting file dialog ready
	file_dialog.use_native_dialog = true
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.png ; PNG File"]
	file_dialog.current_file = "heightmap.png"
	file_dialog.file_selected.connect(on_file_dialog_file_selected)

func _set_defaults():
	set_vars_to_default()
	main.material.set_shader_parameter("snow_color", SNOW_COLOR)
	main.material.set_shader_parameter("rock_color", ROCK_COLOR)


func _on_snow_slope_value_changed(value: float) -> void:
	main.material.set_shader_parameter("snow_slope_threshold", value)

func _on_snow_blend_value_changed(value: float) -> void:
	main.material.set_shader_parameter("snow_blend_amount", value)

func _on_snow_color_changed(color: Color) -> void:
	main.material.set_shader_parameter("snow_color", color)

func _on_rock_color_changed(color: Color) -> void:
	main.material.set_shader_parameter("rock_color", color)

func on_noise_type_changed(index: int) -> void:
	# Update the noise type based on the selected index
	match index:
		0: main.noise_type = FastNoiseLite.TYPE_PERLIN
		1: main.noise_type = FastNoiseLite.TYPE_CELLULAR
		2: main.noise_type = FastNoiseLite.TYPE_SIMPLEX
		3: main.noise_type = FastNoiseLite.TYPE_VALUE

func set_animation_duration(value: float) -> void:
	# Set the animation duration in seconds
	main.animation_duration_sec = value

func on_file_dialog_file_selected(path: String):
	print("Heightmap image saved to: ", path)
	main.create_image(main.orignal_map_data,true,path)

func save_as_png():
	file_dialog.popup_centered()

func regen_button_pressed() -> void:
	# Saving the values from the Ui and then generating
	set_noise_vars_from_ui()
	main.generate()
	ui_seed.value = main.Seed

func erode_gpu_pressed():
	if main.is_eroding_animated:
		print("Animation already in progress.")
		return
	main.erode()
	main.create_mesh(main.eroded_map_data)

func set_erosion_vars_from_ui():
	erosion.num_droplets = ui_droplets.value
	erosion.max_steps = ui_max_steps.value
	erosion.inertia = ui_inertia.value
	erosion.capacity_factor = ui_capacity.value
	erosion.erode_rate = ui_erode_rate.value
	erosion.deposit_rate = ui_deposit_rate.value
	erosion.evaporate_rate = ui_evaporate_rate.value
	erosion.gravity = ui_gravity.value
	erosion.start_speed = ui_start_speed.value
	erosion.start_water = ui_start_water.value
	erosion.erosion_brush_radius = ui_erosion_radius.value

func set_noise_vars_from_ui():
	main.map_size       = ui_mapsize.value
	main.randomize_seed = ui_rand.button_pressed
	main.Seed           = int(ui_seed.value)
	main.frequency      = ui_freq_slider.value
	main.gain           = ui_gain_slider.value
	main.lacunarity     = ui_lac_slider.value
	main.num_octaves    = int(ui_octaves.value)
	main.height_scale   = ui_height.value

func set_vars_to_default():
	# Settig ui values to default
	# nosie ui
	ui_mapsize.value       = main.DEFAULT_MAP_SIZE
	ui_seed.value          = main.DEFAULT_SEED
	ui_rand.button_pressed = main.DEFAULT_RANDOMIZE_SEED
	ui_freq_slider.value   = main.DEFAULT_FREQUENCY
	ui_gain_slider.value   = main.DEFAULT_GAIN
	ui_lac_slider.value    = main.DEFAULT_LACUNARITY
	ui_octaves.value       = main.DEFAULT_NUM_OCTAVES
	ui_height.value        = main.DEFAULT_HEIGHT_SCALE
	noise_type_selector.selected = 0
	
	# erosion ui
	ui_droplets.value       = erosion.DEFAULT_NUM_DROPLETS
	ui_max_steps.value      = erosion.DEFAULT_MAX_STEPS
	ui_inertia.value        = erosion.DEFAULT_INERTIA
	ui_capacity.value       = erosion.DEFAULT_CAPACITY_FACTOR
	ui_erode_rate.value     = erosion.DEFAULT_ERODE_RATE
	ui_deposit_rate.value   = erosion.DEFAULT_DEPOSIT_RATE
	ui_evaporate_rate.value = erosion.DEFAULT_EVAPORATE_RATE
	ui_gravity.value        = erosion.DEFAULT_GRAVITY
	ui_start_speed.value    = erosion.DEFAULT_START_SPEED
	ui_start_water.value    = erosion.DEFAULT_START_WATER
	ui_erosion_radius.value = erosion.DEFAULT_EROSION_BRUSH_RADIUS

	# Setting vars to default
	# noise vars
	main.map_size       = main.DEFAULT_MAP_SIZE
	main.randomize_seed = main.DEFAULT_RANDOMIZE_SEED
	main.Seed           = main.DEFAULT_SEED
	main.frequency      = main.DEFAULT_FREQUENCY
	main.gain           = main.DEFAULT_GAIN
	main.lacunarity     = main.DEFAULT_LACUNARITY
	main.num_octaves    = main.DEFAULT_NUM_OCTAVES
	main.height_scale   = main.DEFAULT_HEIGHT_SCALE
	main.noise_type     = main.DEFAULT_NOISE_TYPE

	# erosion vars
	erosion.num_droplets       = erosion.DEFAULT_NUM_DROPLETS
	erosion.max_steps          = erosion.DEFAULT_MAX_STEPS
	erosion.inertia            = erosion.DEFAULT_INERTIA
	erosion.capacity_factor    = erosion.DEFAULT_CAPACITY_FACTOR
	erosion.erode_rate         = erosion.DEFAULT_ERODE_RATE
	erosion.deposit_rate       = erosion.DEFAULT_DEPOSIT_RATE
	erosion.evaporate_rate     = erosion.DEFAULT_EVAPORATE_RATE
	erosion.gravity            = erosion.DEFAULT_GRAVITY
	erosion.start_speed        = erosion.DEFAULT_START_SPEED
	erosion.start_water        = erosion.DEFAULT_START_WATER
	erosion.erosion_brush_radius = erosion.DEFAULT_EROSION_BRUSH_RADIUS

	# Setting default values for snow vars
	snow_slope.value = 0.24
	snow_blend.value = 0.3
	snow_color.color = SNOW_COLOR
	rock_color.color = ROCK_COLOR

	# Setting default values for animation
	erosion_anim_length.value = main.DEFAULT_ANIMATION_DURATION
	# Setting default values for erosion animation
	main.animation_duration_sec = main.DEFAULT_ANIMATION_DURATION
