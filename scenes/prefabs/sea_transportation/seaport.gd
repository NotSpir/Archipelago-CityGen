extends Node3D


@onready var docking_points = $DockingPoints
var docking_info = {}

func set_all_docking_positions():
	for child in docking_points.get_children():
		docking_info[child.global_position] = {"taken": false}

func get_first_dock_available():
	for dock in docking_info:
		if !docking_info[dock].taken: 
			docking_info[dock].taken = true
			return dock
	return null

func has_dock_available():
	for dock in docking_info:
		if !docking_info[dock].taken: 
			return true
	return false

func _ready() -> void:
	set_all_docking_positions()
