extends CharacterBody2D

var game_manager : Node
var concurrency_handler : ConcurrencyHandler
var collision_shape_2D : CollisionShape2D
var info_label : Label

var icon : Texture
var animation_texture : Texture
var animated_sprite_2d

var agent_name : String
var age : int
var gender : String
var traits : String

var recency_weight : float = 1
var importance_weight : float = 0.5
var relevance_weight : float = 1

var navigation_agent_2d
var interaction_zone
var acceleration=7
var speed=150
var destination:Node
var previous_destination:Node
var facing_direction : Vector2 = Vector2.DOWN

var agent_summary : String
var memories : Array[Memory]
var new_observations : Array[Entity]
var dialogue_history : Array[Dictionary]
var dialogue_partner : Node2D
var dialogue_context : String

var as_entity : Entity

var can_trigger : bool = false
var time_since_last_trigger : int
var trigger_duration : int = 10 # in seconds

# These variables are used for the relfection process
var recent_importance_threshold : int = 150
var oldest_memory_index : int = 0
var is_reflecting : bool = false
var num_reflection_questions : int = 3
var num_insights_per_reflection_question : int = 3

var is_alive : bool = true
var is_in_meeting : bool
var has_received_discussion : bool

var conversation_panel


func _initialize_children():
	game_manager = get_node("/root/Game/GameManager")
	animated_sprite_2d = $AnimatedSprite2D
	navigation_agent_2d = $NavigationAgent2D
	interaction_zone = $"Interaction Zone"
	conversation_panel = $"Conversation Panel"
	collision_shape_2D = $"CollisionShape2D"
	info_label = $"Info Label"

func setup_intial_values(info, starting_location):
	_initialize_children()
	
	global_position = starting_location
	agent_name = info.name
	gender = info.gender
	animation_texture = info.texture
	age = info.age
	traits = info.traits
	
	concurrency_handler = ConcurrencyHandler.new()
	
	as_entity = Entity.new(self, agent_name, game_manager.get_location(global_position), "is planning out the day", null)
	game_manager.can_record = true
	conversation_panel.visible = false
	info_label.text = ""
	info_label.visible = false

	for content in info.history.split(";"):
		_add_memory(content.strip_edges(), true)
	
	await concurrency_handler.wait_for_responses(info.history.split(";").size())
	
	await _generate_agent_summary()
	await _generate_plan(0)
	as_entity.set_action("is idle")
	
	can_trigger = true

func _physics_process(delta):
	if !is_alive or is_in_meeting:
		return
	
	_navigate(delta)
	
	as_entity.set_location(game_manager.get_location(global_position))
	_interact_with_nearby_entities()	
	if Engine.get_physics_frames() % 5 == 0:
		_observe()
	_check_reflection()
	_check_trigger()
	
	if !is_alive or is_in_meeting:
		return
	
	_animate()

func _check_reflection():
	if !memories.is_empty() && !is_reflecting:
		var total_recent_importance = 0
		for i in range(oldest_memory_index, memories.size()):
			total_recent_importance += memories[i].importance
		
		if total_recent_importance >= recent_importance_threshold:
			_reflect()

func _check_trigger():
	var current_time = Time.get_unix_time_from_system()
	if can_trigger && (current_time-time_since_last_trigger) >= trigger_duration:
		_trigger_brain()

func _navigate(delta):
	if destination != null:
		var direction=Vector3()
		navigation_agent_2d.target_position=destination.global_position
		direction=navigation_agent_2d.get_next_path_position()-global_position
		direction=direction.normalized()
		
		var intended_velocity=velocity.lerp(direction*speed,acceleration*delta)
		navigation_agent_2d.set_velocity(intended_velocity)
		
		move_and_slide()
	else:
		# At this part of the program, the agent is idle, so face a random direction every now and then
		if randf() < 0.001:
			facing_direction = Vector2.from_angle(randi_range(0,3)*PI/2)

func _animate():
	var directions = ["up", "right", "down", "left"]
	if velocity != Vector2.ZERO and velocity != null:
		animated_sprite_2d.animation = "run "+directions[round(velocity.angle()/(PI/2))+1]
		facing_direction = velocity
	else:
		animated_sprite_2d.animation = "idle "+directions[round(facing_direction.angle()/(PI/2))+1]

func kill_agent(method_of_killing):
	as_entity.set_action("lying dead on the floor, unattended and in need of attention, killed by being choked")
	_end_navigation()
	is_alive = false
	if facing_direction.x < 0:
		animated_sprite_2d.animation = "dead right"
	else:
		animated_sprite_2d.animation = "dead left"
	#player.kill_enabled=false
	#await get_tree().create_timer(10).timeout
	#player.kill_enabled=true

func _set_destination(chosen_node):
	if chosen_node == null:
		return
	previous_destination = destination
	destination = chosen_node

func can_be_interacted_wtih() -> bool:
	return is_alive and dialogue_partner == null

func _end_navigation():
	destination = null
	navigation_agent_2d.set_velocity(Vector2.ZERO)
	navigation_agent_2d.target_position = global_position

func _generate_memory_summary(queries: Array[String]) -> String:
	var retrieved_memories : Array[Memory] = await _retrieve_memories(queries)
	var summary_prompt = "Answer the follwing queries ("
	for query in queries:
		summary_prompt += query+" , "
	summary_prompt += ") using the following statements (sorted from most relevant to least relevant) with as much detail as necessary:\n"
	
	if retrieved_memories.size() == 0:
		return ""
	
	var current_token_count = 0
	var existing_strings : Array[String] = []
	for memory in retrieved_memories:
		if memory.content in existing_strings:
			continue
			
		if current_token_count + memory.token_count < 2040:
			existing_strings.append(memory.content)
			summary_prompt += "- "+memory.content+"\n"
			current_token_count += memory.token_count
		else:
			break
	
	summary_prompt += "Address each query directly and ignore everything else, don't make inferences, assumptions, or hallucinations."
	return await game_manager.chat_request(summary_prompt, 0, 600)

func _generate_agent_summary():
	agent_summary = "Name: " + agent_name + " (gender: "+gender+" | age:" + str(age) + ")\n"
	agent_summary += "Innate traits: " + traits + "\n"
	
	
	var queries : Array[String] = []
	queries.append(agent_name + "'s core characteristics")
	queries.append(agent_name + "'s current daily occupation")
	queries.append(agent_name + "'s feelings about his/her recent progress in life")
	agent_summary += await _generate_memory_summary(queries)
	print(agent_summary)

func _generate_plan(starting_level_of_detail:int = 2):
	var start_time = game_manager.get_current_time_string()
	
	var levels_of_detail : Array[String] = ["multi-hour", "hourly", "5-15 minute"]
	var current_plan = ""
	for level in range(starting_level_of_detail,levels_of_detail.size()):
		var detail = levels_of_detail[level]
		var plan_prompt = agent_summary
		
		plan_prompt += "\nToday is "+game_manager.get_current_datetime_string()+". Here is "+agent_name+"'s current plan for the day:\n"
		if current_plan == "":
			plan_prompt = await _generate_memory_summary(["What is "+agent_name+"'s plan for "+game_manager.get_current_date_string()+" in broad strokes"])
		else:
			plan_prompt += current_plan
		
		plan_prompt += "\nHere are all the places "+agent_name+" is aware of:\n"
		var locations = game_manager.get_all_locations()
		for location in locations:
			plan_prompt += "-"+location+"\n"
		
		plan_prompt += agent_name+" wants to do the following task: "+as_entity.action+".\n"
		plan_prompt += "Update the plan for "+agent_name+" starting from "+start_time+" by breaking down each entry into "+detail+" long tasks (might be completed in only 1 task if necessary).\n"
		plan_prompt += "The format of each entry in the plan should be as follows: Plan made at "+start_time+" for "+game_manager.get_current_date_string()+", for [chosen duration in mins] from [starting time of task in 24hr HH:MM format], at [chosen location], [plan entry in one sentence].\n"
		plan_prompt += "Respond only with the entries of the plan with each on a new line. You can only use the locations listed and nothing else"
		current_plan = await game_manager.chat_request(plan_prompt)

	var all_tasks = current_plan.split("\n")
	for task in all_tasks:
		_add_memory(task)

func _print_all_memories():
	for memory in memories:
		_print_memory(memory)

func _print_memory(memory):
	print("Memory <" + memory.content + ">:")
	print("- Time Created: ", memory.time_created)
	print("- Time Last Accessed: ", memory.time_last_accessed)
	print("- Importance: ", memory.importance)
	print("- Embeddings: ", memory.embedding.slice(0,5))
	print()

func _add_memory(content, is_concurrent=false):
	var time = game_manager.in_game_time

	var memory = await Memory.new(time, content, game_manager)
	
	if is_concurrent:
		memory.completed.connect(concurrency_handler.response_complete)
	memories.append(memory)

func _get_embedding_from_query(query):
	concurrency_handler.response_complete(await game_manager.embedding_request(query))

func _retrieve_memories(queries:Array[String], num_top_memories=memories.size()) -> Array[Memory]:
	var query_embeddings  = []
	for query in queries:
		_get_embedding_from_query(query)
	await concurrency_handler.wait_for_responses(queries.size())
	query_embeddings.append_array(concurrency_handler.pop_responses())
	
	var current_time = game_manager.in_game_time
	var memory_scores : Array[Dictionary] = []
	var scaling_values = {"min_recency": 1, "max_recency": 0,
						  "min_importance": 1, "max_importance": 0,
						  "min_relevance": 1, "max_relevance": 0}
	for memory in memories:
		var time_difference = float(current_time - memory.time_last_accessed) / 3600
		var recency = 1.0 / exp(0.995 * time_difference)
		var importance = memory.importance
		var record_relevance = 0
		for query_embedding in query_embeddings:
			if query_embedding.size() == memory.embedding.size():
				var relevance = _calculate_cosine_similarity(query_embedding, memory.embedding)
				record_relevance = max(record_relevance, relevance)
		
		if record_relevance < 0.3:
			continue
			
		scaling_values.min_recency = min(scaling_values.min_recency, recency)
		scaling_values.min_importance = min(scaling_values.min_importance, importance)
		scaling_values.min_relevance = min(scaling_values.min_relevance, record_relevance)
		scaling_values.max_recency = max(scaling_values.max_recency, recency)
		scaling_values.max_importance = max(scaling_values.max_importance, importance)
		scaling_values.max_relevance = max(scaling_values.max_relevance, record_relevance)
		
		var score = {"memory": memory, "final_score": 0, "recency": recency, "importance": importance, "relevance": record_relevance}		
		memory_scores.append(score)
		memory.time_last_accessed = current_time

	for score_data in memory_scores:
		var recency_mapped = _map(score_data.recency, scaling_values.min_recency, scaling_values.max_recency, 0, 1)
		var importance_mapped = _map(score_data.importance, scaling_values.min_importance, scaling_values.max_importance, 0, 1)
		var relevance_mapped = _map(score_data.relevance, scaling_values.min_relevance, scaling_values.max_relevance, 0, 1)
		
		score_data.final_score = recency_mapped * recency_weight + importance_mapped * importance_weight + relevance_mapped * relevance_weight

	memory_scores.sort_custom(func(a, b): return a.final_score > b.final_score)
	var result : Array[Memory] = []
	#print(queries,"---------------\n")
	for i in min(num_top_memories,memory_scores.size()):
		var score_data = memory_scores[i]
		#print("T: ",memory_scores[i].final_score,", Rc: ",memory_scores[i].recency,", Im: ",memory_scores[i].importance,", Rl: ",memory_scores[i].relevance,", M: ",memory_scores[i].memory.content)
		result.append(score_data.memory)
	return result

func _map(value, in_min, in_max, out_min, out_max):
	if in_min == in_max:
		return out_max
	return (value - in_min) * (out_max - out_min) / (in_max - in_min) + out_min

func _calculate_cosine_similarity(vector1, vector2):
	var dot_product = 0.0
	var magnitude_vector1_squared = 0.0
	var magnitude_vector2_squared = 0.0
	
	for i in vector1.size():
		var v1 = vector1[i]
		var v2 = vector2[i]
		dot_product += v1 * v2
		magnitude_vector1_squared += v1 * v1
		magnitude_vector2_squared += v2 * v2

	# Avoid division by zero
	if magnitude_vector1_squared == 0.0 or magnitude_vector2_squared == 0.0:
		return 0
	
	return dot_product / (magnitude_vector1_squared * magnitude_vector2_squared)

func _trigger_brain():
	can_trigger = false
	@warning_ignore("narrowing_conversion")
	time_since_last_trigger = Time.get_unix_time_from_system()
	
	if dialogue_partner != null or !is_alive:
		return
	
	var reaction = await _react()
	
	if dialogue_partner != null or !is_alive:
		return
		
	var reaction_parts = reaction.split("|")
	
	if reaction_parts.size() != 2:
		print("Reaction failed: ", reaction)
		return
	
	# Pick a destination, reset the interactable, and set the action
	var new_action : String = reaction_parts[1].strip_edges()
	if ";interact" in reaction_parts[1]:
		var new_action_parts = new_action.split(";")
		new_action = new_action_parts[0].strip_edges()
		var interactable_name : String = new_action_parts[1].replace("interact with ","")
		
		for observation in new_observations:
			if observation.entity_name == interactable_name:
				_set_destination(observation.as_node)
				break
	else:
		await _pick_location()	
	
	if !is_alive:
		return
	
	as_entity.set_interactable(null)
	as_entity.set_action(new_action)

	new_observations.clear()
	if reaction_parts[0] == "Update":
		await _generate_plan()
	can_trigger = true

func _observe():
	# Scan nearby entity nodes
	var space_state = get_world_2d().direct_space_state
	var ray_length = 1000
	var angle = facing_direction.angle() - PI/3
	while angle < facing_direction.angle() + PI/3:
		var direction = Vector2(cos(angle), sin(angle))
		angle += 0.1
		direction *= ray_length
		
		var query = PhysicsRayQueryParameters2D.create(global_position, global_position+direction)
		query.exclude = [self]
		query.collision_mask = 3
		var result = space_state.intersect_ray(query)
		
		# If we haven't detected anything with this ray, move onto the next one
		if result.is_empty():
			continue
		
		# If the current ray didn't hit an entity, move onto the next ray
		if !result.collider.is_in_group("Entity"):
			continue
		
		var new_entity : Entity = result.collider.as_entity
		var entity_node : Node = result.collider
		
		# If someone was already interacting with the destination item, find a similar item to interact with
		if entity_node == destination and new_entity.interactable != null and new_entity.interactable != as_entity:
			if entity_node.is_in_group("Agent"):
				if entity_node.is_alive:
					_end_navigation()
			else:
				_end_navigation()
			
			# The name of the target item without the number
			var destination_name : String = " ".join(entity_node.get_name().split(" ").slice(0, -1))
			
			# All the items in the target room
			var sibling_nodes : Array = game_manager.get_sub_locations(entity_node.get_parent())
			for node in sibling_nodes:
				# If the current node is not one of the other items in the room, leave
				if node == entity_node or !node.is_in_group("Item"):
					continue
				
				# If the current item is interacting with somebody
				if node.as_entity.interactable != null:
					continue
				
				# If the names of the node and the destination match, set it as the new destination
				var node_name = " ".join(node.get_name().split(" ").slice(0, -1))
				if node_name == destination_name:
					_set_destination(node)
					break
		
		var already_exists : bool = false
		for existing_observation in new_observations:
			if new_entity.matches(existing_observation):
				already_exists = true
				break
		
		# If this is not a new observation, move onto the next ray
		if already_exists:
			continue
			
		# Add the new observation to the list
		new_observations.append(new_entity.copy())
		_add_memory(new_entity.description)

func _react():
	var reaction_prompt = agent_summary + "\n"
	reaction_prompt += "It is "+game_manager.get_current_datetime_string()+"\n"
	reaction_prompt += as_entity.description + "\n"
	reaction_prompt += await _generate_memory_summary(["Considering the plans made close to "+game_manager.get_current_datetime_string()+", what does "+agent_name+" plan to do next?"])
	
	reaction_prompt += "\nObservations of nearby entities (sorted from newest to oldest): \n"
	var current_token_count = 0
	for i in range(new_observations.size()-1,-1,-1):
		var description_token_count : int = game_manager.get_token_count(new_observations[i].description)
		if current_token_count + description_token_count < 2040:
			reaction_prompt += "- "+new_observations[i].description+"\n"
			current_token_count += description_token_count
		else:
			break
	
	# There could be multiple observations of the same entity, so generate summaries only for unique entities, not each observation
	var unique_new_nodes : Array[Node] = []
	for entity in new_observations:
		if entity.as_node == null:
			continue
		if !(entity.as_node in unique_new_nodes):
			unique_new_nodes.append(entity.as_node)
	
	var queries : Array[String] = []
	for node in unique_new_nodes:
		queries.append("What does "+agent_name+" know about "+node.as_entity.entity_name+"?")
	var response_string = await _generate_memory_summary(queries)
	
	if response_string.strip_edges() == "":
		reaction_prompt += agent_name+" has no relevant memories about the given observations.\n"
	else:
		reaction_prompt += "Summary of relevant context about each observation: \n"+response_string

	reaction_prompt += "\nShould "+agent_name+" react to any of these observations or continue with their current plan, and if so, what would be an appropriate reaction?\n"
	reaction_prompt += "Respond only in the following format: [Continue/Update]|[action to take in the present continuous tense]\n"
	reaction_prompt += "If the reaction involves interacting with one of the previously mentioned entities, make sure to add \";interact with [entity name]\" to the end of the action\n"
	reaction_prompt += "Examples of responses:\n"
	reaction_prompt += "Update|is going for a walk\n"
	reaction_prompt += "Continue|is making breakfast\n"
	reaction_prompt += "Update|is asking John for help with his injury;interact with John\n"
	reaction_prompt += "Update|is asking Eddy about his music composition;interact with Eddy\n"
	reaction_prompt += "Update|is turning off Oven 1;interact with Oven 1\n"
	reaction_prompt += "Continue|is writing a journal on Desk;interact with Desk"
	
	var reaction = await game_manager.chat_request(reaction_prompt, 0, 40)
	
	return reaction

func _pick_location():
	var chosen_node : Node = null
	
	var available_locations: Array = game_manager.get_sub_locations()
	while !available_locations.is_empty():
		var location_prompt = agent_summary + "\n"
		location_prompt += agent_name+" is located at "+as_entity.location+"\n"
		
		location_prompt += agent_name+" knows of the following locations:\n"
		for i in available_locations.size():
			location_prompt += str(i+1)+") "+available_locations[i].get_name()+"\n"
		location_prompt += agent_name+" wants to do the following: "+as_entity.action+".\n"
		location_prompt += "Which area should "+agent_name+" go to? Respond only with the index of the given locations, nothing else. For example:\n1\n5\n3"
	
		var chosen_index = int(await game_manager.chat_request(location_prompt, 0, 2))-1
		if chosen_index >= available_locations.size():
			break
			
		chosen_node = available_locations[chosen_index]
		available_locations = game_manager.get_sub_locations(chosen_node)
	
	if chosen_node == null || chosen_node == previous_destination:
		return
	_set_destination(chosen_node)	

func _reflect():
	is_reflecting = true
	var questions_prompt : String = "Consider the following memories:\n"
	
	var current_token_count : int = 0
	for i in range(memories.size()-1, oldest_memory_index, -1):
		var memory : Memory = memories[i]
		if current_token_count + memory.token_count < 2040:
			questions_prompt += "- "+memory.content+"\n"
			current_token_count += memory.token_count
	
	questions_prompt += "Given only the information above, what are "+str(num_reflection_questions)+" most salient highlevel questions we can ask about the subjects in the statements. "
	questions_prompt += "Respond with only the questions, each on a new line starting with a dash (-) and then the question itself"
	
	var questions = (await game_manager.chat_request(questions_prompt, 0, 150)).split("\n")
	for question in questions:
		if question.strip_edges() == "":
			continue
		_reflection_coroutine(question)
	
	await concurrency_handler.wait_for_responses(num_reflection_questions * num_insights_per_reflection_question)
	
	oldest_memory_index = memories.size()
	is_reflecting = false

func _reflection_coroutine(question):
	var relevant_memories = await _retrieve_memories([question], 10)
	
	var insights_prompt = "Statements about "+agent_name+"\n"
	for memory in relevant_memories:
		insights_prompt += "- "+memory.content+"\n"
	insights_prompt += "What are "+str(num_insights_per_reflection_question)+" high level insights you can infer from the above statements? "
	insights_prompt += "Respond only with the insights, each on a new line starting with a dash (-) and then the insight itself"

	var insights = (await game_manager.chat_request(insights_prompt, 0, 150)).split("\n")
	for insight in insights:
		if insight.strip_edges() == "":
			continue
		_add_memory(insight)
		concurrency_handler.response_complete()

func dialogue_setup(partner):
	dialogue_history.clear()
	dialogue_partner = partner
	dialogue_context = ""
	can_trigger = false
	as_entity.set_action("busy talking with "+partner.as_entity.entity_name)
	_end_navigation()

func _create_dialogue_context():
	var queries : Array[String] = []
	queries.append("What are all the things "+agent_name+" remembers about "+dialogue_partner.as_entity.entity_name+"?")
	queries.append("Does "+agent_name+" know "+dialogue_partner.as_entity.entity_name+"'s name?")
	return await _generate_memory_summary(queries)

func _create_group_discussion_context():
	var queries : Array[String] = []
	queries.append("Who was the last person that died?")
	queries.append("Does "+agent_name+" suspect anyone of being the killer?")
	queries.append("What clues does "+agent_name+" know about the related murder")
	return await _generate_memory_summary(queries)

func _remove_name_from_response(response:String) -> String:
	var name_index = response.find(agent_name+": ")
	if name_index != -1:
		response = response.erase(name_index, len(agent_name+": "))
	return response

func initiate_dialogue(partner):
	dialogue_setup(partner)
	
	var first_dialogue_prompt = agent_summary+"\n"
	first_dialogue_prompt += "It is "+game_manager.get_current_datetime_string()+"\n"
	first_dialogue_prompt += as_entity.description+"\n"
	first_dialogue_prompt += agent_name+" observes the following: "+dialogue_partner.as_entity.description+"\n"
	first_dialogue_prompt += "Assume "+agent_name+" only knows the following information:\n"
	first_dialogue_prompt += "\n<Start of context>\n"
	dialogue_context = await _create_dialogue_context()
	first_dialogue_prompt += dialogue_context+"\n"
	first_dialogue_prompt += "\n<End of context>\n"
	first_dialogue_prompt += "Greet "+dialogue_partner.as_entity.entity_name+" as if you are in character as "+agent_name+"\n"
	first_dialogue_prompt += "If "+agent_name+" does not know "+dialogue_partner.as_entity.entity_name+"'s name, then "+agent_name+" will see "+dialogue_partner.as_entity.entity_name+" as a stranger.\n"
	
	var first_dialogue = await game_manager.chat_request(first_dialogue_prompt, 0, 100)
	first_dialogue = _remove_name_from_response(first_dialogue)
	
	conversation_panel.find_child("Label").text += agent_name+": "+first_dialogue+"\n\n"
	
	dialogue_history.append({"agent":agent_name, "statement":first_dialogue})
	if dialogue_partner.is_in_group("Agent"):
		dialogue_partner.receive_dialogue(first_dialogue)
	else:
		game_manager.set_dialogue_text(first_dialogue)

func receive_dialogue(partner_statement):
	var txt = partner_statement
	if partner_statement == "":
		txt = "Hello"
	dialogue_history.append({"agent":dialogue_partner.agent_name, "statement":txt})
	
	if partner_statement.contains("[end]"):
		self.end_dialogue()
		return
	
	conversation_panel.find_child("Label").text += dialogue_partner.agent_name+": "+partner_statement+"\n\n"
	
	var next_dialogue_prompt = agent_summary+"\n"
	next_dialogue_prompt += "It is currently "+game_manager.get_current_datetime_string()+"\n"
	next_dialogue_prompt += as_entity.description+"\n"
	next_dialogue_prompt += agent_name+" observes the following: "+dialogue_partner.as_entity.description+"\n"
	
	# Generate the context about the partner and what the partner said
	next_dialogue_prompt += "Assume "+agent_name+" only knows the following information:\n"
	next_dialogue_prompt += "<Start of context>\n"
	if dialogue_context == "":
		dialogue_context = await _create_dialogue_context()
	next_dialogue_prompt += dialogue_context+"\n"
	if partner_statement != "":
		next_dialogue_prompt += await _generate_memory_summary([partner_statement])
	next_dialogue_prompt += "\n<End of context>\n"
	
	if dialogue_partner == null:
		end_dialogue()
		return

	# Append the dialogue history
	next_dialogue_prompt += "\nHere is the conversation that's going on right now:\n"
	next_dialogue_prompt += "<Start of convo>\n"
	for line in dialogue_history:
		next_dialogue_prompt += line["agent"] + ": " + line["statement"]+"\n"
	next_dialogue_prompt += "<End of convo>\n"
	
	next_dialogue_prompt += "Respond to "+dialogue_partner.agent_name+"'s last remark as if you are in character as "+agent_name+"\n"	
	next_dialogue_prompt += "If "+agent_name+" does not know "+dialogue_partner.as_entity.entity_name+"'s name, then "+agent_name+" will see "+dialogue_partner.as_entity.entity_name+" as a stranger.\n"
	
	if dialogue_partner.is_in_group("Agent"):
		next_dialogue_prompt += "If the conversation is nearing its end or becoming repetitive, say one final remark and include the closing tag [end]. For example:\n Okay bye then. [end]"

	var next_dialogue : String = await game_manager.chat_request(next_dialogue_prompt, 0, 100)
	next_dialogue = _remove_name_from_response(next_dialogue)
		
	conversation_panel.find_child("Label").text += agent_name+": "+next_dialogue+"\n\n"
	
	if dialogue_partner == null:
		end_dialogue()
		return
	
	dialogue_history.append({"agent":agent_name, "statement":next_dialogue})
	
	if dialogue_partner.is_in_group("Agent"):
		dialogue_partner.receive_dialogue(next_dialogue)
		if next_dialogue.contains("[end]"):
			self.end_dialogue()
	else:
		game_manager.set_dialogue_text(next_dialogue)

func end_dialogue():
	conversation_panel.visible = false
	
	if dialogue_partner == null:
		print("The following conversation crashed:\n")
		for text in dialogue_history:
			print(text)
		return
		
	var full_dialogue = "Dialogue between "+agent_name+" and "+dialogue_partner.agent_name+" on "+game_manager.get_current_datetime_string()+"\n"
	for line in dialogue_history:
		full_dialogue += line["agent"] + ": " + line["statement"]+"\n"
	dialogue_history.clear()
	dialogue_partner = null
		
	var reaction_prompt = agent_summary + "\n"
	reaction_prompt += "It is "+game_manager.get_current_datetime_string()+"\n"
	reaction_prompt += as_entity.description+"\n"
	reaction_prompt += await _generate_memory_summary(["Considering the plans made close to "+game_manager.get_current_datetime_string()+", what does "+agent_name+" plan to do next?"])
	reaction_prompt += full_dialogue
	reaction_prompt += "Respond only in the following format: [Continue/Update]|[action to take in the present continuous tense]\n"
	reaction_prompt += "Examples of responses:\n"
	reaction_prompt += "Update|is going for a walk\n"
	reaction_prompt += "Continue|is making breakfast\n"
	reaction_prompt += "Update|is asking John for help with his injury\n"
	reaction_prompt += "Continue|is writing a journal"
	
	var reaction : String = await game_manager.chat_request(reaction_prompt, 0, 40)
	
	destination = null
	as_entity.set_interactable(null)
	as_entity.set_action(reaction.split("|")[1].strip_edges())
	await _pick_location()
	if "Update" in reaction:
		await _generate_plan()
	
	_add_memory(full_dialogue)
	can_trigger = true

func initiate_group_discussion():
	var first_dialogue_prompt = agent_summary+"\n"
	first_dialogue_prompt += "It is "+game_manager.get_current_datetime_string()+"\n"
	first_dialogue_prompt += agent_name+" spotted someone die and is now in a group meeting with all the suspects to figure out who the killer is. "
	first_dialogue_prompt += "Here is what we know about the dead body: "
	for agent in game_manager.agents_root.get_children():
		if !agent.is_alive:
			first_dialogue_prompt += agent.as_entity.description
			break
	first_dialogue_prompt += "\nAssume "+agent_name+" only knows the following information:\n"
	first_dialogue_prompt += "\n<Start of context>\n"
	dialogue_context = await _create_group_discussion_context()
	first_dialogue_prompt += dialogue_context+"\n"
	first_dialogue_prompt += "\n<End of context>\n"
	first_dialogue_prompt += "Initiate the group conversation as if you are in character as "+agent_name+"\n"
	
	var first_dialogue = await game_manager.chat_request(first_dialogue_prompt, 0, 100)
	first_dialogue = _remove_name_from_response(first_dialogue)
	
	dialogue_history.append({"agent":agent_name, "statement":first_dialogue})
	game_manager.add_group_message(first_dialogue, self)

func receive_group_discussion(partner_statement:String, partner:Node2D):
	dialogue_history.append({"agent":partner.agent_name, "statement":partner_statement})
	
	if has_received_discussion:
		return
	
	has_received_discussion = true
	var next_dialogue_prompt = agent_summary+"\n"
	next_dialogue_prompt += "It is "+game_manager.get_current_datetime_string()+"\n"
	next_dialogue_prompt += agent_name+" is in a group discussion to figure out who the killer is of a recent murder.\n"
	
	# Append the dialogue history
	next_dialogue_prompt += "\nHere is the conversation that's going on right now:\n"
	next_dialogue_prompt += "<Start of convo>\n"
	for line in dialogue_history:
		next_dialogue_prompt += line["agent"] + ": " + line["statement"]+"\n"
	next_dialogue_prompt += "<End of convo>\n"
	
	# Append the relevant context
	next_dialogue_prompt += "Assume "+agent_name+" only knows the following information:\n"
	next_dialogue_prompt += "\n<Start of context>\n"
	if dialogue_context == "":
		dialogue_context = await _create_group_discussion_context()
	next_dialogue_prompt += dialogue_context+"\n"
	if partner_statement != "":
		next_dialogue_prompt += await _generate_memory_summary([partner_statement])
	next_dialogue_prompt += "\n<End of context>\n"
	has_received_discussion = false
	
	next_dialogue_prompt += "If "+agent_name+" is aware of a clue or has a question that helps the convo reach a conclusion, respond to "+partner.agent_name+"'s last remark as if you are in character as "+agent_name+"\n"
	next_dialogue_prompt += "If the relevant context does not provide any new clues or insight to the convo, respond to this prompt with the folloing tag: [nothing]"
	
	var next_dialogue = await game_manager.chat_request(next_dialogue_prompt, 0, 100)
	
	if "[nothing]" in next_dialogue:
		return
	
	next_dialogue = _remove_name_from_response(next_dialogue)
	
	dialogue_history.append({"agent":agent_name, "statement":next_dialogue})
	game_manager.add_group_message(next_dialogue, self)

func perform_voting() -> String:
	var vote_prompt = agent_summary+"\n"
	vote_prompt += "It is "+game_manager.get_current_datetime_string()+"\n"
	vote_prompt += agent_name+" just had a group meeting to discuss who the killer of a recent murder is. Here is the full conversation:\n"
	
	# Append the dialogue history
	vote_prompt += "<Start of convo>\n"
	var full_history : String = ""
	for line in dialogue_history:
		full_history += line["agent"] + ": " + line["statement"]+"\n"
	vote_prompt += full_history+"<End of convo>\n"
	
	vote_prompt += "Assume "+agent_name+" only knows the following information:\n"
	vote_prompt += "\n<Start of context>\n"
	vote_prompt += await _generate_memory_summary([full_history])
	vote_prompt += "\n<End of context>\n"
	vote_prompt += "It is time to vote for the killer. Considering all you know about the context and the given conversation, pick one of the following suspects:\n"
	vote_prompt += "<Start of suspect names>\n"
	for agent in game_manager.alive_characters:
		if agent.agent_name == agent_name:
			continue
		vote_prompt += agent.agent_name+"\n"
	vote_prompt += "<End of suspect names>\n"
	vote_prompt += "If you think there's not enough information to convict someone of the murder, respond with [Skip]. "
	vote_prompt += "Respond only with either [Skip] or the suspect name, nothing else."
	
	var vote = await game_manager.chat_request(vote_prompt, 0, 5)
	return vote

func _interact_with_nearby_entities():
	var nearby_entities = interaction_zone.get_overlapping_bodies()
	var contains_destination : bool = false
	for i in range(nearby_entities.size()-1,-1,-1):
		var current_entity : Node2D = nearby_entities[i]
		# If the nearby object is not an entity or is just the agent itself, move onto the next one
		if !current_entity.is_in_group("Entity") || current_entity == self:
			nearby_entities.erase(current_entity)
			continue
			
		# If the nearby object is a dead agent, you can't interact with them so move onto the next one
		if current_entity.is_in_group("Agent"):
			if current_entity.dialogue_partner != null:
				nearby_entities.erase(current_entity)
				continue

		if current_entity == destination:
			contains_destination = true
	
	# If the agent has not reached their destination, leave the function
	if !contains_destination:
		return
	
	var body = destination
	_end_navigation()
	body.as_entity.set_interactable(as_entity)
	as_entity.set_interactable(body.as_entity)
	
	facing_direction = body.global_position - global_position
	if body.is_in_group("Player"):
		game_manager.enter_new_dialogue(self)
		initiate_dialogue(body)	
	
	elif body.is_in_group("Agent"):
		if !body.is_alive:
			game_manager.setup_meeting_dialogue(self, body)
			return
		body.dialogue_setup(self)
		initiate_dialogue(body)
		conversation_panel.visible = true
		conversation_panel.find_child("Label").text = ""
	
	elif body.is_in_group("Item"):
		var item_entity : Entity = body.as_entity
		
		var status_update_prompt = "If someone is "+as_entity.action+" and wants to interact with "+item_entity.entity_name+", what would be the new status of "+item_entity.entity_name+"?\n"
		status_update_prompt += "For example, if John wants to make some coffee and he's interacting with a coffee mixer, the mixer's new status should be \"mixing coffee\"."
		status_update_prompt += "Respond only with the status, for example:\nbaking a pie\nburning some wood\nopen"
		var status_update = await game_manager.chat_request(status_update_prompt, 0, 30)
		
		item_entity.set_action(status_update)

func _on_navigation_agent_2d_velocity_computed(safe_velocity):
	velocity = safe_velocity
	move_and_slide()

func enter_meeting_mode(given_seat:Node2D) -> void:
	is_in_meeting = true
	collision_shape_2D.disabled = true
	global_position = given_seat.global_position
	_end_navigation()
	
	if given_seat.position.x > 0:
		animated_sprite_2d.animation = "sit left"
	else:
		animated_sprite_2d.animation = "sit right"
	
	animated_sprite_2d.frame = randi_range(0,6)
	

func exit_meeting_mode(meeting_table:Node2D):
	if !is_alive:
		return

	_end_navigation()
	z_index = 5
	global_position += (global_position-meeting_table.global_position)*0.8
	velocity = Vector2.ZERO
	collision_shape_2D.disabled = false
	is_in_meeting = false
	new_observations.clear()

func set_info_text(new_text:String) -> void:
	info_label.visible = true
	info_label.text = new_text



