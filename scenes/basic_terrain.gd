extends Node3D

var spawn_time = 1
var spawn_timer = 0.0
@onready var player := $CharacterBody3D
var curr_closest_idx = -1

func _ready() -> void:
	RoadSpawner.player = player
	RoadSpawner.play_scene = $Cars
	RoadSpawner.road_network = GlobalValues.road_network
	GlobalValues.minor_chunk_manager = MinorChunkManager.new()
	GlobalValues.chunks_flushed.connect(on_chunks_flushed)
	GlobalValues.road_network_array = []

func on_chunks_flushed():
	for child in $Decor.get_children():
		child.queue_free()
	GlobalValues.minor_chunk_manager.player = player
	GlobalValues.minor_chunk_manager.target_node = $Decor

func scan_nearest_road_network():
	var min_dist = INF
	var closest_idx = -1
	var player_pos = player.global_position
	for i in GlobalValues.road_network_array.size():
		var island = GlobalValues.road_network_array[i]
		var island_pos = island.position
		var dist = (island_pos - player_pos).length()
		if dist < min_dist:
			closest_idx = i
			min_dist = dist
	if curr_closest_idx != closest_idx:
		if closest_idx == -1: return
		RoadSpawner.road_network = GlobalValues.road_network_array[closest_idx].road_network
		RoadSpawner.global_offset = GlobalValues.road_network_array[closest_idx].position

func _process(delta: float) -> void:
	if GlobalValues.minor_chunk_manager.player != null:
		GlobalValues.minor_chunk_manager.follow_player_load()
	
	if GlobalValues.road_network_array.size() > 0:
		scan_nearest_road_network()
	
	if RoadSpawner.road_network == null: return
	if spawn_timer > spawn_time:
		RoadSpawner.spawn_cars_on_player_adjascent_vertices()
		spawn_timer = 0
	spawn_timer += delta
