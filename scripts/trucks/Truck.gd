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
        
        # Add visual representation
        for i in range(amount_to_deliver):
            var fruit_rect = ColorRect.new()
            fruit_rect.size = Vector2(10, 10)
            if required_type == "APPLE":
                fruit_rect.color = Color.RED
            elif required_type == "BANANA":
                fruit_rect.color = Color.YELLOW
            # Position them next to each other inside the truck
            fruit_rect.position = Vector2(-30 + (delivered_amount + i) * 15, -30)
            add_child(fruit_rect)
            
        delivered_amount += amount_to_deliver
        if delivered_amount >= required_amount:
            completed = true
