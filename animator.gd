@tool
class_name Animator extends Node
const GROUP: StringName = &"_animator"

const SIGNAL_HIDE: StringName = GROUP + &"_hide"
const SIGNAL_SHOW: StringName = GROUP + &"_show"
const SIGNAL_FINISHED: StringName = GROUP + &"_finished"

const DEBUG_COLOR: Color = Color(1, 0.4118, 0.7059, 0.5)



var visible: bool = true:
	set(val):
		visible = val
		if visible and elapsed == 0.0: return
		set_process(parent != null)


@export var target: Control : set = set_target

#const CUSTOM_TARGET: int = 4
@export var side: Side = SIDE_LEFT:
	set(val):
		side = val
		axis = side % 2
		update_pivot()
		calculate_delta()
		
@export var hide_on_finish: bool = true

@export_category("Tweening")
@export_range(0.1, 5.0, 0.1, "or_greater", "suffix:sec", )
var duration: float = 1.0:
	set(val): duration = val; set_elapsed(elapsed);

@export_range(0.1, 3.0, 0.1, "or_greater", "suffix:x")
var hide_time_scale: float = 2.0

@export var trans_type_show: Tween.TransitionType = Tween.TRANS_ELASTIC
@export var ease_type_show: Tween.EaseType = Tween.EASE_IN

@export var trans_type_hide: Tween.TransitionType = Tween.TRANS_BOUNCE
@export var ease_type_hide: Tween.EaseType = Tween.EASE_OUT

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



var screen: Vector2 = Vector2(ProjectSettings["display/window/size/viewport_width"], ProjectSettings["display/window/size/viewport_height"])
var axis: int = Vector2.AXIS_X

@export_category("Debug")
@export var debug_rect_visible: bool = true:
	set(val): debug_rect_visible = val; visible_rect.visible = val;

var offset: float = 0.0

var elapsed: float = 0.0: set = set_elapsed
var delay_sec: float = 0.0


func _init() -> void:
	set_process(false)
	
	visible_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible_rect.border_color = Color(1, 0.4118, 0.7059, 0.5)
	visible_rect.border_width = 2.0
	add_child(visible_rect, false, Node.INTERNAL_MODE_DISABLED)
	

func set_target(val: Control) -> void:
	target = val
	notify_property_list_changed()


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
	align_rect()


func calculate_delta() -> void:
	if not parent: return
	offset = -visible_rect.global_position[axis] - (visible_rect.size[axis] * min_scale) if side < 2 else screen[axis] - visible_rect.global_position[axis]
	set_elapsed(elapsed)


func align_rect() -> void:
	if not parent: return
	var is_changed: bool
	if visible_rect.size != parent.size and elapsed == 0.0:
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
	
	var tween_trans: Tween.TransitionType = trans_type_show if visible else trans_type_hide
	var tween_ease: Tween.EaseType = ease_type_show if visible else ease_type_hide
	
	if target:
		for prop: StringName in [&"global_position", &"scale", &"rotation", &"size"]:
			parent[prop] = Tween.interpolate_value(visible_rect[prop], target[prop] - visible_rect[prop], elapsed, duration, tween_trans, tween_ease)
		return
		
	
	parent.global_position[axis ^ 1] = visible_rect.global_position[axis ^ 1]
	parent.global_position[axis] = Tween.interpolate_value(visible_rect.global_position[axis], offset, elapsed, duration, tween_trans, tween_ease)

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

	
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PARENTED when get_parent().is_node_ready():
			set_parent.call_deferred(get_parent())
			
		NOTIFICATION_PARENTED when not get_parent().is_node_ready():
			get_parent().ready.connect(set_parent.bind(get_parent() as Control), CONNECT_DEFERRED | CONNECT_ONE_SHOT)
			
		NOTIFICATION_EXIT_TREE:
			parent = null
			
		NOTIFICATION_READY:
			if not Engine.is_editor_hint():
				get_window().size_changed.connect(_on_window_size_changed)
				_on_window_size_changed()
				visible = false
				
		NOTIFICATION_EDITOR_PRE_SAVE:
			parent.remove_meta(GROUP)
		NOTIFICATION_EDITOR_POST_SAVE:
			parent.set_meta(GROUP, self)
		

func _on_window_size_changed() -> void:
	screen = visible_rect.get_viewport_rect().size
	calculate_delta()

func _validate_property(property: Dictionary) -> void:
	match property.name:
		&"visible", &"delay_sec":
			property.usage |= PROPERTY_USAGE_EDITOR
			
		&"elapsed":
			property.usage |= PROPERTY_USAGE_EDITOR
			property.hint = PROPERTY_HINT_RANGE
			property.hint_string = "0.0,%01.01f,0.1,suffix:sec," % duration
			
		&"Scale" when property.usage&PROPERTY_USAGE_GROUP and target:
			property.name = &""
			
		&"side", &"max_scale", &"min_scale", &"scale_both_axis", &"trans_type_scale", &"ease_type_scale" when target:
			property.usage &= ~(PROPERTY_USAGE_EDITOR)


#region Setter Helpers

func set_trans(trans_mode: Tween.TransitionType) -> Animator:
	self.trans_type_show = trans_mode
	return self
func set_ease(ease_mode: Tween.EaseType) -> Animator:
	self.ease_type_show = ease_mode
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
