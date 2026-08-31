extends Control
class_name PlayerCard

func set_username(username:String)->void:
	$MarginContainer/HBoxContainer/Label.text = username

func set_avatar(texture:Texture2D)->void:
	$MarginContainer/HBoxContainer/TextureRect.texture = texture

func set_ready(ready:bool)->void:
	$MarginContainer/HBoxContainer/CheckBox.button_pressed = ready
