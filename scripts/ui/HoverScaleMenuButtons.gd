extends VBoxContainer

@export var hover_scale: float = 1.06
@export var duration_in: float = 0.08
@export var duration_out: float = 0.10

func _ready() -> void:
	for child in get_children():
		if child is Button:
			child.pivot_offset = child.size * 0.5
			# Connect signals for hover and focus
			child.connect("mouse_entered", Callable(self, "_on_enter").bind(child))
			child.connect("mouse_exited", Callable(self, "_on_exit").bind(child))
			child.connect("focus_entered", Callable(self, "_on_enter").bind(child))
			child.connect("focus_exited", Callable(self, "_on_exit").bind(child))

func _on_enter(btn: Button) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(hover_scale, hover_scale), duration_in)

func _on_exit(btn: Button) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(btn, "scale", Vector2.ONE, duration_out)
