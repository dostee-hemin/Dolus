extends CanvasLayer

@onready var game_manager : Node = get_node("/root/Game/GameManager")

@onready var body_found : Panel = $"Body Found"
@onready var voting_title : Label = $"Voting Title"
@onready var voting_container : ScrollContainer = $"Voting Title/Voting Container"
@onready var v_box_container : VBoxContainer = $"Voting Title/Voting Container/VBoxContainer"
@onready var vote_button = preload("res://Secondary_Scenes/Vote_Button.tscn")
@onready var voting_results : Label = $"Voting Results"
@onready var chat_box : TextEdit = $"Chat Box"


func start_meeting(dead_body):
	visible = true
	voting_title.visible = false
	voting_results.visible = false
	
	body_found.visible=true
	body_found.get_child(0).texture = dead_body.animated_sprite_2d.sprite_frames.get_frame_texture("dead left",0)
	await get_tree().create_timer(3).timeout
	body_found.visible=false
	chat_box.visible=true
	await get_tree().create_timer(60).timeout
	chat_box.visible=false
	
	game_manager.setup_voting_process()
	
	voting_title.visible = true
	voting_container.mouse_filter = Control.MOUSE_FILTER_PASS
	v_box_container.mouse_filter = Control.MOUSE_FILTER_PASS
	for character in game_manager.alive_characters:
		if character.is_in_group("Player"):
			continue
		
		var new_vote_button : Button = vote_button.instantiate()
		var icon_image = character.icon.get_image()
		var new_size = icon_image.get_size()*6
		@warning_ignore("int_as_enum_without_cast")
		icon_image.resize(new_size.x,new_size.y,0)
		new_vote_button.icon = ImageTexture.create_from_image(icon_image)
		new_vote_button.pressed.connect(_disable_other_buttons.bind(new_vote_button, v_box_container))
		v_box_container.add_child(new_vote_button)
		
	await get_tree().create_timer(10).timeout
	
	voting_container.visible = false
	voting_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v_box_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var selected_index : int = -1
	var i : int = 0
	for agent_button in v_box_container.get_children():
		if agent_button.button_pressed:
			selected_index = i
			
		i+=1
	for agent_button in v_box_container.get_children():
		agent_button.queue_free()

	if selected_index == -1:
		game_manager.add_vote("[Skip]")
	else:
		game_manager.add_vote(game_manager.alive_characters[selected_index].agent_name)
	
	var record_score : int = 0
	var winning_vote : String = ""
	var is_unique : bool
	for vote in game_manager.voting_results.keys():
		var score = game_manager.voting_results[vote]
		if score > record_score:
			record_score = score
			is_unique = true
			winning_vote = vote
		elif score == record_score:
			is_unique = false
	
	voting_results.visible = true
	voting_title.visible = false
	if !is_unique or winning_vote == "[Skip]":
		voting_results.text = "No one has been\neliminated."
		winning_vote = "[Skip]"
	else:
		voting_results.text = winning_vote+" has been arrested\nfor investigation!"
	await get_tree().create_timer(5).timeout

	visible=false
	game_manager.end_meeting_dialogue(winning_vote)
	
func _disable_other_buttons(current, buttons_root):
	for button in buttons_root.get_children():		
		button.button_pressed = false
	current.button_pressed = true

func _on_text_edit_text_changed():
	if "\n" in chat_box.text:
		game_manager.add_group_message(chat_box.text)
		chat_box.clear()
