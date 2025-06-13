extends RigidBody3D
signal settled(face_name: String, die: RigidBody3D)

@export var face_textures: Array[Texture2D] = [
	null,                                       # 0 unused
	preload("res://images/turtleFace.png"),     # 1
	preload("res://images/catFace.png"),        # 2
	preload("res://images/frogFace.png"),       # 3
	preload("res://images/owlFace.png"),        # 4
	preload("res://images/bearFace.png"),       # 5
	preload("res://images/rabbitFace.png")      # 6
]

var has_settled: bool = false

func _ready() -> void:
	has_settled = false
	connect("sleeping_state_changed", Callable(self, "_on_sleeping_state_changed"))

	# Paint each Sprite3D quad with its texture
	for i in range(1, 7):  # 1 through 6 inclusive
		var sprite = get_node("Face%d" % i) as Sprite3D
		if face_textures[i]:
			sprite.texture = face_textures[i]

func roll() -> void:
	has_settled = false
	sleeping = false
	apply_impulse(Vector3.ZERO, Vector3(randf()*10 - 5, randf()*10 + 10, randf()*10 - 5))
	apply_torque_impulse(Vector3(randf()*5, randf()*5, randf()*5))

func _on_sleeping_state_changed() -> void:
	if sleeping and not has_settled:
		has_settled = true
		_settle()

func _settle() -> void:
	# 1) Detect which face is most up
	var up = global_transform.basis.y.normalized()
	var best_face = 1
	var best_dot = -1.0
	var dirs = [
		Vector3(0,  1,  0),  # Face1 +Y
		Vector3(0,  0,  1),  # Face2 +Z
		Vector3(1,  0,  0),  # Face3 +X
		Vector3(-1, 0,  0),  # Face4 -X
		Vector3(0,  0, -1),  # Face5 -Z
		Vector3(0, -1,  0)   # Face6 -Y
	]
	for i in range(dirs.size()):
		var d = up.dot(dirs[i])
		if d > best_dot:
			best_dot = d
			best_face = i + 1

	# 2) Rotate flat onto that face & snap yaw
	var flat_rot = _face_rotation(best_face)
	flat_rot.y = round(flat_rot.y / 90) * 90

	# 3) Tween softly into place if needed
	if best_dot < 0.9999:  # always tween a tiny bit
		var t = create_tween()
		t.tween_property(self, "rotation_degrees", flat_rot, 0.3)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)
	var current_rot := rotation_degrees
	current_rot.y = round(current_rot.y / 90) * 90
	var t = create_tween()
	t.tween_property(self, "rotation_degrees", current_rot, 0.3)\
	 .set_trans(Tween.TRANS_SINE)\
	 .set_ease(Tween.EASE_OUT)


	# 5) Emit the settled signal once
	emit_signal("settled", str(best_face), self)


func _face_rotation(face: int) -> Vector3:
	match face:
		1:  return Vector3(-90,   0,   0)
		2:  return Vector3(  0,   0,   0)
		3:  return Vector3(  0,  90,   0)
		4:  return Vector3(  0, -90,   0)
		5:  return Vector3(  0, 180,   0)
		6:  return Vector3( 90,   0,   0)
		_:  return Vector3.ZERO
