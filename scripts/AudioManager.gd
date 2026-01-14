extends Node

# Audio Manager - Handles music and sound effects

# Music players (two for crossfading)
var music_player_1: AudioStreamPlayer
var music_player_2: AudioStreamPlayer
var current_music_player: AudioStreamPlayer
var is_music_fading = false

# SFX player pool
var sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS = 10

# Music tracks
var music_tracks = {
	"menu": "res://audio/music/menu_loop.mp3",
	"game": "res://audio/music/game_loop.mp3"
}

# SFX sounds
var sfx_sounds = {
	"ui_click": "res://audio/sfx/ui_click.mp3",
	"tile_swap": "res://audio/sfx/tile_swap.mp3",
	"match": "res://audio/sfx/match_chime.mp3",
	"combo": "res://audio/sfx/combo_chime.mp3",

	# Special tile / booster sounds (use existing files as fallbacks until dedicated assets are added)
	"special_activate": "res://audio/sfx/match_chime.mp3",
	"special_horiz": "res://audio/sfx/combo_chime.mp3",
	"special_vert": "res://audio/sfx/combo_chime.mp3",
	"special_fourway": "res://audio/sfx/combo_chime.mp3",

	"booster_hammer": "res://audio/sfx/match_chime.mp3",
	"booster_shuffle": "res://audio/sfx/tile_swap.mp3",
	"booster_swap": "res://audio/sfx/tile_swap.mp3",
	"booster_chain": "res://audio/sfx/combo_chime.mp3",
	"booster_bomb_3x3": "res://audio/sfx/combo_chime.mp3",
	"booster_line": "res://audio/sfx/match_chime.mp3",
	"booster_tile_squasher": "res://audio/sfx/combo_chime.mp3",
	"booster_row_clear": "res://audio/sfx/combo_chime.mp3",
	"booster_column_clear": "res://audio/sfx/combo_chime.mp3"
}

# Volume settings (0.0 to 1.0)
var music_volume: float = 0.7
var sfx_volume: float = 0.8
var music_enabled: bool = true
var sfx_enabled: bool = true

# Current track
var current_track: String = ""

var _preserve_current_track_on_stop: bool = false

func _ready():
	print("[AudioManager] Initializing audio system...")

	# If RewardManager exists, initialize audio values from saved progress
	var rm = get_node_or_null('/root/RewardManager')
	if rm:
		# If muted, ensure music/sfx disabled
		if rm.audio_muted:
			music_enabled = false
			sfx_enabled = false
		else:
			music_enabled = rm.audio_music_enabled
			sfx_enabled = rm.audio_sfx_enabled
		# Use saved volumes
		music_volume = rm.audio_music_volume
		sfx_volume = rm.audio_sfx_volume

	# Create music players
	music_player_1 = AudioStreamPlayer.new()
	music_player_1.name = "MusicPlayer1"
	music_player_1.bus = "Music"
	add_child(music_player_1)

	music_player_2 = AudioStreamPlayer.new()
	music_player_2.name = "MusicPlayer2"
	music_player_2.bus = "Music"
	add_child(music_player_2)

	current_music_player = music_player_1

	# Create SFX player pool
	for i in range(MAX_SFX_PLAYERS):
		var sfx_player = AudioStreamPlayer.new()
		sfx_player.name = "SFXPlayer%d" % i
		sfx_player.bus = "SFX"
		add_child(sfx_player)
		sfx_players.append(sfx_player)

	# Set initial volumes
	_update_volumes()

	print("[AudioManager] Audio system ready")

func _update_volumes():
	"""Update volume levels for all audio buses"""
	var music_bus = AudioServer.get_bus_index("Music")
	var sfx_bus = AudioServer.get_bus_index("SFX")

	if music_bus >= 0:
		if music_enabled:
			AudioServer.set_bus_volume_db(music_bus, linear_to_db(music_volume))
			AudioServer.set_bus_mute(music_bus, false)
		else:
			AudioServer.set_bus_mute(music_bus, true)
	else:
		print("[AudioManager] Warning: 'Music' bus not found; skipping music volume setup")

	if sfx_bus >= 0:
		if sfx_enabled:
			AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(sfx_volume))
			AudioServer.set_bus_mute(sfx_bus, false)
		else:
			AudioServer.set_bus_mute(sfx_bus, true)
	else:
		print("[AudioManager] Warning: 'SFX' bus not found; skipping SFX volume setup")

func play_music(track_name: String, fade_duration: float = 1.0):
	"""Play a music track with optional crossfade"""
	if not music_enabled:
		return

	if current_track == track_name and current_music_player.playing:
		# Already playing this track
		return

	if not music_tracks.has(track_name):
		print("[AudioManager] Unknown music track: ", track_name)
		return

	var track_path = music_tracks[track_name]

	if not ResourceLoader.exists(track_path):
		print("[AudioManager] Music file not found: ", track_path)
		return

	var stream = load(track_path)
	if not stream:
		print("[AudioManager] Failed to load music: ", track_path)
		return

	print("[AudioManager] Playing music: ", track_name)
	current_track = track_name

	# Enable looping for music streams
	if stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamOggVorbis:
		stream.loop = true

	if fade_duration > 0 and current_music_player.playing:
		# Crossfade to new track
		_crossfade_to(stream, fade_duration)
	else:
		# Direct play
		current_music_player.stream = stream
		current_music_player.play()

func _crossfade_to(new_stream: AudioStream, duration: float):
	"""Crossfade from current track to new track"""
	if is_music_fading:
		return

	is_music_fading = true

	# Determine which player is current and which is next
	var old_player = current_music_player
	var new_player = music_player_2 if current_music_player == music_player_1 else music_player_1

	# Start new track on the other player
	new_player.stream = new_stream
	new_player.volume_db = -80.0  # Start silent
	new_player.play()

	# Create tween for crossfade
	var tween = create_tween()
	tween.set_parallel(true)

	# Fade out old player
	tween.tween_property(old_player, "volume_db", -80.0, duration)

	# Fade in new player
	tween.tween_property(new_player, "volume_db", 0.0, duration)

	tween.set_parallel(false)
	tween.tween_callback(_on_crossfade_complete.bind(old_player, new_player))

func _on_crossfade_complete(old_player: AudioStreamPlayer, new_player: AudioStreamPlayer):
	"""Called when crossfade completes"""
	old_player.stop()
	old_player.volume_db = 0.0
	current_music_player = new_player
	is_music_fading = false

func stop_music(fade_duration: float = 1.0, preserve_current_track: bool = false):
	"""Stop currently playing music. If preserve_current_track is true, keep `current_track` so it can be resumed later."""
	if preserve_current_track:
		_preserve_current_track_on_stop = true

	if fade_duration > 0 and current_music_player.playing:
		var tween = create_tween()
		tween.tween_property(current_music_player, "volume_db", -80.0, fade_duration)
		tween.tween_callback(Callable(self, "_on_music_stopped"))
	else:
		current_music_player.stop()
		if not _preserve_current_track_on_stop:
			current_track = ""
		else:
			# reset the flag after using it
			_preserve_current_track_on_stop = false

func _on_music_stopped():
	"""Called when music fade out completes"""
	current_music_player.stop()
	current_music_player.volume_db = 0.0
	if not _preserve_current_track_on_stop:
		current_track = ""
	else:
		# Keep the track name so it can be resumed; reset the flag
		_preserve_current_track_on_stop = false

func play_sfx(sfx_name: String, volume_multiplier: float = 1.0):
	"""Play a sound effect"""
	if not sfx_enabled:
		return

	if not sfx_sounds.has(sfx_name):
		print("[AudioManager] Unknown SFX: ", sfx_name)
		return

	var sfx_path = sfx_sounds[sfx_name]

	if not ResourceLoader.exists(sfx_path):
		print("[AudioManager] SFX file not found: ", sfx_path)
		return

	var stream = load(sfx_path)
	if not stream:
		print("[AudioManager] Failed to load SFX: ", sfx_path)
		return

	# Find available player
	var player = _get_available_sfx_player()
	if player:
		player.stream = stream
		# If SFX bus is present, use bus volume; otherwise adjust player volume directly
		var sfx_bus_idx = AudioServer.get_bus_index("SFX")
		if sfx_bus_idx >= 0:
			player.volume_db = linear_to_db(sfx_volume * volume_multiplier)
		else:
			# scale linear gain and set as dB on the player
			player.volume_db = linear_to_db(sfx_volume * volume_multiplier)
		player.play()

func _get_available_sfx_player() -> AudioStreamPlayer:
	"""Get an available SFX player from the pool"""
	for player in sfx_players:
		if not player.playing:
			return player

	# All players busy, return the first one (it will interrupt)
	return sfx_players[0]

func set_music_volume(volume: float):
	"""Set music volume (0.0 to 1.0)"""
	music_volume = clamp(volume, 0.0, 1.0)
	_update_volumes()

func set_sfx_volume(volume: float):
	"""Set SFX volume (0.0 to 1.0)"""
	sfx_volume = clamp(volume, 0.0, 1.0)
	_update_volumes()

func set_music_enabled(enabled: bool):
	"""Enable or disable music"""
	music_enabled = enabled
	print("[AudioManager] set_music_enabled -> ", enabled)
	_update_volumes()

	if not enabled:
		# fade out and stop but preserve track so toggling back resumes
		stop_music(0.5, true)
	else:
		# If there was a fade/crossfade in progress, cancel it so we can resume cleanly
		if is_music_fading:
			is_music_fading = false
			if music_player_1.playing:
				music_player_1.stop()
			if music_player_2.playing:
				music_player_2.stop()
		# If enabling and there's a track selected, start playing it
		if current_track != "":
			# Ensure player isn't left in a stopped-but-playing state
			if current_music_player.playing:
				current_music_player.stop()
			current_music_player.volume_db = 0.0
			# Play immediately without fade
			play_music(current_track, 0.0)
		else:
			# No current track recorded - play the menu track by default
			print("[AudioManager] No current track to resume; playing default 'menu' track")
			play_music("menu", 0.0)

func set_sfx_enabled(enabled: bool):
	"""Enable or disable sound effects"""
	sfx_enabled = enabled
	_update_volumes()
