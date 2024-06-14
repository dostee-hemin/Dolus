extends CharacterBody2D

@onready var game_manager : Node = get_node("/root/Game/GameManager")

@onready var camera : Camera2D = $Camera2D

@export var agent_name : String
@export var animation_texture : Texture
@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var info_label : Label = $"Info Label"
var previous_velocity : Vector2
var damping_factor : float = 0.9

@export var inv: Inv

var dialogue_history : Array
var dialogue_partner : Node2D

var as_entity : Entity

signal callback_signal
var lock : Mutex = Mutex.new()

@onready var popup_ui_label : Label = $"Popup UI"
@onready var interaction_zone : Area2D = $"Interaction Zone"
var popup_alpha : float
var closest_entity : Node2D

var cause_of_kill:String
var is_in_meeting : bool

var kill_enabled: bool = true

func _ready():
	as_entity = Entity.new(self, agent_name, game_manager.get_location(global_position), "is idle", null)
	info_label.visible = false
	cause_of_kill="Choked"
	
	
	#kill cooldown at the beginning
	#kill_enabled=false
	#await get_tree().create_timer(20).timeout
	#kill_enabled=true

func _physics_process(_delta):
	if is_in_meeting:
		return

	var directions = ["up", "right", "down", "left"]
	if velocity != Vector2.ZERO:
		animated_sprite_2d.animation = "run "+directions[round(velocity.angle()/(PI/2))+1]
		previous_velocity = velocity
	else:
		animated_sprite_2d.animation = "idle "+directions[round(previous_velocity.angle()/(PI/2))+1]
	
	as_entity.set_location(game_manager.get_location(global_position))
	
	if game_manager.is_UI_active():
		return
	
	var acceleration : Vector2 = Vector2.ZERO
	if Input.is_action_pressed("Move_left"):
		acceleration.x -=1
	if Input.is_action_pressed("Move_right"):
		acceleration.x +=1
	if Input.is_action_pressed("Move_up"):
		acceleration.y -=1
	if Input.is_action_pressed("Move_down"):
		acceleration.y +=1
	
	# If the player hasn't pressed any movement buttons, slow down to a halt
	if acceleration == Vector2.ZERO:
		velocity *= damping_factor
		
		if velocity.length() < 5:
			velocity = Vector2.ZERO
	# If the player has pressed some movement buttons, apply the acceleration and limit the velocity
	else:
		acceleration *= 10
		velocity += acceleration
		velocity = velocity.limit_length(200)
	move_and_slide()
	
	var nearby_entities = interaction_zone.get_overlapping_bodies()
	for i in range(len(nearby_entities)-1,-1,-1):
		var current_entity : Node2D = nearby_entities[i]
		if !current_entity.is_in_group("Entity") || current_entity.is_in_group("Player"):
			nearby_entities.erase(current_entity)
			
		if current_entity.is_in_group("Agent"):
			if !current_entity.can_be_interacted_wtih():
				nearby_entities.erase(current_entity)
	closest_entity = null
	var min_distance = INF # Start with infinity, which will be larger than any other distance
	for entity in nearby_entities:
		var distance = global_position.distance_to(entity.global_position)
		if distance < min_distance:
			min_distance = distance
			closest_entity = entity
	
	
	var target_alpha : float = 0
	if closest_entity != null:
		target_alpha = 1
		
		popup_ui_label.text = "I"
		if closest_entity.is_in_group("Agent"):
			popup_ui_label.text += " , K"
		
		var direction_to_entity = closest_entity.global_position - global_position
		direction_to_entity = direction_to_entity.limit_length(115)
		popup_ui_label.position = direction_to_entity - popup_ui_label.size/2
	popup_alpha = lerpf(popup_alpha, target_alpha, 0.2)
	popup_ui_label.label_settings.font_color.a = popup_alpha

func _input(_event):
	if game_manager.is_UI_active() or is_in_meeting:
		return
		
	if Input.is_key_pressed(KEY_I) and closest_entity != null:
		if closest_entity.is_in_group("Agent"):
			if !closest_entity.can_be_interacted_wtih():
				return
			game_manager.enter_new_dialogue(closest_entity)
			as_entity.set_action("talking with "+closest_entity.as_entity.entity_name)
			as_entity.set_interactable(closest_entity.as_entity)
			closest_entity.receive_dialogue("")
		elif closest_entity.is_in_group("Item"):
			game_manager.setup_item_panel(closest_entity)
			as_entity.set_action("interacting with "+closest_entity.as_entity.entity_name)
			as_entity.set_interactable(closest_entity.as_entity)
			closest_entity.as_entity.set_interactable(as_entity)
	if Input.is_key_pressed(KEY_K) && closest_entity != null &&kill_enabled:
		if closest_entity.is_in_group("Agent"):
			closest_entity.kill_agent(cause_of_kill)
			as_entity.set_action(cause_of_kill+" someone")
			
			#kill cooldown here:
			#kill_enabled=false
			#await get_tree().create_timer(10).timeout
			#kill_enabled=true
			
			create_tween().tween_callback(reset_action).set_delay(1)
			
			var num_alive : int = 0
			for agent in game_manager.agents_root.get_children():
				if agent.is_alive:
					num_alive += 1
			if num_alive == 1:
				game_manager.win_game()


func reset_action():
	as_entity.set_action("is idle")

func collect(item):
	inv.insert(item)

func enter_meeting_mode(given_seat: Node2D) -> void:
	is_in_meeting = true
	global_position = given_seat.global_position
	popup_ui_label.label_settings.font_color.a = 0
	
	if given_seat.position.x > 0:
		animated_sprite_2d.animation = "sit left"
	else:
		animated_sprite_2d.animation = "sit right"
	animated_sprite_2d.frame = randi_range(0,6)
	
	camera.global_position = given_seat.get_parent().global_position
	camera.zoom = Vector2(3,3)

func exit_meeting_mode(meeting_table:Node2D):
	z_index = 6
	global_position += (global_position-meeting_table.global_position)*0.8
	velocity = Vector2.ZERO
	is_in_meeting = false
	velocity = Vector2.ZERO
	camera.global_position = global_position
	camera.zoom = Vector2(1,1)
 
func set_info_text(new_text:String) -> void:
	info_label.visible = true
	info_label.text = new_text
