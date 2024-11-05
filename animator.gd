@tool
class_name Animator extends Node
const GROUP: StringName = &"animator"
const SIGNAL_HIDE: StringName = GROUP + &"_hide"
const SIGNAL_SHOW: StringName = GROUP + &"_show"
const SIGNAL_FINISHED: StringName = GROUP + &"_finished"


@export_custom(0,"", PROPERTY_USAGE_EDITOR)
var visible: bool = true:
	set(val):
		visible = val
		if visible and elapsed == 0.0: return
		set_process(true)
		

@export_category("Tweening")
@export var side: Side = SIDE_LEFT:
	set(val):
		side = val
		axis = side % 2
		calculate_delta()


@export_range(0.1, 5.0, 0.1, "or_greater", "suffix:sec", ) 
var duration: float = 1.0:
	set(val): duration = val; set_elapsed(elapsed)

@export_range(0.1, 3.0, 0.05, "or_greater",  ) 
var hide_time_scale: float = 1.5

@export_group("Position")
@export var trans_type: Tween.TransitionType = Tween.TRANS_BACK
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT


@export_group("Scale")

@export var min_scale: float = 1.0
@export var trans_type_scale: Tween.TransitionType = Tween.TRANS_BACK
@export var ease_type_scale: Tween.EaseType = Tween.EASE_IN_OUT

var parent: Control: set = set_parent
var rect: ReferenceRect = ReferenceRect.new()

var screen:= Vector2(ProjectSettings["display/window/size/viewport_width"], ProjectSettings["display/window/size/viewport_height"])

var axis : int = Vector2.AXIS_X

@export_category("Debug")
@export var debug_rect_visible: bool = true:
	set(val): debug_rect_visible = val; rect.visible = val;
	
var offset: float = 0.0
@export var max_scale: float = 1.0

@export_custom(0, "", PROPERTY_USAGE_EDITOR)
var elapsed: float = 0.0: set = set_elapsed

#var rid: RID

func _init() -> void:
	set_process(false)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.border_color = Color(Color.FUCHSIA, 0.8)
	rect.border_width = 1.0
	add_child(rect, false, Node.INTERNAL_MODE_FRONT)
	
func show() -> void:
	visible = true
func hide() -> void:
	visible = false


func _process(delta: float) -> void:
	elapsed = elapsed - delta if visible else elapsed + (delta * hide_time_scale)
	if (visible and elapsed == 0.0) or (not visible and elapsed == duration):
		set_process(false)

#func _physics_process(delta: float) -> void:
	#align_rect()
	
func calculate_delta() -> void:
	offset = -rect.global_position[axis] - (rect.size[axis] * min_scale) if side < 2 else screen[axis] - rect.global_position[axis]
	set_elapsed(elapsed)


func align_rect() -> void:
	if not parent: return
	var delta_changed: bool = false
	
	
	if rect.size != parent.size:
		rect.size = parent.size
		delta_changed = true
	
	
	if elapsed == 0.0 and rect.global_position != parent.global_position:
		rect.global_position = parent.global_position
		delta_changed = true
		
	if delta_changed: 
		calculate_delta()


func set_elapsed(val: float) -> void:
	elapsed = clampf(val, 0.0, duration)
	if not parent: return
	parent.visible = elapsed != duration or Engine.is_editor_hint()
	parent.global_position[axis^1] = rect.global_position[axis^1]
	parent.global_position[axis] = Tween.interpolate_value(rect.global_position[axis], offset, elapsed, duration, trans_type, ease_type)
	if min_scale < max_scale:
		parent.scale[axis^1] = max_scale
		parent.scale[axis] = Tween.interpolate_value(max_scale, min_scale - max_scale, elapsed, duration, trans_type_scale, ease_type_scale)

func set_parent(val: Control) -> void:
	if is_instance_valid(parent):
		parent.disconnect(&"resized", _on_parent_resize)
		parent.remove_meta(GROUP)
		for signal_name : StringName in [SIGNAL_HIDE, SIGNAL_SHOW, SIGNAL_FINISHED]:
			parent.remove_user_signal(signal_name)
	
	parent = val
	
	if parent:
		parent.set_meta(GROUP, self as Animator)
		parent.connect(&"resized", _on_parent_resize)
		for signal_name : StringName in [SIGNAL_HIDE, SIGNAL_SHOW, SIGNAL_FINISHED]:
			parent.add_user_signal(signal_name)
		parent.connect(SIGNAL_HIDE, hide)
		parent.connect(SIGNAL_SHOW, show)
			#var callable:= Callable(self, signal_name.trim_prefix(GROUP + "_"))
			#if callable.is_valid() and not parent.is_connected(signal_name, callable):
				#parent.connect(signal_name, callable)
			
		align_rect()
		calculate_delta()
		
	rect.visible = parent != null and debug_rect_visible


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PARENTED:
			parent = get_parent() as Control
		NOTIFICATION_UNPARENTED:
			parent = null
			elapsed = 0.0
		NOTIFICATION_PHYSICS_PROCESS:
			align_rect()
		NOTIFICATION_EDITOR_PRE_SAVE:
			print("Pre save called!")
		NOTIFICATION_READY:
			#rid = RenderingServer.canvas_item_create()
			#RenderingServer.canvas_item_set_parent(rid, get_viewport().world_2d.canvas)
			if not Engine.is_editor_hint():
				get_window().size_changed.connect(_on_window_size_changed)
				_on_window_size_changed()
				
				#create_tween().set_loops(0).tween_callback(align_rect).set_delay(0.1)
		


func _on_parent_resize() -> void:
	calculate_delta()

#func redraw()->void:
	#RenderingServer.canvas_item_clear(rid)
	#if not parent: return
	#var r:= parent.get_global_rect()
	#RenderingServer.canvas_item_add_polyline(rid, [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position], [Color.DIM_GRAY],)
	#RenderingServer.canvas_item_add_polyline(rid, [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position], [Color.DIM_GRAY],)

func _on_window_size_changed() -> void:
	screen = rect.get_viewport_rect().size
	calculate_delta()
	
