extends Game_Manager

@onready var layout = get_node("/root/Game/Layout")

@onready var player = get_node("/root/Game/Player")
@onready var agents_root = get_node("/root/Game/Agents")
@onready var agent_scene = preload("res://Secondary_Scenes/Agent.tscn")
var alive_characters : Array[Node]
var all_speech_bubbles : Array

@onready var dialogue_panel = get_node("/root/Game/UI/Dialogue Panel")
var current_agent

@onready var item_panel = get_node("/root/Game/UI/Item Panel")
var current_item

@onready var inv_ui = get_node("/root/Game/UI/inv_ui")

@onready var meeting_dialogue = $"../UI/Meeting_dialogue"
@onready var meeting_table = $"../Meeting Table"
var speech_bubble = preload("res://Secondary_Scenes/Speech_Bubble.tscn")

var in_game_time

var month_conversions = {
	1: "January",
	2: "February",
	3: "March",
	4: "April",
	5: "May",
	6: "June",
	7: "July",
	8: "August",
	9: "September",
	10: "October",
	11: "November",
	12: "December",
}

var weekday_conversions = {
	0: "Sunday",
	1: "Monday",
	2: "Tuesday",
	3: "Wednesday",
	4: "Thursday",
	5: "Friday",
	6: "Saturday",
}

func _ready():
	in_game_time = Time.get_unix_time_from_datetime_string("2024-03-11T08:45:00")
	dialogue_panel.visible = false
	item_panel.visible = false
	meeting_dialogue.visible=false
	meeting_table.visible = false
	
	# Create all the agents using the information generated in the setup scene
	for info in DataTransfer.agent_infos:
		var new_agent = agent_scene.instantiate()
		agents_root.add_child(new_agent)
		
		var all_standing_zones : Array = get_all_standing_zones()
		var chosen_location = all_standing_zones.pick_random()
		
		new_agent.setup_intial_values(info, chosen_location.global_position)
	
	# Create the player using the information generated in the setup scene
	player.agent_name = DataTransfer.player_info.name
	player.animation_texture = DataTransfer.player_info.texture

func _update_time():
	super._update_time()
	in_game_time += 60

func _prepare_stats_string() -> String:
	return "Time: "+get_current_datetime_string()+"\n"+super._prepare_stats_string()

func get_location(point: Vector2) -> String:
	var result_path = ""
	
	var current_node = layout
	while current_node.get_child_count() != 0:
		var does_intersect : bool = false
		for node in current_node.get_children():
			if node is Area2D:
				var collision_shape = node.get_node("CollisionShape2D")
				if collision_shape:
					var rect : Rect2 = collision_shape.get_shape().get_rect()
					if rect.has_point(point-collision_shape.global_position):
						# If the point is inside the current Area2D, add it to the path
						var node_name = node.get_name()
						if result_path != "":
							result_path += ":"
						result_path += node_name
						does_intersect = true
						current_node = node
						break
		if !does_intersect:
			break
	
	return result_path

func get_sub_locations(parent_node: Node = layout) -> Array:
	if parent_node == layout:
		return layout.get_children()
		
	var sub_locations = parent_node.get_children()
	
	for i in range(len(sub_locations)-1,-1,-1):
		var node = sub_locations[i]
		if !(node is Area2D) and !(node is StaticBody2D):
			sub_locations.erase(node)
	
	return sub_locations

func get_all_standing_zones() -> Array:
	var all_paths = []
	_add_standing_zones_to_list(all_paths, layout)
	return all_paths

func _add_standing_zones_to_list(list: Array, current_node: Node):
	var new_area_found : bool = false
	for node in current_node.get_children():
		if node is Area2D:
			_add_standing_zones_to_list(list, node)
			new_area_found = true
	
	if !new_area_found and "Standing Zone" in current_node.get_name():
		list.append(current_node)
		return

func get_all_locations() -> Array:
	var all_paths = []
	_add_location_path_to_list(all_paths, layout, "")
	return all_paths

func _add_location_path_to_list(list: Array, current_node: Node, current_path: String):
	if current_node is Area2D and "Standing Zone" not in current_node.get_name():
		if current_path != "":
			current_path += ":"
		current_path += current_node.get_name()
		
	var new_area_found : bool = false
	for node in current_node.get_children():
		if node is Area2D:
			_add_location_path_to_list(list, node, current_path)
			new_area_found = true
	
	if !new_area_found and current_path not in list:
		list.append(current_path)
		return

func get_current_date_string() -> String:
	var datetime = Time.get_datetime_dict_from_unix_time(in_game_time)
	var result = weekday_conversions[datetime.weekday] + ", "
	result += month_conversions[datetime.month] + " " + str(datetime.day)
	return result

func get_current_time_string() -> String:
	return Time.get_time_string_from_unix_time(in_game_time)

func get_current_datetime_string():
	return get_current_date_string()+", "+get_current_time_string()

func enter_new_dialogue(agent):
	current_agent = agent
	current_agent.dialogue_setup(player)
	player.velocity = Vector2.ZERO
	dialogue_panel.visible = true
	inv_ui.visible=false
	dialogue_panel.initialize_with_agent(agent)

func set_dialogue_text(new_text):
	dialogue_panel.on_agent_talk(new_text)

func send_dialogue_text(new_text):
	current_agent.receive_dialogue(new_text)

func exit_dialogue ():
	if current_agent == null:
		return
		
	current_agent.end_dialogue()
	current_agent = null
	dialogue_panel.visible = false
	player.as_entity.set_action("is idle")

func disable_all_UI():
	close_item_panel()
	exit_dialogue()
	for agent in agents_root.get_children():
		agent.conversation_panel.visible = false
	inv_ui.visible = false

func is_UI_active():
	return dialogue_panel.visible or item_panel.visible or meeting_dialogue.visible

func setup_item_panel(item):
	current_item = item
	item_panel.initialize_with_item(item)

func close_item_panel():
	if current_item == null:
		return
	current_item.as_entity.set_interactable(null)
	current_item = null
	player.as_entity.set_action("is idle")

func set_item_action(action):
	current_item.as_entity.set_action(action)

func get_item_action(item):
	return item.as_entity.action

func set_item_action_from_nodes(item,action):
	item.as_entity.set_action(action)

func setup_meeting_dialogue(initiater:CharacterBody2D, dead_body):
	disable_all_UI()
	meeting_dialogue.start_meeting(dead_body)
	all_speech_bubbles.clear()
	
	# Get a list of the agents that are still alive
	alive_characters.clear()
	alive_characters = agents_root.get_children()
	for i in range(alive_characters.size()-1,-1,-1):
		var agent = alive_characters[i]
		if !agent.is_alive:
			alive_characters.erase(agent)
	# Add the player to the list of alive characters
	alive_characters.append(player)
	
	# Get a list of the available seets at the meeting table
	var available_seats : Array[Node] = meeting_table.get_children()
	var extreme_values : Dictionary = {"min_y":1.79769e308, "max_y":-1.79769e308}
	for i in range(available_seats.size()-1,-1,-1):
		var seat = available_seats[i]
		
		if seat is Label:
			available_seats.erase(seat)
			continue
		
		extreme_values.min_y = min(extreme_values.min_y, seat.global_position.y)
		extreme_values.max_y = max(extreme_values.max_y, seat.global_position.y)
	
	# Randomly put all the alive characters into seats
	for character in alive_characters:
		var random_seat = available_seats.pick_random()	
		character.enter_meeting_mode(random_seat)
		character.z_index = int(_map(character.global_position.y, extreme_values.min_y, extreme_values.max_y, 5,6))
		available_seats.erase(random_seat)
	
	await initiater.initiate_group_discussion()

var voting_results : Dictionary

func voting_subroutine(agent:Node)->void:
	var vote : String = await agent.perform_voting()
	add_vote(vote)

func add_vote(vote_name:String):
	if meeting_dialogue.visible == false:
		return
	# Add the new vote to the existing tally of votes
	if voting_results.has(vote_name):
		voting_results[vote_name] += 1
	else:
		voting_results[vote_name] = 1
	
	if vote_name == "[Skip]":
		meeting_table.get_child(0).text = str(voting_results[vote_name])+" Skips"
	
	for result in voting_results.keys():
		for character in alive_characters:
			if result == character.agent_name:
				character.set_info_text(str(voting_results[result]))
				break

func setup_voting_process():
	voting_results.clear()
	meeting_table.visible = true
	meeting_table.get_child(0).text = "0 Skips"
	for character in alive_characters:
		character.set_info_text("0")
		
		if character.global_position.x < meeting_table.global_position.x:
			character.info_label.position.x = 40
		else:
			character.info_label.position.x = -60
		character.info_label.position.y = -10
		
		if character.is_in_group("Player"):
			continue
		
		voting_subroutine(character)
	
	# Close all speech bubbles
	for speech_bubble in all_speech_bubbles:
		if speech_bubble == null:
			continue
		speech_bubble.close_bubble()

func end_meeting_dialogue(final_vote:String) -> void:
	if final_vote == player.as_entity.entity_name:
		lose_game()

	var num_alive : int = 0
	for i in range(agents_root.get_child_count()-1,-1,-1):
		var agent = agents_root.get_child(i)
		
		if !agent.is_alive or agent.agent_name == final_vote:
			agent.queue_free()
		else:
			num_alive += 1
	if num_alive == 1:
		win_game()
	
	meeting_table.visible = false
	for character in alive_characters:
		character.info_label.visible = false
		character.info_label.position.x = 0
		character.info_label.position.y = -21
		character.exit_meeting_mode(meeting_table)

func add_group_message(new_message:String, speaker:Node2D=player):
	if !voting_results.is_empty():
		return

	_add_speech_bubble(new_message, speaker)
	
	for agent in agents_root.get_children():
		if !agent.is_alive or agent == speaker:
			continue
		
		agent.receive_group_discussion(new_message, speaker)

func _add_speech_bubble(speech_text:String, speaker:Node2D):
	var new_bubble = speech_bubble.instantiate()
	speaker.add_child(new_bubble)
	all_speech_bubbles.append(new_bubble)
	
	new_bubble.set_text(speech_text)
	var is_left : bool = speaker.global_position.x<meeting_table.global_position.x
	var is_up : bool = speaker.global_position.y>meeting_table.global_position.y
	new_bubble.set_direction(is_left, is_up)

func _map(value, in_min, in_max, out_min, out_max):
	if in_min == in_max:
		return out_max
	return (value - in_min) * (out_max - out_min) / (in_max - in_min) + out_min

func win_game():
	get_tree().change_scene_to_file("res://Main_Scenes/winning_scene.tscn")

func lose_game():
	get_tree().change_scene_to_file("res://Main_Scenes/losing_scene.tscn")
