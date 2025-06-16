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
var settled_count := 0
var _should_print := false
var expected_settles := 0

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
	$CanvasLayer.visible = false
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
	hold_buttons[idx].modulate = Color(1, 1, 1, 1)

	var die: RigidBody3D = dice[idx]

	# Freeze the die while held so it can't be moved or nudged
	die.freeze = pressed
	die.sleeping = pressed

	# Visually lower or raise the die
	_tween_die_into_ground(die, pressed)

	# === Update the button label to reflect new state ===
	var label = "Locked" if held[idx] else "Reroll"
	var face_idx = die.get_meta("face_idx") if die.has_meta("face_idx") else -1
	if face_idx != -1 and die.face_textures.size() > face_idx:
		var animal = die.creature_scenes[face_idx].resource_path.get_file().get_basename().replace("creature_", "").capitalize()
		hold_buttons[idx].icon = die.face_textures[face_idx]
		hold_buttons[idx].text = "%s\n%s" % [label.to_upper(), animal]




func _set_die_collision_enabled(die: Node, enabled: bool) -> void:
	_update_collision_recursive(die, enabled)
	
func _update_collision_recursive(node: Node, enabled: bool) -> void:
	var mask_bit = 1 << 1  # Layer 2
	var layer_bit = 1 << 1  # Layer 2

	if node.has_method("get_collision_layer") and node.has_method("set_collision_layer"):
		if enabled:
			if node.has_meta("orig_layer"):
				node.collision_layer = node.get_meta("orig_layer")
		else:
			node.set_meta("orig_layer", node.collision_layer)
			node.collision_layer &= ~layer_bit

	if node.has_method("get_collision_mask") and node.has_method("set_collision_mask"):
		if enabled:
			if node.has_meta("orig_mask"):
				node.collision_mask = node.get_meta("orig_mask")
		else:
			node.set_meta("orig_mask", node.collision_mask)
			node.collision_mask &= ~mask_bit

	for child in node.get_children():
		_update_collision_recursive(child, enabled)


func _set_die_held_state(die: RigidBody3D, is_held: bool) -> void:
	die.freeze = is_held  # prevents nudging or being moved by engine
	die.sleeping = is_held  # extra safety: force sleep


	_update_collision_recursive(die, !is_held)

func _register_die(die: RigidBody3D) -> void:
	die.set_meta("base_y", die.global_transform.origin.y)
	
func _tween_die_into_ground(die: RigidBody3D, is_held: bool) -> void:
	if not die.has_meta("base_y"):
		die.set_meta("base_y", die.global_transform.origin.y)

	var base_y_variant: Variant = die.get_meta("base_y")
	if typeof(base_y_variant) != TYPE_FLOAT and typeof(base_y_variant) != TYPE_INT:
		push_error("base_y is not a number: %s" % str(base_y_variant))
		return

	var base_y: float = float(base_y_variant)
	var target_y: float = base_y - 0.99 if is_held else base_y

	var current_pos: Vector3 = die.global_transform.origin
	if absf(current_pos.y - target_y) < 0.001:
		return  # Already at or very close to target, skip tween

	var target_position: Vector3 = current_pos
	target_position.y = target_y

	# Kill old tween if it exists
	if die.has_meta("tween"):
		var old_tween = die.get_meta("tween")
		if is_instance_valid(old_tween):
			old_tween.kill()

	var tween: Tween = create_tween()
	die.set_meta("tween", tween)
	tween.tween_property(die, "global_transform:origin", target_position, 0.25)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)




	
func spawn_and_roll_dice() -> void:
	# Clear existing dice
	for old_die in dice:
		old_die.queue_free()
	dice.clear()

	# Spawn grouped dice
	_spawn_group(offense_die_scene, offense_count, "Offense")
	_spawn_group(defense_die_scene, defense_count, "Defense")
	_spawn_group(special_die_scene, special_count, "Special")

	for i in range(TOTAL_DICE):
		held[i] = false
		hold_buttons[i].set_pressed(false)
		hold_buttons[i].icon = null
		hold_buttons[i].text = ""


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
	# 1) remember which face landed and its exact rotation
	die.set_meta("face_idx", face_idx)
	die.set_meta("settled_rot", die.rotation_degrees)

	# 2) log the spawn message
	var scene  = die.creature_scenes[face_idx]
	var animal = scene.resource_path.get_file().get_basename().replace("creature_", "").capitalize()
	spawn_logs.append("%s spawned: %s (face %d)" % [die.name, animal, face_idx])
	settled_count += 1

	# 3) update the corresponding HoldButton’s icon & text
	var idx = dice.find(die)
	if idx != -1:
		# pull the texture from the die itself (exports in die.gd)
		var animal_tex = die.face_textures[face_idx]
		var label = "Locked" if held[idx] else "Reroll"
		hold_buttons[idx].icon = animal_tex
		hold_buttons[idx].text = "%s\n%s" % [label.to_upper(), animal]


	# 4) once all dice have settled, do the layout and print
	if _should_print and settled_count >= expected_settles:
		# 1) print results
		spawn_logs.sort()
		for line in spawn_logs:
			print(line)
		print("\n***************************************\n")

		# 2) wait a bit (e.g. 0.75s) before showing the hold UI
		

		# 3) line up the dice
		_layout_dice()
		
		await get_tree().create_timer(1).timeout
		$CanvasLayer.visible = true

		# 4) reset for next round
		_should_print = false
		spawn_logs.clear()
		settled_count = 0




		
func _layout_dice() -> void:
	const D := 0.5

	for i in range(dice.size()):
		if held[i]:
			continue    # leave held dice exactly where they are
		var die = dice[i]

		# ─── 0) take it out of physics so it won’t move ───
		# either sleep it:
		die.sleeping        = true
		die.linear_velocity = Vector3.ZERO
		die.angular_velocity= Vector3.ZERO

		# or switch to static mode (uncomment if you prefer):
		# die.mode = PhysicsBody3D.MODE_STATIC

		# ─── 1) pick the yaw you want for its face ───
		var face_idx  = die.get_meta("face_idx")
		var target_yaw := 0.0
		match face_idx:
			1: target_yaw =   0
			2: target_yaw =   0
			3: target_yaw = 270
			4: target_yaw =  90
			5: target_yaw = 180
			6: target_yaw = 180
			_: target_yaw =   0

		# ─── 2) compute slide target in local space ───
		var world_slot = dice_slots[i].global_transform.origin
		var local_slot = $DiceContainer.to_local(world_slot)

		# ─── 3) spin & slide in parallel ───
		var tw = create_tween()
		tw.parallel()
		tw.tween_property(die, "rotation_degrees:y", target_yaw, D)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(die, "position",           local_slot, D)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		# ─── 4) (optional) switch back to rigid so you can roll again later ───
		# die.mode = PhysicsBody3D.MODE_RIGID




func _on_button_pressed() -> void:
	const HOP_STRENGTH := 5.0
	$CanvasLayer.visible = false
	# prepare…
	_should_print    = true
	settled_count    = 0
	spawn_logs.clear()

	expected_settles = 0
	for i in range(dice.size()):
		if not held[i]:
			expected_settles += 1

	# debug: print which dice we think are held

		

	if expected_settles == 0:
		_layout_dice()
		return

	for i in range(dice.size()):
		if held[i]:
		
			continue
		
	
		var die = dice[i]
		die.linear_velocity  = Vector3.ZERO
		die.angular_velocity = Vector3.ZERO

		var t = die.global_transform
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

	
