extends Node

## Music — autoload. Knows the full nulldrift soundtrack, categorizes
## tracks by filename hint, picks at random per scene type, crossfades
## between scenes.
##
## Usage from any scene:
##   Music.play_category("apartment")
##   Music.play_category("title")
##   Music.play_track("dark-alley")   # exact name (no extension)
##   Music.stop()

const MUSIC_DIR := "res://audio/music"
const FADE_TIME := 1.4
const TARGET_DB := -8.0

# Maps category → list of filename stems (no .mp3). At play time we pick one
# at random. If a category is empty we fall back to "any".
const CATEGORIES := {
	"title": [
		"nulldrift-bestfriends",
		"nulldrift-intheend",
		"vector-race",
	],
	"apartment": [
		"intro-apartment",
		"alone",
		"alone-full",
		"theres-a-draft-in-here",
		"violet-archive",
	],
	"story": [
		"rooftop-meet",
		"lost-lover", "lost-lover-full",
		"in-love",
		"i-wanted-to-be-yours",
		"why-dont-you-like-me",
		"arcade-girl-is-sad",
		"wow-johnny",
		"nyx-revealed",
		"sad-js", "sad-js-full",
		"black-wings",
		"dark-alley",
		"cast-party",
	],
	"combat": [
		"super-hacker-fights-ice",
		"super-hacker-fights-ice-variation",
		"ghost-fights-the-dragon",
		"team-vs-tusk",
		"cyber-death",
		"aws-sea-hag",
		"grave-repeal", "grave-repeal-full",
	],
	"driving": [
		"neon-car-chase",
		"vector-race",
		"cascading-effect",
	],
	"game_over": [
		"null-drift-game-over",
		"null-drift-game-over-2",
		"null-drift-game-over-full",
		"null-drift-game-over-2-full",
		"null-drift-softgoodye",
	],
	"ending": [
		"ending-rain-full",
		"ending-rain-2-full",
	],
	"ambient": [
		"ydkwli-snes",
		"ydkwli-nes",
		"ydkwli-fantasia-reverb",
		"ydkwli-fantasia-reverb20",
		"bill-evans-ydkwli-snes",
		"you-dont-know-what-love-is-fantasia",
	],
	# Walking the city block — jazz that holds up to a long stroll
	"city": [
		"bill-evans-ydkwli-snes",
		"you-dont-know-what-love-is-fantasia",
		"ydkwli-fantasia-reverb",
		"ydkwli-snes",
	],
	# Same set used on the balcony for now
	"balcony": [
		"bill-evans-ydkwli-snes",
		"you-dont-know-what-love-is-fantasia",
		"ydkwli-fantasia-reverb",
	],
}

var _player: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active: AudioStreamPlayer
var _current_track := ""
var _all_tracks: Array[String] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_player = AudioStreamPlayer.new()
	_player_b = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player_b.bus = "Master"
	add_child(_player)
	add_child(_player_b)
	_active = _player
	_scan_tracks()

func _scan_tracks() -> void:
	_all_tracks.clear()
	var dir := DirAccess.open(MUSIC_DIR)
	if dir == null:
		push_warning("Music dir missing: " + MUSIC_DIR)
		return
	for fname in dir.get_files():
		if fname.ends_with(".mp3"):
			_all_tracks.append(fname.get_basename())

func play_category(category: String) -> void:
	var pool: Array = CATEGORIES.get(category, [])
	var available: Array = []
	for stem in pool:
		if _all_tracks.has(stem):
			available.append(stem)
	if available.is_empty():
		# Fallback: pick any track at all so we never have silence
		if _all_tracks.is_empty():
			return
		available = _all_tracks
	# Avoid replaying the same track if alternatives exist
	var picked: String = available[_rng.randi() % available.size()]
	if available.size() > 1 and picked == _current_track:
		picked = available[(_rng.randi() % available.size())]
		if picked == _current_track:
			picked = available[(available.find(picked) + 1) % available.size()]
	play_track(picked)

func play_track(stem: String) -> void:
	if stem == _current_track and _active and _active.playing:
		return
	var path := "%s/%s.mp3" % [MUSIC_DIR, stem]
	if not ResourceLoader.exists(path):
		push_warning("Music missing: " + path)
		return
	_current_track = stem
	var stream := load(path) as AudioStream
	if stream and stream.has_method("set_loop"):
		stream.set_loop(true)
	var next: AudioStreamPlayer = _player_b if _active == _player else _player
	next.stream = stream
	next.volume_db = -60.0
	next.play()
	# Crossfade
	var tw_in := create_tween()
	tw_in.tween_property(next, "volume_db", TARGET_DB, FADE_TIME)
	if _active and _active.playing:
		var tw_out := create_tween()
		tw_out.tween_property(_active, "volume_db", -60.0, FADE_TIME)
		var fading_out := _active
		tw_out.finished.connect(func():
			if fading_out and fading_out.playing:
				fading_out.stop())
	_active = next

func stop(fade: float = FADE_TIME) -> void:
	if _active and _active.playing:
		var tw := create_tween()
		var fading_out := _active
		tw.tween_property(_active, "volume_db", -60.0, fade)
		tw.finished.connect(func():
			if fading_out and fading_out.playing:
				fading_out.stop())
	_current_track = ""
