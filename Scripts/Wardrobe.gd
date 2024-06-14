extends Sprite2D

var brokenTexture
var nonBrokenTexture

@onready var wardrobe = $".."
@onready var game_manager = $"../../../../../GameManager"
@onready var breaking_sound = $"../breaking sound"

# Called when the node enters the scene tree for the first time.
func _ready():
	brokenTexture=preload("res://Assets/Graphics/Broken wardrobe.png")
	nonBrokenTexture=preload("res://Assets/Graphics/non-broken wardrobe.png")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if game_manager.get_item_action(wardrobe)=="smash wardrobe":
		texture=brokenTexture
		breaking_sound.play()
		game_manager.set_item_action_from_nodes(wardrobe,"wardrobe broken")
