import os

def create_file(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content.strip() + "\n")

# Project Settings
project_godot = """
; Engine configuration file.
; It's best edited using the editor UI and not directly,
; since the parameters that go here are not all obvious.
;
; Format:
;   [section] ; section goes between []
;   param=value ; assign values to parameters

config_version=5

[application]

config/name="SnackyDash Prototype"
run/main_scene="res://scenes/Game.tscn"
config/features=PackedStringArray("4.2", "Forward Plus")

[display]

window/size/viewport_width=1080
window/size/viewport_height=1920
window/size/window_width_override=540
window/size/window_height_override=960
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[input]

swipe_up={
"deadzone": 0.5,
"events": []
}
swipe_down={
"deadzone": 0.5,
"events": []
}
swipe_left={
"deadzone": 0.5,
"events": []
}
swipe_right={
"deadzone": 0.5,
"events": []
}
"""

# Scripts
grid_manager_gd = """
extends Node
class_name GridManager

var width: int = 8
var height: int = 10
var cell_size: int = 80
var walls: Array[Vector2i] = []

func setup(w: int, h: int, c_size: int, wall_cells: Array[Vector2i]):
    width = w
    height = h
    cell_size = c_size
    walls = wall_cells

func is_inside_grid(cell: Vector2i) -> bool:
    return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height

func is_walkable(cell: Vector2i) -> bool:
    if not is_inside_grid(cell):
        return false
    if cell in walls:
        return false
    return true

func cell_to_world(cell: Vector2i) -> Vector2:
    # Offset so (0,0) is centered top-leftish based on grid size
    var offset_x = (1080 - (width * cell_size)) / 2.0
    var offset_y = (1920 - (height * cell_size)) / 2.0
    return Vector2(offset_x + cell.x * cell_size + cell_size / 2.0, offset_y + cell.y * cell_size + cell_size / 2.0)

func world_to_cell(pos: Vector2) -> Vector2i:
    var offset_x = (1080 - (width * cell_size)) / 2.0
    var offset_y = (1920 - (height * cell_size)) / 2.0
    var cx = int((pos.x - offset_x) / cell_size)
    var cy = int((pos.y - offset_y) / cell_size)
    return Vector2i(cx, cy)

func get_slide_destination(start_cell: Vector2i, direction: Vector2i) -> Vector2i:
    var current = start_cell
    while true:
        var next_cell = current + direction
        if not is_walkable(next_cell):
            break
        current = next_cell
    return current

func get_cells_along_path(start_cell: Vector2i, direction: Vector2i) -> Array[Vector2i]:
    var path: Array[Vector2i] = []
    var current = start_cell + direction
    while is_walkable(current):
        path.append(current)
        current += direction
    return path
"""

player_movement_gd = """
extends Node2D

signal move_started
signal move_finished(cells_crossed)

@export var move_speed := 1000.0
var is_moving := false
var current_cell: Vector2i
var grid_manager: GridManager

func setup(start_cell: Vector2i, gm: GridManager):
    current_cell = start_cell
    grid_manager = gm
    position = grid_manager.cell_to_world(current_cell)

func try_move(direction: Vector2i):
    if is_moving:
        return
    
    var destination = grid_manager.get_slide_destination(current_cell, direction)
    if destination == current_cell:
        return # Can't move
        
    var path = grid_manager.get_cells_along_path(current_cell, direction)
    is_moving = true
    emit_signal("move_started")
    
    var target_pos = grid_manager.cell_to_world(destination)
    var distance = position.distance_to(target_pos)
    var duration = distance / move_speed
    
    var tween = create_tween()
    tween.tween_property(self, "position", target_pos, duration)
    tween.tween_callback(func(): _on_move_complete(destination, path))

func _on_move_complete(dest: Vector2i, path: Array[Vector2i]):
    current_cell = dest
    is_moving = false
    emit_signal("move_finished", path)
"""

player_gd = """
extends Node2D
class_name Player

@onready var movement = $PlayerMovement

var inventory: Dictionary = {}

func setup(start_cell: Vector2i, gm: GridManager):
    movement.setup(start_cell, gm)

func add_fruit(type: String):
    if not inventory.has(type):
        inventory[type] = 0
    inventory[type] += 1
    
func get_fruit_count(type: String) -> int:
    return inventory.get(type, 0)
    
func remove_fruit(type: String, amount: int):
    if inventory.has(type):
        inventory[type] = max(0, inventory[type] - amount)
"""

input_manager_gd = """
extends Node

signal swipe_detected(direction)

var touch_start_pos: Vector2
var is_touching := false
var swipe_threshold := 50.0

func _input(event):
    if event is InputEventScreenTouch:
        if event.pressed:
            touch_start_pos = event.position
            is_touching = true
        else:
            if is_touching:
                _check_swipe(event.position)
            is_touching = false
            
func _check_swipe(touch_end_pos: Vector2):
    var diff = touch_end_pos - touch_start_pos
    if diff.length() < swipe_threshold:
        return
        
    if abs(diff.x) > abs(diff.y):
        if diff.x > 0:
            emit_signal("swipe_detected", Vector2i.RIGHT)
        else:
            emit_signal("swipe_detected", Vector2i.LEFT)
    else:
        if diff.y > 0:
            emit_signal("swipe_detected", Vector2i.DOWN)
        else:
            emit_signal("swipe_detected", Vector2i.UP)
"""

fruit_gd = """
extends Node2D
class_name Fruit

var grid_cell: Vector2i
var type: String
var collected := false
var grid_manager: GridManager

func setup(cell: Vector2i, f_type: String, gm: GridManager):
    grid_cell = cell
    type = f_type
    grid_manager = gm
    position = grid_manager.cell_to_world(grid_cell)

func collect():
    if not collected:
        collected = true
        visible = false
"""

truck_gd = """
extends Node2D
class_name Truck

var grid_cell: Vector2i
var required_type: String
var required_amount: int
var delivered_amount: int = 0
var completed := false
var grid_manager: GridManager

func setup(cell: Vector2i, type: String, req_amt: int, gm: GridManager):
    grid_cell = cell
    required_type = type
    required_amount = req_amt
    grid_manager = gm
    position = grid_manager.cell_to_world(grid_cell)

func can_deliver(player: Player) -> bool:
    return not completed and player.get_fruit_count(required_type) > 0

func deliver(player: Player):
    var p_count = player.get_fruit_count(required_type)
    var needed = required_amount - delivered_amount
    var amount_to_deliver = min(p_count, needed)
    
    if amount_to_deliver > 0:
        player.remove_fruit(required_type, amount_to_deliver)
        delivered_amount += amount_to_deliver
        if delivered_amount >= required_amount:
            completed = true
"""

game_manager_gd = """
extends Node2D

enum GameState { PLAYING, MOVING, LEVEL_COMPLETE }

var state = GameState.PLAYING

@onready var grid_manager = $GridManager
@onready var input_manager = $InputManager
@onready var player = $Player
@onready var items_container = $Items
@onready var trucks_container = $Trucks
@onready var walls_container = $Walls
@onready var ui_layer = $UI
@onready var level_complete_label = $UI/LevelCompleteLabel
@onready var debug_label = $UI/DebugLabel

var fruits: Array[Fruit] = []
var trucks: Array[Truck] = []

func _ready():
    level_complete_label.visible = false
    _load_level()
    input_manager.connect("swipe_detected", Callable(self, "_on_swipe_detected"))
    player.movement.connect("move_started", Callable(self, "_on_player_move_started"))
    player.movement.connect("move_finished", Callable(self, "_on_player_move_finished"))

func _load_level():
    # Hardcoded test level data as requested
    var width = 8
    var height = 10
    var cell_size = 100
    var start_cell = Vector2i(1, 1)
    var walls = [
        Vector2i(2,1), Vector2i(2,2), Vector2i(2,3),
        Vector2i(5,5), Vector2i(6,5), Vector2i(7,5)
    ]
    var f_data = [
        {"cell": Vector2i(3,1), "type": "APPLE"},
        {"cell": Vector2i(3,4), "type": "BANANA"},
        {"cell": Vector2i(6,1), "type": "APPLE"}
    ]
    var t_data = [
        {"cell": Vector2i(6,8), "type": "APPLE", "required": 2},
        {"cell": Vector2i(1,8), "type": "BANANA", "required": 1}
    ]
    
    grid_manager.setup(width, height, cell_size, walls)
    player.setup(start_cell, grid_manager)
    
    # Spawn walls
    for w_cell in walls:
        var w_rect = ColorRect.new()
        w_rect.size = Vector2(cell_size, cell_size)
        w_rect.color = Color.DARK_GRAY
        w_rect.position = grid_manager.cell_to_world(w_cell) - w_rect.size / 2.0
        walls_container.add_child(w_rect)
        
    # Spawn Grid Background (Walkable)
    for x in range(width):
        for y in range(height):
            var c = Vector2i(x,y)
            if c not in walls:
                var bg = ColorRect.new()
                bg.size = Vector2(cell_size-4, cell_size-4)
                bg.color = Color(0.2, 0.2, 0.2)
                bg.position = grid_manager.cell_to_world(c) - bg.size / 2.0
                walls_container.add_child(bg)
                walls_container.move_child(bg, 0)
    
    # Spawn fruits
    var fruit_scene = load("res://scenes/Fruit.tscn")
    for fd in f_data:
        var f = fruit_scene.instantiate()
        items_container.add_child(f)
        f.setup(fd["cell"], fd["type"], grid_manager)
        fruits.append(f)
        
    # Spawn trucks
    var truck_scene = load("res://scenes/Truck.tscn")
    for td in t_data:
        var t = truck_scene.instantiate()
        trucks_container.add_child(t)
        t.setup(td["cell"], td["type"], td["required"], grid_manager)
        trucks.append(t)
        
    _update_debug()

func _on_swipe_detected(direction: Vector2i):
    if state == GameState.PLAYING:
        player.movement.try_move(direction)

func _on_player_move_started():
    state = GameState.MOVING

func _on_player_move_finished(path: Array[Vector2i]):
    # Process path for fruits
    for cell in path:
        for f in fruits:
            if not f.collected and f.grid_cell == cell:
                f.collect()
                player.add_fruit(f.type)
                
    # Check trucks at final cell
    for t in trucks:
        if t.grid_cell == player.movement.current_cell:
            if t.can_deliver(player):
                t.deliver(player)
                
    state = GameState.PLAYING
    _update_debug()
    _check_win_condition()

func _check_win_condition():
    var all_done = true
    for t in trucks:
        if not t.completed:
            all_done = false
            break
            
    if all_done:
        state = GameState.LEVEL_COMPLETE
        level_complete_label.visible = true

func _update_debug():
    var text = "Player: " + str(player.movement.current_cell) + "\\n"
    text += "Inventory:\\n"
    for k in player.inventory:
        text += k + ": " + str(player.inventory[k]) + "\\n"
    text += "\\nTrucks:\\n"
    for t in trucks:
        text += t.required_type + " " + str(t.delivered_amount) + "/" + str(t.required_amount) + "\\n"
    debug_label.text = text
"""

# Scenes
game_tscn = """
[gd_scene load_steps=5 format=3 uid="uid://game_scene_uid"]

[ext_resource type="Script" path="res://scripts/core/GameManager.gd" id="1_gm"]
[ext_resource type="Script" path="res://scripts/grid/GridManager.gd" id="2_grid"]
[ext_resource type="Script" path="res://scripts/input/InputManager.gd" id="3_inp"]
[ext_resource type="PackedScene" uid="uid://player_scene_uid" path="res://scenes/Player.tscn" id="4_pl"]

[node name="Game" type="Node2D"]
script = ExtResource("1_gm")

[node name="GridManager" type="Node" parent="."]
script = ExtResource("2_grid")

[node name="InputManager" type="Node" parent="."]
script = ExtResource("3_inp")

[node name="Walls" type="Node2D" parent="."]

[node name="Items" type="Node2D" parent="."]

[node name="Trucks" type="Node2D" parent="."]

[node name="Player" parent="." instance=ExtResource("4_pl")]

[node name="UI" type="CanvasLayer" parent="."]

[node name="LevelCompleteLabel" type="Label" parent="UI"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_font_sizes/font_size = 64
text = "LEVEL COMPLETE"
horizontal_alignment = 1
vertical_alignment = 1

[node name="DebugLabel" type="Label" parent="UI"]
offset_left = 20.0
offset_top = 20.0
offset_right = 300.0
offset_bottom = 200.0
theme_override_font_sizes/font_size = 32
text = "Debug"
"""

player_tscn = """
[gd_scene load_steps=3 format=3 uid="uid://player_scene_uid"]

[ext_resource type="Script" path="res://scripts/player/Player.gd" id="1_pl"]
[ext_resource type="Script" path="res://scripts/player/PlayerMovement.gd" id="2_plm"]

[node name="Player" type="Node2D"]
script = ExtResource("1_pl")

[node name="PlayerMovement" type="Node2D" parent="."]
script = ExtResource("2_plm")

[node name="ColorRect" type="ColorRect" parent="."]
offset_left = -30.0
offset_top = -30.0
offset_right = 30.0
offset_bottom = 30.0
color = Color(0, 0.5, 1, 1)
"""

fruit_tscn = """
[gd_scene load_steps=2 format=3 uid="uid://fruit_scene_uid"]

[ext_resource type="Script" path="res://scripts/items/Fruit.gd" id="1_fr"]

[node name="Fruit" type="Node2D"]
script = ExtResource("1_fr")

[node name="ColorRect" type="ColorRect" parent="."]
offset_left = -20.0
offset_top = -20.0
offset_right = 20.0
offset_bottom = 20.0
color = Color(1, 0, 0, 1)
"""

truck_tscn = """
[gd_scene load_steps=2 format=3 uid="uid://truck_scene_uid"]

[ext_resource type="Script" path="res://scripts/trucks/Truck.gd" id="1_tr"]

[node name="Truck" type="Node2D"]
script = ExtResource("1_tr")

[node name="ColorRect" type="ColorRect" parent="."]
offset_left = -40.0
offset_top = -40.0
offset_right = 40.0
offset_bottom = 40.0
color = Color(0, 1, 0, 1)
"""

def main():
    root = "c:/Users/CT_USER/Documents/snackydash"
    create_file(root + "/project.godot", project_godot)
    
    create_file(root + "/scripts/core/GameManager.gd", game_manager_gd)
    create_file(root + "/scripts/grid/GridManager.gd", grid_manager_gd)
    create_file(root + "/scripts/player/Player.gd", player_gd)
    create_file(root + "/scripts/player/PlayerMovement.gd", player_movement_gd)
    create_file(root + "/scripts/input/InputManager.gd", input_manager_gd)
    create_file(root + "/scripts/items/Fruit.gd", fruit_gd)
    create_file(root + "/scripts/trucks/Truck.gd", truck_gd)
    
    create_file(root + "/scenes/Game.tscn", game_tscn)
    create_file(root + "/scenes/Player.tscn", player_tscn)
    create_file(root + "/scenes/Fruit.tscn", fruit_tscn)
    create_file(root + "/scenes/Truck.tscn", truck_tscn)

if __name__ == "__main__":
    main()
