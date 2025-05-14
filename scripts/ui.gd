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

# Ui buttons
@onready var regen_button: Button = $Panel/Tabs/Noise/Container/Regenerate
@onready var erode_gpu: Button = $Panel/Tabs/Erosion/Container/Erode_GPU
@onready var erosion_anim: Button = $Panel/Tabs/Erosion/Container/Erosion_Anim
@onready var save: Button = $Panel/Tabs/Other/Save

# Other ui
@onready var file_dialog: FileDialog = $Panel/FileDialog
@onready var snow_slope: HSlider = $Panel/Tabs/Other/Snow_slope
@onready var snow_blend: HSlider = $Panel/Tabs/Other/Snow_blend

# Script Nodes
@onready var main: MainClass = $".."
@onready var erosion: Node = $"../Erosion"

func _ready() -> void:
	snow_slope.value = 0.24
	snow_blend.value = 0.3
	
	# Connecting buttons
	regen_button.pressed.connect(regen_button_pressed)
	erode_gpu.pressed.connect(erode_gpu_pressed)
	save.pressed.connect(save_as_png)
	snow_slope.value_changed.connect(_on_snow_slope_value_changed)
	snow_blend.value_changed.connect(_on_snow_blend_value_changed)
	erosion_anim.pressed.connect(main.animated_erosion)
	noise_type_selector.item_selected.connect(on_noise_type_changed)
	
	# Getting file dialog ready
	file_dialog.use_native_dialog = true
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.png ; PNG File"]
	file_dialog.current_file = "heightmap.png"
	file_dialog.file_selected.connect(on_file_dialog_file_selected)
	
	set_noise_ui_from_vars()
	set_erosion_ui_from_vars()

func on_file_dialog_file_selected(path: String):
	print(path)
	main.create_image(main.orignal_map_data,true,path)

func save_as_png():
	file_dialog.popup_centered()

func regen_button_pressed() -> void:
	# Saving the values from the Ui and then generating
	set_noise_vars_from_ui()
	main.generate()
	ui_seed.value = main.Seed

func erode_gpu_pressed():
	main.erode()
	main.create_mesh(main.eroded_map_data)

func set_erosion_ui_from_vars():
	ui_droplets.value = erosion.num_droplets
	ui_max_steps.value = erosion.max_steps
	ui_inertia.value = erosion.inertia
	ui_capacity.value = erosion.capacity_factor
	ui_erode_rate.value = erosion.erode_rate
	ui_deposit_rate.value = erosion.deposit_rate
	ui_evaporate_rate.value = erosion.evaporate_rate
	ui_gravity.value = erosion.gravity
	ui_start_speed.value = erosion.start_speed
	ui_start_water.value = erosion.start_water

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

func set_noise_ui_from_vars():
	ui_mapsize.value       = main.map_size
	ui_seed.value          = main.Seed
	ui_rand.button_pressed = main.randomize_seed
	ui_freq_slider.value   = main.frequency
	ui_gain_slider.value   = main.gain
	ui_lac_slider.value    = main.lacunarity
	ui_octaves.value       = main.num_octaves
	ui_height.value        = main.height_scale

func set_noise_vars_from_ui():
	main.map_size       = ui_mapsize.value
	main.randomize_seed = ui_rand.button_pressed
	main.Seed           = int(ui_seed.value)
	main.frequency      = ui_freq_slider.value
	main.gain           = ui_gain_slider.value
	main.lacunarity     = ui_lac_slider.value
	main.num_octaves    = int(ui_octaves.value)
	main.height_scale   = ui_height.value


func _on_snow_slope_value_changed(value: float) -> void:
	main.material.set_shader_parameter("snow_slope_threshold", value)
	print(main.material)

func _on_snow_blend_value_changed(value: float) -> void:
	main.material.set_shader_parameter("snow_blend_amount", value)
	print(main.material)

func on_noise_type_changed(index: int) -> void:
	# Update the noise type based on the selected index
	match index:
		0: main.noise_type = FastNoiseLite.TYPE_PERLIN
		1: main.noise_type = FastNoiseLite.TYPE_CELLULAR
		2: main.noise_type = FastNoiseLite.TYPE_SIMPLEX
		3: main.noise_type = FastNoiseLite.TYPE_VALUE

