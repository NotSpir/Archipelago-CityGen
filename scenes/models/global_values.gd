extends Node

#Single gen type network
var road_network:RoadNetwork

#Archipelago gen type network
var road_network_array:Array = []
var major_chunk_manager = ""
var minor_chunk_manager = MinorChunkManager.new()
signal chunks_flushed

func flush_chunks():
	minor_chunk_manager.unload_all_chunks()
	minor_chunk_manager = MinorChunkManager.new()
	major_chunk_manager = ""
	chunks_flushed.emit()

var park_objects_pool = [
	preload("res://scenes/prefabs/park_assets/makeshift_bush.tscn"),
	preload("res://scenes/prefabs/park_assets/makeshift_flowers.tscn"),
	preload("res://scenes/prefabs/park_assets/makeshift_monument.tscn"),
	preload("res://scenes/prefabs/park_assets/makeshift_tree_round.tscn"),
	preload("res://scenes/prefabs/park_assets/makeshift_tree_spike.tscn")
]

var park_roads_set:Dictionary = {
	"Empty": "res://assets/park_grid/Empty.png",
	"Straight": "res://assets/park_grid/Straight.png",
	"Corner": "res://assets/park_grid/Corner.png",
	"Deadend": "res://assets/park_grid/Deadend.png",
	"T": "res://assets/park_grid/T.png",
	"Cross": "res://assets/park_grid/Cross.png"
}

var construction_objects_pool = [
	
]

var pond_ground_objects_pool = [
	
]

var pond_water_objects_pool = [
	
]

var shore_objects_pool = [
	
]
