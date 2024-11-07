@tool
class_name AnimatorNotifier extends Node
const GROUP: StringName = &"animator_notifier"

@export var enabled: bool = true:
	set(val):
		enabled = val
		if not enabled:
			set_process_input(false)
			set_process_unhandled_input(false)
		else:
			use_input = use_input
		
		
@export var parent: Control:
	set(val):
		if parent: parent.remove_meta(GROUP)
		parent = val
		if parent: parent.set_meta(GROUP, self)

@export_range(0, 500, 10, "or_greater", "suffix:px")
var hide_distance: float = 100

@export_range(0, 500, 10, "or_less", "suffix:px")
var show_distance: float = 100

@export var use_input: bool = false:
	set(val):
		use_input = val
		set_process_input(use_input)
		set_process_unhandled_input(!use_input)

@export_group("Parent & Signals")
@export var signal_show: String = &"animator_show"
@export var signal_hide: String = &"animator_hide"
		
		
var visible: bool

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		handle_mouse_movement(event)
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		handle_mouse_movement(event)

func handle_mouse_movement(event: InputEventMouseMotion) -> void:
	if not parent or not parent.is_node_ready(): return
	var rect:= parent.get_rect().grow(hide_distance if visible else show_distance)
	if rect.has_point(event.position):
		parent.emit_signal(signal_hide if visible else signal_show)
	
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			add_to_group(GROUP)
			if not parent and get_parent() is Control:
				parent = get_parent()
		NOTIFICATION_EDITOR_PRE_SAVE when parent:
			parent.remove_meta(GROUP)
		NOTIFICATION_EDITOR_POST_SAVE when parent:
			parent.set_meta(GROUP, self)
		
		
			
		
		NOTIFICATION_EXIT_TREE when not Engine.is_editor_hint():
			get_parent().remove_meta(GROUP)
			
			
		NOTIFICATION_READY:
			pass


func _validate_property(property: Dictionary) -> void:
	match property.name:
		&"signal_show", &"signal_hide" when parent:
			var signal_names:PackedStringArray
			for dict: Dictionary in parent.get_signal_list():
				signal_names.push_back(dict.name)
			property.hint = PROPERTY_HINT_ENUM_SUGGESTION
			property.hint_string = ",".join(signal_names)
			
