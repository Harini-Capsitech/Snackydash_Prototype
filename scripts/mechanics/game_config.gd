## GameConfig defines palette tokens, fruit data, crate specs, and layer enums
## matching the authentic Snacky Dash screenshot aesthetics.
class_name GameConfig
extends RefCounted

# Tile definitions for ASCII maps
const TILE_WALL: String = "#"
const TILE_FLOOR: String = "."
const TILE_JUNCTION: String = "J" # Explicit checkpoint/junction node
const TILE_BRIDGE: String = "="   # Arched road overpass/underpass
const TILE_CRATE: String = "C"    # Delivery crate intake dock
const TILE_SNAKE_START: String = "S"

enum Layer {
	GROUND = 0,
	OVERPASS = 1,   # Horizontal arched bridge over the road
	UNDERPASS = 2   # Vertical road passing under the bridge
}

const TILE_SIZE: int = 60

# Fruit Definitions matching screenshots
const FRUIT_DATA: Dictionary = {
	"R": { "name": "Apple", "color": Color("#e11d48"), "dark": Color("#9f1239"), "icon": "🍎" },
	"B": { "name": "Plum", "color": Color("#2563eb"), "dark": Color("#1e40af"), "icon": "🫐" },
	"Y": { "name": "Lemon", "color": Color("#eab308"), "dark": Color("#a16207"), "icon": "🍋" },
	"G": { "name": "GreenApple", "color": Color("#16a34a"), "dark": Color("#15803d"), "icon": "🍏" },
	"P": { "name": "Peach", "color": Color("#ec4899"), "dark": Color("#be185d"), "icon": "🍑" }
}

# Visual Colors directly sampled from screenshots
const COLOR_GRASS_BG: Color = Color("#7bb342")       # Soft clover field
const COLOR_GRASS_ALT: Color = Color("#74a83d")      # Subtle clover pattern
const COLOR_ISLAND_FILL: Color = Color("#8cc54c")    # Inner raised/recessed island
const COLOR_ISLAND_BORDER: Color = Color("#64972e")  # Island curb shadow
const COLOR_ROAD_ASPHALT: Color = Color("#374151")   # Charcoal dark asphalt track
const COLOR_ROAD_BORDER: Color = Color("#2b323f")    # Road edge outline
const COLOR_JUNCTION_INDENT: Color = Color("#2d3748") # Dark square on junction
const COLOR_RETICLE_ORANGE: Color = Color("#f97316")  # [ ] orange checkpoint brackets

# Snake and Wagon styling
const COLOR_SNAKE_PURPLE: Color = Color("#9333ea")   # Vibrant purple head
const COLOR_SNAKE_SHADOW: Color = Color("#6b21a8")   # Head lower bevel
const COLOR_WAGON_PURPLE: Color = Color("#7e22ce")   # Open cargo tray body
const COLOR_WAGON_INNER: Color = Color("#581c87")    # Inside wagon tray

# Trajectory Chevrons
const COLOR_CHEVRON: Color = Color("#c084fc")        # Glowing light purple preview arrows

# Crate dimensions
const CRATE_SLOTS: int = 9 # 3x3 capacity per crate tier
