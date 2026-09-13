extends Node
## A fixed PS1 framebuffer; window resizing only changes integer enlargement.

const INTERNAL_SIZE := Vector2i(320, 240)


func _ready() -> void:
	var window := get_window()
	window.min_size = INTERNAL_SIZE
	window.content_scale_size = INTERNAL_SIZE
	window.content_scale_factor = 1.0
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
	window.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	window.msaa_3d = Viewport.MSAA_DISABLED
	window.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	window.use_taa = false
	window.scaling_3d_scale = 1.0
	_attach_compositor.call_deferred()


func _attach_compositor() -> void:
	if RenderingServer.get_rendering_device() == null:
		return
	for environment in get_parent().find_children("*", "WorldEnvironment", true, false):
		environment.compositor = preload("res://resources/render/ps1_compositor.tres")
