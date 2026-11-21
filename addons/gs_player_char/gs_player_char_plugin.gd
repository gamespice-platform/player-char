@tool
extends EditorPlugin

## Editor entry point for GameSpice Player Char. Registers inspector types only.
## No autoloads: two players in one scene are two characters, and a menu preview beside the player is a third.

const _ICON := "res://addons/gs_player_char/icon_placeholder.svg"

const _NODES := "res://addons/gs_player_char/nodes/"

const _TYPES := [
	["GSPlayerChar", "Node", _NODES + "gs_player_char.gd"],
	["GSPlayerCharVisual", "Node", _NODES + "gs_player_char_visual.gd"],
	["GSPlayerModelVisual", "Node", _NODES + "gs_player_model_visual.gd"],
	["GSPlayerModelRig", "Node3D", _NODES + "gs_player_model_rig.gd"],
	["GSPlayerSpriteVisual", "Node", _NODES + "gs_player_sprite_visual.gd"],
	["GSPlayerAnimDriver", "Node", _NODES + "gs_player_anim_driver.gd"],
	["GSPlayerAnimPlayerSink", "Node", _NODES + "gs_player_anim_player_sink.gd"],
	["GSPlayerAnimSpriteSink", "Node", _NODES + "gs_player_anim_sprite_sink.gd"],
]


func _enter_tree() -> void:
	var icon: Texture2D = null
	if ResourceLoader.exists(_ICON):
		icon = load(_ICON) as Texture2D

	for entry in _TYPES:
		add_custom_type(entry[0], entry[1], load(entry[2]), icon)


func _exit_tree() -> void:
	for i in range(_TYPES.size() - 1, -1, -1):
		remove_custom_type(_TYPES[i][0])
