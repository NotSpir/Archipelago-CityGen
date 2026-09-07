extends Control

var host
@onready var options_background := $OptionsRect
@onready var options_container := $OptionsContainer
@onready var player_options_container := $PlayerOptions
@onready var rect_options_cont := $OptionsContainer/SquareRoadOptions
@onready var ring_options_cont := $OptionsContainer/RingRoadOptions
@onready var circle_options_cont := $OptionsContainer/CircleRoadOptions
@onready var archipelago_options_cont := $OptionsContainer/ArchipelagoOptions
@onready var note := $Note

#Generation options
@onready var gen_type_item_list:ItemList = $OptionsContainer/GenerationOptions/ItemList
@onready var seed_line_edit:LineEdit = $OptionsContainer/GenerationOptions/SeedLineEdit
var gen_seed = 0
#Building options
@onready var max_height_line_edit:LineEdit = $OptionsContainer/BuildingOptions/MaxHeightLineEdit
var max_height = 1000
@onready var cell_size_line_edit:LineEdit = $OptionsContainer/BuildingOptions/CellSizeLineEdit
var cell_size = 8

#SQUARE Road options
@onready var square_max_split_line_edit:LineEdit = $OptionsContainer/SquareRoadOptions/MaxSplitLineEdit
var square_max_split = 0
@onready var square_min_split_line_edit:LineEdit = $OptionsContainer/SquareRoadOptions/MinSplitLineEdit
var square_min_split = 0
@onready var square_min_area_line_edit:LineEdit = $OptionsContainer/SquareRoadOptions/MinAreaLineEdit
var square_min_area = 1000
@onready var square_split_block_line_edit:LineEdit = $OptionsContainer/SquareRoadOptions/SplitBlockLineEdit
var square_split_block = 0.01
#Finite square options
@onready var square_size_line_edit:LineEdit = $OptionsContainer/SquareRoadOptions/SquareSizeLineEdit
var square_size = 495
@onready var square_distance_line_edit:LineEdit = $OptionsContainer/SquareRoadOptions/SquareDistanceLineEdit
var square_distance = 2

#RING Road options
@onready var ring_split_line_edit:LineEdit = $OptionsContainer/RingRoadOptions/RingSplitLineEdit
var ring_split = 0
@onready var ring_min_area_line_edit:LineEdit = $OptionsContainer/RingRoadOptions/MinAreaLineEdit
var ring_min_area = 20000
@onready var ring_split_block_line_edit:LineEdit = $OptionsContainer/RingRoadOptions/SplitBlockLineEdit
var ring_split_block = 0.01
@onready var ring_outer_rings_line_edit:LineEdit = $OptionsContainer/RingRoadOptions/OuterRingsLineEdit
var ring_outer_rings = 1
@onready var ring_outer_distance_line_edit:LineEdit = $OptionsContainer/RingRoadOptions/OuterDistanceLineEdit
var ring_outer_distance = 500
@onready var ring_initial_radius_line_edit:LineEdit = $OptionsContainer/RingRoadOptions/StartRingRadiusLineEdit
var ring_initial_radius = 500

#CIRCLE Road options
@onready var circle_split_line_edit:LineEdit = $OptionsContainer/CircleRoadOptions/CircleSplitLineEdit
var circle_split = 0
@onready var circle_min_area_line_edit:LineEdit = $OptionsContainer/CircleRoadOptions/MinAreaLineEdit
var circle_min_area = 10000
@onready var circle_split_block_line_edit:LineEdit = $OptionsContainer/CircleRoadOptions/SplitBlockLineEdit
var circle_split_block = 0.01
@onready var circle_vertices_line_edit:LineEdit = $OptionsContainer/CircleRoadOptions/CircleVerticesLineEdit
var circle_vertice = 10
@onready var circle_radius_line_edit:LineEdit = $OptionsContainer/CircleRoadOptions/CircleRadiusLineEdit
var circle_radius = 500
#Archipelago options
@onready var island_amount_line_edit:LineEdit = $OptionsContainer/ArchipelagoOptions/IslandAmountLineEdit
var archipelago_island_amount = 3

var curr_generator

var prepacked_ring_gen = preload("res://scenes/single_gen/ring/ring_road_generator.tscn")
var prepacked_circle_gen = preload("res://scenes/single_gen/circle/circle_city.tscn")
var prepacked_archipelago_gen = preload("res://scenes/archipelago_gen/archipelago_gen.tscn")
var gen_type_idx = 0

signal regen_initiated(respawn_position:Vector3)
signal speed_changed(value)
signal flight_changed(value)


func showhide_ui(visibility := true):
	options_container.visible = visibility
	options_background.visible = visibility
	player_options_container.visible = visibility
	note.visible = visibility

func _perform_generation() -> void:
	for child in $"../../Cars".get_children():
		child.queue_free()
	if curr_generator != null:
		curr_generator.queue_free()
	match gen_type_idx:
		#0: #Infinite squares ON HOLD
			#regen_initiated.emit(Vector3(250,10,250))
			#curr_generator = InfiniteSquareCityGenerator.new()
			#curr_generator.player = $".."
			#$"../..".add_child(curr_generator)
			#curr_generator.owner = get_tree().edited_scene_root
			#await get_tree().process_frame
			#curr_generator._set_params(seed_line_edit.text.to_int(), square_min_split_line_edit.text.to_int(), square_max_split_line_edit.text.to_int(), 
			#square_min_area_line_edit.text.to_float(), square_split_block_line_edit.text.to_float(), 
			#max_height_line_edit.text.to_int(), cell_size_line_edit.text.to_int())
		
		0: #Archipelago
			regen_initiated.emit(Vector3(0,10,0))
			curr_generator = prepacked_archipelago_gen.instantiate()
			$"../..".add_child(curr_generator)
			curr_generator._set_params(gen_seed, archipelago_island_amount, 
			max_height, cell_size)
		
		1: #Squares
			var sq_dist = square_size_line_edit.text.to_int()
			regen_initiated.emit(Vector3(sq_dist/2.,10,sq_dist/2.))
			curr_generator = SquareCityGenerator.new()
			$"../..".add_child(curr_generator)
			curr_generator.owner = get_tree().edited_scene_root
			await get_tree().process_frame
			curr_generator._set_params(gen_seed ,square_distance,square_size, 
			square_min_split, square_max_split, 
			square_min_area, square_split_block, 
			max_height, cell_size)
		2: #Rings
			regen_initiated.emit(Vector3(0,10,0))
			curr_generator = prepacked_ring_gen.instantiate()
			$"../..".add_child(curr_generator)
			curr_generator.owner = get_tree().edited_scene_root
			await get_tree().process_frame
			curr_generator._set_params(gen_seed, ring_split, 
			ring_min_area, ring_split_block,  
			ring_outer_rings, ring_outer_distance, ring_initial_radius,
			max_height, cell_size)
		3: #Circle
			regen_initiated.emit(Vector3(0,10,0))
			curr_generator = prepacked_circle_gen.instantiate()
			$"../..".add_child(curr_generator)
			curr_generator.owner = get_tree().edited_scene_root
			await get_tree().process_frame
			curr_generator._set_params(gen_seed, circle_split, 
			circle_min_area, circle_split_block,  
			circle_radius, circle_vertice,
			max_height, cell_size)
	GlobalValues.flush_chunks()
	GlobalValues.road_network_array = []
	curr_generator._regenerate()
	pass

func _on_seed_line_edit_text_submitted(new_text: String) -> void:
	if new_text.length() > 32:
		return
	
	var caret_pos = seed_line_edit.get_caret_column()
	seed_line_edit.text = str(new_text.to_int())
	seed_line_edit.set_caret_column(min(caret_pos, seed_line_edit.text.length()))
	gen_seed = new_text.to_int()

func _on_max_height_line_edit_text_submitted(new_text: String) -> void:
	var caret_pos = max_height_line_edit.get_caret_column()
	var val = clampi(new_text.to_int(),1,1500)
	max_height_line_edit.text = str(val)
	max_height_line_edit.set_caret_column(min(caret_pos, max_height_line_edit.text.length()))
	max_height = val
func _on_cell_size_line_edit_text_submitted(new_text: String) -> void:
	var caret_pos = cell_size_line_edit.get_caret_column()
	print("AAAAAAAAAA")
	var val = clampi(new_text.to_int(),4,100)
	cell_size_line_edit.text = str(val)
	assert(val == cell_size_line_edit.text.to_int(), "Success")
	print(val == cell_size_line_edit.text.to_int())
	cell_size_line_edit.set_caret_column(min(caret_pos, cell_size_line_edit.text.length()))
	cell_size = val
func _on_min_split_line_edit_text_submitted(new_text: String) -> void:
	var caret_pos = square_min_split_line_edit.get_caret_column()
	var max_val = square_max_split_line_edit.text.to_int()
	var val = clampi(new_text.to_int(),0,max_val)
	square_min_split_line_edit.text = str(val)
	square_min_split_line_edit.set_caret_column(min(caret_pos, square_min_split_line_edit.text.length()))
	square_min_split = val
func _on_max_split_line_edit_text_submitted(new_text: String) -> void:
	var caret_pos = square_max_split_line_edit.get_caret_column()
	var min_val = square_min_split_line_edit.text.to_int()
	var val = clampi(new_text.to_int(),min_val,10)
	square_max_split_line_edit.text = str(val)
	square_max_split_line_edit.set_caret_column(min(caret_pos, square_max_split_line_edit.text.length()))
	square_max_split = val
func _on_min_area_line_edit_text_submitted(new_text: String) -> void:
	var caret_pos = square_min_area_line_edit.get_caret_column()
	var val = clampi(new_text.to_int(),100,1000000)
	square_min_area_line_edit.text = str(val)
	ring_min_area_line_edit.text = str(val)
	square_min_area_line_edit.set_caret_column(min(caret_pos, square_min_area_line_edit.text.length()))
	square_min_area = val
func _on_split_block_line_edit_text_submitted(new_text: String) -> void:
	var caret_pos = square_split_block_line_edit.get_caret_column()
	var val = clampf(new_text.to_float(), 0.0, 1.0)
	square_split_block_line_edit.text = str(val)
	ring_split_block_line_edit.text = str(val)
	square_split_block_line_edit.set_caret_column(min(caret_pos, square_split_block_line_edit.text.length()))
	square_split_block = val
	ring_split_block = val

func _on_item_list_item_selected(index: int) -> void:
	gen_type_idx = index
	match gen_type_idx:
		#0: INFINITE SQUARE GEN (HIDDEN FOR NOW)
			#rect_options_cont.visible = true
			#ring_options_cont.visible = false
			#circle_options_cont.visible = false
		0:
			rect_options_cont.visible = false
			ring_options_cont.visible = false
			circle_options_cont.visible = false
			archipelago_options_cont.visible = true
		1:
			rect_options_cont.visible = true
			ring_options_cont.visible = false
			circle_options_cont.visible = false
			archipelago_options_cont.visible = false
		2:
			rect_options_cont.visible = false
			ring_options_cont.visible = true
			circle_options_cont.visible = false
			archipelago_options_cont.visible = false
		3:
			circle_options_cont.visible = true
			rect_options_cont.visible = false
			ring_options_cont.visible = false
			archipelago_options_cont.visible = false


func _on_button_button_down() -> void:
	options_container.visible = false
	options_background.visible = false
	player_options_container.visible = false
	note.visible = false
	_perform_generation()


func _on_ring_split_line_edit_text_submitted(new_text: String) -> void:
	var caret_pos = ring_split_line_edit.get_caret_column()
	var val = clampi(new_text.to_int(),0,10)
	ring_split_line_edit.text = str(val)
	ring_split_line_edit.set_caret_column(min(caret_pos, ring_split_line_edit.text.length()))
	ring_split = val


func _on_outer_rings_line_edit_text_submitted(new_text: String) -> void:
	var caret_pos = ring_outer_rings_line_edit.get_caret_column()
	var val = clampi(new_text.to_int(),1,3)
	ring_outer_rings_line_edit.text = str(val)
	ring_outer_rings_line_edit.set_caret_column(min(caret_pos, ring_outer_rings_line_edit.text.length()))
	ring_outer_rings = val


func _on_outer_distance_line_edit_text_submitted(new_text: String) -> void:
	var caret_pos = ring_outer_distance_line_edit.get_caret_column()
	var val = clampi(new_text.to_int(), 128, 1000)
	ring_outer_distance_line_edit.text = str(val)
	ring_outer_distance_line_edit.set_caret_column(min(caret_pos, ring_outer_distance_line_edit.text.length()))
	ring_outer_distance = val


func _on_start_ring_radius_line_edit_text_submitted(new_text: String) -> void:
	var caret_pos = ring_initial_radius_line_edit.get_caret_column()
	var val = max(50, new_text.to_int())
	ring_initial_radius_line_edit.text = str(val)
	ring_initial_radius_line_edit.set_caret_column(min(caret_pos, ring_initial_radius_line_edit.text.length()))
	ring_initial_radius = val


func _on_square_size_line_edit_text_submitted(new_text: String) -> void:
	var caret_pos = square_size_line_edit.get_caret_column()
	var val = clamp(new_text.to_int(), 50, 2000)
	square_size_line_edit.text = str(val)
	square_size_line_edit.set_caret_column(min(caret_pos, square_size_line_edit.text.length()))
	square_size = val


func _on_square_distance_line_edit_text_submitted(new_text: String) -> void:
	var caret_pos = square_distance_line_edit.get_caret_column()
	var val = clamp(new_text.to_int(), 0, 10)
	square_distance_line_edit.text = str(val)
	square_distance_line_edit.set_caret_column(min(caret_pos, square_distance_line_edit.text.length()))
	square_distance = val


func _on_circle_split_line_edit_text_submitted(new_text: String) -> void:
	var caret_pos = circle_split_line_edit.get_caret_column()
	var val = clamp(new_text.to_int(), 0, 10)
	circle_split_line_edit.text = str(val)
	circle_split_line_edit.set_caret_column(min(caret_pos, circle_split_line_edit.text.length()))
	circle_split = val


func _on_min_area_circle_line_edit_text_submitted(new_text: String) -> void:
	var caret_pos = circle_min_area_line_edit.get_caret_column()
	var val = clamp(new_text.to_int(), 0, 10)
	circle_min_area_line_edit.text = str(val)
	circle_min_area_line_edit.set_caret_column(min(caret_pos, circle_min_area_line_edit.text.length()))
	circle_min_area = val


func _on_split_block_circle_line_edit_text_submitted(new_text: String) -> void:
	var caret_pos = circle_split_block_line_edit.get_caret_column()
	var val = clampf(new_text.to_float(), 0.0, 1.0)
	circle_split_block_line_edit.text = str(val)
	circle_split_block_line_edit.set_caret_column(min(caret_pos, circle_split_block_line_edit.text.length()))
	circle_split_block = val


func _on_circle_vertices_line_edit_text_submitted(new_text: String) -> void:
	var caret_pos = circle_vertices_line_edit.get_caret_column()
	var val = clamp(new_text.to_int(), 0, 50)
	circle_vertices_line_edit.text = str(val)
	circle_vertices_line_edit.set_caret_column(min(caret_pos, circle_vertices_line_edit.text.length()))
	circle_vertice = val


func _on_circle_radius_line_edit_text_submitted(new_text: String) -> void:
	var caret_pos = circle_radius_line_edit.get_caret_column()
	var val = clamp(new_text.to_int(), 0, 10000)
	circle_radius_line_edit.text = str(val)
	circle_radius_line_edit.set_caret_column(min(caret_pos, circle_radius_line_edit.text.length()))
	circle_radius = val


func _on_island_amount_line_edit_text_submitted(new_text: String) -> void:
	var caret_pos = island_amount_line_edit.get_caret_column()
	var val = clamp(new_text.to_int(), 0, 10)
	island_amount_line_edit.text = str(val)
	island_amount_line_edit.set_caret_column(min(caret_pos, island_amount_line_edit.text.length()))
	archipelago_island_amount = val


func _on_speed_line_edit_text_submitted(new_text: String) -> void:
	var val = clamp(new_text.to_int(), 0, 10000)
	$PlayerOptions/VBoxContainer/SpeedLineEdit.text = str(val)
	speed_changed.emit(val)


func _on_flight_line_edit_text_submitted(new_text: String) -> void:
	var val = clamp(new_text.to_int(), 0, 10000)
	$PlayerOptions/VBoxContainer2/FlightLineEdit.text = str(val)
	flight_changed.emit(val)
