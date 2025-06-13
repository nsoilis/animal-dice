extends RigidBody3D
signal settled(face_idx: int, die: RigidBody3D)

@export var face_textures: Array[Texture2D] = []
@export var creature_scenes: Array[PackedScene] = []

var has_settled = false

@onready var _targets := [
	$Target1,
	$Target2,
	$Target3,
	$Target4,
	$Target5,
	$Target6,
]

func _ready() -> void:
	print("OK, I compiled!")
