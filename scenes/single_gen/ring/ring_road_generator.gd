@tool
extends Node3D
class_name RingRoadGenerator

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
@export_range(0, 1024, 1) var streetlight_distance := 128.:
	set(new_value):
		streetlight_distance = new_value
@export_group("Central Circle")
@export_range(5, 10000, 5) var initial_circle_radius := 100:
	set(new_value):
		initial_circle_radius = new_value
@export_range(3, 100, 1) var number_of_circle_vertices := 15:
	set(new_value):
		number_of_circle_vertices = new_value
@export_group("Potato Outers")
@export_range(0, 20, 1) var number_of_outers := 1:
	set(new_value):
		number_of_outers = new_value
@export_range(100, 5000, 50) var distance_between_outers := 1500:
	set(new_value):
		distance_between_outers = new_value
@export_range(50, 5000, 50) var additional_distance_between_outers := 100:
	set(new_value):
		additional_distance_between_outers = new_value
@export_range(0, 1, 0.05) var jank := 0.2:
	set(new_value):
		jank = new_value #This code is so jank. (humour)
@export_range(0, 1, 0.05) var minimal_radius_range := 0.4:
	set(new_value):
		minimal_radius_range = new_value
@export_range(3, 100, 1) var number_of_potato_vertices := 20:
	set(new_value):
		number_of_potato_vertices = new_value
@export_group("Highways")
@export_range(0, 10, 1) var starting_highways := 4:
	set(new_value):
		starting_highways = new_value
@export_range(0, 1000, 5) var min_highway_segment_length := 200:
	set(new_value):
		min_highway_segment_length = new_value
@export_range(0, 1000, 5) var max_highway_segment_length := 200:
	set(new_value):
		max_highway_segment_length = new_value
@export_range(0, 255, 1) var max_highway_length := 15:
	set(new_value):
		max_highway_length = new_value
@export_range(-180, 180, 5) var highway_turn_angle := 0:
	set(new_value):
		highway_turn_angle = new_value
@export_group("Splits")
@export_range(0, 10, 1) var split_iterations:int = 3:
	set(new_value):
		split_iterations = new_value
@export_range(0, 1, 0.001) var split_block_chance:float = 0.01:
	set(new_value):
		split_block_chance = new_value
@export_range(0, 10000000, 5) var minimum_split_area := 100:
	set(new_value):
		minimum_split_area = new_value
@export_range(0, 10000000, 5) var max_blocked_sector_size := 1000:
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
@export_range(1, 1000, 1) var shore_size = 150

var highway_vertices : Array[Dictionary] = [] #{'vertice_id': int, 'is_intersection': bool}
var current_highway_count := 0
var last_start_highway_vid = -1
var curr_start_highway_vid = -1
var last_highway_radius_vid = -1
var last_highway_vids = []
var first_highway_vids = []
var curr_highway_idx := -1
var roads_target
var building_target
var vertices_roadpoints := {}

var outermost_potato_vertices = []
var max_outermost_radius = 0

var road_network:RoadNetwork
var road_renderer = RoadRenderer.new()
var building_renderer = BuildingRenderer.new()

@onready var ground_mesh = $StaticBody3D/GroundMesh
@onready var ground_collision = $StaticBody3D/CollisionShape3D

#Traversing the seas
var seaports = []


func _ready() -> void:
	pass
	#_regenerate()

func _regenerate() -> void:
	
	await _update_structure()
	_reset_building_lots()
	await building_renderer.place_building_lots(building_target)
	max_outermost_radius += shore_size
	#Perform cleanup. to fill empty spaces
	for s in road_network.sectors:
		if s.type != "Nonbuildable": continue
		var verts = building_renderer.clean_up_sector(s.vertices.duplicate())
		building_renderer.place_building_color(verts, 0.3, building_target, Color(0,1,0,1))
	update_terrain_mesh()
	GlobalValues.road_network_array.append({"position": global_position, "road_network": road_network})
	var chunk_radius = GlobalValues.minor_chunk_manager.convert_radius_to_chunk_radius(max_outermost_radius+shore_size) + 2
	var center_chunk_pos = GlobalValues.minor_chunk_manager.convert_world_pos_to_chunk_pos(global_position)
	GlobalValues.minor_chunk_manager.cover_terrain_by_radius(center_chunk_pos, chunk_radius)
	GlobalValues.minor_chunk_manager.cover_island_territory_by_radius(center_chunk_pos, chunk_radius+3)
	place_seaports()

func _set_params(gen_seed:int= 0, split_iter:int = 0, 
	min_split_area = 1000, split_block_ch:float = 0.0, 
	outer_rings = 1, ring_distance = 500, initial_radius = 100, 
	building_max_height:int = 1000, build_cell_size:int = 16) -> void:
	rseed = gen_seed
	split_iterations = split_iter
	minimum_split_area = min_split_area
	split_block_chance = split_block_ch
	number_of_outers = outer_rings
	distance_between_outers = ring_distance
	initial_circle_radius = initial_radius
	building_renderer.max_height = building_max_height
	building_renderer.lot_cell_size = build_cell_size
	building_renderer.sector_edge_distance = sector_edge_distance
	road_renderer.width = width
	road_renderer.thickness = thickness
	road_renderer.side_width = side_width

func _update_structure() -> void:
	_reset_road_network()
	road_renderer.road_network = road_network
	building_renderer.road_network = road_network
	building_renderer.global_offset = global_position
	start_sprawling_highways()
	_perform_splits(split_iterations)
	road_renderer.road_network = road_network
	road_renderer.render_road_network(roads_target, split_iterations <= 2)
	road_renderer.place_crossings(road_network.vertex_edges.keys(), roads_target)

func _reset_building_lots() -> void:
	if building_target == null:
		var root_node := Node3D.new()
		root_node.name = "Buildings"
		add_child(root_node)
		building_target = root_node
		root_node.owner = get_tree().edited_scene_root
	
	for child in building_target.get_children():
		child.queue_free()

func _reset_road_network() -> void:
	if roads_target == null:
		var root_node := Node3D.new()
		root_node.name = "Roads"
		add_child(root_node)
		roads_target = root_node
		root_node.owner = get_tree().edited_scene_root
	
	for child in roads_target.get_children():
		child.queue_free()
	vertices_roadpoints = {}
	current_highway_count = 0
	highway_vertices = []
	last_start_highway_vid = -1
	curr_start_highway_vid = -1
	last_highway_radius_vid = -1
	last_highway_vids = []
	first_highway_vids = []
	curr_highway_idx = -1
	road_network = RoadNetwork.new()
	seed(rseed)

func _perform_splits(iterations:int) -> void:
	var polygons : Array[RoadSector] = []
	var ci = 0
	while ci < iterations:
		var current_sector_ids = []
		for i in range(road_network.sectors.size()):
			current_sector_ids.append(i)
		
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
			result = road_network.split_sector_longest_to_opposite(pid, 0.15, true, 2)
			if result:
				if result.polygon1.vertices.size() <= 2:
					road_network.sectors[pid].splittable = false
					polygons.append(road_network.sectors[pid])
					continue
				if result.polygon2.vertices.size() <= 2:
					road_network.sectors[pid].splittable = false
					polygons.append(road_network.sectors[pid])
					continue
				
				polygons.append(result.polygon1)
				polygons.append(result.polygon2)
				continue
			
			road_network.sectors[pid].splittable = false
			polygons.append(road_network.sectors[pid])
		
		road_network.sectors = []
		for poly in polygons:
			poly.edges = road_network.reconstruct_sector_from_vertices(poly)
			road_network.add_sector(poly)
		polygons = []
		ci += 1
	road_network.reassign_all_sectors_random()
	
	var n = road_network.sectors.size()
	for i in n:
		var vids = road_network.sectors[i].vertices
		var vertices = []
		for vid in vids:
			vertices.append(road_network.vertices[vid])
		#var is_convex = road_network.is_sector_convex(vertices)
		#if !is_convex:
			#road_network.sectors[i].type = "Blocked"

func start_sprawling_highways() -> void:
	for i in starting_highways:
		last_start_highway_vid = curr_start_highway_vid
		var theta := (i/(starting_highways*1.)) * 2 * PI
		var x:float = initial_circle_radius * cos(theta)
		var y:float = initial_circle_radius * sin(theta)
		var directed_pos = Vector3(x, 0, y)
		var start_vid = road_network.add_vertice(directed_pos)
		create_highway_segment(start_vid, directed_pos.normalized(), 0, 0, [start_vid])
		current_highway_count += 1

func create_highway_segment(start_vertice_id:int, direction:Vector3, current_length:int, 
current_intersections:int, current_highway_vids:Array[int] = [], 
previous_potato_vids:Array[int] = [], last_sector_previous_potato_vids:Array[int] = []) -> void:
	if (current_length >= max_highway_length):
		return
	
	var randomized_rotation = deg_to_rad(randf_range(-highway_turn_angle, highway_turn_angle))
	var randomized_distance = randf_range(min_highway_segment_length, max_highway_segment_length)
	var modified_direction = direction.rotated(Vector3.UP, randomized_rotation)
	var end_pos = modified_direction * randomized_distance + road_network.vertices[start_vertice_id]
	var new_vertice_id = road_network.add_vertice(end_pos)
	road_network.add_edge_to_network(start_vertice_id, new_vertice_id)
	current_highway_vids.append(new_vertice_id)
	
	var next_outer_radius := initial_circle_radius + distance_between_outers + current_intersections * additional_distance_between_outers
	if end_pos.length() >= next_outer_radius && current_intersections < number_of_outers:
		if current_highway_count >= 1:
			#Perform filling in
			var new_poly_vids: Array[int] = []
			new_poly_vids.append(last_highway_vids[0])
			var last_highway_theta := ((current_highway_count-1)/(starting_highways*1.)) * 2 * PI
			var curr_highway_theta := (current_highway_count/(starting_highways*1.)) * 2 * PI
			var data = create_polygon_between_highways(last_highway_vids, current_highway_vids, 
				last_highway_theta, curr_highway_theta, 
				next_outer_radius, previous_potato_vids)
			var new_sector = data.new_sector
			previous_potato_vids = data.potato_vids
			road_network.add_sector(new_sector)
		else:
			first_highway_vids = current_highway_vids.duplicate()
			
		if current_highway_count == starting_highways-1:
			var last_highway_theta := ((current_highway_count)/(starting_highways*1.)) * 2 * PI
			var curr_highway_theta := 2 * PI
			var data = create_polygon_between_highways(current_highway_vids, first_highway_vids, 
			last_highway_theta, curr_highway_theta, 
			next_outer_radius, last_sector_previous_potato_vids)
			var new_sector = data.new_sector
			last_sector_previous_potato_vids = data.potato_vids
			road_network.add_sector(new_sector)

		current_intersections += 1
		if current_intersections == number_of_outers:
			last_highway_vids = current_highway_vids.duplicate()
			return
		
	create_highway_segment(new_vertice_id, modified_direction, current_length + 1, current_intersections,current_highway_vids, previous_potato_vids, last_sector_previous_potato_vids)

func create_polygon_between_highways(prev_highway_vids, curr_highway_vids, prev_theta, curr_theta, potato_radius, inner_potato_vertices = []):
	#Perform filling in
	var new_poly_vids: Array[int] = []
	
	#Filling in the circle edges between
	var starting_id = prev_highway_vids[0]
	var current_start_id = starting_id
	var current_end_id = starting_id
	
	if inner_potato_vertices.is_empty():
		new_poly_vids.append(starting_id)
		#If first ring, create circle.
		for i in number_of_circle_vertices + 1:
			var theta :=  (i / (number_of_circle_vertices * 1.0)) * 2.0 * PI
			if theta <= prev_theta: continue
			
			if (theta >= curr_theta):
				road_network.add_edge_to_network(current_end_id, curr_highway_vids[0])
				break
			var x:float = initial_circle_radius * cos(theta)
			var y:float = initial_circle_radius * sin(theta)
			current_start_id = current_end_id
			current_end_id = road_network.add_vertice(Vector3(x, 0, y))
			new_poly_vids.append(current_end_id)
			road_network.add_edge_to_network(current_start_id, current_end_id)
	else:
		#If second, apply previous potato's vertices here. From other end of course, since it's opposite now.
		var p = inner_potato_vertices.size()-1
		while p >= 0:
			new_poly_vids.append(inner_potato_vertices[p])
			p-=1
	
	#Adding this highway vertices in their original order
	var prev_potato_radius = potato_radius - additional_distance_between_outers
	for vid in curr_highway_vids: 
		var vertice = road_network.vertices[vid]
		if vertice.length() < prev_potato_radius: continue
		new_poly_vids.append(vid)
		if vertice.length() >= potato_radius: break
	
	#Noting other highway's vertices (in opposite order) and receiving vid for potato to end on
	var prev_highway_vids_included = []
	var potato_end_vid = -1
	var j = prev_highway_vids.size()-1
	while j >= 0:
		var vid = prev_highway_vids[j]
		if vid == new_poly_vids[0]: 
			break
		var vertice = road_network.vertices[vid]
		if vertice.length() >= potato_radius+distance_between_outers: 
			j-=1
			continue
		if potato_end_vid == -1:
			potato_end_vid = vid
		prev_highway_vids_included.append(vid)
		j-=1
	#Filling in the outer 'potato' between (With theta going backwards).
	var potato_vids:Array[int] = []
	var potato_i := number_of_potato_vertices - 1
	var potato_start_id = new_poly_vids[new_poly_vids.size()-1]
	var potato_end_id = new_poly_vids[new_poly_vids.size()-1]
	
	var phases = []
	phases.append(randf_range(0, 2 * PI))
	phases.append(randf_range(0, 2 * PI))
	phases.append(randf_range(0, 2 * PI))
	phases.append(randf_range(0, 2 * PI))
	var amplitudes = [jank * 0.5, jank * 0.3, jank * 0.15, jank * 0.05]
	while potato_i >= 0:
		var potato_theta :=  (potato_i / (number_of_potato_vertices * 1.0)) * 2.0 * PI
		if potato_theta >= curr_theta: 
			potato_i -= 1
			continue
		
		if potato_theta <= prev_theta:
			road_network.add_edge_to_network(potato_end_id, potato_end_vid) 
			potato_vids.append(potato_end_vid)
			break
		var mod_r = potato_radius * (1 
		+ amplitudes[0] * sin(1 * potato_theta + phases[0])  # 1 lobe (egg shape)
		+ amplitudes[1] * sin(2 * potato_theta + phases[1])  # 2 lobes (peanut)
		+ amplitudes[2] * sin(3 * potato_theta + phases[2])  # 3 lobes (triangle-ish)
		+ amplitudes[3] * sin(4 * potato_theta + phases[3])  # minor micro-jank
	)
		mod_r = max(minimal_radius_range * potato_radius, mod_r)
		var x:float = mod_r * cos(potato_theta)
		var y:float = mod_r * sin(potato_theta)
		
		potato_start_id = potato_end_id
		potato_end_id = road_network.add_vertice(Vector3(x, 0, y))
		potato_vids.append(potato_end_id)
		new_poly_vids.append(potato_end_id)
		road_network.add_edge_to_network(potato_start_id, potato_end_id)
		potato_i -= 1
	
	for vid in prev_highway_vids_included:
		new_poly_vids.append(vid)
	
	#Storing outer to note shoreline
	if potato_radius >= initial_circle_radius + distance_between_outers + (number_of_outers - 1) * additional_distance_between_outers - 100:
		var i = potato_vids.size()-1
		while i >= 0:
			var pvid = potato_vids[i]
			outermost_potato_vertices.append(pvid)
			var v = road_network.vertices[pvid]
			if v.length() > max_outermost_radius:
				max_outermost_radius = v.length()
			i-=1
	
	var new_sector = RoadSector.new([],new_poly_vids)
	new_sector.edges = road_network.reconstruct_sector_from_vertices(new_sector)
	new_sector.area = road_network.calculate_polygon_area(new_sector.vertices, true)
	return {"new_sector": new_sector, "potato_vids": potato_vids}

func update_terrain_mesh() -> void:
	var plane := PlaneMesh.new()
	plane.subdivide_depth = resolution
	plane.subdivide_width = resolution
	var size = max_outermost_radius*2+600
	plane.size = Vector2(size, size)
	
	var plane_arrays := plane.get_mesh_arrays()
	var vertex_array : PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_VERTEX]
	var normal_array : PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_NORMAL]
	var tangent_array : PackedFloat32Array = plane_arrays[ArrayMesh.ARRAY_TANGENT]
	
	for i:int in vertex_array.size():
		var vertex := vertex_array[i]
		var normal := Vector3.UP
		var tangent := Vector3.RIGHT
		if vertex.length() > max_outermost_radius:
			vertex.y = (max_outermost_radius - vertex.length())/2
			var epsilon = size/resolution
			tangent = normal.cross(Vector3.UP)
		elif vertex.length() < initial_circle_radius - 50:
			vertex.y = (initial_circle_radius - vertex.length() - 50)/-3
			var epsilon = size/resolution
			tangent = normal.cross(Vector3.UP)
		vertex_array[i] = vertex
		normal_array[i] = normal
		tangent_array[4*i] = tangent.x
		tangent_array[4*i + 1] = tangent.y
		tangent_array[4*i + 2] = tangent.z
	
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane_arrays)
	ground_mesh.mesh = array_mesh
	
	var shape = ground_mesh.mesh.create_trimesh_shape()
	ground_collision.shape = shape

#Sea stuff
var seaport = preload("res://scenes/prefabs/sea_transportation/seaport.tscn")

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
	var number_of_seaports := 5
	var radius = max_outermost_radius
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
