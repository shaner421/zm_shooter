extends CanvasLayer

## Central authority for which UI screen is currently visible.
##
## Autoloaded as a scene so screen_container stays valid for the life of the
## application. Screens are not required to inherit from any shared base
## class. A screen's root node can optionally define _on_screen_enter() and
## _on_screen_exit() and this manager will call them if present, checked with
## has_method() rather than a type check. This keeps screens free to extend
## Control, Node2D, or anything else without coordinating with this script.


## Emitted after a new screen has been instanced and added under screen_container.
signal screen_changed(screen_name: StringName)

## Emitted immediately before the previous screen is freed. Other systems
## (audio bus changes, Discord presence updates) can listen for this to react
## before the swap happens.
signal screen_closing(screen_name: StringName)


## Screens this manager can navigate to. Populate in the inspector by adding
## entries and assigning a screen_name and scene to each.
@export var screen_entries: Array[ScreenRegistryEntry] = []

## Node that instanced screens are added under. Assign in the inspector to
## the PanelContainer child named "screen".
@export var screen_container: PanelContainer

## Screen shown automatically when the game starts. Must match a screen_name
## used in screen_entries. Left as StringName rather than an int/enum so
## screens can be added or renamed without renumbering anything.
@export var initial_screen: StringName = &""

## Node overlays (popups, modal confirmations) are instanced into. Sits above
## screen_container so a popup can appear on top of whatever screen is active
## without replacing it. Assign in the inspector to a full rect Control
## placed after "screen" in the node order, with mouse_filter set to Ignore
## so it does not block input to the screen below while empty.
@export var overlay_container: Control

## Runtime lookup built from screen_entries in _ready. Not exported directly,
## since typed dictionaries with resource values have unreliable editor
## serialization as of Godot 4.7.
var _screens: Dictionary[StringName, PackedScene] = {}

## Identifier of whichever screen is currently active. Empty StringName if none.
var current_screen_name: StringName = &""

## Instance of the currently active screen, or null if none.
var current_screen: Node = null

## Names of previously visited screens, most recent last. Read by go_back().
## Not appended to when go_back() itself performs the swap.
var _history: Array[StringName] = []

## Instance of the currently active overlay, or null if none.
var current_overlay: Node = null


## Instances scene under overlay_container, replacing whatever overlay is
## currently shown. Returns the instanced node so the caller can connect to
## its signals right away. Unlike screens, overlays are not tracked by name
## or added to history, since only one is ever expected to be visible.
func show_overlay(scene: PackedScene) -> Node:
	close_overlay()

	var overlay: Node = scene.instantiate()
	overlay_container.add_child(overlay)
	current_overlay = overlay

	return overlay


## Frees the currently active overlay, if any. Safe to call even when no
## overlay is showing.
func close_overlay() -> void:
	if current_overlay != null:
		current_overlay.queue_free()
		current_overlay = null


func _ready() -> void:
	_screens.clear()
	for entry in screen_entries:
		if entry == null or entry.screen_name == &"":
			continue
		_screens[entry.screen_name] = entry.scene

	if initial_screen != &"":
		change_screen(initial_screen, false, false)


## Switches to the screen registered under screen_name, freeing whatever
## screen is currently active first. Does nothing if screen_name is already
## active and force is false. Pushes the outgoing screen onto _history unless
## remember is false, so entry points like the main menu can skip logging
## themselves into back-navigation.
func change_screen(screen_name: StringName, force: bool = false, remember: bool = true) -> void:
	if screen_name == current_screen_name and not force:
		return

	if not _screens.has(screen_name):
		push_error("MenuManager: no screen_entries entry with screen_name '%s'" % screen_name)
		return

	if remember and current_screen_name != &"":
		_history.append(current_screen_name)

	_swap_to(screen_name, _screens[screen_name])


## Switches to a screen scene that was not added to screen_entries, useful
## for one-off or dynamically loaded content. screen_name is still required
## since it drives signals and history, so pass a unique identifier.
func change_screen_to_scene(screen_name: StringName, scene: PackedScene, remember: bool = true) -> void:
	if remember and current_screen_name != &"":
		_history.append(current_screen_name)

	_swap_to(screen_name, scene)


## Returns to the previously visited screen. Does nothing if _history is empty.
func go_back() -> void:
	if _history.is_empty():
		return

	var previous_name: StringName = _history.pop_back()

	if not _screens.has(previous_name):
		push_error("MenuManager: cannot go back, '%s' is not in screen_entries" % previous_name)
		return

	_swap_to(previous_name, _screens[previous_name])


## Instances scene under screen_container and frees whatever screen was
## active beforehand. Single point of truth for the actual swap so both
## change_screen() and go_back() stay in sync with current_screen state.
func _swap_to(screen_name: StringName, scene: PackedScene) -> void:
	if screen_container == null:
		push_error("MenuManager: screen_container is not assigned")
		return

	if current_screen != null:
		screen_closing.emit(current_screen_name)

		if current_screen.has_method(&"_on_screen_exit"):
			current_screen._on_screen_exit()

		current_screen.queue_free()
		current_screen = null

	var new_screen: Node = scene.instantiate()
	screen_container.add_child(new_screen)

	current_screen = new_screen
	current_screen_name = screen_name

	if new_screen.has_method(&"_on_screen_enter"):
		new_screen._on_screen_enter()

	screen_changed.emit(screen_name)
