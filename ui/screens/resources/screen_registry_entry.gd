extends Resource
class_name ScreenRegistryEntry

## Identifier a screen is looked up by when calling MenuManager.change_screen().
@export var screen_name: StringName = &""

## Scene instanced when screen_name is requested.
@export var scene: PackedScene
