extends Camera3D

# Nodes
@onready var main: MainClass = $".."
@onready var heightmap_mesh: MeshInstance3D = $"../HeightmapMesh"

# Fov settings
var fov_zoom_sensitivity: float = 0.05
var max_fov: float = 120.0 
var min_fov: float = 30.0 
var default_fov : float = 70

# Rotating mesh vars
@export var rotate_sensitivity: float = 0.005
var rotating_mesh := false

# Other vars
var ui_width : float
var mouse_pos

func _ready() -> void:
	fov = default_fov
	clamp_fov()
	var viewport_size = get_viewport().get_visible_rect().size
	ui_width = viewport_size.x * 0.2

func _input(event: InputEvent) -> void:
	if event.is_action("go_down") and event.is_pressed():
		position.y -= 2
	elif event.is_action("go_up") and event.is_pressed():
		position.y += 2
	position.y = clamp(position.y, 150,350)

func _unhandled_input(event: InputEvent) -> void:
	mouse_pos = get_viewport().get_mouse_position()
	if event is InputEventMouseButton and mouse_pos.x > ui_width:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					rotating_mesh = true
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				else:
					rotating_mesh = false
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

			MOUSE_BUTTON_WHEEL_UP:
				fov -= fov * fov_zoom_sensitivity
				clamp_fov()

			MOUSE_BUTTON_WHEEL_DOWN:
				fov += fov * fov_zoom_sensitivity
				clamp_fov()

	# Mouse motion when dragging spin around Y
	elif event is InputEventMouseMotion:
		if rotating_mesh:
			heightmap_mesh.rotate_y(event.relative.x * rotate_sensitivity)

func clamp_fov():
	fov = clamp(fov, min_fov, max_fov)

func position_cam():
	position.y = clamp(main.height_scale - 20, 200,320)
