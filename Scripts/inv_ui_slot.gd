extends Panel

@onready var item_visuals:Sprite2D=$CenterContainer/Panel/inside_slot
@onready var amount_text:Label=$CenterContainer/Panel/Label

@onready var button = $Button
@onready var inv_ui = $"../../.."
var player:Node

func update(slot:InvSlot):
	if !slot.item:
		item_visuals.visible=false
		amount_text.visible=false
		button.visible=false
	else:
		item_visuals.visible=true
		button.visible=true
		if slot.item.pickup_type=="Weapon":
			button.kill_method=slot.item.method_of_killing
		player=inv_ui.player
		item_visuals.texture=slot.item.texture
		amount_text.visible=true
		amount_text.text=str(slot.amount)
