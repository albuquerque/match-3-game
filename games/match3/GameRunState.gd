extends Node
## GameRunState — live runtime data singleton for Match-3 gameplay.
##
## PR 5a: This is the single source of truth for all mutable game state
## that was previously scattered across GameManager's vars.
## GameManager reads AND writes through this node during PR 5a so that
## call sites (GameBoard, BoardActionExecutor, etc.) can be migrated
## one file at a time in PR 5b without breaking anything.
##
## ❌ NO logic here — only data.
## ❌ NO signals here — signals stay on GameManager during 5a/5b.
## ❌ NO references to other nodes — pure data store.

# ── Grid dimensions (mutable — set from level data) ──────────────────────────
var GRID_WIDTH: int  = 8
var GRID_HEIGHT: int = 8

# ── Tile-type constants ───────────────────────────────────────────────────────
const TILE_TYPES:      int = 6
const MIN_MATCH_SIZE:  int = 3
const HORIZTONAL_ARROW: int = 7   # note: intentional typo preserved from GameManager
const VERTICAL_ARROW:  int = 8
const FOUR_WAY_ARROW:  int = 9
const COLLECTIBLE:     int = 10
const UNMOVABLE:       int = 11
const SPREADER:        int = 12

# ── Scoring constants ─────────────────────────────────────────────────────────
const POINTS_PER_TILE:  int   = 100
const COMBO_MULTIPLIER: float = 1.5

# ── Core game state ───────────────────────────────────────────────────────────
var score:       int = 0
var level:       int = 1
var moves_left:  int = 30
var target_score: int = 10000
var grid:        Array = []
var combo_count: int = 0
var initialized: bool = false

# ── Flow-control flags ────────────────────────────────────────────────────────
var processing_moves:      bool = false
var level_transitioning:   bool = false
var pending_level_complete: bool = false
var pending_level_failed:  bool = false
var in_bonus_conversion:   bool = false
var bonus_skipped:         bool = false

# ── Last-level snapshot (used by rewards / transition screens) ────────────────
var last_level_won:        bool = false
var last_level_score:      int  = 0
var last_level_target:     int  = 0
var last_level_number:     int  = 0
var last_level_moves_left: int  = 0

# ── Collectible state ─────────────────────────────────────────────────────────
var collectibles_collected: int    = 0
var collectible_target:     int    = 0
var collectible_type:       String = "coin"
var collectible_positions:  Array  = []

# ── Unmovable state ───────────────────────────────────────────────────────────
var unmovable_type:    String     = "snow"
var unmovables_cleared: int       = 0
var unmovable_target:  int        = 0
var unmovable_map:     Dictionary = {}

# ── Spreader state ────────────────────────────────────────────────────────────
var use_spreader_objective:      bool       = false
var spreader_count:              int        = 0
var spreader_positions:          Array      = []
var spreaders_destroyed_this_turn: Array    = []
var spreader_grace_default:      int        = 2
var max_spreaders:               int        = 20
var spreader_spread_limit:       int        = 0
var spreader_textures_map:       Dictionary = {}
var spreader_type:               String     = "virus"

# ── Booster state ─────────────────────────────────────────────────────────────
var available_boosters: Array = []

# ── Special-tile request (transient, cleared each turn) ───────────────────────
var requested_special_tile: Dictionary = {}

# ── Debug ─────────────────────────────────────────────────────────────────────
var DEBUG_LOGGING: bool = true

# ── Board reference (set by GameBoard._ready) ─────────────────────────────────
# Allows board services to reach tiles without going through GameManager.
var board_ref: Node = null

