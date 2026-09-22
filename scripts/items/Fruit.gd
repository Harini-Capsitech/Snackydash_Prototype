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
    
    var color_rect = $ColorRect
    if type == "APPLE":
        color_rect.color = Color.RED
    elif type == "BANANA":
        color_rect.color = Color.YELLOW

func collect():
    if not collected:
        collected = true
        visible = false
