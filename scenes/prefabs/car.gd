extends Node3D

var player:CharacterBody3D
var despawn_distance = 500
var global_offset = Vector3.ZERO

var target_vid = 0
var target_pos = Vector3.ZERO
var prev_vid = -1
var prev_pos = Vector3.ZERO
var move_speed = 150
var turn_speed = 5
var road_network:RoadNetwork

enum CarState { IDLE, ROTATING, MOVING, WAITING }
var state = CarState.IDLE
var target_reached_threshold = 2.5
var wait_time = 5.

func _process(delta:float) -> void:
	if (player.position - position).length() > despawn_distance:
		despawn()
	
	match state:
		CarState.WAITING:
			wait_time -= delta
			if wait_time <= 0:
				state = CarState.IDLE
		
		CarState.IDLE:
			pick_next_target()
			#print(name, ": State shift: Idle -> Rotating")
			state = CarState.ROTATING

		CarState.ROTATING:
			turn_toward_target(delta)
			if is_facing_target():
				#print(name, ": State shift: Rotating -> Moving")
				state = CarState.MOVING

		CarState.MOVING:
			move_toward_target(delta)
			if reached_target():
				#print(name, "State shift: Moving -> Idle")
				state = CarState.IDLE


func move_toward_target(delta:float):
	var dir = (target_pos - position)
	var dir_norm = dir.normalized()
	var actual_move_speed = move_speed
	position += dir_norm * actual_move_speed * delta

func turn_toward_target(delta:float):
	var dir_to_target = (target_pos - position).normalized()
	var forward =  transform.basis.z
	var angle = forward.angle_to(dir_to_target)
	if angle <= 0:
		return
	var s = sign(forward.cross(dir_to_target).y)
	var max_turn = turn_speed * delta
	var turn_angle = clamp(s * angle, -max_turn, max_turn)
	rotate_y(turn_angle)

func is_facing_target() -> bool:
	var dir_to_target = (target_pos - position).normalized()
	var forward = transform.basis.z
	var angle = forward.angle_to(dir_to_target)
	return abs(angle) <= 0.05 || abs(angle) >= PI - 0.05 

func reached_target() -> bool:
	return position.distance_to(target_pos) < target_reached_threshold

func pick_next_target():
	if !road_network.vertex_edges.has(target_vid): queue_free()
	var edges = road_network.vertex_edges[target_vid]
	while true:
		var random_idx = randi_range(0,edges.size()-1)
		var eid = edges[random_idx]
		var edge = road_network.edges[eid]
		var new_vid = edge.end_index if edge.start_index == target_vid else edge.start_index
		if new_vid == prev_vid && edges.size() > 1: continue
		
		prev_vid = target_vid
		target_vid = new_vid
		prev_pos = target_pos
		target_pos = road_network.vertices[target_vid] + global_offset
		break

func despawn():
	queue_free()
