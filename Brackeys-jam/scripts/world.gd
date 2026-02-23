extends Node3D

var activated_generators: int = 0
@export var total_generators_needed: int = 3

func _ready():

	var generators = get_tree().get_nodes_in_group("generator")

	$NavigationRegion3D/Generator.generator_activated.connect(_on_generator_activated)
	$NavigationRegion3D/Generator2.generator_activated.connect(_on_generator_activated)
	$NavigationRegion3D/Generator3.generator_activated.connect(_on_generator_activated)

func _on_generator_activated():
	activated_generators += 1
	
	if activated_generators >= total_generators_needed:
		win_game()

func win_game():
	get_tree().change_scene_to_file("res://scenes/win_screen.tscn")
