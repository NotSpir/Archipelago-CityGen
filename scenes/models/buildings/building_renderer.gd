extends Node
class_name BuildingRenderer

var road_network:RoadNetwork
var sector_edge_distance:float = 20
var minimal_building_area:float = 20
var lot_cell_size:float = 8
var corner_subdivision_distance:float = 0
var min_corner_angle:float = 0
var max_height:float = 1000
var global_offset = Vector3.ZERO
 
func place_building_lots(build_target:Node3D) -> void:
	for sector in road_network.sectors:
		var result = create_lots_from_sector(sector)
		if result == null:
			sector.type = "Nonbuildable"
			continue
		
		var lot =  result.lot
		var centroid =  result.centroid
		var new_placement_lots = break_sector_into_grid(lot, lot_cell_size,centroid, sector.type)
		if new_placement_lots.type == "Buildings":
			var new_buildings = new_placement_lots.result
			for b in new_buildings:
				GlobalValues.minor_chunk_manager.append_corresponding_chunk_with_building(b)
				#place_building_color(b.corners, b.height,build_target, b.color)
		elif new_placement_lots.type == "Objects":
			var new_cells = new_placement_lots.cells
			for nc in new_cells:
				pass
				#build_target.add_child(nc)
			var new_objects = new_placement_lots.objects
			for no in new_objects:
				pass
				#build_target.add_child(no)


func create_lots_from_sector(sector: RoadSector, check_convex:bool = true):
	if sector.type == "Blocked": return null
	
	var verts = clean_up_sector(sector.vertices.duplicate())
	var centroid = get_geometric_centroid(verts)
	#var shifted_verts = shift_vertices_to_point(verts, centroid)
	var shifted_verts = get_sector_inside_offset(verts, 22.)
	
	#shifted_verts = soften_sector(shifted_verts.duplicate())
	if shifted_verts.size() == 0: return null
	if check_convex:
		if !road_network.is_sector_convex(verts): return null
		if !is_point_in_polygon(shifted_verts, centroid): return null
	#var area = road_network.calculate_polygon_area_by_vectors(shifted_verts)
	return {"lot": shifted_verts, "centroid": centroid}


func soften_sector(vertices: Array) -> Array:
	var i = 0
	var curvy_vertices = []
	while i < vertices.size():
		var v = vertices[i]
		var nv = vertices[(i+1)%vertices.size()]
		var pv 
		if i != 0: pv = vertices[i-1]
		else: pv = vertices[vertices.size()-1]
		var angle = UsefulFunctions.get_angle_by_points_degrees(pv,v,nv)
		if (angle < min_corner_angle):
			var p1 = pv + 0.5*(v - pv)
			var p2 = nv + 0.5*(v - nv)
			curvy_vertices.append(p1)
			curvy_vertices.append(p2)
		else:
			curvy_vertices.append(v)
		i+=1
	return curvy_vertices
func clean_up_sector(vertices: Array) -> Array:
	var i = 0
	var clean_vertices = []
	while i < vertices.size():
		var vid = vertices[i]
		var next_vid = vertices[(i+1)%vertices.size()]
		var prev_vid 
		if i != 0: prev_vid = vertices[i-1]
		else: prev_vid = vertices[vertices.size()-1]
		var v = road_network.vertices[vid]
		var nv = road_network.vertices[next_vid]
		var pv = road_network.vertices[prev_vid]
		var is_extra = UsefulFunctions.check_3D_point_on_line(v, nv, pv, 3)
		#A fix for a very specific bug that happens comically rare for me to bother debugging. Sorry!
		is_extra = UsefulFunctions.check_3D_point_on_line(pv, v, nv, 3)
		#var is_prev_extra = UsefulFunctions.check_3D_point_on_line(pv, nv, v, 3)
		#if is_prev_extra: clean_vertices.remove_at(clean_vertices.size()-1)
		if !is_extra: clean_vertices.append(vid)
		
		i+=1
	return clean_vertices

func get_arithmetic_centroid(vertices: Array) -> Vector3:
	if vertices.is_empty():
		return Vector3.ZERO
	var center = Vector3.ZERO
	for v in vertices:
		center += road_network.vertices[v]
	return center / vertices.size()

func get_geometric_centroid(vertices: Array) -> Vector3:
	if vertices.size() < 3:
		return Vector3.ZERO
	
	var center = Vector3.ZERO
	var signed_area = 0.0
	for vidx in vertices.size():
		var a = road_network.vertices[vertices[vidx]]
		var b = road_network.vertices[vertices[(vidx+1)%vertices.size()]]
		var cross = a.x*b.z - b.x*a.z
		signed_area += cross
		center.x += (a.x+b.x)*cross
		center.z += (a.z+b.z)*cross
	signed_area *= 0.5
	
	if signed_area == 0: return get_arithmetic_centroid(vertices)
	center.x /= (6.0*signed_area)
	center.z /= (6.0*signed_area)
	return center

func get_geometric_centroid_vectors(vertices: Array) -> Vector3:
	if vertices.size() < 3:
		return Vector3.ZERO
	
	var center = Vector3.ZERO
	var signed_area = 0.0
	for vidx in vertices.size():
		var a = vertices[vidx]
		var b = vertices[(vidx+1)%vertices.size()]
		var cross = a.x*b.z - b.x*a.z
		signed_area += cross
		center.x += (a.x+b.x)*cross
		center.z += (a.z+b.z)*cross
	signed_area *= 0.5
	
	if signed_area == 0: return get_arithmetic_centroid(vertices)
	center.x /= (6.0*signed_area)
	center.z /= (6.0*signed_area)
	return center

func is_point_in_polygon_vid(vertices: Array, point:Vector3) -> bool:
	var check_line_start = Vector2(point.x,point.z)
	var max_x = -INF
	var min_x = INF
	for vid in vertices:
		var v = road_network.vertices[vid]
		if v.x > max_x: max_x = v.x
		if v.x < min_x: min_x = v.x
	var check_line_max = Vector2(max_x + 10, point.y)
	var check_line_min = Vector2(min_x - 10, point.y)
	
	var right_intersected_edges = 0
	for i in vertices.size():
		var j = (i+1)%vertices.size()
		var a = Vector2(road_network.vertices[vertices[i]].x, road_network.vertices[vertices[i]].z)
		var b = Vector2(road_network.vertices[vertices[j]].x, road_network.vertices[vertices[j]].z)
		var cross = Geometry2D.segment_intersects_segment(check_line_start, check_line_max, a,b)
		if cross != null: right_intersected_edges+=1
	
	if right_intersected_edges%2 == 0: return false
	
	var left_intersected_edges = 0
	for i in vertices.size():
		var j = (i+1)%vertices.size()
		var a = Vector2(road_network.vertices[vertices[i]].x, road_network.vertices[vertices[i]].z)
		var b = Vector2(road_network.vertices[vertices[j]].x, road_network.vertices[vertices[j]].z)
		var cross = Geometry2D.segment_intersects_segment(check_line_start, check_line_min, a,b)
		if cross != null: left_intersected_edges+=1
	return left_intersected_edges%2 == 1

func is_point_in_polygon(vertices: Array, point:Vector3) -> bool:
	var check_line_start = Vector2(point.x,point.z)
	var max_x = -INF
	var min_x = INF
	for v in vertices:
		if v.x > max_x: max_x = v.x
		if v.x < min_x: min_x = v.x
	var check_line_max = Vector2(max_x + 10, point.y)
	var check_line_min = Vector2(min_x - 10, point.y)
	
	var right_intersected_edges = 0
	for i in vertices.size():
		var j = (i+1)%vertices.size()
		var a = Vector2(vertices[i].x, vertices[i].z)
		var b = Vector2(vertices[j].x, vertices[j].z)
		var cross = Geometry2D.segment_intersects_segment(check_line_start, check_line_max, a,b)
		if cross != null: right_intersected_edges+=1
	
	if right_intersected_edges%2 == 0: return false
	
	var left_intersected_edges = 0
	for i in vertices.size():
		var j = (i+1)%vertices.size()
		var a = Vector2(vertices[i].x, vertices[i].z)
		var b = Vector2(vertices[j].x, vertices[j].z)
		var cross = Geometry2D.segment_intersects_segment(check_line_start, check_line_min, a,b)
		if cross != null: left_intersected_edges+=1
	return left_intersected_edges%2 == 1

func shift_vertices_to_point(verts:Array, point:Vector3) -> PackedVector3Array:
	var shifted_array:PackedVector3Array = []
	for idx in verts.size():
		var vid = verts[idx]
		var v = road_network.vertices[vid]
		var direction = (v - point).normalized()
		var distance = v.distance_to(point)
		var new_distance = max(distance - sector_edge_distance, 0.1)
		var new_pos = point + direction * new_distance
		shifted_array.append(new_pos)
	return shifted_array

func get_sector_inside_offset(verts:Array, step:float):
	var shifted_array:PackedVector3Array = []
	var rotate_value = deg_to_rad(-90)
	
	var v_s = road_network.vertices[verts[0]]
	var v_e = road_network.vertices[verts[1]]
	var dir = (v_e - v_s).normalized()
	var off = dir * step*2
	var test_pos = v_s + off + step * dir.rotated(Vector3.UP, rotate_value)
	if !is_point_in_polygon_vid(verts, test_pos):
		rotate_value = deg_to_rad(90)
		test_pos = v_s + off + step * dir.rotated(Vector3.UP, rotate_value)
		if !is_point_in_polygon_vid(verts, test_pos):
			return []
	
	for idx in verts.size():
		var vid = verts[idx]
		var vid_next = verts[(idx+1)%verts.size()]
		var v = road_network.vertices[vid]
		var v2 = road_network.vertices[vid_next]
		var edir = (v2 - v).normalized()
		var offset = edir * step*2
		var new_pos = v + offset + step * edir.rotated(Vector3.UP, rotate_value)
		shifted_array.append(new_pos)
	var self_intersect = check_sector_for_self_intersections(shifted_array)
	if self_intersect:
		
		shifted_array = []
	return shifted_array


func check_sector_for_self_intersections(verts:Array[Vector3]):
	for idx in verts.size():
		var v = verts[idx]
		var next_idx = (idx+1)%verts.size()
		var v2 = verts[next_idx]
		for sub_idx in verts.size():
			var s_next_idx = (sub_idx+1)%verts.size()
			if sub_idx == idx || s_next_idx == next_idx: continue
			if sub_idx == next_idx || s_next_idx == idx: continue
			var sv = verts[sub_idx]
			var sv2 = verts[(sub_idx+1)%verts.size()]
			
			if UsefulFunctions.get_vectors_intersection(v,v2, sv,sv2) != null:
				print("Self intersecton: ")
				print(" - Line 1: ", v, " ; ", v2)
				print(" - Line 2: ", sv, " ; ", sv2)
				return true
	return false

func break_sector_into_grid(vertices:Array, cell_size:float, centroid = Vector3.ZERO, sector_type:String = "Building"):
	var min_x:float = INF
	var max_x:float = -INF
	var min_y:float = INF
	var max_y:float = -INF
	
	#Getting grid boundaries and centroid
	for v in vertices:
		if v.x > max_x:
			max_x = v.x
		if v.x < min_x:
			min_x = v.x
		if v.z > max_y:
			max_y = v.z
		if v.z < min_y:
			min_y = v.z
	if centroid == Vector3.ZERO:
		centroid = get_geometric_centroid_vectors(vertices)
	var w := ceili((max_x - min_x)/cell_size)
	var h := ceili((max_y - min_y)/cell_size)
	#Creating the grid of ones [Building lot] and zeroes [Unavailable], -1 - Blocked [Building nearby]
	var grid:Array[Array]
	grid.resize(h)
	for i in h:
		var row:Array[int] = []
		row.resize(w)
		row.fill(1)
		
		for j in w:
			var a = Vector3(min_x + j*cell_size, 0, min_y+i*cell_size) #0,0
			var b = Vector3(min_x + j*cell_size, 0, min_y+i*cell_size - cell_size) #0,-1
			var c = Vector3(min_x + j*cell_size+cell_size, 0, min_y+i*cell_size) #+1,0
			var d = Vector3(min_x + j*cell_size+cell_size, 0, min_y+i*cell_size - cell_size) #+1,-1
			var centroid_square =  Vector3(min_x + j*cell_size+cell_size/2, 0, min_y+i*cell_size - cell_size/2)
			#Check intersections
			for vi in vertices.size():
				var v = vertices[vi]
				var nv = vertices[(vi+1)%vertices.size()]
				var flag1:bool = UsefulFunctions.get_vectors_intersection(a,b,v,nv) != null
				var flag2:bool = UsefulFunctions.get_vectors_intersection(a,c,v,nv) != null
				var flag3:bool = UsefulFunctions.get_vectors_intersection(c,d,v,nv)  != null
				var flag4:bool = UsefulFunctions.get_vectors_intersection(b,d,v,nv)  != null
				#var flag_c:bool = !is_point_in_polygon(vertices, centroid_square)
				var flag_c:bool = UsefulFunctions.get_vectors_intersection(centroid_square, centroid, v,nv) != null
				if flag1 || flag2 || flag3 || flag4:
					row[j] = 0
					break
				if flag_c:
					row[j] = 0
					break
		grid[i] = row
		
	if sector_type == "Park":
		var grid_gen = GridPathGenerator.new()
		var result = grid_gen.perform_generation(grid, cell_size, Vector3(min_x, 0.05, min_y), GlobalValues.park_roads_set, GlobalValues.park_objects_pool)
		var objects = result.objects
		var cells = result.cells
		for o in objects:
			o.position += global_offset
			GlobalValues.minor_chunk_manager.append_corresponding_chunk(o)
		for c in cells:
			c.position += global_offset
			GlobalValues.minor_chunk_manager.append_corresponding_chunk(c)
		return { "type": "Objects", 
		"objects": objects, 
		"cells": cells 
		}
	if sector_type == "Construction":
		#scatter_objects_on_grid(construction_objects_pool, min_objects, max_objects)
		#place_roads_on_grid(construction_roads_pool)
		return []
	if sector_type == "Pond":
		#place_pond_on_grid(pond_objects_pool)
		#scatter_objects_on_grid(pond_ground_objects_pool, min_objects, max_objects, search_num = 1)
		#scatter_objects_on_grid(pond_water_objects_pool, min_objects, max_objects, search_num = 2)
		return []
	return { "type": "None", 
	"result": break_grid_into_building_lots(grid, min_x, min_y, cell_size) 
	}

func break_grid_into_building_lots(grid:Array, min_x, min_y, cell_size):
	var buildings:Array[BuildingData] = []
	var build_num = 2
	for r in grid.size():
		for c in grid[r].size():
			if grid[r][c] != 1: continue
			var min_c = c*cell_size
			var top_r = r*cell_size
			var c_dist = +cell_size
			var r_dist = -cell_size
			var step = set_square_building_lot(grid, r,c,build_num)
			
			top_r = (r+step-1)*cell_size
			c_dist *= step
			r_dist *= step
			var a1 = Vector3(min_x+min_c, 0, min_y+top_r)+global_offset #0,0
			var a2 = Vector3(min_x+min_c, 0, min_y+top_r+r_dist)+global_offset #0,-1
			var a3 = Vector3(min_x+min_c+c_dist, 0, min_y+top_r)+global_offset #+1,0
			var a4 = Vector3(min_x+min_c+c_dist, 0, min_y+top_r+r_dist)+global_offset #+1,-1
			build_num+=1
			var height = randf_range(100, 100*step) if step != 1 else randf_range(40, 50 + (build_num * 5))
			height = clamp(height, 40, max_height)
			var new_building:BuildingData = BuildingData.new([a1,a2,a4,a3], height, Color(randf(),randf(),randf()))
			#buildings.append(new_building)
			GlobalValues.minor_chunk_manager.append_corresponding_chunk_with_building(new_building)
	return buildings

func set_square_building_lot(grid:Array, row:int,col:int, building_num:int):
	var step = 1
	grid[row][col] = building_num
	#Setting biggest square building 
	while true:
		var r = row+step
		var c = col+step
		if r >= grid.size(): break
		if c >= grid[row].size(): break
		if grid[r][c] != 1: break
		
		var can_expand := true
		for i in step:
			var a = grid[r][col+i] == 1
			var b = grid[row+i][c] == 1
			if !a || !b: 
				can_expand = false
				break
		if !can_expand: break
		
		for i in step:
			grid[r][col+i] = building_num
			grid[row+i][c] = building_num
		grid[r][c] = building_num
		step+=1
	
	#Blocking area around to avoid side-to-side buildings
	for r in range(row - 1, row + step + 1):
		for c in range(col - 1, col + step + 1):
			if r < 0 or r >= grid.size() or c < 0 or c >= grid[row].size():continue
			if r >= row and r < row + step and c >= col and c < col + step:continue
			grid[r][c] = -1
	return step




func place_building_color(lot_vertices: Array, depth:float, parent:Node3D, color:Color = Color(1,1,1,1)) -> Node3D:
	#if !has_node(parent.get_path()):
		#return
	var poly_2d = PackedVector2Array()
	var min_y = INF
	for vid in lot_vertices:
		var v
		if vid is Vector3:
			v = vid
		else: v = road_network.vertices[vid]
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
	
	return csg
