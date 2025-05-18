extends CanvasLayer

# -- Noise ui node paths --
@onready var ui_mapsize: SpinBox = $Panel/Tabs/Noise/VBox/Mapsize
@onready var ui_seed: SpinBox = $Panel/Tabs/Noise/VBox/Seed
@onready var ui_rand: CheckBox = $Panel/Tabs/Noise/VBox/Rand_seed
@onready var ui_freq_slider: SpinBox = $Panel/Tabs/Noise/VBox/Freq_slider
@onready var ui_gain_slider: SpinBox = $Panel/Tabs/Noise/VBox/Gain_slider
@onready var ui_lac_slider: SpinBox = $Panel/Tabs/Noise/VBox/Lacunarity_slider
@onready var ui_octaves: SpinBox = $Panel/Tabs/Noise/VBox/Octaves
@onready var ui_height: HSlider = $Panel/Tabs/Noise/VBox/Height
@onready var ui_height_label: Label = $Panel/Tabs/Noise/VBox/Height_label
@onready var noise_type_selector: OptionButton = $Panel/Tabs/Noise/VBox/Noise_type

# -- Erosion ui node paths --
# Hydraulic erosion
@onready var ui_droplets: SpinBox = $Panel/Tabs/Erosion/Hydraulic/VBox/Droplets
@onready var ui_max_steps: SpinBox = $Panel/Tabs/Erosion/Hydraulic/VBox/Max_steps
@onready var ui_inertia: SpinBox = $Panel/Tabs/Erosion/Hydraulic/VBox/Inertia
@onready var ui_capacity: SpinBox = $Panel/Tabs/Erosion/Hydraulic/VBox/Capacity
@onready var ui_erode_rate: SpinBox = $Panel/Tabs/Erosion/Hydraulic/VBox/Erode_rate
@onready var ui_deposit_rate: SpinBox = $Panel/Tabs/Erosion/Hydraulic/VBox/Deposit_rate
@onready var ui_evaporate_rate: SpinBox = $Panel/Tabs/Erosion/Hydraulic/VBox/Evaporate_rate
@onready var ui_gravity: SpinBox = $Panel/Tabs/Erosion/Hydraulic/VBox/Gravity
@onready var ui_start_speed: SpinBox = $Panel/Tabs/Erosion/Hydraulic/VBox/Start_speed
@onready var ui_start_water: SpinBox = $Panel/Tabs/Erosion/Hydraulic/VBox/Start_water
@onready var ui_erosion_radius: SpinBox = $Panel/Tabs/Erosion/Hydraulic/VBox/Erosion_radius
@onready var anim_length: SpinBox = $Panel/Tabs/Other/VBox/Erosion_anim_length

# -- Ui buttons --
@onready var regen_noise_button: Button = $Panel/Tabs/Noise/VBox/Regenerate
@onready var hydraulic_erode: Button = $Panel/Tabs/Erosion/Hydraulic/VBox/Erode_GPU
@onready var animate_button: Button = $Panel/Tabs/Erosion/Hydraulic/VBox/Erosion_Anim
@onready var save: Button = $Panel/Tabs/Other/VBox/Save
@onready var set_defaults: Button =  $Panel/Tabs/Other/VBox/Set_defaults

@onready var show_heatmap_button: Button = $Panel/Tabs/Other/VBox/Show_Heatmap
@onready var clear_overlay_button: Button = $Panel/Tabs/Other/VBox/Clear_Overlay

# -- Other ui node paths --
@onready var snow_slope: HSlider = $Panel/Tabs/Other/VBox/Snow_slope
@onready var snow_blend: HSlider = $Panel/Tabs/Other/VBox/Snow_blend
@onready var snow_color: ColorPickerButton = $Panel/Tabs/Other/VBox/Snow_color
@onready var rock_color: ColorPickerButton = $Panel/Tabs/Other/VBox/Rock_color

# -- File dialog --
@onready var file_dialog: FileDialog = $Panel/FileDialog

# Script Nodes
@onready var main: MainClass = $".."
@onready var hydraulic_erosion: Node = $"../Erosion/Hydraulic"

# -- Default values --
const SNOW_COLOR :=  Color(0.9, 0.9, 0.85, 1.0)
const ROCK_COLOR := Color(0.06, 0.06, 0.1, 1.0)


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
	ui_height_label.text   = "Height Scale: " + str(main.DEFAULT_HEIGHT_SCALE)
	noise_type_selector.selected = 0
	
	# hydraulic_erosion ui
	ui_droplets.value       = hydraulic_erosion.DEFAULT_NUM_DROPLETS
	ui_max_steps.value      = hydraulic_erosion.DEFAULT_MAX_STEPS
	ui_inertia.value        = hydraulic_erosion.DEFAULT_INERTIA
	ui_capacity.value       = hydraulic_erosion.DEFAULT_CAPACITY_FACTOR
	ui_erode_rate.value     = hydraulic_erosion.DEFAULT_ERODE_RATE
	ui_deposit_rate.value   = hydraulic_erosion.DEFAULT_DEPOSIT_RATE
	ui_evaporate_rate.value = hydraulic_erosion.DEFAULT_EVAPORATE_RATE
	ui_gravity.value        = hydraulic_erosion.DEFAULT_GRAVITY
	ui_start_speed.value    = hydraulic_erosion.DEFAULT_START_SPEED
	ui_start_water.value    = hydraulic_erosion.DEFAULT_START_WATER
	ui_erosion_radius.value = hydraulic_erosion.DEFAULT_EROSION_BRUSH_RADIUS

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

	# hydraulic_erosion vars
	hydraulic_erosion.num_droplets       = hydraulic_erosion.DEFAULT_NUM_DROPLETS
	hydraulic_erosion.max_steps          = hydraulic_erosion.DEFAULT_MAX_STEPS
	hydraulic_erosion.inertia            = hydraulic_erosion.DEFAULT_INERTIA
	hydraulic_erosion.capacity_factor    = hydraulic_erosion.DEFAULT_CAPACITY_FACTOR
	hydraulic_erosion.erode_rate         = hydraulic_erosion.DEFAULT_ERODE_RATE
	hydraulic_erosion.deposit_rate       = hydraulic_erosion.DEFAULT_DEPOSIT_RATE
	hydraulic_erosion.evaporate_rate     = hydraulic_erosion.DEFAULT_EVAPORATE_RATE
	hydraulic_erosion.gravity            = hydraulic_erosion.DEFAULT_GRAVITY
	hydraulic_erosion.start_speed        = hydraulic_erosion.DEFAULT_START_SPEED
	hydraulic_erosion.start_water        = hydraulic_erosion.DEFAULT_START_WATER
	hydraulic_erosion.erosion_brush_radius = hydraulic_erosion.DEFAULT_EROSION_BRUSH_RADIUS

	# Setting default values for snow vars
	snow_slope.value = 0.24
	snow_blend.value = 0.3
	snow_color.color = SNOW_COLOR
	rock_color.color = ROCK_COLOR

	# Setting default values for animation
	anim_length.value = main.DEFAULT_ANIMATION_DURATION
	# Setting default values for hydraulic_erosion animation
	main.animation_duration_sec = main.DEFAULT_ANIMATION_DURATION
