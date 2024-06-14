extends Sprite2D

@onready var speech_text : RichTextLabel = $"Speech Text"
@onready var progress_bar : Panel = $"Progress Bar"

@export var lifetime_seconds : float = 5 # Number of seconds the speech bubble will be shown

# Called when the node enters the scene tree for the first time.
func _ready():
	speech_text.text = ""

func close_bubble():
	var tween = create_tween()
	tween.tween_property(self, "scale",Vector2.ZERO,0.4).set_trans(Tween.TRANS_QUART)
	tween.tween_callback(queue_free)

func set_text(new_text:String) -> void:
	speech_text.text = new_text
	
	var num_words : int = new_text.split(" ").size()
	lifetime_seconds = max(2,num_words * 0.24)
	
	var tween = create_tween()
	var target_scale = scale
	scale = Vector2.ZERO
	tween.tween_property(self, "scale",target_scale,0.4).set_trans(Tween.TRANS_BOUNCE)
	
	create_tween().tween_callback(close_bubble).set_delay(lifetime_seconds)
	var initial_size = progress_bar.size
	create_tween().tween_property(progress_bar, "size", Vector2(0,initial_size.y), lifetime_seconds)	

func set_direction(is_left:bool,is_up:bool):
	if is_left:
		position.x = abs(position.x)
		flip_h = false
	else:
		position.x = -abs(position.x)
		speech_text.position.x -= 90
		flip_h = true
	
	flip_v = is_up
	if is_up:
		position.y += 10
	else:
		position.y -= 10
