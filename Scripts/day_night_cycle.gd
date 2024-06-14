extends CanvasModulate

@export var gradient:GradientTexture1D
@onready var game_manager = $"../../GameManager"
var time_as_float : float

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta:float):
	_convert_time_to_float(game_manager.get_current_datetime_string())
	# Adjust the time to start from 0 at 8 pm (20:00)
	var adjusted_time = (time_as_float - 8)
	# Calculate the phase based on adjusted time
	var phase = (adjusted_time / 24.0) * 2 * PI  # Convert time to radians
	var value=(sin(phase)+1.0)/2
	self.color=gradient.gradient.sample(value)

func _convert_time_to_float(time_str: String):
	# Split the time string by colon (:) to separate hours, minutes, and seconds
	var date_parts := time_str.split(",")
	var time_parts := date_parts[2].split(":")
	# Get the hour part (index 0 after splitting)
	var hour_str := time_parts[0].strip_edges()
	var minute_str = time_parts[1].strip_edges()
	# Convert the time string to a floating point value from 0.0 - 24.0
	time_as_float = float(hour_str) + float(minute_str)/60
