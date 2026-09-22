extends Node2D
class_name Player

@onready var movement = $PlayerMovement

var inventory: Dictionary = {}

var tail_cells: Array[Vector2i] = []
var tail_segments: Array[ColorRect] = []
var pending_growth_colors: Array[Color] = []

func setup(start_cell: Vector2i, gm: GridManager):
    movement.setup(start_cell, gm)

func add_fruit(type: String):
    if not inventory.has(type):
        inventory[type] = 0
    inventory[type] += 1
    grow_tail(type)
    
func get_fruit_count(type: String) -> int:
    return inventory.get(type, 0)
    
func remove_fruit(type: String, amount: int):
    if inventory.has(type):
        inventory[type] = max(0, inventory[type] - amount)

func grow_tail(type: String):
    var color = Color(0, 0.4, 0.8)
    if type == "APPLE":
        color = Color.RED
    elif type == "BANANA":
        color = Color.YELLOW
    pending_growth_colors.append(color)

func update_tail(old_cell: Vector2i):
    tail_cells.insert(0, old_cell)
    
    if pending_growth_colors.size() > 0:
        var color = pending_growth_colors.pop_front()
        var new_segment = ColorRect.new()
        new_segment.size = Vector2(60, 60)
        # Offset to center it like the player head
        new_segment.position = -Vector2(30, 30)
        new_segment.color = color
        
        # Create a container node for the segment so we can position it in world space easily
        var container = Node2D.new()
        container.add_child(new_segment)
        # Add to parent (the root or GameManager) so it doesn't move with the head
        get_parent().add_child(container)
        tail_segments.append(new_segment)
    else:
        if tail_cells.size() > tail_segments.size():
            tail_cells.pop_back()
            
    # Update visual positions
    for i in range(tail_segments.size()):
        if i < tail_cells.size():
            var cell_pos = movement.grid_manager.cell_to_world(tail_cells[i])
            tail_segments[i].get_parent().position = cell_pos
