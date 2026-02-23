extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const SENSIVITY = 0.003

const BOB_FREQ = 2.0
const BOB_AMP = 0.08
var t_bob = 0.0

var flash_light_on: bool = false

# Variables pour le Screen Shake
var shake_strength: float = 0.0
@export var shake_decay: float = 5.0  # Vitesse à laquelle la secousse s'arrête
@export var munitions: int = 6

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var spot_light_3d: SpotLight3D = $Head/Camera3D/Spotlight/SpotLight3D
@onready var flash_light_warning: Control = $CanvasLayer/FlashLightWarning

# Récupération des nœuds du flash
@onready var flash_sprite: Sprite3D = $Head/Camera3D/Gun/Muzzle/Sprite3D
@onready var flash_light: OmniLight3D = $Head/Camera3D/Gun/Muzzle/OmniLight3D
@onready var gpu_particles_3d: GPUParticles3D = $Head/Camera3D/Gun/Muzzle/GPUParticles3D
@onready var ray_cast_3d: RayCast3D = $Head/Camera3D/RayCast3D
@onready var gun_shot: AudioStreamPlayer3D = $GunShot
@onready var ammo_label: Label = $CanvasLayer/AmmoLabel

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	update_ammo_ui()

func _unhandled_input(event: InputEvent) -> void:
	
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			# On "consomme" l'événement pour que le premier clic serve 
			# UNIQUEMENT à capturer la souris (plus safe sur le web)
			get_viewport().set_input_as_handled()
			return 
	# -----------------------------

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		head.rotate_y(-event.relative.x * SENSIVITY)
		camera.rotate_x(-event.relative.y * SENSIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-40), deg_to_rad(60))

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
		shoot()

func _input(event: InputEvent) -> void:
	# Ajoute ceci au début de ta fonction _input existante
	if event is InputEventMouseButton:
		if event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	#if Input.is_action_just_pressed("ui_accept") and is_on_floor():
	#	velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction : Vector3 = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var new_speed = 0
		
	if Input.is_action_pressed(	"sprint"):
		new_speed = 2
	
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

func shoot() -> void:
	
	if munitions <= 0:
		return
	
	munitions -= 1
	
	update_ammo_ui()
	
	gun_shot.play()
	gun_shot.pitch_scale = randf_range(0.9, 1.1)
	
	apply_shake(0.1)
	
		# --- LOGIQUE DE TIR (HITSCAN) ---
	if ray_cast_3d.is_colliding():
		var target = ray_cast_3d.get_collider() # On récupère l'objet touché
		var enemy = null
		
		# --- LOGIQUE DE DÉTECTION ROBUSTE ---
		# 1. Est-ce que l'objet touché est lui-même l'ennemi (la Capsule globale) ?
		if target.is_in_group("enemy"):
			enemy = target
		# 2. Sinon, est-ce que son "propriétaire" est l'ennemi (les Areas des membres) ?
		elif target.owner and target.owner.is_in_group("enemy"):
			enemy = target.owner
		# 3. Au cas où, on cherche dans les parents
		elif target.get_parent().is_in_group("enemy"):
			enemy = target.get_parent()
			
		# Si on a trouvé un ennemi, on le stun
		if enemy and enemy.has_method("stun"):
			enemy.stun()
	# --------------------------------
	
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
	flash_light_on = !flash_light_on
	
	spot_light_3d.visible = flash_light_on
	
	if flash_light_on:
		_flash_loop()
	else:
		flash_light_warning.visible = false

func _flash_loop() -> void:
	# Tant que la lumière est éteinte (flash_light_on est faux)
	while flash_light_on == true:
		# L'astuce magique : visible devient l'inverse de visible
		flash_light_warning.visible = !flash_light_warning.visible
		
		# On attend un peu (0.5s est un bon rythme pour une alerte)
		await get_tree().create_timer(0.5).timeout
		
		# Sécurité : Si le joueur a rallumé la lumière PENDANT le timer
		if flash_light_on == false:
			flash_light_warning.visible = false
			return # On arrête la boucle
			
		#flash_light_warning.visible = !flash_light_warning.visible

func die() -> void:
	var dead_screen_scene = load("res://scenes/death_screen.tscn")
	var dead_screen_instance = dead_screen_scene.instantiate()
	get_tree().root.add_child(dead_screen_instance)
	
	set_physics_process(false)
	set_process_unhandled_input(false)
	
func update_ammo_ui() -> void:
	ammo_label.text = "Ammo : " + str(munitions)
