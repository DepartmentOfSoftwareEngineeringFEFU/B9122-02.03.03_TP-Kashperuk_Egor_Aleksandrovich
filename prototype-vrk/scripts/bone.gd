extends RigidBody3D

@export var strength: float = 1.0
@export var align_torque_strength: float = 10.0
@export var connector_aim_axis: Vector3 = Vector3.UP

var is_grabbed := false
var grab_offset := Vector3.ZERO
var grab_distance: float = 0.0
var camera: Camera3D
var _orig_linear_damp: float 
var _orig_gravity_scale: float

var speed_to_turn: Vector3 = Vector3.ZERO
var turn_time: float = 1.0

var is_aligning := false


func _ready() -> void:
	for area in _get_connector_areas():
		area.input_ray_pickable = false
	camera = get_viewport().get_camera_3d()
	_orig_linear_damp = linear_damp
	_orig_gravity_scale = gravity_scale


func _input_event(_camera: Camera3D, event: InputEvent, event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_start_grab(event_position)
			get_viewport().set_input_as_handled()
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and is_grabbed:
			if grab_distance < 20:
				grab_distance += 0.3
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and is_grabbed:
			if grab_distance > 3:
				grab_distance -= 0.3
	
	if is_grabbed:
		if Input.is_action_just_pressed("arrow_up"):
			speed_to_turn = compute_angular_velocity_to_rotate(rotation, Vector3(0, 0, 0), 0.85)
			turn_time = 0
		elif Input.is_action_just_pressed("arrow_right"):
			speed_to_turn = compute_angular_velocity_to_rotate(rotation, Vector3(0, 0, -PI/2), 0.85)
			turn_time = 0
		elif Input.is_action_just_pressed("arrow_left"):
			speed_to_turn = compute_angular_velocity_to_rotate(rotation, Vector3(0, 0, PI/2), 0.85)
			turn_time = 0
		elif Input.is_action_just_pressed("arrow_down"):
			speed_to_turn = compute_angular_velocity_to_rotate(rotation, Vector3(0, 0, PI), 0.85)
			turn_time = 0




func _physics_process(delta: float) -> void:
	if not is_grabbed:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_release_grab()
		return
	if not camera:
		return
	
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	var target := origin + dir * grab_distance
	
	var to_target := target - global_position
	linear_velocity = to_target * strength
	
	_apply_connector_align()
	if is_aligning:
		if turn_time <= 1.1:
			turn_time = 2
	elif turn_time <= 1.1:
		turn_to_target(delta)


func _start_grab(hit_global: Vector3) -> void:
	is_grabbed = true
	grab_offset = to_local(hit_global)
	grab_distance = camera.global_position.distance_to(hit_global)
	gravity_scale = 0.0
	linear_damp = 8.0
	angular_damp = 8.0
	sleeping = false 

func _release_grab() -> void:
	is_grabbed = false
	gravity_scale = _orig_gravity_scale
	linear_damp = _orig_linear_damp
	angular_damp = 0.0
	linear_velocity *= 0.3 


func compute_angular_velocity_to_rotate(current_euler: Vector3, target_euler: Vector3, T: float) -> Vector3:
	
	var q_current := Quaternion.from_euler(current_euler)
	var q_target := Quaternion.from_euler(target_euler)
	
	var q_delta := q_target * q_current.inverse()
	
	var angle := q_delta.get_angle()
	if angle < 0.001:
		return Vector3.ZERO
	
	var axis := q_delta.get_axis().normalized()
	
	var speed := 2.0 * angle / T
	return axis * speed


func turn_to_target(delta: float):
	angular_velocity = lerp(speed_to_turn, Vector3.ZERO, turn_time)
	turn_time += delta


func _get_connector_areas() -> Array[Area3D]:
	var res: Array[Area3D] = []
	for child in get_children():
		if child is Node3D and child.name.begins_with("Connector"):
			var area := child.get_node_or_null("Area3D") as Area3D
			if area:
				res.append(area)
	return res


func _apply_connector_align() -> void:
	is_aligning = false
	var my_areas := _get_connector_areas()
	if my_areas.is_empty(): return

	# собираем все уникальные other-коннекторы из overlaps всех своих
	var others: Array[Area3D] = []
	for ma in my_areas:
		for oa in ma.get_overlapping_areas():
			if oa not in others:
				var p := oa.get_parent()
				if p and p.get_parent() is RigidBody3D and p.get_parent() != self:
					others.append(oa)

	if others.is_empty(): return

	var best_my: Area3D = null
	var best_other: Area3D = null
	var min_d := INF

	for ma in my_areas:
		var my_pos := ma.global_position
		for oa in others:
			var d := my_pos.distance_to(oa.global_position)
			if d < min_d:
				min_d = d
				best_my = ma
				best_other = oa

	if not best_my or min_d > 2.0: return

	var target_pos := best_other.global_position
	var desired_dir := (target_pos - best_my.global_position).normalized()

	# используем Node3D родителя best_my как Connector
	var conn_node := best_my.get_parent() as Node3D
	if not conn_node: return
	var current_dir := (conn_node.global_transform.basis * connector_aim_axis).normalized()

	var cross := current_dir.cross(desired_dir)
	if cross.length_squared() < 0.00001: return

	var axis := cross.normalized()
	var dot = clamp(current_dir.dot(desired_dir), -1.0, 1.0)
	var angle := acos(dot)
	apply_torque(axis * angle * align_torque_strength)
	is_aligning = true
	
	var from := best_my.global_position
	DebugDraw3D.draw_line(from, from + current_dir , Color(0, 1, 0))      # текущий forward коннектора (зелёный)
	DebugDraw3D.draw_line(from, from + desired_dir , Color(1, 0, 0))     # желаемое направление к nearest (красный)
	DebugDraw3D.draw_line(from, from + axis , Color(0, 0, 1))            # ось torque (синяя)
	DebugDraw3D.draw_sphere(from, 0.3, Color(1, 1, 0))
