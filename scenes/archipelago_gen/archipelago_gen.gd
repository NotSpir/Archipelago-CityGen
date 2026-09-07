extends Node3D

var prepacked_ring_gen = preload("res://scenes/single_gen/ring/ring_road_generator.tscn")
var prepacked_circle_gen = preload("res://scenes/single_gen/circle/circle_city.tscn")

var gen_seed = 0
var islands_amount := 7
var max_height = 1000
var cell_size = 8

var islands = []
var ship_prefab = preload("res://scenes/prefabs/sea_transportation/ship.tscn")
const DIRECTIONS = [
	Vector2.UP,
	Vector2.RIGHT,
	Vector2.DOWN,
	Vector2.LEFT
]

var small_island_prefab = preload("res://scenes/small_islands/predetermined-test.tscn")
var island_chance = 0.001
var centre = Vector3(0,0,0)

func _set_params(new_seed, island_count, build_height, build_cell_size):
	gen_seed = new_seed
	islands_amount = island_count
	max_height = build_height
	cell_size = build_cell_size

func _regenerate():
	GlobalValues.road_network_array = []
	spawn_big_islands()
	create_sea_routes()

func spawn_big_islands():
	var counter := islands_amount
	var iter = 0
	var max_count := 1
	while counter > 0:
		var radius = iter * 5000
		for i in max_count:
			var theta :=  (i / (max_count * 1.0)) * 2.0 * PI
			var x:float = centre.x + radius * cos(theta)
			var y:float = centre.y + radius * sin(theta)
			var island_pos = Vector3(x, 0, y)
			match randi_range(0,2):
				0:
					spawn_ring_island(island_pos)
				1:
					spawn_square_island(island_pos)
				2:
					spawn_circle_island(island_pos)
		iter +=1
		counter -= max_count
		if max_count == 1:
			max_count = min(max_count+4, counter)
		else: max_count = min(max_count*2, counter)

func create_sea_routes():
	var i = 0
	while i < islands.size():
		var curr_island = islands[i]
		var curr_center_pos = curr_island.position
		for j in range(i+1, islands.size()):
			var scan_island = islands[j]
			var scan_center_pos = scan_island.position
			var curr_has_dock = curr_island.has_available_sea_docks() 
			var scan_has_dock = scan_island.has_available_sea_docks() 
			if curr_has_dock && scan_has_dock:
				var start_dock_pos = curr_island.get_closest_available_sea_dock_to_point(scan_center_pos)
				var scan_dock_pos = scan_island.get_closest_available_sea_dock_to_point(curr_center_pos)
				if start_dock_pos == null || scan_dock_pos == null:
					continue
				var chunk_path = calculate_sea_path(start_dock_pos, scan_dock_pos)
				if chunk_path == []:
					continue
				var path = [scan_dock_pos]
				chunk_path.pop_back()
				chunk_path.pop_front()
				
				for chunk in chunk_path:
					GlobalValues.minor_chunk_manager.cover_ship_routes_by_radius(chunk, 2)
					var mid_cpoint = GlobalValues.minor_chunk_manager.convert_chunk_pos_to_world_pos(chunk)
					path.append(mid_cpoint)
				path.append(start_dock_pos)
				var ship = ship_prefab.instantiate()
				ship.set_path(path)
				ship.position = start_dock_pos
				add_child(ship)
		i+=1
			


func calculate_sea_path(start, end):
	var chunk_dict = convert_minor_chunks_to_search_dict(start, end, 100)
	var open_list = get_cell_dict_from_grid(chunk_dict)
	var start_chunk_pos = GlobalValues.minor_chunk_manager.convert_world_pos_to_chunk_pos(start)
	var end_chunk_pos = GlobalValues.minor_chunk_manager.convert_world_pos_to_chunk_pos(end)
	var candidates = [start_chunk_pos]
	while true:
		var new_candidates = []
		while candidates.size() > 0:
			var pos = candidates.pop_back()
			for dir in DIRECTIONS:
				var new_pos =  pos + dir
				if !chunk_dict.has(new_pos): continue
				
				if new_pos == end_chunk_pos:
					var path = [new_pos, pos]
					var current_pos = pos
					while true:
						current_pos = chunk_dict[current_pos].prev_passed
						path.append(current_pos)
						if current_pos == Vector2(-1,-1):
							print("Broken sea route. Dang.")
							break
						if (current_pos == start_chunk_pos): break
					return path
				
				if open_list[new_pos]:
					open_list[new_pos] = false
					if chunk_dict[new_pos].num == 0: continue
					if chunk_dict[new_pos].num == 2: continue
					
					#If rolled, instead of proceeding will place a random island. Pure fun.
					if randf() <= island_chance:
						if chunk_dict[new_pos].num == 3: continue
						chunk_dict[new_pos].num = 0
						var conv_pos = GlobalValues.minor_chunk_manager.convert_chunk_pos_to_world_pos(new_pos)
						spawn_small_island_along_the_path(conv_pos)
						continue
					chunk_dict[new_pos].prev_passed = pos
					new_candidates.append(new_pos)
						
		candidates = new_candidates.duplicate()
		new_candidates.clear()
		if candidates.size() == 0: 
			break
	return []

func convert_minor_chunks_to_search_dict(start, end, radius):
	var new_chunk_grid = {}
	var start_pos = GlobalValues.minor_chunk_manager.convert_world_pos_to_chunk_pos(start)
	var end_pos = GlobalValues.minor_chunk_manager.convert_world_pos_to_chunk_pos(end)
	for dx in range(-radius, radius+1):
		for dz in range(-radius, radius+1):
			var sr_chunk_pos = start_pos + Vector2(dx,dz)
			var er_chunk_pos = end_pos + Vector2(dx,dz)
			if !new_chunk_grid.has(sr_chunk_pos):
				var num = 1
				var chunk = GlobalValues.minor_chunk_manager.create_chunk_if_not_exists(sr_chunk_pos)
				if chunk.has_data(): num = 0
				elif chunk.contains_terrain: num = 0
				elif chunk.contains_island_nearby: num = 3
				new_chunk_grid[sr_chunk_pos] = Cell.new(num)
			if !new_chunk_grid.has(er_chunk_pos):
				var num = 1
				var chunk = GlobalValues.minor_chunk_manager.create_chunk_if_not_exists(er_chunk_pos)
				if chunk.has_data(): num = 0
				elif chunk.contains_terrain: num = 2
				new_chunk_grid[er_chunk_pos] = Cell.new(num)
	return new_chunk_grid

func get_cell_dict_from_grid(chunk_dict):
	var open_list = {}
	for chunk in chunk_dict.keys():
		open_list[chunk] = true
	return open_list

class Cell:
	var num = 0
	var prev_passed = Vector2i(-1,-1)
	
	func _init(new_num):
		num = new_num

func spawn_small_island_along_the_path(pos):
	var small_island = small_island_prefab.instantiate()
	var chunk_pos = GlobalValues.minor_chunk_manager.convert_world_pos_to_chunk_pos(pos)
	GlobalValues.minor_chunk_manager.cover_terrain_by_radius(chunk_pos, 2)
	GlobalValues.minor_chunk_manager.cover_island_territory_by_radius(chunk_pos, 3)
	small_island.position = pos
	add_child(small_island)
	small_island.generate_new_terrain()

func get_seed_by_pos(pos:Vector3):
	return gen_seed + pos.x + pos.z

func spawn_square_island(pos:Vector3):
	var square_island = SquareCityGenerator.new()
	square_island.position = pos
	var cell_radius = randf_range(1,3)
	var square_cell_size = randf_range(256,512)
	var min_split_amount = randi_range(0,2)
	var max_split_amount = randi_range(min_split_amount, 4)
	square_island._set_params(get_seed_by_pos(pos), cell_radius, square_cell_size,
			min_split_amount, max_split_amount,
			20000, 0.01,  
			max_height, cell_size)
	add_child(square_island)
	square_island._regenerate(square_island.position)
	islands.append(square_island)

func spawn_ring_island(pos:Vector3):
	var ring_island = prepacked_ring_gen.instantiate()
	ring_island.position = pos
	var random_initial_radius = randi_range(150,500)
	var outer_number = randi_range(1,2)
	var split_amount = randi_range(0,2*outer_number)
	ring_island._set_params(get_seed_by_pos(pos), split_amount, 
			20000, 0.01,  
			outer_number, 100, random_initial_radius,
			max_height, cell_size)
	add_child(ring_island)
	ring_island._regenerate()
	islands.append(ring_island)

func spawn_circle_island(pos:Vector3):
	var circle_island = prepacked_circle_gen.instantiate()
	var split_amount = randi_range(1,5)
	var random_radius = randi_range(100,1000)
	var random_verts_amount = randi_range(6,20)
	circle_island._set_params(get_seed_by_pos(pos), split_amount, 
			20000, 0.01,  
			random_radius, random_verts_amount,
			max_height, cell_size)
	circle_island.position = pos
	add_child(circle_island)
	circle_island._regenerate()
	islands.append(circle_island)
