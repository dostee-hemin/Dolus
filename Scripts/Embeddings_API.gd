extends Node2D

class_name Embedding_API

var api_key : String = Env.get_key("OPEN_AI_KEY")
var url : String = "https://api.openai.com/v1/embeddings"
var headers = ["Content-type: application/json", "Authorization: Bearer " + api_key]
var model : String = "text-embedding-3-small"
var output
signal response_recieved

# Function to make a dialogue request
func send_request(input_text, request):
	request.connect("request_completed", _on_request_completed)
	
	var body = JSON.stringify({
		"input": input_text,
		"model": model
	})

	if request.request(url, headers, HTTPClient.METHOD_POST, body) != OK:
		print("There was an error in the embeddings api!")
	
	await response_recieved

	return output

# Function called when the HTTPRequest is completed
func _on_request_completed(_result, _response_code, _headers, body):
	var json = JSON.new()
	json.parse(body.get_string_from_utf8())
	var response = json.get_data()

	output = response
	response_recieved.emit()

