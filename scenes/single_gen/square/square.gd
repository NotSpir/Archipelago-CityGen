extends Node3D
class_name SquareCityGenerator

@export_range(0, 65535, 1) var rseed := 0:
	set(new_value):
		rseed = new_value
		seed(rseed)
@export_group("Render")
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
@export_group("Terrain")
@export_range(4, 256, 4) var resolution = 32

var square_chunks:Dictionary = {}
var chunk_nodes:Dictionary = {}
var current_centre_chunk = Vector3(0,0,0)
var ground_mesh
var ground_collision

var road_network:RoadNetwork
var road_renderer = RoadRenderer.new()
var building_renderer = BuildingRenderer.new()

func _regenerate(center_pos:Vector3 = Vector3.ZERO) -> void:
	await _reset_road_network()
	await _remove_chunks()
	update_terrain_mesh()
	building_renderer.global_offset = global_position
	building_renderer.road_network = road_network
	road_renderer.road_network = road_network
	current_centre_chunk = center_pos
	var cx = round(current_centre_chunk.x / side_length)
	var cz = round(current_centre_chunk.z / side_length)
	current_centre_chunk = Vector3(cx,0,cz)
	print(current_centre_chunk)
	await place_squares_around(square_distance, current_centre_chunk)
	GlobalValues.road_network_array.append({"position": global_position, "road_network": road_network})
	var chunk_radius = GlobalValues.minor_chunk_manager.convert_radius_to_chunk_radius(square_distance*side_length) + 2
	var center_chunk_pos = GlobalValues.minor_chunk_manager.convert_world_pos_to_chunk_pos(global_position)
	GlobalValues.minor_chunk_manager.cover_terrain_by_radius(center_chunk_pos, chunk_radius)
	GlobalValues.minor_chunk_manager.cover_island_territory_by_radius(center_chunk_pos, chunk_radius+3)
	place_seaports()

func _set_params(gen_seed:int= 0, render_distance = 2, square_size = 495, min_split_iter:int = 0, max_split_iter:int = 0, 
	min_split_area:float = 1000., split_block_ch:float = 0.0, 
	building_max_height:int = 1000, build_cell_size:int = 16) -> void:
	rseed = gen_seed
	min_split_iterations = min_split_iter
	max_split_iterations = max_split_iter
	minimum_split_area = min_split_area
	square_distance = render_distance
	side_length = square_size
	split_block_chance = split_block_ch
	building_renderer.max_height = building_max_height
	building_renderer.lot_cell_size = build_cell_size

func _update_structure() -> void:
	await _reset_road_network()
	await _remove_chunks()
	await place_squares_around(square_distance, current_centre_chunk)
	print('Sectors: ',road_network.sectors.size())
func _remove_chunks() -> void:
	for child in get_children():
		if child is Node3D:
			if child != $SectorPaths && child != $BuildingMeshes && child != $RoadSections:
				child.queue_free()
	chunk_nodes = {}
	square_chunks = {}

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
				if result != null:
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

func load_chunk(chunk_pos:Vector3) -> void:
	var new_root = Node3D.new()
	add_child(new_root)
	new_root.owner = get_tree().edited_scene_root
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

func update_terrain_mesh() -> void:
	var plane := PlaneMesh.new()
	var max_distance = square_distance * side_length
	plane.subdivide_depth = resolution
	plane.subdivide_width = resolution
	var size = max_distance*4 + 500
	plane.size = Vector2(size, size)
	
	var plane_arrays := plane.get_mesh_arrays()
	var vertex_array : PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_VERTEX]
	var normal_array : PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_NORMAL]
	var tangent_array : PackedFloat32Array = plane_arrays[ArrayMesh.ARRAY_TANGENT]
	
	for i:int in vertex_array.size():
		var vertex := vertex_array[i]
		var normal := Vector3.UP
		var tangent := Vector3.RIGHT
		
		var edge = size / 3.0
		if abs(vertex.x) > edge:
			vertex.y = (vertex.length()-max_distance)/(-2.)
		elif abs(vertex.z) > edge:
			vertex.y = (vertex.length()-max_distance)/(-2.)
		
		tangent = normal.cross(Vector3.UP)
		vertex_array[i] = vertex
		normal_array[i] = normal
		tangent_array[4*i] = tangent.x
		tangent_array[4*i + 1] = tangent.y
		tangent_array[4*i + 2] = tangent.z
	
	
	var static_body = StaticBody3D.new()
	ground_mesh = MeshInstance3D.new()
	ground_collision = CollisionShape3D.new()
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane_arrays)
	ground_mesh.mesh = array_mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 0.0)
	ground_mesh.material_override = mat
	
	var shape = ground_mesh.mesh.create_trimesh_shape()
	ground_collision.shape = shape
	
	static_body.add_child(ground_mesh)
	static_body.add_child(ground_collision)
	add_child(static_body)

#Sea stuff
var seaport = preload("res://scenes/prefabs/sea_transportation/seaport.tscn")
var seaports = []

func get_closest_available_sea_dock_to_point(point:Vector3):
	var closest_dist = INF
	var closest_seaport = null
	for seaport in seaports:
		if seaport.has_dock_available():
			var curr_dist = (seaport.global_position - point).length()
			if curr_dist < closest_dist:
				closest_seaport = seaport
				closest_dist = curr_dist
	#All seaports are taken or there are no ports on the island
	if closest_seaport == null:
		return null
	
	return closest_seaport.get_first_dock_available()

func has_available_sea_docks():
	for seaport in seaports:
		if seaport.has_dock_available():
			return true
	return false

func place_seaports():
	var number_of_seaports := 4
	var max_distance = square_distance * side_length
	var size = max_distance*4 + side_length
	var radius = size/3
	var center_pos = Vector3.ZERO
	for i in number_of_seaports:
		var theta :=  (i / (number_of_seaports * 1.0)) * 2.0 * PI
		var x:float = center_pos.x + radius * cos(theta)
		var y:float = center_pos.z + radius * sin(theta)
		var new_port = seaport.instantiate()
		var new_pos = Vector3(x, -0.1, y)
		new_port.position = new_pos
		new_port.rotate(Vector3.UP, -theta - PI/2)
		seaports.append(new_port)
		add_child(new_port)
