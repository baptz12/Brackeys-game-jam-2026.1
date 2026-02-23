extends Node3D

signal generator_activated # Signal envoyé au World quand c'est fini

@export var required_time: float = 10.0
var current_time: float = 0.0
var is_activated: bool = false
var player_in_range = null # On stocke le joueur s'il est proche

@onready var activation_light = $OmniLight3D # La lumière rouge actuelle
@onready var progress_bar = $ProgressSprite/SubViewport/ProgressBar
@onready var progress_sprite = $ProgressSprite
@onready var alert_icon: Label3D = $AlertIcon

func _ready():
	# Connecter les signaux de l'Area3D (assure-toi que ton Area3D est bien nommée Area3D)
	$Area3D.body_entered.connect(_on_body_entered)
	$Area3D.body_exited.connect(_on_body_exited)
	progress_sprite.visible = false # Caché au début
	progress_bar.max_value = required_time

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = body
		if not is_activated:
			progress_sprite.visible = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = null
		progress_sprite.visible = false # On cache la barre
		current_time = 0.0 

func _process(delta):
	if is_activated:
		return

	if alert_icon.visible:
		alert_icon.rotate_y(delta * 4.0) # Vitesse de rotation

	if is_activated:
		alert_icon.visible = false # Disparaît si fini
		return

	# 2. Logique de visibilité
	# On veut le cacher si on est en train de charger (barre de progression visible)
	if player_in_range and player_in_range.flash_light_on:
		alert_icon.visible = false
	else:
		alert_icon.visible = true

	if player_in_range and player_in_range.flash_light_on:
		current_time += delta
		
		progress_bar.value = current_time
		
		activation_light.light_energy = 2.0 + (current_time * 2) 
		
		if current_time >= required_time:
			activate()
	else:
		current_time = 0.0
		progress_bar.value = 0.0
		activation_light.light_energy = 5.0

func activate():
	is_activated = true
	generator_activated.emit()

	progress_sprite.visible = false # On cache la barre une fois fini
	activation_light.light_color = Color.GREEN
	activation_light.light_energy = 10.0
