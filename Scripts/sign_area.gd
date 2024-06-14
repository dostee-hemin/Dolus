extends Area2D

@onready var sign_UI = $sign_UI

@export_multiline var titleText:String
@export_multiline var bodyText:String


func _ready():
	sign_UI.visible=false
	sign_UI.title.text=titleText
	sign_UI.body.text=bodyText


func _process(delta):
	pass


func _on_body_entered(body):
	sign_UI.visible=true


func _on_body_exited(body):
	sign_UI.visible=false
