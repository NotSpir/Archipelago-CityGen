extends Node
class_name GridPathGenerator

@export var regenerate = false:
	set(new_value):
		for child in get_children():
			if child is MeshInstance3D:
				child.queue_free()
		
		place_grid_assets(6, 0)
		

@export_range(1, 256, 1) var grid_width:int = 32
@export_range(1, 256, 1) var grid_height:int = 32
@export_range(0., 1., 0.001) var target_placement_chance = 0.01
@export_range(0., 1., 0.001) var decor_chance = 0.15
@export var decor_num = 3
@export var road_num = 2
@export var block_num = 0

const DIRECTIONS = [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT
]

var roads_default_road_pool:Dictionary = {
	"Empty": "res://assets/programmer_grid/Empty.png",
	"Straight": "res://assets/programmer_grid/Straight.png",
	"Corner": "res://assets/programmer_grid/Corner.png",
	"Deadend": "res://assets/programmer_grid/Deadend.png",
	"T": "res://assets/programmer_grid/T.png",
	"Cross": "res://assets/programmer_grid/Cross.png"
}

var roads_default_objects_pool:Array = [
	preload("res://scenes/prefabs/park_assets/makeshift_bush.tscn")
	]

var grid:Array = []

func print_grid() -> void:
	for r in grid.size():
		print(grid[r])

func generate_random_grid() -> void:
	grid = []
	for r in grid.size():
		var row = []
		for c in grid[r].size():
			if randf() < decor_chance:
				row.append(3)
			else: row.append(1)
		grid.append(row)



func convert_num_grid_to_search_grid(num_grid:Array) -> Array:
	var new_grid = []
	for r in grid.size():
		var row = []
		for c in grid[r].size():
			var cell = Cell.new()
			cell.num = num_grid[r][c]
			row.append(cell)
		new_grid.append(row)
	return new_grid

func scatter_target_points():
	var targets = []
	for r in grid.size():
		for c in grid[r].size():
			if (grid[r][c] != 1): continue
			var roll = randf()
			if roll <= target_placement_chance:
				targets.append(Vector2i(r,c))
				r+=1
				break
	return targets

func get_cell_dict_from_grid():
	var open_list = {}
	for r in grid.size():
		for c in grid[r].size():
			open_list[Vector2i(r,c)] = true
	return open_list

func get_path_between_two_targets(start:Vector2i, target_pos:Vector2i, num_grid) -> Array:
	var open_list = get_cell_dict_from_grid()
	var converted_grid = convert_num_grid_to_search_grid(grid)
	var candidates = [start]
	while true:
		var new_candidates = []
		while candidates.size() > 0:
			var pos = candidates.pop_back()
			for dir in DIRECTIONS:
				var new_pos =  pos + dir
				if new_pos.x < 0 || new_pos.x >= grid.size(): continue
				if new_pos.y < 0 || new_pos.y >= grid[new_pos.x].size(): continue
				
				if new_pos == target_pos:
					var path = [new_pos, pos]
					var current_pos = pos
					while true:
						current_pos = converted_grid[current_pos.x][current_pos.y].prev_passed
						path.append(current_pos)
						if current_pos == Vector2i(-1,-1):
							break
						if (current_pos == start): break
					return path
				
				if open_list[new_pos]:
					open_list[new_pos] = false
					if converted_grid[new_pos.x][new_pos.y].num != 0:
						converted_grid[new_pos.x][new_pos.y].prev_passed = pos
						new_candidates.append(new_pos)
		candidates = new_candidates.duplicate()
		new_candidates.clear()
		if candidates.size() == 0: 
			break
	return []

func find_nearest_path_point(grid: Array, target: Vector2i) -> Vector2i:
	var closest_pos = Vector2i(-1,-1)
	var closest_dist = INF
	
	for x in grid.size():
		for y in grid[0].size():
			if grid[x][y] == 2:  # Path cell
				var dist = abs(x - target.x) + abs(y - target.y)
				if dist < closest_dist:
					closest_dist = dist
					closest_pos = Vector2i(x, y)
	return closest_pos

class Cell:
	var num = 0
	var prev_passed = Vector2i(-1,-1)


func create_textured_plane(texture_path: String, size: Vector2 = Vector2(1, 1)) -> MeshInstance3D:
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

func place_grid_assets(cell_size, grid_start_pos = Vector3(0,0,0), roads_pool:Dictionary = roads_default_road_pool, objects_pool:Array = roads_default_objects_pool):
	var cell_meshes = []
	var objects = []
	for r in grid.size():
		for c in grid[r].size():
			var grid_pos = Vector2(r,c)
			var world_pos_2d = grid_pos * cell_size
			var world_pos = Vector3(world_pos_2d.x,0,world_pos_2d.y)
			var cell_mesh
			var cell_info = {"type": "Cell", "texture": "", "position": world_pos, "rotation": 0, "cell_size": cell_size }
			if grid[r][c] == decor_num:
				cell_mesh = create_textured_plane(roads_pool["Empty"], Vector2(cell_size,cell_size))
				cell_info.texture = roads_pool["Empty"]
				var obj_prefab = objects_pool[randi_range(0, objects_pool.size()-1)]
				var new_obj = obj_prefab.instantiate()
				var obj_pos = grid_start_pos + Vector3(world_pos.z, 0, world_pos.x) + Vector3(0,0.01,0)
				new_obj.position = obj_pos
				var obj_info = {"type": "Object", "position": obj_pos, "object_prefab": obj_prefab}
				objects.append(obj_info)
			elif grid[r][c] == 1:
				cell_mesh = create_textured_plane(roads_pool["Empty"], Vector2(cell_size,cell_size))
				cell_info.texture = roads_pool["Empty"]
			elif grid[r][c] == road_num:
				var result = get_path_tile_type(grid_pos)
				match result.type:
					"Deadend":
						cell_mesh = create_textured_plane(roads_pool["Deadend"], Vector2(cell_size,cell_size))
						cell_info.texture = roads_pool["Deadend"]
					"Straight":
						cell_mesh = create_textured_plane(roads_pool["Straight"], Vector2(cell_size,cell_size))
						cell_info.texture = roads_pool["Straight"]
					"Corner":
						cell_mesh = create_textured_plane(roads_pool["Corner"], Vector2(cell_size,cell_size))
						cell_info.texture = roads_pool["Corner"]
					"T":
						cell_mesh = create_textured_plane(roads_pool["T"], Vector2(cell_size,cell_size))
						cell_info.texture = roads_pool["T"]
					"Cross":
						cell_mesh = create_textured_plane(roads_pool["Cross"], Vector2(cell_size,cell_size))
						cell_info.texture = roads_pool["Cross"]
					"Empty":
						continue
				cell_mesh.rotate(Vector3.UP, result.rotation)
				cell_info.rotation = result.rotation
			else: continue
			var result_pos = Vector3(world_pos.z, 0, world_pos.x) + grid_start_pos
			cell_mesh.position = result_pos
			cell_info.position = result_pos
			cell_meshes.append(cell_info) 
	return {"cells": cell_meshes, "objects": objects }

func get_path_tile_type(grid_pos:Vector2i):
	var type = "Deadend"
	var tile_rotation = 0
	var connections = []
	for dir in DIRECTIONS:
		var pos = grid_pos + dir
		if (pos.x >= grid.size() || pos.x < 0): 
			continue
		if (pos.y >= grid[pos.x].size() || pos.y < 0): 
			continue
		if grid[pos.x][pos.y] == 2:
			connections.append(pos)
	
	match connections.size():
		1: #Deadend
			var dir = grid_pos - connections[0]
			tile_rotation = get_rotation_from_grid_dir(dir)
			
		
		2: #Corner/Straight
			type = "Corner"
			var dir1 = grid_pos - connections[0]
			var dir2 = grid_pos - connections[1]
			#var angle = abs(dir1.angle_to(dir2))
			if dir1 == -dir2:
				type = "Straight"
				tile_rotation = get_rotation_from_grid_dir(dir1)
			else:
				type = "Corner"
				tile_rotation = get_rotation_from_grid_dir(dir1)
		
		3: #T corner
			type = "T"
			for dir in DIRECTIONS:
				var pos = grid_pos + dir
				if (pos.x >= grid.size() || pos.x < 0): 
					tile_rotation = get_rotation_from_grid_dir(dir)
					break
				if (pos.y >= grid[pos.x].size() || pos.y < 0): 
					tile_rotation = get_rotation_from_grid_dir(dir)
					break
				if grid[pos.x][pos.y] != 2:
					tile_rotation = get_rotation_from_grid_dir(dir)
					break
	
		4: #Cross
			type = "Cross"
		0: 
			type = "Empty"
	
	return { "type": type, "rotation": tile_rotation }


func get_rotation_from_grid_dir(dir:Vector2i):
	if dir == Vector2i(0,1): return -PI/2
	elif dir == Vector2i(1,0): return PI
	elif dir == Vector2i(0,-1): return PI/2
	elif dir == Vector2i(-1,0): return 0

func scatter_decor_on_existing_grid():
	for r in grid.size():
		for c in grid[r].size():
			if grid[r][c] != 1: continue
			if randf() < decor_chance:
				grid[r][c] = decor_num

func create_random_paths():
	var targets = scatter_target_points()
	var set_start = false
	for t in targets:
		if !set_start:
			grid[t.x][t.y] = road_num
			set_start = true
			continue
		var dest = find_nearest_path_point(grid, t)
		if dest == Vector2i(-1,-1):
			continue
		var path_t = get_path_between_two_targets(t, dest, grid)
		for p in path_t:
			grid[p.x][p.y] = road_num

func perform_generation(new_grid:Array, cell_size, grid_start_pos = Vector3(0,0,0),  roads_pool:Dictionary = roads_default_road_pool, objects_pool:Array = roads_default_objects_pool):
	grid = new_grid
	scatter_decor_on_existing_grid()
	create_random_paths()
	var result = place_grid_assets(cell_size, grid_start_pos, roads_pool, objects_pool)
	return result
