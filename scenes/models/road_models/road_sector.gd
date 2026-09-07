class_name RoadSector

var edges: Array[int] = []
var vertices: Array[int] = []
var area: float = 0

var splittable = true
var type = 'Normal'

func _init(new_edges: Array[int], new_vertices: Array[int], new_area:float = 0, is_splittable:bool = true, sector_type = "Normal"):
	edges = new_edges
	vertices = new_vertices
	area = new_area
	splittable = is_splittable
