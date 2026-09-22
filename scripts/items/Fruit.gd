extends Node2D
class_name Fruit

var grid_cell: Vector2i
var type: String
var collected := false
var grid_manager: GridManager

func setup(cell: Vector2i, f_type: String, gm: GridManager, tex: Texture2D = null):
    grid_cell = cell
    type = f_type
    grid_manager = gm
    position = grid_manager.cell_to_world(grid_cell)
    
    if has_node("ColorRect"):
        get_node("ColorRect").queue_free()
        
    if tex:
        var sprite = Sprite2D.new()
        sprite.texture = tex
        var tex_size = tex.get_size()
        if tex_size.x > 0 and tex_size.y > 0:
            var scale_factor = min(grid_manager.cell_size / float(tex_size.x), grid_manager.cell_size / float(tex_size.y))
            sprite.scale = Vector2(scale_factor, scale_factor)
        add_child(sprite)

func collect():
    if not collected:
        collected = true
        visible = false
