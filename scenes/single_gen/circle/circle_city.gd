extends Node3D

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
@export_range(5, 10000, 5) var circle_radius := 300:
	set(new_value):
		circle_radius = new_value
@export_range(3, 100, 1) var number_of_circle_vertices := 15:
	set(new_value):
		number_of_circle_vertices = new_value
@export_group("Splits")
@export_range(0, 10, 1) var split_iterations:int = 1:
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
@export_range(1, 1000, 1) var shore_size = 100

var roads_target
var building_target
var vertices_roadpoints := {}

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
	_update_structure()
	_reset_building_lots()
	building_renderer.place_building_lots(building_target)
	max_outermost_radius = circle_radius * 2 + shore_size + 50
	#Perform cleanup. to fill empty spaces
	for s in road_network.sectors:
		if s.type != "Nonbuildable": continue
		var verts = building_renderer.clean_up_sector(s.vertices.duplicate())
		building_renderer.place_building_color(verts, 0.3, building_target, Color(0,1,0,1))
	update_terrain_mesh()
	GlobalValues.road_network_array.append({"position": global_position, "road_network": road_network})
	var chunk_radius = GlobalValues.minor_chunk_manager.convert_radius_to_chunk_radius(circle_radius + shore_size)
	var center_chunk_pos = GlobalValues.minor_chunk_manager.convert_world_pos_to_chunk_pos(global_position)
	GlobalValues.minor_chunk_manager.cover_terrain_by_radius(center_chunk_pos, chunk_radius)
	GlobalValues.minor_chunk_manager.cover_island_territory_by_radius(center_chunk_pos, chunk_radius+3)
	place_seaports()

func _set_params(gen_seed:int= 0, split_iter:int = 0, 
	min_split_area = 1000, split_block_ch:float = 0.0, 
	radius = 100, circle_vertices = 10, 
	building_max_height:int = 1000, build_cell_size:int = 16) -> void:
	rseed = gen_seed
	split_iterations = split_iter
	minimum_split_area = min_split_area
	split_block_chance = split_block_ch
	circle_radius = radius
	number_of_circle_vertices = circle_vertices
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
	var vids = create_circle_polygon(0,0,circle_radius)
	var sector = RoadSector.new([], vids)
	sector.edges = road_network.reconstruct_sector_from_vertices(sector)
	sector.area = road_network.calculate_polygon_area(sector.vertices, true)
	road_network.add_sector(sector)
	
	_perform_splits(split_iterations)
	road_renderer.road_network = road_network
	road_renderer.render_road_network(roads_target, split_iterations <= 2)
	road_renderer.place_crossings(road_network.vertex_edges.keys(), roads_target)

func create_circle_polygon(cx:float, cy:float, radius:float) -> Array[int]:
	var vertices:Array[int] = []
	var edges:Array[int] = []
	var starting_id = road_network.get_last_vertice()
	var current_start_id = starting_id
	var current_end_id = starting_id
	
	for i in number_of_circle_vertices:
		var theta :=  (i / (number_of_circle_vertices * 1.0)) * 2.0 * PI
		var x:float = cx + radius * cos(theta)
		var y:float = cy + radius * sin(theta)
		current_start_id = current_end_id
		current_end_id = road_network.add_vertice(Vector3(x, 0, y))
		vertices.append(current_end_id)
		if (vertices.size() >= 2):
			var edge_id :int = road_network.add_edge_to_network(current_start_id, current_end_id)
			edges.append(edge_id)
			if (vertices.size() >= number_of_circle_vertices):
				road_network.add_edge_to_network(current_end_id, vertices[0])
	return vertices

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
func update_terrain_mesh() -> void:
	var plane := PlaneMesh.new()
	plane.subdivide_depth = resolution
	plane.subdivide_width = resolution
	var size = max_outermost_radius + 500
	plane.size = Vector2(size, size)
	
	var plane_arrays := plane.get_mesh_arrays()
	var vertex_array : PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_VERTEX]
	var normal_array : PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_NORMAL]
	var tangent_array : PackedFloat32Array = plane_arrays[ArrayMesh.ARRAY_TANGENT]
	
	for i:int in vertex_array.size():
		var vertex := vertex_array[i]
		var normal := Vector3.UP
		var tangent := Vector3.RIGHT
		if vertex.length() > circle_radius + shore_size:
			vertex.y = (circle_radius + shore_size - vertex.length())/2
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
	var radius = circle_radius + shore_size
	var center_pos = Vector3.ZERO
	for i in number_of_seaports:
		var theta :=  (i / (number_of_seaports * 1.0)) * 2.0 * PI
		var x:float = center_pos.x + radius * cos(theta)
		var y:float = center_pos.z + radius * sin(theta)
		var new_port = seaport.instantiate()
		var new_pos = Vector3(x, -0.05, y)
		new_port.position = new_pos
		new_port.rotate(Vector3.UP, -theta - PI/2)
		seaports.append(new_port)
		add_child(new_port)
