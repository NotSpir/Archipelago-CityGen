extends Node3D


const size := 512.0
@onready var plane_mesh = $MeshInstance3D
@export_range(4, 256, 4) var resolution = 32
@export var noise: FastNoiseLite
@export_range(4.0, 512.0, 4.0) var height := 128.0

func generate_new_terrain():
	
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.009
	noise.seed = round(global_position.x) + round(global_position.y) + randi_range(0, 100)
	plane_mesh.material_override.set_shader_parameter("normal_map", noise)
	update_mesh()

func get_height(x:float, y:float) -> float:
	return noise.get_noise_2d(x,y) * height

func get_normal(x:float, y:float) -> Vector3:
	var epsilon = size/resolution
	var normal:= Vector3(
		(get_height(x + epsilon, y) - get_height(x - epsilon, y)) / (2. * epsilon),
		1.,
		(get_height(x, y + epsilon) - get_height(x, y - epsilon)) / (2. * epsilon)
	)
	return normal.normalized()

func update_mesh() -> void:
	var plane := PlaneMesh.new()
	plane.subdivide_depth = resolution
	plane.subdivide_width = resolution
	plane.size = Vector2(size, size)
	
	var plane_arrays := plane.get_mesh_arrays()
	var vertex_array : PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_VERTEX]
	var normal_array : PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_NORMAL]
	var tangent_array : PackedFloat32Array = plane_arrays[ArrayMesh.ARRAY_TANGENT]
	
	for i:int in vertex_array.size():
		var vertex := vertex_array[i]
		var normal := Vector3.UP
		var tangent := Vector3.RIGHT
		if noise:
			vertex.y = get_height(vertex.x, vertex.z)
			normal = get_normal(vertex.x, vertex.z)
			tangent = normal.cross(Vector3.UP)
		if vertex.length() > 200:
			vertex.y += (100 - vertex.length())
		vertex_array[i] = vertex
		normal_array[i] = normal
		tangent_array[4*i] = tangent.x
		tangent_array[4*i + 1] = tangent.y
		tangent_array[4*i + 2] = tangent.z
	
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane_arrays)
	plane_mesh.mesh = array_mesh
	
	var static_body = StaticBody3D.new()
	var ground_collision = CollisionShape3D.new()	
	var shape = plane_mesh.mesh.create_trimesh_shape()
	ground_collision.shape = shape
	static_body.position.y += 50
	static_body.add_child(ground_collision)
	add_child(static_body)
