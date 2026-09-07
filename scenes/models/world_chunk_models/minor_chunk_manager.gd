extends Node
class_name MinorChunkManager

var chunks = {}
var loaded_object_chunks = {}
var loaded_building_chunks = {}
var tracked_pos = Vector3(0,0,0)
var curr_chunk_pos = Vector2(0,0)
const CHUNK_SIZE = 256

const BUILDING_LOAD_RADIUS = 5
const BUILDING_UNLOAD_RADIUS = 6
const LOAD_RADIUS = 2
const UNLOAD_RADIUS = 3

var target_node:Node3D
var player:CharacterBody3D

func convert_world_pos_to_chunk_pos(world_pos:Vector3):
	var cpos = round(world_pos/CHUNK_SIZE)
	return Vector2(cpos.x, cpos.z)

func convert_chunk_pos_to_world_pos(chunk_pos:Vector2):
	var wpos = chunk_pos * CHUNK_SIZE
	return Vector3(wpos.x, 0, wpos.y)

func convert_radius_to_chunk_radius(radius:float):
	return round(radius/CHUNK_SIZE)

func cover_terrain_by_radius(center_chunk:Vector2, radius:int):
	for dx in range(-radius, radius+1):
		for dz in range(-radius, radius+1):
			var chunk_pos = center_chunk + Vector2(dx,dz)
			var chunk = create_chunk_if_not_exists(chunk_pos)
			chunk.contains_terrain = true

func cover_ship_routes_by_radius(center_chunk:Vector2, radius:int):
	for dx in range(-radius, radius+1):
		for dz in range(-radius, radius+1):
			var chunk_pos = center_chunk + Vector2(dx,dz)
			var chunk = create_chunk_if_not_exists(chunk_pos)
			chunk.contains_ship_route = true

func cover_island_territory_by_radius(center_chunk:Vector2, radius:int):
	for dx in range(-radius, radius+1):
		for dz in range(-radius, radius+1):
			var chunk_pos = center_chunk + Vector2(dx,dz)
			var chunk = create_chunk_if_not_exists(chunk_pos)
			chunk.contains_island_nearby = true


func create_chunk_if_not_exists(chunk_pos:Vector2) -> MinorChunk:
	if chunks.has(chunk_pos):
		return chunks[chunk_pos]
	var new_chunk = MinorChunk.new()
	new_chunk.target_node = target_node
	new_chunk.chunk_position = chunk_pos
	chunks[chunk_pos] = new_chunk
	return chunks[chunk_pos]

func update_chunks():
	var tracked_cpos = convert_world_pos_to_chunk_pos(tracked_pos)
	var obj_chunks_to_unload = []
	var build_chunks_to_unload = []
	for chunk_pos in loaded_object_chunks:
		if (chunk_pos - tracked_cpos).length() >= UNLOAD_RADIUS:
			obj_chunks_to_unload.append(chunk_pos)
	for chunk_pos in loaded_building_chunks:
		if (chunk_pos - tracked_cpos).length() >= BUILDING_UNLOAD_RADIUS:
			build_chunks_to_unload.append(chunk_pos)
	
	for chunk_pos in obj_chunks_to_unload:
		chunks[chunk_pos].unload_objects()
		loaded_object_chunks.erase(chunk_pos)
	
	for chunk_pos in build_chunks_to_unload:
		chunks[chunk_pos].unload_buildings()
		loaded_building_chunks.erase(chunk_pos)
	
	for dx in range(-LOAD_RADIUS, LOAD_RADIUS+1):
		for dz in range(-LOAD_RADIUS, LOAD_RADIUS+1):
			var chunk_pos = tracked_cpos + Vector2(dx,dz)
			if loaded_object_chunks.has(chunk_pos): continue
			var chunk = create_chunk_if_not_exists(chunk_pos)
			chunk.load_chunk()
			chunks[chunk_pos] = chunk
			loaded_object_chunks[chunk_pos] = true
	
	for dx in range(-BUILDING_LOAD_RADIUS, BUILDING_LOAD_RADIUS+1):
		for dz in range(-BUILDING_LOAD_RADIUS, BUILDING_LOAD_RADIUS+1):
			var chunk_pos = tracked_cpos + Vector2(dx,dz)
			if loaded_building_chunks.has(chunk_pos): continue
			var chunk = create_chunk_if_not_exists(chunk_pos)
			chunk.load_buildings()
			chunks[chunk_pos] = chunk
			loaded_building_chunks[chunk_pos] = true

func append_corresponding_chunk(object_info):
	var cpos = convert_world_pos_to_chunk_pos(object_info.position)
	var chunk = create_chunk_if_not_exists(cpos)
	chunk.add_info(object_info)
	var tracked_cpos = convert_world_pos_to_chunk_pos(tracked_pos)
	if (cpos - tracked_cpos).length() <= LOAD_RADIUS:
		chunk.render_info(object_info)
		loaded_object_chunks[cpos] = true
	chunks[cpos] = chunk

func append_corresponding_chunk_with_building(building_info):
	var arithm_centroid = Vector3(0,0,0)
	for v in building_info.corners:
		arithm_centroid += Vector3(v.x,0, v.z)
	arithm_centroid /= building_info.corners.size()
	var cpos = convert_world_pos_to_chunk_pos(arithm_centroid)
	var chunk = create_chunk_if_not_exists(cpos)
	chunk.add_building_info(building_info)
	var tracked_cpos = convert_world_pos_to_chunk_pos(tracked_pos)
	if (cpos - tracked_cpos).length() <= BUILDING_LOAD_RADIUS:
		chunk.render_building(building_info.corners, building_info.height, target_node, building_info.color)
		loaded_object_chunks[cpos] = true
	chunks[cpos] = chunk

func update_tracked_pos(new_pos):
	tracked_pos = new_pos
	update_chunks()

func unload_all_chunks():
	for chunk_pos in loaded_object_chunks:
		chunks[chunk_pos].unload_objects()
	for chunk_pos in loaded_building_chunks:
		chunks[chunk_pos].unload_buildings()

#Checking player's position and updating accordingly
func follow_player_load():
	var new_chunk_pos = player.global_position
	new_chunk_pos = convert_world_pos_to_chunk_pos(new_chunk_pos)
	if (curr_chunk_pos != new_chunk_pos):
		curr_chunk_pos = new_chunk_pos
		update_tracked_pos(player.global_position)
