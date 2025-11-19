extends Control

@onready var anim_player = $Title/AnimationPlayer
@onready var network := get_node("/root/NetworkManager")
@onready var lobby_code_input: LineEdit = $Lobbycode

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	anim_player.play("float")


## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass


func _on_host_button_pressed() -> void:
	if network:
		network.host_game(4) # Steam if available, ENet placeholder otherwise
	get_tree().change_scene_to_file("res://scenes/3d/Main3D.tscn")


func _on_join_button_pressed() -> void:
	#print(lobby_code_input.text.strip_edges())
	var code := lobby_code_input.text.strip_edges()
	if code.is_empty():
		print("Enter a lobby ID first")
		return
	if code.is_valid_int():
		var lobby_id := code.to_int()
		print("Sending numeric lobby ID to NetworkManager", lobby_id)
		NetworkManager.join_game(lobby_id)
	else:
		var short_code := code.to_upper()
		print("Sending lobby short code to NetworkManager", short_code)
		NetworkManager.join_game(short_code)

func _on_option_button_pressed() -> void:
	pass # Replace with function body.


func _on_quit_button_pressed() -> void:
	get_tree().quit()
