extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const SENSIVITY = 0.003

const BOB_FREQ = 2.0
const BOB_AMP = 0.08
var t_bob = 0.0

# Variables pour le Screen Shake
var shake_strength: float = 0.0
@export var shake_decay: float = 5.0  # Vitesse à laquelle la secousse s'arrête

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var spot_light_3d: SpotLight3D = $Head/Camera3D/Spotlight/SpotLight3D

# Récupération des nœuds du flash
@onready var flash_sprite: Sprite3D = $Head/Camera3D/Gun/Muzzle/Sprite3D
@onready var flash_light: OmniLight3D = $Head/Camera3D/Gun/Muzzle/OmniLight3D
@onready var gpu_particles_3d: GPUParticles3D = $Head/Camera3D/Gun/Muzzle/GPUParticles3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSIVITY)
		camera.rotate_x(-event.relative.y * SENSIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-40), deg_to_rad(60))
		
	if event.is_action_pressed("ui_cancel") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("ui_cancel") and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
	if event.is_action_pressed("flashlight"):
		switch_flashlight()
		
	if event.is_action_pressed("shoot"):
		create_muzzle_flash()

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction : Vector3 = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var new_speed = 0
		
	if Input.is_action_pressed(	"sprint"):
		new_speed = 10
	
	if direction:
		velocity.x = direction.x * (SPEED + new_speed)
		velocity.z = direction.z * (SPEED + new_speed)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		
	# Head bob
	t_bob += delta * velocity.length() * float(is_on_floor())
	var bob_vector = _headbob(t_bob)
	
	var shake_vector = Vector3.ZERO
	if shake_strength > 0:
		# On réduit la force petit à petit
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
		
		# On crée un vecteur de déplacement aléatoire
		shake_vector = Vector3(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength),
			0.0
		)
	
	camera.transform.origin = bob_vector + shake_vector
	
	# On s'assure que les offsets sont à 0 (on n'utilise plus ça)
	camera.h_offset = 0.0
	camera.v_offset = 0.0

		
	move_and_slide()

func create_muzzle_flash() -> void:
	
	apply_shake(0.1)
	
	gpu_particles_3d.restart()
	gpu_particles_3d.emitting = true
	
	# 1. On rend visible
	flash_sprite.visible = true
	flash_light.visible = true
	
	# 2. Petite rotation aléatoire pour varier le visuel (Roll)
	flash_sprite.rotation.z = randf_range(0, 2 * PI)
	
	# 3. On attend un tout petit moment (ex: 0.05 secondes)
	# L'utilisation de 'create_timer' avec 'await' est parfaite pour ça
	await get_tree().create_timer(0.1).timeout
	
	# 4. On cache tout
	flash_sprite.visible = false
	flash_light.visible = false
	
func apply_shake(strength: float) -> void:
	# On définit la for	ce actuelle (ex: 0.1 pour un petit tir, 0.5 pour une explosion)
	shake_strength = strength
	
func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

func switch_flashlight() -> void:
	if spot_light_3d.visible == true:
		spot_light_3d.visible = false
	else:
		spot_light_3d.visible = true
