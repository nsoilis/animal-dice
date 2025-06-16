extends Node3D

# === Exported Dice Prefabs ===
@export var offense_die_scene: PackedScene
@export var defense_die_scene: PackedScene
@export var special_die_scene: PackedScene

# === Exported Creature Prefabs ===
@export var offense_creatures: Array[PackedScene]
@export var defense_creatures: Array[PackedScene]
@export var special_creatures: Array[PackedScene]
@export var creature_scenes: Array[PackedScene] = []

# === Dice Roll Counts ===
@export var offense_count: int = 2
@export var defense_count: int = 2
@export var special_count: int = 2

# === Die Face Visuals ===
@export var face_textures: Array[Texture2D] = []

# === Internal State ===
var dice: Array[RigidBody3D] = []
var spawn_logs: Array[String] = []
var _layout_tween = null
var settled_count := 0
var _should_print := false

var held: Array = []
var hold_buttons: Array = []
const TOTAL_DICE: int = 6

@onready var dice_slots = [
	$DiceSlots/DiceSlot1,
	$DiceSlots/DiceSlot2,
	$DiceSlots/DiceSlot3,
	$DiceSlots/DiceSlot4,
	$DiceSlots/DiceSlot5,
	$DiceSlots/DiceSlot6,
]



func _ready() -> void:
	held.resize(TOTAL_DICE)
	for i in range(TOTAL_DICE):
		held[i] = false

		var btn = $CanvasLayer/MarginContainer/GridContainer.get_node("HoldButton%d" % (i+1)) as Button
		btn.toggle_mode = true
		btn.set_pressed(false)

		# Create a Callable that calls our handler with the index baked in
		var cb = Callable(self, "_on_hold_toggled").bind(i)
		# Connect the toggled signal to that callable
		btn.toggled.connect(cb)

		hold_buttons.append(btn)

	spawn_and_roll_dice()


func _on_hold_toggled(pressed: bool, idx: int) -> void:
	held[idx] = pressed
	hold_buttons[idx].modulate = Color(1,1,1,0.5) if pressed else Color(1,1,1,1)






	
func spawn_and_roll_dice() -> void:
	# Clear existing dice
	for old_die in dice:
		old_die.queue_free()
	dice.clear()

	# Spawn grouped dice
	_spawn_group(offense_die_scene, offense_count, "Offense")
	_spawn_group(defense_die_scene, defense_count, "Defense")
	_spawn_group(special_die_scene, special_count, "Special")


func _spawn_group(prefab: PackedScene, count: int, role_name: String) -> void:
	for i in range(count):
		var die := prefab.instantiate() as RigidBody3D
		die.name = "%s Die %d" % [role_name, i + 1]

		# Random face-up
		var face_idx := randi() % 6 + 1
		die.rotation_degrees = rotation_for_face(face_idx)

		# Circular spawn positioning
		var idx := dice.size()
		var angle := idx * TAU / TOTAL_DICE
		die.position = Vector3(sin(angle) * 2, 2, cos(angle) * 2)

		# Attach and roll
		$DiceContainer.add_child(die)
		dice.append(die)
		die.connect("settled", Callable(self, "_on_die_settled"))
		die.roll()


func _on_die_settled(face_idx: int, die: RigidBody3D) -> void:
	die.set_meta("face_idx", face_idx)
	die.set_meta("settled_rot", die.rotation_degrees)
	# Extract creature name from resource path
	var scene = die.creature_scenes[face_idx]
	var animal = scene.resource_path.get_file()\
		.get_basename()\
		.replace("creature_", "")\
		.capitalize()
	
	spawn_logs.append("%s spawned: %s (face %d)" % [die.name, animal, face_idx])
	settled_count += 1

	if _should_print and settled_count == TOTAL_DICE:
		spawn_logs.sort()
		for line in spawn_logs:
			print(line)
		print("\n***************************************\n")
		_layout_dice() 
		_should_print = false
		spawn_logs.clear()
		settled_count = 0

		
func _layout_dice() -> void:
	const D := 0.5
	
	if _layout_tween and _layout_tween.is_running():
		_layout_tween.kill()

	for i in range(dice.size()):
		var die = dice[i]
		die.sleeping = true

		# get your face index
		var face_idx = die.get_meta("face_idx")

		# decide your yaw via match
		var target_yaw: float
		match face_idx:
			1: target_yaw = 0
			2: target_yaw = 0
			3: target_yaw = 270
			4: target_yaw =  90
			5: target_yaw = 180
			6: target_yaw = 180
			_: target_yaw = 0

		# compute slide target
		var world_slot = dice_slots[i].global_transform.origin
		var local_slot = $DiceContainer.to_local(world_slot)

		# now tween in parallel: yaw and roll zero, plus slide
		var tw = create_tween()
		tw.parallel()
		tw.tween_property(die, "rotation_degrees:y", target_yaw, D)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
		tw.tween_property(die, "position",          local_slot, D)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_button_pressed() -> void:
	# Prepare for output on next full settle
	_should_print = true
	settled_count = 0
	spawn_logs.clear()

	# Remove creatures
	for c in $CreatureContainer.get_children():
		c.queue_free()

	# Reroll each die
	const HOP_STRENGTH := 5.0
	for die in dice:
		die.linear_velocity = Vector3.ZERO
		die.angular_velocity = Vector3.ZERO

		var t := die.global_transform
		t.origin.y += 0.2
		die.global_transform = t

		die.apply_central_impulse(Vector3.UP * HOP_STRENGTH)
		die.roll()


func rotation_for_face(face: int) -> Vector3:
	match face:
		1: return Vector3(  0,   0,   0)
		2: return Vector3( 90,   0,   0)
		3: return Vector3(  0,   0,  90)
		4: return Vector3(  0,   0, -90)
		5: return Vector3(-90,   0,   0)
		6: return Vector3(180,   0,   0)
		_: return Vector3.ZERO


func _align_die_yaw(die: RigidBody3D) -> void:
	# preserve the pitch/roll set by _settle(), but force yaw to zero
	var r = die.rotation_degrees
	r.y = 0
	die.rotation_degrees = r

	
