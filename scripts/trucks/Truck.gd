extends Node2D
class_name Truck

var grid_cell: Vector2i
var grid_size: Vector2i = Vector2i(1, 1)
var crates: Array[Dictionary] = [] # [{"type": "apple_green", "amount": 9, "delivered": 0}]
var completed := false
var grid_manager: GridManager
var entity_sprites: Dictionary = {}
var current_crate_sprites: Array[Node] = []

func setup(cell: Vector2i, _type: String, _req_amt: int, gm: GridManager, tex: Texture2D = null, sprites: Dictionary = {}, size: Vector2i = Vector2i(1, 1)):
	grid_cell = cell
	grid_size = size if size.x > 0 and size.y > 0 else Vector2i(1, 1)
	grid_manager = gm
	entity_sprites = sprites
	
	var offset_x = (1080 - (grid_manager.width * grid_manager.cell_size)) / 2.0
	var offset_y = (1920 - (grid_manager.height * grid_manager.cell_size)) / 2.0
	position = Vector2(
		offset_x + (grid_cell.x + grid_size.x / 2.0) * grid_manager.cell_size,
		offset_y + (grid_cell.y + grid_size.y / 2.0) * grid_manager.cell_size
	)
	
	if has_node("ColorRect"):
		get_node("ColorRect").queue_free()
		
	if tex:
		var sprite = Sprite2D.new()
		sprite.texture = tex
		var tex_size = tex.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			var target_w = grid_size.x * grid_manager.cell_size
			var target_h = grid_size.y * grid_manager.cell_size
			var scale_factor = min(target_w / float(tex_size.x), target_h / float(tex_size.y))
			sprite.scale = Vector2(scale_factor, scale_factor)
		add_child(sprite)

func occupies_cell(cell: Vector2i) -> bool:
	return cell.x >= grid_cell.x and cell.x < grid_cell.x + grid_size.x and \
		   cell.y >= grid_cell.y and cell.y < grid_cell.y + grid_size.y

func set_crates(crate_list: Array[Dictionary]):
	crates = crate_list
	_update_visuals()

func can_deliver(player: Player) -> bool:
	if completed or crates.is_empty():
		return false
	return player.get_fruit_count(crates[0]["type"]) > 0

func deliver(player: Player):
	if completed or crates.is_empty():
		return
		
	var cascade_happened = false
	while not crates.is_empty():
		var top_crate = crates[0]
		var p_count = player.get_fruit_count(top_crate["type"])
		var needed = top_crate["amount"] - top_crate.get("delivered", 0)
		
		var amount_to_deliver = min(p_count, needed)
		
		if amount_to_deliver > 0:
			player.remove_fruit(top_crate["type"], amount_to_deliver)
			top_crate["delivered"] = top_crate.get("delivered", 0) + amount_to_deliver
			cascade_happened = true
			
			# Animate the delivery (visual representation)
			_animate_delivery(amount_to_deliver, top_crate["type"], top_crate["delivered"])
			
			if top_crate["delivered"] >= top_crate["amount"]:
				crates.pop_front()
				if not crates.is_empty():
					_clear_delivered_fruits_animated()
				# Loop will continue to check the NEXT crate in the cascade!
				_update_visuals()
			else:
				break # Partially filled
		else:
			break # No matching fruits for this crate
			
	if crates.is_empty() and cascade_happened:
		completed = true

func _update_visuals():
	# Show active top crate UI (just print for now, could be a label)
	if not crates.is_empty():
		var t = crates[0]
		print("Truck needs: %s (%d/%d)" % [t["type"], t.get("delivered", 0), t["amount"]])

func _clear_delivered_fruits_animated():
	for s in current_crate_sprites:
		if is_instance_valid(s):
			var tween = create_tween()
			tween.tween_property(s, "modulate:a", 0.0, 0.5)
			tween.tween_callback(s.queue_free)
	current_crate_sprites.clear()

func _animate_delivery(amount: int, fruit_type: String, current_delivered: int):
	var tex = entity_sprites.get(fruit_type)
	var truck_pixel_size = min(grid_size.x * grid_manager.cell_size, grid_size.y * grid_manager.cell_size)
	var slot_spacing = truck_pixel_size * 0.25
	var fruit_display_size = truck_pixel_size * 0.20
	
	for i in range(amount):
		var index = (current_delivered - amount) + i
		var col = index % 3
		var row = int(index / 3)
		var pos = Vector2((col - 1) * slot_spacing, (row - 1) * slot_spacing)
		
		if tex:
			var sprite = Sprite2D.new()
			sprite.texture = tex
			var tex_size = tex.get_size()
			if tex_size.x > 0 and tex_size.y > 0:
				sprite.scale = Vector2(fruit_display_size / tex_size.x, fruit_display_size / tex_size.y)
			sprite.position = pos
			add_child(sprite)
			current_crate_sprites.append(sprite)
		else:
			var fruit_rect = ColorRect.new()
			var rect_dim = fruit_display_size * 0.5
			fruit_rect.size = Vector2(rect_dim, rect_dim)
			fruit_rect.color = Color.WHITE
			fruit_rect.position = pos - Vector2(rect_dim / 2.0, rect_dim / 2.0)
			add_child(fruit_rect)
			current_crate_sprites.append(fruit_rect)
