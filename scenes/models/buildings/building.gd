class_name BuildingData

var corners: Array[Vector3] = []
var height: float = 0
var color:Color = Color(1,1,1,1)

func _init(cords:Array[Vector3], height_tall:float, building_color:Color = Color(1,1,1,1)) -> void:
	corners = cords
	height = height_tall
	color = building_color
