extends CharacterBody3D

# Vitesse de déplacement
@export var speed: float = 1.5
# Liste des points de passage (à assigner dans l'inspecteur)
@export var patrol_points: Array[Node3D]

@export var stun_duration: float = 3.0 

@onready var animation_player: AnimationPlayer = $PSX_BagMan/AnimationPlayer
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var player: CharacterBody3D = null

var current_point_index: int = 0
var is_stunned: bool = false

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	
	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = 1.0

func _physics_process(delta: float) -> void:
	# Appliquer la gravité si l'ennemi n'est pas au sol
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0
	
	if is_stunned:
		if $FootstepsSound.playing and not $FootstepsSound.stream_paused:
			$FootstepsSound.stream_paused = true
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		move_and_slide()
		return
	elif $FootstepsSound.stream_paused:
		$FootstepsSound.stream_paused = false
	
	var target_destination: Vector3 = Vector3.ZERO
	var is_chasing_player: bool = false
		
	if player and player.flash_light_on:
		animation_player.play("Run")
		speed = 3.0
		target_destination = player.global_position
		is_chasing_player = true
	elif not patrol_points.is_empty():
		animation_player.play("Walk")
		speed = 1.5
		target_destination = patrol_points[current_point_index].global_position
		
		if global_position.distance_to(target_destination) < 1.0:
			# ... On passe au suivant
			current_point_index = (current_point_index + 1) % patrol_points.size()
			# IMPORTANT : On met à jour la cible IMMÉDIATEMENT pour cette frame
			# Sinon l'ennemi essaie de revenir au point précédent pendant 1 frame (ce qui cause le tremblement)
			target_destination = patrol_points[current_point_index].global_position
	else:
		move_and_slide()
		return

	nav_agent.target_position = target_destination
	
	# 2. On demande le PROCHAIN point à atteindre pour contourner les murs
	var next_path_position: Vector3 = nav_agent.get_next_path_position()
	
	# 3. On calcule la direction vers ce prochain point (et pas vers la cible finale !)
	# On garde la hauteur actuelle pour ne pas voler
	next_path_position.y = global_position.y
	var direction = global_position.direction_to(next_path_position)
	
	# Application de la vitesse
	# Tu peux augmenter la vitesse si il chasse le joueur (optionnel)
	var current_speed = speed
	if is_chasing_player:
		current_speed = speed * 2.0 # Il court plus vite quand il te voit !
		
	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed
	
	# --- ROTATION FLUIDE ---
	if direction.length() > 0.001:
		var target_rotation_y = transform.looking_at(next_path_position, Vector3.UP).basis.get_euler().y
		rotation.y = lerp_angle(rotation.y, target_rotation_y, delta * 10.0)

	move_and_slide()

func stun() -> void:
	if is_stunned: return # Déjà sonné, on ne fait rien (ou on reset le timer si tu préfères)

	is_stunned = true
	nav_agent.target_position = global_position 
	animation_player.pause()
	
	# On attend 3 secondes (ou la valeur de stun_duration)
	await get_tree().create_timer(stun_duration).timeout
	
	# On réveille l'ennemi
	is_stunned = false
	animation_player.play("Walk")

func _on_kill_zone_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and not is_stunned:
		if body.has_method("die"):
			body.die()
