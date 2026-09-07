class_name RoadChunk

var edges: Array[int] = []
var vertices: Array[int] = []

func add_edge(edge_id:int) -> int:
	edges.append(edge_id)
	return edges.size()-1

func add_vertice(vid:int) -> int:
	vertices.append(vid)
	return vertices.size()-1
