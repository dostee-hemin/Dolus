extends AnimatedSprite2D

@onready var texture_image : Image = $"..".animation_texture.get_image()

var frames = SpriteFrames.new()
var frame_count : int = 6
var frame_size = Vector2(16, 32) # Size of each frame

func _ready():
	var actions = ["idle", "run", "sit"]
	var directions = ["right", "up", "left", "down"]
	
	if get_parent().is_in_group("Agent"):
		get_parent().icon = ImageTexture.create_from_image(_get_image_region(0, 3, 0.3, 0.7))
	
	# Idle and running animations
	for i in 2:
		for j in 4:
			var speed : int = 5
			if i==1:
				speed = 10
			_create_animation(actions[i]+" "+directions[j], Vector2i(j*6, i+1), speed)
	
	# Sitting animation
	for j in range(0,3,2):
		_create_animation(actions[2]+" "+directions[j], Vector2i((j/2)*6, 5), 5)
		
	# Death frames
	for direction in range(0,3,2):
		var current_animation_name = "dead "+directions[direction] 
		frames.add_animation(current_animation_name)
		var frame_image = _get_image_region(5,12 + direction/2.0)
		if direction == 0:
			frame_image.rotate_90(CLOCKWISE)
		else:
			frame_image.rotate_90(COUNTERCLOCKWISE)
		frames.add_frame(current_animation_name, ImageTexture.create_from_image(frame_image))
	
	sprite_frames = frames
	animation = "idle down"
	play("idle down")

func _create_animation(animation_name:String, starting_location:Vector2i, animation_speed:int) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, animation_speed)
	
	for f in frame_count:
		var frame_texture = ImageTexture.create_from_image(_get_image_region(starting_location.y,starting_location.x+f))
		frames.add_frame(animation_name, frame_texture)

func _get_image_region(row, column, offset_y=0, offset_height=1) -> Image:
	var frame_position = Vector2(column * frame_size.x, (row+offset_y) * frame_size.y)
	var cutout_size = Vector2(frame_size.x,frame_size.y*offset_height)
	var region = Rect2i(frame_position, cutout_size)
	var image_region = texture_image.get_region(region)
	return image_region
