extends Node

var rd: RenderingDevice

func _ready() -> void:
	call_deferred("init_rendering_device")

func init_rendering_device():
	# Initialize the RenderingDevice
	rd = RenderingServer.get_rendering_device()
	if not rd:
		printerr("Erosion Node: Failed to get RenderingDevice.")
		return