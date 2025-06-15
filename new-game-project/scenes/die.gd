extends RigidBody3D

signal settled(face_idx: int, die: RigidBody3D)

# === Exported Data ===
@export var face_textures: Array[Texture2D] = []
@export var creature_scenes: Array[PackedScene] = []

@export var min_bounce:    float = 12.0    # how high it jumps at minimum
@export var max_bounce:    float = 18.0    # how high it jumps at maximum
@export var max_impulse:   float = 5.0     # horizontal impulse range
@export var min_forward:   float = 2.0     # guarantee at least this much Z
@export var spin_strength: float = 8.0    # torque range on X/Z axes

# === Internal State ===
var has_settled := false

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

	# Assign textures to face sprites
	for i in range(1, 7):
		var sprite := get_node("Face%d" % i) as Sprite3D
		if face_textures.size() > i and face_textures[i]:
			sprite.texture = face_textures[i]


func roll() -> void:
	has_settled = false
	sleeping     = false

	var ix = randf() * (2 * max_impulse) - max_impulse
	var iy = randf() * (max_bounce - min_bounce) + min_bounce
	var iz = randf() * (2 * max_impulse) - max_impulse
	if abs(iz) < min_forward:
		iz = min_forward * (-1 if iz < 0 else 1)

	apply_impulse(Vector3.ZERO, Vector3(ix, iy, iz))

	var tx = randf() * (2 * spin_strength) - spin_strength
	var tz = randf() * (2 * spin_strength) - spin_strength
	apply_torque_impulse(Vector3(tx, 0, tz))

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
