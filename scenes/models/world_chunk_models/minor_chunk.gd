class_name MinorChunk

var chunk_position:Vector2
var loading_objects = []
var loaded_objects = []
var target_node:Node3D
var loading_buildings = []
var loaded_buildings = []
var contains_terrain = false
var contains_ship_route = false
var contains_island_nearby = false
#TODO: Add roads to minor chunks. I have no clue how to do it better. Torture
var loading_roads = []
var loaded_roads = []

func load_chunk():
	for info in loading_objects:
		render_info(info)

func add_info(info):
	loading_objects.append(info)

func add_building_info(info):
	loading_buildings.append(info)

func unload_objects():
	for object in loaded_objects:
		object.queue_free()
	loaded_objects = []

func unload_buildings():
	for b in loaded_buildings:
		if (b != null):
			b.queue_free()
	loaded_buildings = []

func load_buildings():
	for b in loading_buildings:
		render_building(b.corners, b.height, target_node, b.color)

#Copied from BuildingRenderer lol
func render_building(lot_vertices: Array, depth:float, parent:Node3D, color:Color = Color(1,1,1,1)):
	var poly_2d = PackedVector2Array()
	var min_y = INF
	for v in lot_vertices:
		min_y = min(min_y, v.y)
		poly_2d.append(Vector2(v.x, v.z))
	var csg = CSGPolygon3D.new()
	csg.mode = CSGPolygon3D.MODE_DEPTH
	csg.polygon = poly_2d
	csg.depth = depth
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	csg.material_override = mat
	csg.use_collision = true
	csg.rotation.x = deg_to_rad(90)
	parent.add_child(csg)
	loaded_buildings.append(csg)

func has_data():
	if loading_objects.size() != 0: return true
	if loading_buildings.size() != 0: return true
	return false

func render_info(info):
	match info.type:
		"Object":
			var obj = render_object(info.object_prefab, info.position)
			loaded_objects.append(obj)
		
		"Cell":
			var cell_size = Vector2(info.cell_size,info.cell_size)
			var cell = create_cell_mesh(info.texture, cell_size)
			cell.rotate(Vector3.UP, info.rotation)
			cell.position = info.position
			loaded_objects.append(cell)
			target_node.add_child(cell)
		
func render_object(obj_prefab, obj_pos):
	var new_obj = obj_prefab.instantiate()
	new_obj.position = obj_pos
	target_node.add_child(new_obj)
	return new_obj

func create_cell_mesh(texture_path: String, size: Vector2 = Vector2(1, 1)) -> MeshInstance3D:
	var texture = load(texture_path) as Texture2D
	if texture == null:
		printerr("Failed to load texture: ", texture_path)
		return null
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = size
	var material = StandardMaterial3D.new()
	material.albedo_texture = texture
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = plane_mesh
	mesh_instance.material_override = material
	return mesh_instance
