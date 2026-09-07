extends Node3D


var path = []
var current_path_idx = 1
var waiting_time = 5.
var waiting_timer = 0.
var travel_speed = 10
var docking_speed = 3
var is_destination = false
var is_waiting = true
var travel_path_threashold = 5
@onready var visual_model = $"Viking boat"

func set_path(new_path = []):
	path = new_path
	is_destination = true

func _process(delta:float) -> void:
	if is_waiting:
		waiting_timer += delta
		if waiting_timer >= waiting_time:
			is_waiting = !is_waiting
			waiting_timer = 0
		return
	
	if path.size() < 2: return
	
	
	if !is_destination:
		follow_path()
	else:
		follow_path_back()

func follow_path():
	var speed = travel_speed
	if current_path_idx < 2: #Undocking
		speed = docking_speed
	elif current_path_idx >= path.size()-2: #Docking
		speed = docking_speed
	
	var dir = (path[current_path_idx] - position).normalized()
	position += dir*speed
	visual_model.rotate(Vector3.UP, 0.6)
	
	if reached_travel_target():
		current_path_idx += 1
		if current_path_idx >= path.size():
			is_waiting = true
			is_destination = true
			current_path_idx = path.size() - 2
			return

func follow_path_back():
	var speed = travel_speed
	if current_path_idx < 3: #Docking
		speed = docking_speed
	elif current_path_idx >= path.size()-3: #Unocking
		speed = docking_speed
	
	var dir = (path[current_path_idx] - position).normalized()
	position += dir*speed
	visual_model.rotate(Vector3.UP, 0.5)
	
	if reached_travel_target():
		current_path_idx -= 1
		if current_path_idx < 0:
			is_waiting = true
			is_destination = false
			current_path_idx = 1
			return

func reached_travel_target() -> bool:
	return position.distance_to(path[current_path_idx]) < travel_path_threashold
