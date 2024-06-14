extends Panel

@onready var game_manager : Node = get_node("/root/Game/GameManager")

@onready var name_label : Label = get_node("Name")
@onready var current_action_label : Label = get_node("Current Action")
@onready var action_list : ItemList = get_node("Action List")

@onready var inv_ui = $"../inv_ui"

func initialize_with_item(item):
	self.visible = true
	inv_ui.visible=false
	name_label.text = item.as_entity.entity_name
	current_action_label.text = "Currently: "+item.as_entity.action
	for action in item.all_actions:
		action_list.add_item(action.strip_edges())

func close_panel():
	self.visible = false
	action_list.clear()
	game_manager.close_item_panel()

func _choose_action(action):
	game_manager.set_item_action(action)
	current_action_label.text = "Currently: "+action

func _on_action_list_item_selected(index):
	_choose_action(action_list.get_item_text(index))
