extends Panel

@onready var game_manager = get_node("/root/Game/GameManager")

@onready var dialogue_text = $"Dialogue Text"
@onready var agent_icon = $"Agent Icon"
@onready var agent_name = $"Agent Name"
@onready var player_input_box = $"Player Input Box"
@onready var leave_button = $"Leave Button"

var can_talk : bool

func initialize_with_agent(agent):
	agent_icon.texture = agent.icon
	agent_name.text = agent.agent_name
	dialogue_text.text = "..."
	can_talk = false


func _on_leave_button_pressed():
	game_manager.exit_dialogue()
	
func on_agent_talk(agent_dialogue):
	dialogue_text.text = agent_dialogue
	can_talk = true

func _on_player_input_box_text_changed():
	if !can_talk:
		return

	if "\n" in player_input_box.text and player_input_box.text.strip_edges().strip_escapes() != "":
		game_manager.send_dialogue_text(player_input_box.text)
		player_input_box.text = ""
		dialogue_text.text = "..."
		can_talk = false
