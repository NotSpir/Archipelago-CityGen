@tool
extends Node

func get_vectors_intersection(vec1_start:Vector3, vec1_end:Vector3, vec2_start:Vector3, vec2_end:Vector3):
	var line1_start = Vector2(vec1_start.x, vec1_start.z)
	var line1_end = Vector2(vec1_end.x, vec1_end.z)
	var line2_start = Vector2(vec2_start.x, vec2_start.z)
	var line2_end = Vector2(vec2_end.x, vec2_end.z)
	var result = Geometry2D.segment_intersects_segment(line1_start, line1_end, line2_start, line2_end)
	if result:
		return Vector3(result.x, 0, result.y)
	return null

func check_3D_point_on_line(point:Vector3, start:Vector3, end:Vector3, epsilon := 0.001) -> bool:
	var point2 = Vector3_to_Vector2(point)
	var start2 = Vector3_to_Vector2(start)
	var end2 = Vector3_to_Vector2(end)
	return Geometry2D.get_closest_point_to_segment(point2, start2, end2).distance_to(point2) < epsilon

func Vector3_to_Vector2(vector:Vector3) -> Vector2:
	return Vector2(vector.x, vector.z)

func get_line_length(start:Vector3, end:Vector3):
	return (end - start).length()

func get_angle_by_points(p1:Vector3,p_center:Vector3,p2:Vector3):
	var v := Vector3_to_Vector2(p1) - Vector3_to_Vector2(p_center)
	var u := Vector3_to_Vector2(p2) - Vector3_to_Vector2(p_center)
	var d := v.dot(u)
	var len_v = v.length()
	var len_u = u.length()
	var cos_theta:float= clamp(d/(len_v*len_u), -1.0, 1.0)
	var angle_rad: float = acos(cos_theta)
	return angle_rad

func get_angle_by_points_degrees(p1:Vector3,p_center:Vector3,p2:Vector3):
	var v := Vector3_to_Vector2(p1) - Vector3_to_Vector2(p_center)
	var u := Vector3_to_Vector2(p2) - Vector3_to_Vector2(p_center)
	var d := v.dot(u)
	var len_v = v.length()
	var len_u = u.length()
	var cos_theta:float= clamp(d/(len_v*len_u), -1.0, 1.0)
	var angle_rad: float = acos(cos_theta)
	return angle_rad * 180/PI
