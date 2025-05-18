# ui.gd
extends "res://scripts/ui_base.gd"
class_name ErosionUiManager

func _ready() -> void:
	set_vars_to_default()
	
	# Connecting buttons
	regen_noise_button.pressed.connect(_regen_noise_pressed)
	hydraulic_erode.pressed.connect(hydraulic_erode_pressed)
	save.pressed.connect(save_as_png)
	animate_button.pressed.connect(play_lerp_animation_pressed)
	set_defaults.pressed.connect(_set_all_defaults)
	show_heatmap_button.pressed.connect(_on_show_heatmap_pressed)
	clear_overlay_button.pressed.connect(_on_clear_overlay_pressed)

	# Connecting ui elements
	ui_height.value_changed.connect(_ui_height_value_changed)

	snow_slope.value_changed.connect(_on_snow_slope_value_changed)
	snow_blend.value_changed.connect(_on_snow_blend_value_changed)
	snow_color.color_changed.connect(_on_snow_color_changed)
	rock_color.color_changed.connect(_on_rock_color_changed)

	anim_length.value_changed.connect(_on_animation_duration_changed)
	noise_type_selector.item_selected.connect(_on_noise_type_changed)
	
	# Getting file dialog ready
	file_dialog.use_native_dialog = true
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.png ; PNG File"]
	file_dialog.current_file = "heightmap.png"
	file_dialog.file_selected.connect(on_file_dialog_file_selected)


func _set_all_defaults():
	set_vars_to_default()
	main.material.set_shader_parameter("snow_color", SNOW_COLOR)
	main.material.set_shader_parameter("rock_color", ROCK_COLOR)

func _ui_height_value_changed(value: float) -> void:
	ui_height_label.text = "Height Scale: " + str(value)
	main.height_scale = value
	main.material.set_shader_parameter("height_scale", value)

func _on_noise_type_changed(index: int) -> void:
	# Update the noise type based on the selected index
	match index:
		0: main.noise_type = FastNoiseLite.TYPE_PERLIN
		1: main.noise_type = FastNoiseLite.TYPE_CELLULAR
		2: main.noise_type = FastNoiseLite.TYPE_SIMPLEX
		3: main.noise_type = FastNoiseLite.TYPE_VALUE

func _on_animation_duration_changed(value: float) -> void:
	# Set the animation duration in seconds
	main.animation_duration_sec = value

func on_file_dialog_file_selected(path: String):
	print("Heightmap image saved to: ", path)
	main.create_image(main.orignal_map_data,true,path)

func save_as_png():
	file_dialog.popup_centered()



# Snow and rock shader parameters
func _on_snow_slope_value_changed(value: float) -> void:
	main.material.set_shader_parameter("snow_slope_threshold", value)

func _on_snow_blend_value_changed(value: float) -> void:
	main.material.set_shader_parameter("snow_blend_amount", value)

func _on_snow_color_changed(color: Color) -> void:
	main.material.set_shader_parameter("snow_color", color)

func _on_rock_color_changed(color: Color) -> void:
	main.material.set_shader_parameter("rock_color", color)



func _regen_noise_pressed() -> void:
	if main.animation_running:
		print("Animation already in progress.")
		return
	# Saving the values from the Ui and then generating
	set_noise_vars_from_ui()
	main.generate()
	ui_seed.value = main.Seed

func hydraulic_erode_pressed():
	if main.animation_running:
		print("Animation already in progress.")
		return
	set_hydraulic_erosion_vars_from_ui()
	main.hydraulic_erode()
	main.create_mesh(main.eroded_map_data)

func play_lerp_animation_pressed():
	set_hydraulic_erosion_vars_from_ui()
	main.play_lerp_animation()



func _on_show_heatmap_pressed():
	main.show_erosion_heatmap()

func _on_clear_overlay_pressed():
	main.clear_visual_overlay()


# Set the noise variables from the UI
func set_noise_vars_from_ui():
	main.map_size       = ui_mapsize.value
	main.randomize_seed = ui_rand.button_pressed
	main.Seed           = int(ui_seed.value)
	main.frequency      = ui_freq_slider.value
	main.gain           = ui_gain_slider.value
	main.lacunarity     = ui_lac_slider.value
	main.num_octaves    = int(ui_octaves.value)

func set_hydraulic_erosion_vars_from_ui():
	hydraulic_erosion.num_droplets = ui_droplets.value
	hydraulic_erosion.max_steps = ui_max_steps.value
	hydraulic_erosion.inertia = ui_inertia.value
	hydraulic_erosion.capacity_factor = ui_capacity.value
	hydraulic_erosion.erode_rate = ui_erode_rate.value
	hydraulic_erosion.deposit_rate = ui_deposit_rate.value
	hydraulic_erosion.evaporate_rate = ui_evaporate_rate.value
	hydraulic_erosion.gravity = ui_gravity.value
	hydraulic_erosion.start_speed = ui_start_speed.value
	hydraulic_erosion.start_water = ui_start_water.value
	hydraulic_erosion.erosion_brush_radius = ui_erosion_radius.value
