extends Game_Manager

var concurrency_handler : ConcurrencyHandler

@onready var instruction_label : Label = get_node("/root/Setup/CanvasLayer/Instruction")
@onready var slider : HBoxContainer = get_node("/root/Setup/CanvasLayer/ScrollContainer/Slider")
@onready var start_button : Button = get_node("/root/Setup/CanvasLayer/Start Button")
@onready var character_setup = preload("res://Secondary_Scenes/Character_Setup.tscn")

@export_file("*.tscn") var next_scene

var character_nodes : Array
var selected_character
var target_character

func _ready():
	concurrency_handler = ConcurrencyHandler.new()
	start_button.visible = false
	
	var folder_path = "res://Assets/Graphics/32x32/Characters/"
	var dir = DirAccess.open(folder_path)
	var files : PackedStringArray = dir.get_files()
	for path in files:
		# If the current file is not one of the agent image sheets, move onto the next one
		if path.find(".png") != len(path)-4:
			continue
			
		# Get the gender of the current agent
		var is_male : bool = false
		if path.split(".")[0].split("_")[-1] == "M":
			is_male = true

		# Create a new character setup node by setting all its respective properties and adding it to the grid
		var new_setup = character_setup.instantiate()
		new_setup.setup_initial_values(load(folder_path+path), is_male)
		new_setup.sprite_button.pressed.connect(_character_selected.bind(new_setup))
		new_setup.name_textbox.text_submitted.connect(_character_name_entered)
		slider.add_child(new_setup)
		character_nodes.append(new_setup)
	
# Called once the player clicks on a character to be their avatar
func _character_selected(selected_node):
	instruction_label.text = "What's Your Name?"
	for node in character_nodes:
		node.disable_button()
	
	selected_character = selected_node
	selected_character.enable_textbox()

# Called once the player has entered their name into the text box
func _character_name_entered(text):
	instruction_label.text = "Generating the Other Characters"
	selected_character.set_name_text(text)
	selected_character.disable_textbox()

	for node in character_nodes:
		if node == selected_character:
			node.description_label.text = "Player"
			continue
		node.generate_info(self, concurrency_handler)
	await concurrency_handler.wait_for_responses(len(character_nodes)-1)
	
	instruction_label.text = "Kill "+str(character_nodes.size()-2)+" Other Characters!"
	start_button.visible = true

func _on_redo_button_pressed():
	get_tree().reload_current_scene()

func _on_start_button_pressed():
	var player_info = {"name": selected_character.character_name, "texture": selected_character.texture_sheet}
	DataTransfer.set_player_info(player_info)
	character_nodes.erase(selected_character)
	
	DataTransfer.reset_values()
	for node in character_nodes:
		var agent_info = {"name": node.character_name, "texture": node.texture_sheet, "age": node.age, "gender": node.gender, "traits": node.traits, "history": node.history}
		DataTransfer.add_agent_info(agent_info)
	get_tree().change_scene_to_file(next_scene)
