class_name RoadSection

func _init(start_id:int, end_id:int, segment_type:String):
	start_index = start_id
	end_index = end_id
	type = segment_type

var start_index: int
var end_index: int
var type: String
