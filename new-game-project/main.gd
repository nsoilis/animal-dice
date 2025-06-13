extends Node3D

@export var offense_die_scene: PackedScene
@export var defense_die_scene: PackedScene
@export var special_die_scene: PackedScene

@export var offense_creatures: Array[PackedScene]
@export var defense_creatures: Array[PackedScene]
@export var special_creatures: Array[PackedScene]

@export var offense_count: int = 2
@export var defense_count: int = 2
@export var special_count: int = 1

@export var face_textures: Array[Texture2D] = [] 
@export var creature_scenes: Array[PackedScene] = []         # ← NEW line

var dice: Array[RigidBody3D] = []
const TOTAL_DICE: int = 5
var settled_count := 0

func _ready() -> void:
	spawn_and_roll_dice()

func spawn_and_roll_dice() -> void:
	# clear old dice
	for old_die in dice:
		old_die.queue_free()
	dice.clear()

	# spawn each category
	_spawn_group(offense_die_scene, offense_count, "Offense")
	_spawn_group(defense_die_scene, defense_count, "Defense")
	_spawn_group(special_die_scene, special_count, "Special")

func _spawn_group(prefab: PackedScene, count: int, role_name: String) -> void:
	for i in range(count):
		var die = prefab.instantiate() as RigidBody3D
		# name for clarity
		die.name = "%s Die %d" % [role_name, i + 1]

		# random face-up orientation
		var face_idx = randi() % 6 + 1
		die.rotation_degrees = rotation_for_face(face_idx)

		# position in a circle
		var idx = dice.size()
		var angle = idx * TAU / TOTAL_DICE
		die.position = Vector3(sin(angle) * 2, 2, cos(angle) * 2)

		# add, connect, and roll
		$DiceContainer.add_child(die)
		dice.append(die)
		die.connect("settled", Callable(self, "_on_die_settled"))
		die.roll()

func rotation_for_face(face: int) -> Vector3:
	match face:
		1:
			return Vector3(  0,   0,   0)
		6:
			return Vector3(180,   0,   0)
		2:
			return Vector3( 90,   0,   0)
		5:
			return Vector3(-90,   0,   0)
		3:
			return Vector3(  0,   0,  90)
		4:
			return Vector3(  0,   0, -90)
		_:
			return Vector3.ZERO

func _on_die_settled(face_idx: int, die: RigidBody3D) -> void:
	settled_count += 1
	var scene = die.creature_scenes[face_idx]
	var animal = scene.resource_path.get_file().get_basename().replace("creature_","").capitalize()
	print("%s spawned: %s (face %d)" % [die.name, animal, face_idx])

	if settled_count == TOTAL_DICE:
		print("")  
		print("***************************************")
		print("")
		settled_count = 0




func _on_button_pressed() -> void:
	
	# clear old creatures
	for c in $CreatureContainer.get_children():
		c.queue_free()

	# reset & re-roll each die
	const HOP_STRENGTH = 5.0
	for die in dice:
		die.linear_velocity  = Vector3.ZERO
		die.angular_velocity = Vector3.ZERO
		# lift slightly
		var t = die.global_transform
		t.origin.y += 0.2
		die.global_transform = t
		# hop + roll
		die.apply_central_impulse(Vector3.UP * HOP_STRENGTH)
		die.roll()
