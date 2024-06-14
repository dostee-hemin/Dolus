# Chat_API.gd
extends Node2D

class_name Chat_API

var api_key : String = Env.get_key("OPEN_AI_KEY")
var url : String = "https://api.openai.com/v1/chat/completions"
var temperature : float = 1
var max_tokens : int
var headers = ["Content-type: application/json", "Authorization: Bearer " + api_key]
var model : String = "gpt-3.5-turbo"
var messages : Array
var output
signal response_recieved

func _init(_max_tokens):
	max_tokens = _max_tokens

# Function to make a dialogue request
func send_request (prompt, request, get_token_count=false):
	if get_token_count:
		request.connect("request_completed", _get_token_count)		
	else:
		request.connect("request_completed", _get_response)
	
	messages.append({
		"role": "user",
		"content": prompt
	})
	
	var body = JSON.stringify({
		"messages": messages,
		"temperature": temperature,
		"max_tokens": max_tokens,
		"model": model
	})
	
	if request.request(url, headers, HTTPClient.METHOD_POST, body) != OK:
		print("There was an error in the chat api!")
	
	await response_recieved

	return output

func _parse_response(body):
	var json = JSON.new()
	json.parse(body.get_string_from_utf8())
	return json.get_data()

func _get_token_count(_result, _response_code, _headers, body):
	output = _parse_response(body)["usage"]["prompt_tokens"]
	response_recieved.emit()

# Function called when the HTTPRequest is completed
func _get_response (_result, _response_code, _headers, body):
	output = _parse_response(body)
	response_recieved.emit()
