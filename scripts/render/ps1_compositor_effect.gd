@tool
extends CompositorEffect
class_name Ps1CompositorEffect
## Copy first: chromatic neighbour reads must never race in-place writes.

const POST_SHADER = preload("res://shaders/ps1_post.glsl")
var _rd: RenderingDevice
var _shader: RID
var _pipeline: RID
var _mutex := Mutex.new()
var _settings := Vector4(1.0, 0.18, 0.012, -1.0)


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	_rd = RenderingServer.get_rendering_device()


func configure(dither: float, chroma: float, grain: float, fixed_phase: float = -1.0) -> void:
	_mutex.lock()
	_settings = Vector4(clampf(dither, 0.0, 1.0), clampf(chroma, 0.0, 1.0),
		clampf(grain, 0.0, 0.1), fixed_phase)
	_mutex.unlock()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _rd != null and _shader.is_valid():
		_rd.free_rid(_shader)


func _render_callback(callback_type: int, render_data: RenderData) -> void:
	if _rd == null or callback_type != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:
		return
	if not _shader.is_valid():
		_shader = _rd.shader_create_from_spirv(POST_SHADER.get_spirv())
		_pipeline = _rd.compute_pipeline_create(_shader)
	if not _pipeline.is_valid():
		return
	var buffers := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers == null:
		return
	var size := buffers.get_internal_size()
	if size.x <= 0 or size.y <= 0:
		return
	_mutex.lock()
	var settings := _settings
	_mutex.unlock()
	var phase: float = settings.w if settings.w >= 0.0 else floorf(Time.get_ticks_msec() * 0.015)
	for view in buffers.get_view_count():
		var color := buffers.get_color_layer(view)
		var scratch := buffers.create_texture(&"outpost_ps1", StringName("source_%d" % view),
			RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, RenderingDevice.TEXTURE_USAGE_STORAGE_BIT,
			RenderingDevice.TEXTURE_SAMPLES_1, size, 1, 1, false, false)
		_dispatch(color, scratch, size, phase, 0.0, settings)
		_dispatch(scratch, color, size, phase, 1.0, settings)


func _dispatch(source: RID, target: RID, size: Vector2i, phase: float,
		pass_index: float, settings: Vector4) -> void:
	var source_uniform := RDUniform.new()
	source_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	source_uniform.binding = 0
	source_uniform.add_id(source)
	var target_uniform := RDUniform.new()
	target_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	target_uniform.binding = 1
	target_uniform.add_id(target)
	var uniforms := UniformSetCacheRD.get_cache(_shader, 0, [source_uniform, target_uniform])
	var constants := PackedFloat32Array([size.x, size.y, phase, pass_index,
		settings.x, settings.y, settings.z, 31.0]).to_byte_array()
	var compute_list := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(compute_list, _pipeline)
	_rd.compute_list_bind_uniform_set(compute_list, uniforms, 0)
	_rd.compute_list_set_push_constant(compute_list, constants, constants.size())
	_rd.compute_list_dispatch(compute_list, ceili(size.x / 8.0), ceili(size.y / 8.0), 1)
	_rd.compute_list_end()
