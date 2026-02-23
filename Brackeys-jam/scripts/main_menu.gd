extends Control

@onready var how_to_play_panel = $HowToPlayPanel

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_play_button_pressed():
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_how_to_play_button_pressed():
	how_to_play_panel.visible = true

func _on_back_button_pressed():
	how_to_play_panel.visible = false

func _on_exit_button_pressed():
	get_tree().quit()
