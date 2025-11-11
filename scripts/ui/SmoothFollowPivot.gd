extends Node3D

@export_node_path("Node3D") var target_path: NodePath
@export var follow_speed: float = 8.0
@export var keep_yaw_zero: bool = true

var _t: Node3D

func _ready() -> void:
	if target_path != NodePath():
		_t = get_node(target_path) as Node3D

func _physics_process(delta: float) -> void:
	if not _t:
		return
	var cur := global_transform.origin
	var dst := _t.global_transform.origin
	global_transform.origin = cur.lerp(dst, clamp(follow_speed * delta, 0.0, 1.0))
	if keep_yaw_zero:
		rotation_degrees.y = 0.0
