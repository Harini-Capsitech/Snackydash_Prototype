extends Node2D
class_name Player

@onready var movement = $PlayerMovement

var inventory: Dictionary = {}

var tail_cells: Array[Vector2i] = []
var entity_sprites: Dictionary = {}
var tail_segments: Array[Dictionary] = [] # Array of {"type": String, "node": Node2D}
var pending_growth_types: Array[String] = []

func setup(start_cell: Vector2i, gm: GridManager, sprites: Dictionary = {}):
    entity_sprites = sprites
    movement.setup(start_cell, gm)
    
    if has_node("ColorRect"):
        get_node("ColorRect").queue_free()
        
    var tex = entity_sprites.get("player")
    if tex:
        var sprite = Sprite2D.new()
        sprite.texture = tex
        var tex_size = tex.get_size()
        if tex_size.x > 0 and tex_size.y > 0:
            var scale_factor = min(gm.cell_size / float(tex_size.x), gm.cell_size / float(tex_size.y))
            sprite.scale = Vector2(scale_factor, scale_factor)
        add_child(sprite)

func add_fruit(type: String):
    if not inventory.has(type):
        inventory[type] = 0
    inventory[type] += 1
    grow_tail(type)
    
func get_fruit_count(type: String) -> int:
    return inventory.get(type, 0)
    
func remove_fruit(type: String, amount: int):
    if not inventory.has(type):
        return
    inventory[type] = max(0, inventory[type] - amount)
    
    for _step in range(amount):
        var matching_idx = -1
        for i in range(tail_segments.size()):
            if tail_segments[i]["type"] == type:
                matching_idx = i
                break
                
        if matching_idx != -1:
            var carried_types = []
            for i in range(tail_segments.size()):
                carried_types.append(tail_segments[i]["type"])
                
            carried_types.remove_at(matching_idx)
            
            var last_seg = tail_segments.pop_back()
            if last_seg and last_seg.has("node") and is_instance_valid(last_seg["node"]):
                last_seg["node"].queue_free()
                
            if tail_cells.size() > tail_segments.size():
                tail_cells.pop_back()
                
            for i in range(carried_types.size()):
                tail_segments[i]["type"] = carried_types[i]
                var tex = entity_sprites.get(carried_types[i])
                var sprite = tail_segments[i]["node"].get_child(0) as Sprite2D
                if sprite and tex:
                    sprite.texture = tex
                    var tex_size = tex.get_size()
                    if tex_size.x > 0 and tex_size.y > 0:
                        var scale_factor = min(movement.grid_manager.cell_size / float(tex_size.x), movement.grid_manager.cell_size / float(tex_size.y))
                        sprite.scale = Vector2(scale_factor, scale_factor)

func grow_tail(type: String):
    pending_growth_types.append(type)

func update_tail(old_cell: Vector2i):
    tail_cells.insert(0, old_cell)

    if pending_growth_types.size() > 0:
        var type = pending_growth_types.pop_front()
        var tex = entity_sprites.get(type)

        var container = Node2D.new()
        if tex:
            var sprite = Sprite2D.new()
            sprite.texture = tex
            var tex_size = tex.get_size()
            if tex_size.x > 0 and tex_size.y > 0:
                var scale_factor = min(movement.grid_manager.cell_size / float(tex_size.x), movement.grid_manager.cell_size / float(tex_size.y))
                sprite.scale = Vector2(scale_factor, scale_factor)
            container.add_child(sprite)

        get_parent().add_child(container)
        tail_segments.append({"type": type, "node": container})
    else:
        if tail_cells.size() > tail_segments.size():
            tail_cells.pop_back()

    _update_visuals()

func _update_visuals():
    for i in range(tail_segments.size()):
        if i < tail_cells.size():
            var cell_pos = movement.grid_manager.cell_to_world(tail_cells[i])
            tail_segments[i]["node"].position = cell_pos

func get_tail_cells() -> Array[Vector2i]:
    return tail_cells
