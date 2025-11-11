extends Camera3D

@export var min_fov: float = 35.0
@export var max_fov: float = 85.0
@export var step: float = 3.0
@export var smooth: float = 10.0

var _target_fov: float

func _ready() -> void:
	_target_fov = fov  # start from current FOV

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_fov = max(min_fov, _target_fov - step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_fov = min(max_fov, _target_fov + step)

func _process(delta: float) -> void:
	fov = lerpf(fov, _target_fov, clamp(smooth * delta, 0.0, 1.0))
