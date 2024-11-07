@tool
class_name Animator extends Node
const GROUP: StringName = &"animator"

const SIGNAL_HIDE: StringName = GROUP + &"_hide"
const SIGNAL_SHOW: StringName = GROUP + &"_show"
const SIGNAL_FINISHED: StringName = GROUP + &"_finished"

const DEBUG_COLOR: Color = Color(1, 0.4118, 0.7059, 0.5)

var visible: bool = true:
	set(val):
		visible = val
		if visible and elapsed == 0.0: return
		set_process(parent != null)


@export_category("Tweening")

@export_custom(PROPERTY_HINT_ENUM, "Left Side:0,Top Side:1,Right Side:2,Bottom Side:3,Custom Rect:4") 
var side: Side = SIDE_LEFT:
	set(val):
		side = val
		if side == 4:
			visible_rect.queue_redraw.call_deferred()
			update_pivot()
			return
		
		
		axis = side % 2
		update_pivot()
		calculate_delta()


@export_range(0.1, 5.0, 0.1, "or_greater", "suffix:sec", )
var duration: float = 1.0:
	set(val): duration = val; set_elapsed(elapsed);

@export_range(0.1, 3.0, 0.05, "or_greater", )
var hide_time_scale: float = 1.5

@export var trans_type: Tween.TransitionType = Tween.TRANS_BACK
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT

@export var hide_on_finish: bool = true

@export_group("Scale")

@export_range(0.05, 1.0, 0.05,) var min_scale: float = 0.3:
	set(val): min_scale = clampf(val, 0.01, max_scale); set_elapsed(elapsed);
	
@export_range(0.1, 2.0, 0.1, "or_greater") var max_scale: float = 1.0:
	set(val): max_scale = maxf(val, min_scale)

@export var scale_both_axis: bool = true
@export var auto_adjust_pivot: bool = true

@export var trans_type_scale: Tween.TransitionType = Tween.TRANS_BACK
@export var ease_type_scale: Tween.EaseType = Tween.EASE_IN_OUT

var parent: Control: set = set_parent
var visible_rect: ReferenceRect = ReferenceRect.new()

var target: ReferenceRect: set = set_target

var screen: Vector2 = Vector2(ProjectSettings["display/window/size/viewport_width"], ProjectSettings["display/window/size/viewport_height"])
var axis: int = Vector2.AXIS_X

@export_category("Debug")
@export var debug_rect_visible: bool = true:
	set(val): debug_rect_visible = val; visible_rect.visible = val;

var offset: float = 0.0


@export_custom(0, "", PROPERTY_USAGE_EDITOR) 
var elapsed: float = 0.0: set = set_elapsed
var delay_sec: float = 0.0


func _init() -> void:
	set_process(false)
	
	visible_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible_rect.border_color = Color(1, 0.4118, 0.7059, 0.5)
	visible_rect.border_width = 2.0
	add_child(visible_rect, false, Node.INTERNAL_MODE_DISABLED)
	
	
	target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.border_color = Color(1, 0.4118, 0.7059, 0.5)
	target.border_width = 2.0
	target.name = &"TargetRect"
	#target.call_deferred.connect(&"tree_entered")
	add_child(target, true, Node.INTERNAL_MODE_DISABLED)
	




func show(delay_sec: float = 0.0) -> void:
	self.delay_sec = delay_sec
	visible = true

func hide() -> void:
	visible = false


func _process(delta: float) -> void:
	if delay_sec > 0.0:
		delay_sec -= maxf(0.0, delta)
		return
	
	
	
	elapsed = elapsed - delta if visible else elapsed + (delta * hide_time_scale)
	if (visible and elapsed == 0.0) or (not visible and elapsed == duration):
		set_process(false)


func _physics_process(delta: float) -> void:
	if side == 4:
		pass
		return
		
	align_rect()


func calculate_delta() -> void:
	if not parent: return
	offset = -visible_rect.global_position[axis] - (visible_rect.size[axis] * min_scale) if side < 2 else screen[axis] - visible_rect.global_position[axis]
	set_elapsed(elapsed)


func align_rect() -> void:
	if not parent: return
	var is_changed: bool
	if visible_rect.size != parent.size:
		visible_rect.size = parent.size
		update_pivot()
		is_changed = true
	
	if elapsed == 0.0 and visible_rect.global_position != parent.global_position:
		visible_rect.global_position = parent.global_position
		is_changed = true
	
	if is_changed:
		calculate_delta()


func update_pivot() -> void:
	if not auto_adjust_pivot or not parent: return
	#TODO 
	parent.pivot_offset.x = parent.size.x * 0.5 if side % 2 == 1 else parent.size.x * float(side == SIDE_RIGHT)
	parent.pivot_offset.y = parent.size.y * 0.5 if side % 2 == 0 else parent.size.y * float(side == SIDE_BOTTOM)


func set_elapsed(val: float) -> void:
	elapsed = clampf(val, 0.0, duration)
	if not parent or not parent.is_node_ready(): return
	parent.visible = elapsed != duration or Engine.is_editor_hint() or not hide_on_finish
	
	if side == 4:
		parent.global_position = Tween.interpolate_value(visible_rect.global_position, target.global_position - visible_rect.global_position, elapsed, duration, trans_type, ease_type)
		parent.scale = Tween.interpolate_value(visible_rect.scale, visible_rect.scale - target.scale, elapsed, duration, trans_type, ease_type)
		parent.rotation = Tween.interpolate_value(visible_rect.rotation, visible_rect.rotation - target.rotation, elapsed, duration, trans_type, ease_type)
		parent.size = Tween.interpolate_value(visible_rect.size, visible_rect.size - target.size, elapsed, duration, trans_type, ease_type)
		return
		
	
	parent.global_position[axis ^ 1] = visible_rect.global_position[axis ^ 1]
	parent.global_position[axis] = Tween.interpolate_value(visible_rect.global_position[axis], offset, elapsed, duration, trans_type, ease_type)

	if min_scale < max_scale:
		parent.scale[axis] = Tween.interpolate_value(max_scale, min_scale - max_scale, elapsed, duration, trans_type_scale, ease_type_scale)
		parent.scale[axis ^ 1] = parent.scale[axis] if scale_both_axis else max_scale
		parent.global_position[axis ^ 1] = visible_rect.global_position[axis ^ 1] + (max_scale - parent.scale[axis ^ 1]) * visible_rect.size[axis ^ 1] / 2.0


func set_parent(val: Control) -> void:
	if parent:
		for signal_name: StringName in [SIGNAL_HIDE, SIGNAL_SHOW, SIGNAL_FINISHED]:
			parent.remove_user_signal(signal_name)
	
	parent = val
	
	if parent:
		for signal_name: StringName in [SIGNAL_HIDE, SIGNAL_SHOW, SIGNAL_FINISHED]:
			parent.add_user_signal(signal_name, [ {name=&"delay_sec", type=TYPE_FLOAT}] if signal_name == SIGNAL_SHOW else [])
		parent.connect(SIGNAL_HIDE, hide)
		parent.connect(SIGNAL_SHOW, show)
		
		align_rect()
	
	visible_rect.visible = parent != null and debug_rect_visible

func set_target(val: ReferenceRect) -> void:
	if not val: return
	target = val
	
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PARENTED when get_parent().is_node_ready():
			set_parent.call_deferred(get_parent())
		NOTIFICATION_PARENTED when not get_parent().is_node_ready():
			get_parent().ready.connect(set_parent.bind(get_parent() as Control), CONNECT_DEFERRED | CONNECT_ONE_SHOT)
			
		NOTIFICATION_EXIT_TREE:
			parent = null
			
		NOTIFICATION_READY:
			if not target: 
				target = ReferenceRect.new()
			if not Engine.is_editor_hint():
				get_window().size_changed.connect(_on_window_size_changed)
				_on_window_size_changed()


func _on_window_size_changed() -> void:
	screen = visible_rect.get_viewport_rect().size
	calculate_delta()

func _validate_property(property: Dictionary) -> void:
	match property.name:
		&"visible":
			property.usage |= PROPERTY_USAGE_EDITOR
	
	
#region Setter Helpers

func set_trans(trans_mode: Tween.TransitionType) -> Animator:
	self.trans_type = trans_mode
	return self
func set_ease(ease_mode: Tween.EaseType) -> Animator:
	self.ease_type = ease_mode
	return self
func set_duration(time_sec: float) -> Animator:
	self.duration = time_sec
	return self
func set_side(side: Side) -> Animator:
	self.side = side
	return self
func set_scale(min_scale: float = 0.3, max_scale: float = 1.0, scale_both_axis: bool = true) -> Animator:
	self.min_scale = min_scale
	self.max_scale = max_scale
	self.scale_both_axis = scale_both_axis
	return self

#endregion
