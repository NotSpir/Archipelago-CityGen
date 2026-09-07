extends Node
class_name RoadRenderer

var road_network:RoadNetwork
var thickness:float = 1.
var width:float = 12.
var side_width:float = 4.
var streetlight_distance := 128.

var streetlight_prefab = preload("res://scenes/prefabs/streetlight.tscn")

func place_road(start_pos: Vector3, end_pos: Vector3, road_width:int, road_thickness:int, parent:Node3D, color := Color(0.3, 0.6, 1.0, 1.0), node_name:String = "", type:String = "Road") -> void:
	var path = Path3D.new()
	var curve := Curve3D.new()
	
	curve.add_point(start_pos)
	curve.add_point(end_pos)
	if node_name != "": path.name = node_name
	path.curve = curve
	parent.add_child(path)
	var csg = CSGPolygon3D.new()
	csg.mode = CSGPolygon3D.MODE_PATH
	csg.path_node = path.get_path()
	var half_width = road_width
	var half_thickness = road_thickness/2.0
	csg.polygon = PackedVector2Array([
		Vector2(-half_width, -half_thickness),
		Vector2(-half_width, half_thickness),
		Vector2(half_width, half_thickness),
		Vector2(half_width, -half_thickness)
	])
	csg.path_local = true
	csg.use_collision = true
	csg.path_interval = 25.
	path.add_child(csg)
	if type == "Road":
		var shader_mat = ShaderMaterial.new()
		var shader = preload("res://scenes/assets/road_shader.gdshader")  # or load() if you have the path
		shader_mat.shader = shader
		# Set uniform values
		shader_mat.set_shader_parameter("tile_scale", road_width)
		shader_mat.set_shader_parameter("road_texture", preload("res://scenes/assets/road-texture2.jpg"))
		csg.material_override = shader_mat
	elif type == "Sidewalk":
		var material = StandardMaterial3D.new()
		material.albedo_color = color
		csg.material_override = material
	csg.path_u_distance = 10

func place_road_from_network(eid:int, start_offset, end_offset, parent:Node3D, color := Color(0.3, 0.6, 1.0, 1.0),  name:String = "") -> void:
	var path = Path3D.new()
	var curve := Curve3D.new()
	var edge = road_network.edges[eid]
	var start_pos = road_network.vertices[edge.start_index]
	var end_pos = road_network.vertices[edge.end_index]
	var road_dir = (end_pos - start_pos).normalized()
	var epos = end_pos - road_dir * end_offset
	var spos = start_pos + road_dir * start_offset
	curve.add_point(spos)
	curve.add_point(epos)
	if name != "": path.name = name
	path.curve = curve
	parent.add_child(path)
	var csg = CSGPolygon3D.new()
	csg.mode = CSGPolygon3D.MODE_PATH
	csg.path_node = path.get_path()
	var half_width = width
	var half_thickness = thickness/2.0
	csg.polygon = PackedVector2Array([
		Vector2(-half_width, -half_thickness),
		Vector2(-half_width, half_thickness),
		Vector2(half_width, half_thickness),
		Vector2(half_width, -half_thickness)
	])
	csg.path_local = true
	csg.use_collision = true
	csg.path_interval = 25.
	path.add_child(csg)
	#var material = StandardMaterial3D.new()
	#material.albedo_color = color
	#csg.material_override = material
	var shader_mat = ShaderMaterial.new()
	var shader = preload("res://scenes/assets/road_shader.gdshader")  # or load() if you have the path
	shader_mat.shader = shader
	# Set uniform values
	shader_mat.set_shader_parameter("tile_scale", 8)
	shader_mat.set_shader_parameter("road_texture", preload("res://scenes/assets/road-texture2.jpg"))
	csg.material_override = shader_mat
	csg.path_u_distance = 10

func place_crossings(vertices:Array, target_node:Node3D) -> void:
	for vid in vertices:
		place_intersection(vid,target_node)
		#fill_sidewalk_intersections(vid,target_node)

func fill_sidewalk_intersections(vid:int, parent:Node3D, color:Color = Color(0.25,0.25,0.25,1)):
	if !has_node(parent.get_path()):
		return
	var v := road_network.vertices[vid]
	var edges = road_network.vertex_edges[vid]
	var sorted_edge_ends = []
	for eid in edges:
		var e := road_network.edges[eid]
		var vid2 = e.end_index if e.start_index == vid else e.start_index
		var v2 := road_network.vertices[vid2]
		sorted_edge_ends.append(v2)
	
	var center = Vector2(v.x, v.z)
	sorted_edge_ends.sort_custom(func(a, b):
		var pa = Vector2(a.x,a.z)
		var pb = Vector2(b.x,b.z)
		return atan2(pa.y - center.y, pa.x - center.x) > atan2(pb.y - center.y, pb.x - center.x)
	)
	
	for i in sorted_edge_ends.size():
		var v1 = sorted_edge_ends[i]
		var v2 = sorted_edge_ends[(i + 1)%sorted_edge_ends.size()]
		var edir1 = (v1 - v).normalized()
		var edir2 = (v2 - v).normalized()
		var offset1 = edir1 * width*2
		var offset2 = edir2 * width*2
		var c1 = v + offset1
		var c2 = v + offset2
		var p11 = c1 + (width) * edir1.rotated(Vector3.UP, deg_to_rad(90))
		var p12 = c2 + (width) * edir2.rotated(Vector3.UP, deg_to_rad(-90))
		#var p11 = side_center1 + side_width * edir1.rotated(Vector3.UP, deg_to_rad(-90))
		#var p12 = side_center1 + side_width * edir1.rotated(Vector3.UP, deg_to_rad(90))
		var p21 = p11 + side_width * 2 * edir1.rotated(Vector3.UP, deg_to_rad(90))
		var p22 = p12 + side_width * 2 * edir2.rotated(Vector3.UP, deg_to_rad(-90))
		var raw_points = [Vector2(p11.x, p11.z),Vector2(p12.x, p12.z),Vector2(p21.x, p21.z),Vector2(p22.x, p22.z)]
		var a_side_centroid_v3 =  (p11+p12+p21+p22)/4
		var a_side_centroid = Vector2(a_side_centroid_v3.x,a_side_centroid_v3.z)
		raw_points.sort_custom(func(a, b):
			return atan2(a.y - a_side_centroid.y, a.x - a_side_centroid.x) < atan2(b.y - a_side_centroid.y, b.x - a_side_centroid.x)
		)
		
		var poly_2d = PackedVector2Array(raw_points)
		var material = StandardMaterial3D.new()
		material.albedo_color = color
		place_plate_csg(poly_2d, parent, material, .5)

func place_intersection(vid:int, parent:Node3D):
	#if !has_node(parent.get_path()):
		#print("NOPE: ", parent)
		#return
	var v := road_network.vertices[vid]
	var edges = road_network.vertex_edges[vid]
	#When edges cross, get their ends corners. Then, add these corners to the polygon and render
	var poly_2d = PackedVector2Array()
	var raw_points = []
	
	for eid in edges:
		var e := road_network.edges[eid]
		var vid2 = e.end_index if e.start_index == vid else e.start_index
		var v2 := road_network.vertices[vid2]
		var edir = (v2 - v).normalized()
		var offset = edir * width*2
		var p1 = v + offset + width * edir.rotated(Vector3.UP, deg_to_rad(-90))
		var p2 = v + offset + width * edir.rotated(Vector3.UP, deg_to_rad(90))
		raw_points.append(Vector2(p1.x, p1.z))
		raw_points.append(Vector2(p2.x, p2.z))
	
	var unique = {}
	var unique_points = []
	for pt in raw_points:
		var key = str(pt.x) + "," + str(pt.y) 
		if not unique.has(key):
			unique[key] = true
			unique_points.append(pt)
	
	# Sort by angle around v
	var center = Vector2(v.x, v.z)
	unique_points.sort_custom(func(a, b):
		return atan2(a.y - center.y, a.x - center.x) < atan2(b.y - center.y, b.x - center.x)
	)
	poly_2d = PackedVector2Array(unique_points)
	
	var shader_mat = ShaderMaterial.new()
	var shader = preload("res://scenes/assets/road_shader.gdshader")  # or load() if you have the path
	shader_mat.shader = shader
	# Set uniform values
	shader_mat.set_shader_parameter("tile_scale", 8)
	shader_mat.set_shader_parameter("road_texture", preload("res://scenes/assets/road-texture_nodir.jpg"))
	place_plate_csg(poly_2d, parent, shader_mat, .1)

func place_plate_csg(poly_2d:PackedVector2Array, parent, material, offset = 0.):
	var csg = CSGPolygon3D.new()
	csg.mode = CSGPolygon3D.MODE_DEPTH
	csg.polygon = poly_2d
	csg.depth = thickness
	csg.material_override = material
	csg.use_collision = true
	csg.rotation.x = deg_to_rad(90)
	csg.position.y = -thickness/2. + offset
	parent.add_child(csg)


func render_road_network(roads_target:Node3D, render_sidewalks = true) -> void:
	var rendered_edges = 0
	for edge in road_network.edges:
		var ename = str(edge.start_index)+'-'+str(edge.end_index)
		if (edge.type == 'Old-Full' || edge.type == 'Old-Split'): 
			continue
		if (edge.type == 'Split'):
			ename += "_Split"
		else:
			ename += "_Full"
		var estart_pos = road_network.vertices[edge.start_index]
		var eend_pos = road_network.vertices[edge.end_index]
		
		var road_dir = (eend_pos - estart_pos).normalized()
		var epos = eend_pos - road_dir * width*2
		var spos = estart_pos + road_dir * width*2
		place_road(spos, epos, width, thickness, roads_target, Color(), ename)
		#Sidewalks
		var edir = (eend_pos - estart_pos).normalized()
		var side_offset = (side_width + width) * edir.rotated(Vector3.UP, deg_to_rad(-90))
		var side1p1 = spos  + (side_width + width) * edir.rotated(Vector3.UP, deg_to_rad(90)) + Vector3(0,.5,0)
		var side1p2 = epos + (side_width + width) * edir.rotated(Vector3.UP, deg_to_rad(90)) + Vector3(0,.5,0)
		var side2p1 = spos  + (side_width + width) * edir.rotated(Vector3.UP, deg_to_rad(-90)) + Vector3(0,.5,0)
		var side2p2 = epos + (side_width + width) * edir.rotated(Vector3.UP, deg_to_rad(-90)) + Vector3(0,.5,0)
		if render_sidewalks:
			var clr = Color(0.25,0.25,0.25)
			place_road(side1p1, side1p2, side_width, thickness, roads_target, clr, "Sidewalk1_" + ename, "Sidewalk")
			place_road(side2p1, side2p2, side_width, thickness, roads_target, clr, "Sidewalk2_" + ename, "Sidewalk")
		var dist = 50
		var total_dist = (epos - spos).length()
		while dist < total_dist:
			var light_pos = lerp(estart_pos, eend_pos, dist/total_dist)
			light_pos += side_offset
			var streetlight = streetlight_prefab.instantiate()
			streetlight.position = light_pos
			roads_target.add_child(streetlight)
			dist += streetlight_distance
		
		rendered_edges += 1
		if rendered_edges >= 25:
			#await get_tree().process_frame
			rendered_edges = 0

#WIP
func render_road_network_new(roads_target:Node3D) -> void:
	var scanned_vids = {} #vid: [eid1_v_offset, eid2_v_offset, ... , eidn_v_offset]
	var candidates = [road_network.vertex_edges.keys()[0]]
	while candidates.size() > 0:
		var vid = candidates.pop_back()
		scanned_vids[vid] = true
		var eids = road_network.vertex_edges[vid]
		for eid in eids:
			var edge = road_network.edges[eid]
			var evid = edge.end_index if edge.start_index == vid else edge.start_index
			if !scanned_vids.has(evid):
				candidates.append(evid)
				continue
			
			#Set offsets
			
	
	pass
