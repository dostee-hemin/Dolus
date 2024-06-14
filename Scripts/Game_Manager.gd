extends Node
class_name Game_Manager

@onready var stats_label : Label = $"CanvasLayer/Stats Panel/Stats Label"

var num_chat_requests = 0
var num_embedding_requests = 0
var num_chat_tokens = 0

var start_time = 0
var prev_update_time = 0

var can_record = true

func _process(_delta):
	if can_record && start_time == 0:
		start_time = Time.get_unix_time_from_system()
		prev_update_time = start_time
		_update_stats()
	
	if Time.get_unix_time_from_system() - prev_update_time >= 1 && can_record:
		_update_time()

func _input(event):
	if event is InputEventKey and event.pressed:
		if Input.is_action_pressed("toggle game stats"):
			stats_label.get_parent().visible = !stats_label.get_parent().visible

func _update_time():
	prev_update_time = Time.get_unix_time_from_system()
	_update_stats()

func get_token_count(prompt):
	return len(prompt)/4.5
	#return int(await _send_chat_request(prompt, 1, true))

func chat_request(prompt, num_input_tokens=0, num_output_tokens=0):
	if num_input_tokens == 0:
		num_input_tokens = get_token_count(prompt)
	if num_output_tokens == 0:
		num_output_tokens = num_input_tokens
	return await _send_chat_request(prompt, num_input_tokens+num_output_tokens)

func _send_chat_request(prompt, token_count, get_tokens=false):
	var request = HTTPRequest.new()
	add_child(request)
	
	var response = await Chat_API.new(token_count).send_request(prompt, request, get_tokens)
	
	if response == null:
		print("Chat GPT API produced [null]")
		print(prompt)
		return "[Ignore this text]"
	
	if !response.has("usage"):
		print("Chat GPT API failed: ", response)
		print(prompt)
		return "[Ignore this text]"
	
	if(can_record):
		num_chat_requests += 1
		num_chat_tokens += response["usage"]["total_tokens"]
		_update_stats()
	request.queue_free()
	return response["choices"][0]["message"]["content"]

func embedding_request(input_text):
	var request = HTTPRequest.new()
	add_child(request)
	
	var response = await Embedding_API.new().send_request(input_text, request)
	if response == null:
		print("Embedding API failed: ", response)
		return []
	
	if !response.has("data"):
		print("Embedding API failed: ", response)
		return []
	
	if(can_record):
		num_embedding_requests += 1
		_update_stats()
	request.queue_free()
	return response["data"][0]["embedding"]

func _update_stats():
	stats_label.text = _prepare_stats_string()

func _prepare_stats_string() -> String:
	var num_mins = (Time.get_unix_time_from_system()-start_time)/60
	var label_text = "Chat Requests: "+str(num_chat_requests)+"    (per min: "+str(round(num_chat_requests/num_mins))+")\n"
	label_text += "Embedding Requests: "+str(num_embedding_requests)+"    (per min: "+str(round(num_embedding_requests/num_mins))+")\n"
	label_text += "Chat Tokens: "+str(round(num_chat_tokens))+"    (per min: "+str(round(num_chat_tokens/num_mins))+")\n"
	return label_text
