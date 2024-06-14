class_name Memory extends Node2D

var time_created : float
var time_last_accessed : float
var importance : int
var embedding : Array
var content : String
var token_count : int

signal completed

func _init(_time_created, _content, game_manager):
	time_created = _time_created
	time_last_accessed = time_created
	content = _content
	importance = 5 # temporary value in case requests are slow
	
	var importance_prompt = "Rate the importance of the following memory from 1 to 10 (1 = purely mundane like brushing teeth, 10 = extremely poignant like parents dying).\n"
	importance_prompt += "Memory: "+content+"\n"
	importance_prompt += "Respond only with the rating. Examples: 1\n6\n3"
	importance = int(await game_manager.chat_request(importance_prompt, 0,3))
	token_count = await game_manager.get_token_count(content)
	embedding = await game_manager.embedding_request(content)
	completed.emit()

