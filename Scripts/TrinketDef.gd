extends Resource
class_name TrinketDef

@export var id: String
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D

# skrypt efektu (np. TrinketSlowTimer.gd)
@export var effect_script: Script
