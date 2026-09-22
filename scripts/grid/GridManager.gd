extends Node
class_name GridManager

var width: int = 8
var height: int = 10
var cell_size: int = 80
var walls: Array[Vector2i] = []
var road_cells: Array[Vector2i] = []

func setup(w: int, h: int, c_size: int, wall_cells: Array[Vector2i]):
    width = w
    height = h
    cell_size = c_size
    walls = wall_cells
    road_cells = []

func setup_level(w: int, h: int, c_size: int, roads: Array[Vector2i], wall_cells: Array[Vector2i]):
    width = w
    height = h
    cell_size = c_size
    road_cells = roads.duplicate()
    walls = wall_cells.duplicate()

func is_inside_grid(cell: Vector2i) -> bool:
    return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height

func is_walkable(cell: Vector2i) -> bool:
    if not is_inside_grid(cell):
        return false
    if cell in walls:
        return false
    if not road_cells.is_empty() and cell not in road_cells:
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
