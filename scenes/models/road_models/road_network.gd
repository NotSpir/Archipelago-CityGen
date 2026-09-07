class_name RoadNetwork

var vertices: Array[Vector3] = []
var edges: Array[RoadSection] = []
var vertex_edges: Dictionary = {} #{'vertice_id': [edge_id1, edge_id2, ... , edge_idn]}

var sectors: Array[RoadSector] = [] 

var chunks: Dictionary = {} #{Vector2: RoadChunk }
const CHUNK_SIZE := 64
const VERTEX_EPSILON = 1.0

var building_lots: Array[Dictionary] = []

func add_vertice(position: Vector3) -> int:
	var chunk_pos = create_new_chunk_if_not_exists(position)
	for vid in chunks[chunk_pos].vertices:
		if vertices[vid].distance_to(position) < VERTEX_EPSILON:
			#print("VERTICE ALREADY EXISTS. RETURNING EXISTING ID...")
			return vid
	
	vertices.append(position)
	var vid = vertices.size()-1
	chunks[chunk_pos].add_vertice(vid)
	return vid

func get_last_vertice() -> int:
	return vertices.size()-1

func add_edge(start_index: int, end_index: int, type: String = "Full") -> int:
	var new_segment = RoadSection.new(start_index, end_index, type)
	edges.append(new_segment)
	return edges.size() - 1

func split_edge(edge_index: int, split_vertice_id: int) -> Array[RoadSection]:
	var og_edge = edges[edge_index]
	if (og_edge.type == "Split"):
		edges[edge_index].type = "Old-Split"
	else:
		edges[edge_index].type = "Old-Full"
	var new_edge1 = RoadSection.new(og_edge.start_index, split_vertice_id, 'Split')
	var new_edge2 = RoadSection.new(split_vertice_id, og_edge.end_index, 'Split')
	return [new_edge1, new_edge2]

func add_edge_as_segment(new_segment: RoadSection) -> int:
	edges.append(new_segment)
	return edges.size() - 1

func create_new_chunk_if_not_exists(global_position: Vector3) -> Vector2:
	var grid_position = transform_position_to_chunk_position(global_position)
	if chunks.has(grid_position):
		#print("Chunk ", grid_position," already exists.")
		return grid_position
	
	#print("Chunk ", grid_position," succesfully created.")
	var new_chunk = RoadChunk.new()
	chunks[grid_position] = new_chunk
	return grid_position

func create_new_chunk_if_not_exists_chunk_position(chunk_position: Vector2) -> Vector2:
	if chunks.has(chunk_position):
		#print("Chunk ", chunk_position," already exists.")
		return chunk_position
	
	#print("Chunk ", chunk_position," succesfully created.")
	var new_chunk = RoadChunk.new()
	chunks[chunk_position] = new_chunk
	return chunk_position

func transform_position_to_chunk_position(position: Vector3) -> Vector2:
	var uniform_x = round(position.x/CHUNK_SIZE)
	var uniform_y = round(position.z/CHUNK_SIZE)
	var uniform_position = Vector2(uniform_x,uniform_y)
	return uniform_position

func add_edge_to_chunk(chunk_position, edge_id:int) -> int:
	return chunks[chunk_position].add_edge(edge_id)

func get_all_edges_in_chunk(chunk_position: Vector2) -> Array[int]:
	return chunks[chunk_position].edges

func get_all_vertices_in_chunk(chunk_position: Vector2) -> Array[int]:
	return chunks[chunk_position].vertices

func remove_edge_in_chunk(chunk_position: Vector2, edge_index:int) -> void:
	chunks[chunk_position].edges.erase(edge_index)

func add_edge_to_network(vertice_id1:int,vertice_id2:int, type:String = "Full") -> int:
	var edge_id = add_edge(vertice_id1, vertice_id2, type)
	add_edge_to_vertex_graph(edge_id)
	var v1 = vertices[vertice_id1]
	var v2 = vertices[vertice_id2]
	var crossed_chunk_positions = get_all_chunks_crossed_by_line(v2,v1)
	for chpos in crossed_chunk_positions:
		var chunk = create_new_chunk_if_not_exists_chunk_position(chpos)
		add_edge_to_chunk(chunk, edge_id)

	return edge_id

func split_edge_to_network(edge_id:int, split_vertice_id:int):
	var new_edges := split_edge(edge_id, split_vertice_id)
	var start_edge_pos = vertices[edges[edge_id].start_index]
	var end_edge_pos = vertices[edges[edge_id].end_index]
	var chunk_pos = transform_position_to_chunk_position(start_edge_pos)
	var crossed_chunk_positions = get_all_chunks_crossed_by_line(start_edge_pos,end_edge_pos)
	for chpos in crossed_chunk_positions:
		var chunk = create_new_chunk_if_not_exists_chunk_position(chpos)
		remove_edge_in_chunk(chunk, edge_id)
	var split_edge1_id = add_edge_to_network(new_edges[0].start_index, new_edges[0].end_index, new_edges[0].type)
	var split_edge2_id = add_edge_to_network(new_edges[1].start_index, new_edges[1].end_index, new_edges[1].type)
	
	return {'new_vertice_id': split_vertice_id, 'split_edges': [split_edge1_id, split_edge2_id]}

func add_edge_to_vertex_graph(edge_id: int):
	var edge = edges[edge_id]
	
	var vertice_id_1 = edge.start_index
	var vertice_id_2 = edge.end_index
	
	if !vertex_edges.has(vertice_id_1):
		vertex_edges[vertice_id_1] = []
	vertex_edges[vertice_id_1].append(edge_id)
	
	if !vertex_edges.has(vertice_id_2):
		vertex_edges[vertice_id_2] = []
	vertex_edges[vertice_id_2].append(edge_id)

func remove_edge_in_vertex_graph(edge_id: int) -> void:
	var edge = edges[edge_id]
	var vertice_id_1 = edge.start_index
	var vertice_id_2 = edge.end_index
	if vertex_edges.has(vertice_id_1):
		vertex_edges[vertice_id_1].erase(edge_id)
	if vertex_edges.has(vertice_id_2):
		vertex_edges[vertice_id_2].erase(edge_id)

func get_edges_for_vertex(vertice_id: int) -> Array:
	return vertex_edges.get(vertice_id, [])

func get_edge_between_vertices(vid1:int, vid2:int):
	var v_edges = get_edges_for_vertex(vid1)
	for eid in v_edges:
		var e = edges[eid]
		if vid2 == e.start_index || vid2 == e.end_index:
			return eid
	return null

func add_sector(sector: RoadSector):
	sectors.append(sector)
	return sectors.size() - 1

func calculate_polygon_area(poly_vertices, return_abs := false):
	# Compute area using shoelace formula
	var area2 = 0.0
	for i in range(poly_vertices.size()):
		var j = (i + 1) % poly_vertices.size()
		var vi = vertices[poly_vertices[i]]
		var vj = vertices[poly_vertices[j]]
		area2 += vi.x * vj.z - vj.x * vi.z
	var area = area2 * 0.5
	if area < 0 && return_abs:
		area = -area
	return area

func calculate_polygon_area_by_vectors(poly_vertices):
	# Compute area using shoelace formula
	var area2 = 0.0
	for i in range(poly_vertices.size()):
		var j = (i + 1) % poly_vertices.size()
		var vi = poly_vertices[i]
		var vj = poly_vertices[j]
		area2 += vi.x * vj.z - vj.x * vi.z
	var area = area2 * 0.5
	return area

func split_sector_longest_to_furthest(sector_id:int):
	var splittable_sector := sectors[sector_id]
	
	var longest_edge_id = splittable_sector.edges[0]
	var longest_length = 0
	#Get longest edge first
	for eid in splittable_sector.edges:
		var edge_length = (vertices[edges[eid].end_index] - vertices[edges[eid].start_index]).length()
		if (edge_length > longest_length):
			longest_edge_id = eid
			longest_length = edge_length
	#Get its midpoint
	var mid_point : Vector3 = (vertices[edges[longest_edge_id].end_index] + vertices[edges[longest_edge_id].start_index])/2.
	#Then get furthest midpoint from this midpoint
	var furthest_edge_id = splittable_sector.edges[0]
	var furthest_edge_mid_point : Vector3
	var furthest_distance = 0
	for eid in splittable_sector.edges:
		if eid == longest_edge_id: continue #Not that it should be possible that is would be furthest from itself
		var edge_length = (vertices[edges[eid].end_index] - vertices[edges[eid].start_index]).length()
		if (edge_length < 50): continue
		var edge_mid_point = (vertices[edges[eid].end_index] + vertices[edges[eid].start_index])/2.
		var distance = (edge_mid_point - mid_point).length()
		if (distance > furthest_distance):
			furthest_edge_id = eid
			furthest_distance = distance
			furthest_edge_mid_point = edge_mid_point
	
	#SPLIT!
	return split_polygon_by_two_points(sector_id, mid_point, furthest_edge_mid_point)

func split_sector_longest_to_opposite(sector_id: int, deviation:float = 0, check_crossing = false, retries:int = 0):
	var splittable_sector := sectors[sector_id]
	var sector_edges = splittable_sector.edges  # Array of edge IDs
	
	# Find the index of the longest edge
	var longest_index = 0
	var longest_length = 0.0
	
	for i in range(sector_edges.size()):
		var eid = sector_edges[i]
		var edge = edges[eid]
		var length = (vertices[edge.end_index] - vertices[edge.start_index]).length()
		if length > longest_length:
			longest_length = length
			longest_index = i
	var longest_eid = sector_edges[longest_index]
	var longest_edge = edges[longest_eid]
	
	# Get its midpoint
	var mid_point = (vertices[longest_edge.end_index] + vertices[longest_edge.start_index]) / 2.0
	
	# Find the opposite edge INDEX (in the sector's edge array)
	var opposite_index = (longest_index + floori(sector_edges.size() / 2.0)) % sector_edges.size()
	var opposite_eid = sector_edges[opposite_index]
	var opposite_edge = edges[opposite_eid]
	
	# Get its midpoint
	var opposite_edge_point = lerp(vertices[opposite_edge.end_index], vertices[opposite_edge.start_index], randfn(0.5,deviation))
	
	if !check_crossing: return split_polygon_by_two_points(sector_id, mid_point, opposite_edge_point)
	
	var attempts := retries
	while attempts > 0:
		var success = true
		for eid in sector_edges:
			if eid == longest_eid || eid == opposite_eid: continue
			var e_start_pos = vertices[edges[eid].start_index]
			var e_end_pos = vertices[edges[eid].end_index]
			var crossing_point = UsefulFunctions.get_vectors_intersection(mid_point, opposite_edge_point, e_start_pos, e_end_pos)
			if crossing_point != null:
				success = false
				break
		if success: break
		
		opposite_index += 1
		opposite_index = opposite_index%sector_edges.size()
		opposite_eid = sector_edges[opposite_index]
		opposite_edge = edges[opposite_eid]
		opposite_edge_point = lerp(vertices[opposite_edge.end_index], vertices[opposite_edge.start_index], randfn(0.5,deviation))
		attempts-=1
	
	# 6. Split!
	return split_polygon_by_two_points(sector_id, mid_point, opposite_edge_point)

func split_polygon_by_two_points(sid:int, point1:Vector3, point2:Vector3):
	var vid1 = add_vertice(point1)
	var vid2 = add_vertice(point2)
	var new_eid = add_edge_to_network(vid1, vid2)
	var sector = sectors[sid]
	var s_vertices = sector.vertices
	var s_edges = sector.edges
	
	var insert_pos1 = -1
	var insert_pos2 = -1
	for i in range(s_edges.size()):
		var eid = s_edges[i]
		if insert_pos1 == -1 and is_vertice_on_edge(vid1, eid):
			split_edge_to_network(eid, vid1)
			insert_pos1 = i + 1
		if insert_pos2 == -1 and is_vertice_on_edge(vid2, eid):
			split_edge_to_network(eid, vid2)
			insert_pos2 = i + 1
	
	# Handle case where a point is exactly on a vertex (rare)
	if insert_pos1 == -1:
		print("pos 1 failure")
		for i in range(s_vertices.size()):
			if s_vertices[i] == vid1:
				print("pos 1 fixed")
				insert_pos1 = i + 1
				break
	if insert_pos2 == -1:
		print("pos 2 failure")
		for i in range(s_vertices.size()):
			if s_vertices[i] == vid2:
				print("pos 2 fixed")
				insert_pos2 = i + 1
				break
	
	if insert_pos1 == -1 || insert_pos2 == -1:
		return null
	
	var new_s_vertices = s_vertices.duplicate()
	
	if insert_pos1 > insert_pos2:
		new_s_vertices.insert(insert_pos1, vid1)
		new_s_vertices.insert(insert_pos2, vid2)
	else:
		new_s_vertices.insert(insert_pos2, vid2)
		new_s_vertices.insert(insert_pos1, vid1)
	
	var idx1 = new_s_vertices.find(vid1)
	var idx2 = new_s_vertices.find(vid2)
	
	if (idx1 > idx2):
		var temp = idx2
		idx2 = idx1
		idx1 = temp
		var temp_vid = vid2
		vid2 = vid1
		vid1 = vid2
	
	var polygon1 = RoadSector.new([], [])
	var polygon2 = RoadSector.new([], [])
	
	var i = 0
	while i < new_s_vertices.size():
		polygon1.vertices.append(new_s_vertices[i])
		if i == idx1:
			i = idx2
			continue
		i+=1
	i = idx1
	while i <= idx2:
		polygon2.vertices.append(new_s_vertices[i])
		i+=1
	polygon1.area = calculate_polygon_area(polygon1.vertices, true)
	polygon2.area = calculate_polygon_area(polygon2.vertices, true)
	return {'polygon1': polygon1, 'polygon2': polygon2}

func reconstruct_sector_from_vertices(sector:RoadSector):
	for i in sector.vertices.size():
		var vid = sector.vertices[i]
		var next_vid = sector.vertices[(i + 1)%sector.vertices.size()]
		var vert_edges = get_edges_for_vertex(vid)
		var found_edge := false
		for eid in vert_edges:
			var edge = edges[eid]
			if edge.start_index == next_vid || edge.end_index == next_vid:
				sector.edges.append(eid)
				found_edge = true
				break
		if found_edge: continue
		
		print("EDGE NOT FOUND BETWEEN VERTICES: ", vid, " AND ", next_vid)
	return sector.edges

func is_vertice_on_edge(vid: int, eid:int) -> bool:
	var v = vertices[vid]
	var e = edges[eid]
	var a = vertices[e.start_index]
	var b = vertices[e.end_index]
	return UsefulFunctions.check_3D_point_on_line(v,a,b)

func get_all_chunks_crossed_by_line(start: Vector3, end: Vector3):
	var crossed_chunks = []
	var start_chunk := transform_position_to_chunk_position(start)
	var end_chunk := transform_position_to_chunk_position(end)
	
	var cells = []
	var x_step:int = 1
	var y_step:int = 1
	var error
	var error_prev
	var x = start.x
	var y = start.z
	var ddy:float
	var ddx:float
	var dx = end.x - x
	var dy = end.z - y
	if dy < 0:
		y_step = -1
		dy = -dy
	if dx < 0:
		x_step = -1
		dx = -dx
	ddx = 2*dx
	ddy = 2*dy
	if ddx >= ddy:
		error = dx
		error_prev = dx
		for i in range(0, dx):
			x += x_step
			error += ddy
			if (error > ddx):
				y += y_step
				error -= ddx
				if (error + error_prev) < ddx:
					cells.append(Vector2(x, y-y_step))
				elif (error + error_prev) > ddx:
					cells.append(Vector2(x-x_step, y))
				else:
					cells.append(Vector2(x, y-y_step))
					cells.append(Vector2(x-x_step, y))
			cells.append(Vector2(x,y))
			error_prev = error
	else:
		error = dy
		error_prev = dy
		for i in range(0, dy):
			y += y_step
			error += ddx
			if (error > ddy):
				x += x_step
				error -= ddy
				if (error + error_prev) < ddy:
					cells.append(Vector2(x-x_step, y))
				elif (error + error_prev) > ddy:
					cells.append(Vector2(x, y-y_step))
				else:
					cells.append(Vector2(x, y-y_step))
					cells.append(Vector2(x-x_step, y))
			cells.append(Vector2(x,y))
			error_prev = error
	
	
	crossed_chunks.append(start_chunk)
	for c in cells:
		var c_v3 = Vector3(c.x,0,c.y)
		var ch = transform_position_to_chunk_position(c_v3)
		if crossed_chunks[crossed_chunks.size()-1] != ch:
			crossed_chunks.append(ch)
	return crossed_chunks


func is_sector_convex(sector: PackedVector3Array) -> bool:
	var n = sector.size()
	if n < 3: return false 
	
	var sign = 0
	for i in range(n):
		var a = sector[i]
		var b = sector[(i + 1) % n]
		var c = sector[(i + 2) % n]
		
		var ab = Vector2(b.x - a.x, b.z - a.z)
		var bc = Vector2(c.x - b.x, c.z - b.z)
		var cross = ab.cross(bc)
		if cross == 0:
			continue
		if sign == 0:
			sign = sign(cross)
		elif sign != sign(cross):
			return false
	
	return true

func reassign_all_sectors_random(curr_sectors = sectors) -> void:
	var park_chance = 0.15
	var pond_chance = 0.
	var construction_chance = 0.
	var market_chance = 0.
	for s in curr_sectors:
		var roll = randf()
		var accumulated_chance = park_chance
		if roll <= accumulated_chance:
			s.type = "Park"
			continue
		accumulated_chance += pond_chance
		if roll <= accumulated_chance:
			s.type = "Pond"
			continue
		accumulated_chance += construction_chance
		if roll <= accumulated_chance:
			s.type = "Construction"
			continue
		accumulated_chance += market_chance
		if roll <= accumulated_chance:
			s.type = "Market"
			continue
		
		s.type = "Buildings"

func reassign_all_sectors_random_sid(sids = [0]) -> void:
	var park_chance = 0.05
	var pond_chance = 0.
	var construction_chance = 0.
	var market_chance = 0.
	for sid in sids:
		var roll = randf()
		var accumulated_chance = park_chance
		if roll <= accumulated_chance:
			sectors[sid].type = "Park"
			continue
		accumulated_chance += pond_chance
		if roll <= accumulated_chance:
			sectors[sid].type = "Pond"
			continue
		accumulated_chance += construction_chance
		if roll <= accumulated_chance:
			sectors[sid].type = "Construction"
			continue
		accumulated_chance += market_chance
		if roll <= accumulated_chance:
			sectors[sid].type = "Market"
			continue
		
		sectors[sid].type = "Buildings"
