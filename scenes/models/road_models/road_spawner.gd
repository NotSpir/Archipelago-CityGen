extends Node

var player:CharacterBody3D
var play_scene:Node3D
var spawn_cap = 20
var road_network = RoadNetwork.new()
var global_offset = Vector3.ZERO

var car_prefab = preload("res://scenes/prefabs/car.tscn")

func spawn_cars_on_player_adjascent_vertices(spawn_radius = 5, ignore_radius = 3):
	if player == null: return
	if spawn_cap < play_scene.get_children().size(): return
	
	var pos = player.position - global_offset
	var c = road_network.transform_position_to_chunk_position(pos)
	
	for dx in range(-spawn_radius, spawn_radius + 1):
		for dy in range(-spawn_radius, spawn_radius+1):
			var dist_sq = dx*dx + dy*dy
			if dist_sq < ignore_radius: continue
			
			var x = dx + c.x
			var y = dy + c.y
			var chunk_pos = Vector2(x, y)
			if !road_network.chunks.has(chunk_pos): continue
			var chunk_vertices = road_network.get_all_vertices_in_chunk(chunk_pos)
			for vid in chunk_vertices:
				var v = road_network.vertices[vid]
				spawn_car(vid, v ,play_scene)

func spawn_car(start_vid, spawn_pos:Vector3, scene:Node3D):
	if spawn_cap < play_scene.get_children().size(): return
	#Car spawns at initial position and then follows the road_)network. SO car should get road-netwoprk_access.
	var car = car_prefab.instantiate()
	car.player = player
	car.target_vid = start_vid
	car.position = spawn_pos + global_offset
	car.global_offset = global_offset
	car.road_network = road_network
	scene.add_child(car)
