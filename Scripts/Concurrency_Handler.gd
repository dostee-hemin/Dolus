class_name ConcurrencyHandler

signal response_recieved
var lock : Mutex = Mutex.new()
var responses = []

# Call this with "await" whenever you want to stop the program so that all submitted requests get processed before continuing
func wait_for_responses(num_expected_responses):
	var num_responses_recieved = 0
	while num_responses_recieved != num_expected_responses:
		await response_recieved
		num_responses_recieved += 1

# Whenever we declare that a request was successfully processed, store any response and trigger the signal
func response_complete(response=null):
	lock.lock()
	
	if response != null:
		responses.append(response)
	response_recieved.emit()
		
	lock.unlock()

# Return all responses collected in the array as a string seperated by a delimiter
func pop_responses_as_string(delimiter = " ") -> String:
	var result : String = ""
	for response in responses:
		result += response + delimiter
	responses.clear()
	return result
	
func pop_responses() -> Array:
	var result : Array = []
	for response in responses:
		result.append(response)
	responses.clear()
	return result

