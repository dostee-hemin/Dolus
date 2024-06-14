extends Node2D

class_name Entity

var as_node : Node

var entity_name : String
var location : String
var action : String
var interactable : Entity

var description : String

func _init(_as_node, _entity_name, _location, _action, _interactable):
	as_node = _as_node
	entity_name = _entity_name
	location = _location
	action = _action
	interactable = _interactable
	
	generate_description()

func generate_description():
	description = entity_name+" currently "
	
	if action != "[nothing]":
		description += action
	else:
		description += "is"

	description +=  " at "+location+"."
	
	
func set_location(new_location: String):
	location = new_location
	generate_description()

func set_action(new_action: String):
	action = new_action
	generate_description()

func set_interactable(new_interactable: Entity):
	interactable = new_interactable

func copy() -> Entity:
	return Entity.new(as_node, entity_name, location, action, interactable)

func matches(other_entity) -> bool:
	var result : bool = true
	
	if location != other_entity.location:
		result = false
		
	if action != other_entity.action:
		result = false
		
	if interactable != other_entity.interactable:
		result = false

	return result
