extends Node3D
class_name InfiniteSquareCityGenerator

@export var regenerate_road: bool:
	set(new_value):
		_update_structure()

@export var reset: bool:
	set(new_value):
		_reset_road_network()
		_remove_chunks()
		for child in get_children():
			if child is StaticBody3D:
				child.queue_free()
@export_range(0, 65535, 1) var rseed := 0:
	set(new_value):
		rseed = new_value
		seed(rseed)
@export_group("Render")
@export var render_roads:bool = true
@export_range(0, 256, 1) var width := 12:
	set(new_value):
		width = new_value
@export_range(0, 256, 1) var side_width := 4:
	set(new_value):
		width = new_value
@export_range(0, 256, 0.25) var thickness := 1.:
	set(new_value):
		thickness = new_value
@export_group("Block options")
@export_range(5, 10000, 5) var side_length := 495:
	set(new_value):
		side_length = new_value
@export_range(1, 50, 1) var square_distance := 2:
	set(new_value):
		square_distance = new_value
@export_group("Splits")
@export_range(0, 10, 1) var min_split_iterations:int = 0:
	set(new_value):
		if new_value > max_split_iterations:
			min_split_iterations = max_split_iterations
		else:
			min_split_iterations = new_value
@export_range(0, 10, 1) var max_split_iterations:int = 4:
	set(new_value):
		if new_value < min_split_iterations:
			max_split_iterations = min_split_iterations
		else:
			max_split_iterations = new_value
@export_range(0, 1, 0.001) var split_block_chance:float = 0.01:
	set(new_value):
		split_block_chance = new_value
@export_range(0, 10000000, 5) var minimum_split_area := 100:
	set(new_value):
		minimum_split_area = new_value
@export_range(0, 10000000, 5) var max_blocked_sector_size := 100000:
	set(new_value):
		max_blocked_sector_size = new_value
@export_group("Buildings")
@export_range(0, 200, 1) var sector_edge_distance:float = 20:
	set(new_value):
		sector_edge_distance = new_value
@export_range(0, 10000, 1) var minimal_building_area:float = 20:
	set(new_value):
		minimal_building_area = new_value
@export_range(0, 256, 1) var lot_cell_size:float = 8:
	set(new_value):
		lot_cell_size = new_value
@export_range(0, 1000, 1) var corner_subdivision_distance:float = 0:
	set(new_value):
		corner_subdivision_distance = new_value
@export_range(0, 180, 1) var min_corner_angle:float = 0:
	set(new_value):
		min_corner_angle = new_value
@export_range(0, 5000, 1) var max_height:float = 1000:
	set(new_value):
		max_height = new_value

var square_chunks:Dictionary = {}
var chunk_nodes:Dictionary = {}
var currently_loaded_chunks = {}
var current_centre_chunk = Vector3(0,0,0)
@export var player:CharacterBody3D 
@onready var premade_ground_cell:PackedScene = preload("res://scenes/terrain_no_addons/premade_ground_celllol.tscn")

var road_network:RoadNetwork
var road_renderer = RoadRenderer.new()
var building_renderer = BuildingRenderer.new()

func _regenerate() -> void:
	await _reset_road_network()
	await _remove_chunks()
	building_renderer.road_network = road_network
	road_renderer.road_network = road_network
	var centre_position = Vector3.ZERO
	if player != null: centre_position = player.global_position
	var current_centre_chunk = centre_position
	var cx = round(current_centre_chunk.x / side_length)
	var cz = round(current_centre_chunk.z / side_length)
	current_centre_chunk = Vector3(cx,0,cz)
	await place_squares_around(square_distance, current_centre_chunk)

func _set_params(gen_seed:int= 0, min_split_iter:int = 0, max_split_iter:int = 0, 
	min_split_area:float = 1000., split_block_ch:float = 0.0, 
	building_max_height:int = 1000, build_cell_size:int = 16) -> void:
	rseed = gen_seed
	min_split_iterations = min_split_iter
	max_split_iterations = max_split_iter
	minimum_split_area = min_split_area
	split_block_chance = split_block_ch
	building_renderer.max_height = building_max_height
	building_renderer.lot_cell_size = build_cell_size

func _process(delta: float) -> void:
	if player != null:
		var new_chunk_pos = player.global_position
		var cx = round(new_chunk_pos.x / side_length)
		var cz = round(new_chunk_pos.z / side_length)
		new_chunk_pos = Vector3(cx,0,cz)
		if (current_centre_chunk != new_chunk_pos):
			print("CHUNK CHANGE TRIGGERED: ",current_centre_chunk, " -> ", new_chunk_pos)
			current_centre_chunk = new_chunk_pos
			#generation_thread.wait_to_finish()
			place_squares_around(square_distance, player.global_position)
			#generation_thread.start(place_squares_around.bind(square_distance, player.global_position), 1)

func _update_structure() -> void:
	await _reset_road_network()
	await _remove_chunks()
	await place_squares_around(square_distance, current_centre_chunk)
	print('Sectors: ',GlobalValues.road_network.sectors.size())
func _remove_chunks() -> void:
	for child in get_children():
		if child is Node3D:
			if child != $SectorPaths && child != $BuildingMeshes && child != $RoadSections:
				child.queue_free()
	chunk_nodes = {}
	current_centre_chunk = Vector3(0,0,0)
	square_chunks = {}
	currently_loaded_chunks = {}

func _reset_road_network() -> void:
	road_network = RoadNetwork.new()
	seed(rseed)

func create_square_polygon(cx:float, cy:float, side_len:float) -> Array:
	var vertices:Array[int] = []
	var edges:Array[int] = []
	var half_side = side_len/2.
	var a = Vector3(cx+half_side, 0, cy+half_side) #+1, +1
	var b = Vector3(cx+half_side, 0, cy-half_side) #+1, -1
	var c = Vector3(cx-half_side, 0, cy-half_side) #-1, -1
	var d = Vector3(cx-half_side, 0, cy+half_side) #-1, +1
	var aid = road_network.add_vertice(a)
	var a_overlap = true if aid < road_network.vertices.size()-1 else false
	var bid = road_network.add_vertice(b)
	var b_overlap = true if bid < road_network.vertices.size()-1 else false
	var cid = road_network.add_vertice(c)
	var c_overlap = true if cid < road_network.vertices.size()-1 else false
	var did = road_network.add_vertice(d)
	var d_overlap = true if did < road_network.vertices.size()-1 else false
	vertices = [aid,bid,cid,did]
	
	var ab
	if a_overlap && b_overlap:
		ab = road_network.get_edge_between_vertices(aid,bid)
		if ab == null: ab = road_network.add_edge_to_network(aid, bid)
	else: ab = road_network.add_edge_to_network(aid, bid)
	
	var bc
	if b_overlap && c_overlap:
		bc = road_network.get_edge_between_vertices(bid,cid)
		if bc == null: bc = road_network.add_edge_to_network(bid, cid)
	else: bc = road_network.add_edge_to_network(bid, cid)
	
	var cd
	if c_overlap && d_overlap:
		cd = road_network.get_edge_between_vertices(cid, did)
		if cd  == null: cd = road_network.add_edge_to_network(cid, did)
	else: cd = road_network.add_edge_to_network(cid, did)
	
	var da
	if d_overlap && a_overlap:
		da = road_network.get_edge_between_vertices(did,aid)
		if da == null: da = road_network.add_edge_to_network(did, aid)
	else: da = road_network.add_edge_to_network(did, aid)
	
	edges = [ab,bc,cd,da]
	var s = RoadSector.new(edges ,vertices)
	s.area = road_network.calculate_polygon_area(vertices, true)
	var sid = road_network.add_sector(s)
	var new_sids = await _perform_splits_singular(randi_range(min_split_iterations,max_split_iterations), sid)
	return new_sids

func _perform_splits_singular(iterations:int, start_sid:int) -> Array:
	var polygons : Array[RoadSector] = []
	var ci = 0
	var final_sectors = []
	var prev_polygon_count = 0
	while ci < iterations:
		var current_sector_ids = []
		if (ci == 0): current_sector_ids.append(start_sid)
		
		var i = road_network.sectors.size()-1
		while i > road_network.sectors.size()-prev_polygon_count-1:
			current_sector_ids.append(i)
			i-=1
		
		for pid in current_sector_ids:
			if (!road_network.sectors[pid].splittable):
				polygons.append(road_network.sectors[pid])
				continue
			var result
			if (road_network.sectors[pid].area <= minimum_split_area * 2.1):
				road_network.sectors[pid].splittable = false
				polygons.append(road_network.sectors[pid])
				continue
			if split_block_chance > randf_range(0.000, 1.000):
				road_network.sectors[pid].splittable = false
				polygons.append(road_network.sectors[pid])
				continue
			result = road_network.split_sector_longest_to_opposite(pid, 0.15)
			if result:
				polygons.append(result.polygon1)
				polygons.append(result.polygon2)
				continue
			
			var old_sector = road_network.sectors[pid]
			old_sector.splittable = false
			polygons.append(old_sector)
		if (ci == 0):
			road_network.sectors.remove_at(start_sid)
		if (ci != 0):
			while prev_polygon_count > 0:
				road_network.sectors.remove_at(road_network.sectors.size()-1)
				prev_polygon_count-=1
		
		for poly in polygons:
			poly.edges = road_network.reconstruct_sector_from_vertices(poly)
			var new_sid = road_network.add_sector(poly)
			if (ci == iterations-1):
				final_sectors.append(new_sid)
		prev_polygon_count = polygons.size()
		polygons = []
		ci += 1
	if final_sectors.size() == 0:
		final_sectors.append(start_sid)
	
	road_network.reassign_all_sectors_random_sid(final_sectors)
	return final_sectors

func place_squares_around(radius:int, center:Vector3):
	var cx = round(center.x / side_length)
	var cz = round(center.z / side_length)
	
	var new_loaded_chunks:Array = []
	for dx in range(-radius, radius+1):
		for dz in range(-radius, radius+1):
			var chunk_pos = Vector3(cx + dx, 0, cz + dz)
			if square_chunks.has(chunk_pos):
				if currently_loaded_chunks.has(chunk_pos): 
					new_loaded_chunks.append(chunk_pos)
					continue 
				load_chunk(chunk_pos)
				new_loaded_chunks.append(chunk_pos)
				continue
			var new_root = Node3D.new()
			add_child(new_root)
			new_root.owner = get_tree().edited_scene_root
			chunk_nodes[chunk_pos] = new_root
			var world_pos = chunk_pos * side_length
			var sectors:Array = await create_square_polygon(world_pos.x, world_pos.z, side_length)
			var buildings:Array[BuildingData] = []
			var objects:Array = []
			for sid in sectors:
				var sector = road_network.sectors[sid]
				var result = building_renderer.create_lots_from_sector(sector)
				var lot = result.lot
				building_renderer.break_sector_into_grid(lot, lot_cell_size, Vector3.ZERO, sector.type)
					
			var unique_eids = [] 
			var unique_vids = [] 
			for sid in sectors:
				for eid in road_network.sectors[sid].edges:
					var is_unique = true
					for ueid in unique_eids:
						if eid == ueid: 
							is_unique = false
							break
					if !is_unique: continue
					unique_eids.append(eid)
			for sid in sectors:
				for vid in road_network.sectors[sid].vertices:
					var is_unique = true
					for uvid in unique_vids:
						if vid == uvid: 
							is_unique = false
							break
					if !is_unique: continue
					unique_vids.append(vid)
			square_chunks[chunk_pos] = {"vertices": unique_vids, "edges": unique_eids, "buildings": buildings, "objects": objects}
			await load_chunk(chunk_pos)
			new_loaded_chunks.append(chunk_pos)
	update_chunks(new_loaded_chunks)
	#await get_tree().process_frame

func load_chunk(chunk_pos:Vector3) -> void:
	var new_root = Node3D.new()
	add_child(new_root)
	chunk_nodes[chunk_pos] = new_root
	for eid in square_chunks[chunk_pos].edges:
		if !has_node(new_root.get_path()): break
		var estart_pos = road_network.vertices[road_network.edges[eid].start_index]
		var eend_pos = road_network.vertices[road_network.edges[eid].end_index]
		var road_dir = (eend_pos - estart_pos).normalized()
		var epos = eend_pos - road_dir * width*2
		var spos = estart_pos + road_dir * width*2
		var edir = (eend_pos - estart_pos).normalized()
		var side_offset = (side_width + width) * edir.rotated(Vector3.UP, deg_to_rad(-90))
		var side1p1 = spos  + (side_width + width) * edir.rotated(Vector3.UP, deg_to_rad(90)) + Vector3(0,.5,0)
		var side1p2 = epos + (side_width + width) * edir.rotated(Vector3.UP, deg_to_rad(90)) + Vector3(0,.5,0)
		var side2p1 = spos  + (side_width + width) * edir.rotated(Vector3.UP, deg_to_rad(-90)) + Vector3(0,.5,0)
		var side2p2 = epos + (side_width + width) * edir.rotated(Vector3.UP, deg_to_rad(-90)) + Vector3(0,.5,0)
		var clr = Color(0.25,0.25,0.25)
		road_renderer.place_road(side1p1, side1p2, side_width,thickness, new_root, clr, "", "Sidewalk")
		road_renderer.place_road(side2p1, side2p2, side_width,thickness, new_root, clr, "", "Sidewalk")
		road_renderer.place_road_from_network(eid, width*2, width*2, new_root)
	road_renderer.place_crossings(square_chunks[chunk_pos].vertices, new_root)

func update_chunks(new_loaded_chunks: Array):
	var i = 0
	while i < currently_loaded_chunks.size():
		var found = false
		for new_chunk in new_loaded_chunks:
			if new_chunk == currently_loaded_chunks[i]: 
				found = true
				break
		if found: 
			i+=1
			continue
		if chunk_nodes.has(currently_loaded_chunks[i]):
			chunk_nodes[currently_loaded_chunks[i]].queue_free()
			chunk_nodes.erase(currently_loaded_chunks[i])
		currently_loaded_chunks.remove_at(i)
	currently_loaded_chunks = new_loaded_chunks
