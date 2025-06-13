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
	has_settled = false
	connect("sleeping_state_changed", Callable(self, "_on_sleeping_state_changed"))

	# Paint your Face1…Face6 Sprite3Ds as before…
	for i in range(1, 7):
		var sprite = get_node("Face%d" % i) as Sprite3D
		if face_textures[i]:
			sprite.texture = face_textures[i]
			
func roll() -> void:
	# Reset our settled flag and physics sleeping state
	has_settled = false
	sleeping = false
	# Impulse + torque to make it tumble
	apply_impulse(Vector3.ZERO, Vector3(randf()*10 - 5, randf()*10 + 10, randf()*10 - 5))
	apply_torque_impulse(Vector3(randf()*5, randf()*5, randf()*5))

func _on_sleeping_state_changed() -> void:
	if sleeping and not has_settled:
		has_settled = true
		_settle()

func _settle() -> void:
	var best_face = 1
	var best_y = -INF
	for i in range(_targets.size()):
		var y = _targets[i].global_transform.origin.y
		if y > best_y:
			best_y = y
			best_face = i + 1
	emit_signal("settled", best_face, self)



func _face_rotation(face: int) -> Vector3:
	match face:
		1: return Vector3(-90,   0,   0)
		2: return Vector3(  0,   0,   0)
		3: return Vector3(  0,  90,   0)
		4: return Vector3(  0, -90,   0)
		5: return Vector3(  0, 180,   0)
		6: return Vector3( 90,   0,   0)
		_: return Vector3.ZERO
