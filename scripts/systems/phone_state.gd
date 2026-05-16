## PhoneState — runtime state for the phone (separate from static data files
## in res://data/). Tracks read threads, picked choices, dating votes, etc.
## Saved/restored via the standard SaveManager dict pipeline.
##
## Apps in `phone_overlay.gd` read state via:
##   PhoneState.is_read(thread_id)
##   PhoneState.choice_for(thread_id, turn)
## And write via:
##   PhoneState.mark_read(thread_id)
##   PhoneState.set_choice(thread_id, turn, choice_index)
extends Node

signal thread_read(thread_id: String)
signal choice_made(thread_id: String, turn: int, choice_index: int)
signal profile_voted(profile_id: String, liked: bool)

# read_threads: { thread_id: true }
var read_threads: Dictionary = {}
# choices: { thread_id: { turn_index: choice_index } }
var choices: Dictionary = {}
# dating votes: { profile_id: true/false (liked/passed) }
var dating_votes: Dictionary = {}

func is_read(thread_id: String) -> bool:
	return read_threads.get(thread_id, false)

func mark_read(thread_id: String) -> void:
	if read_threads.get(thread_id, false):
		return
	read_threads[thread_id] = true
	thread_read.emit(thread_id)

func choice_for(thread_id: String, turn: int) -> int:
	var t: Dictionary = choices.get(thread_id, {})
	return int(t.get(turn, -1))

func set_choice(thread_id: String, turn: int, choice_index: int) -> void:
	if not choices.has(thread_id):
		choices[thread_id] = {}
	choices[thread_id][turn] = choice_index
	choice_made.emit(thread_id, turn, choice_index)

func unread_count(threads: Array) -> int:
	var n := 0
	for t in threads:
		if not is_read(t.get("id", "")):
			n += 1
	return n

# ─────────────────────────────────────────────────────────────────────
# Dating
# ─────────────────────────────────────────────────────────────────────

func has_voted(profile_id: String) -> bool:
	return dating_votes.has(profile_id)

func liked(profile_id: String) -> bool:
	return dating_votes.get(profile_id, false) == true

func vote(profile_id: String, liked_it: bool) -> void:
	dating_votes[profile_id] = liked_it
	profile_voted.emit(profile_id, liked_it)

# ─────────────────────────────────────────────────────────────────────
# Save/Load
# ─────────────────────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"read_threads": read_threads.duplicate(),
		"choices": choices.duplicate(true),
		"dating_votes": dating_votes.duplicate(),
	}

func from_dict(d: Dictionary) -> void:
	read_threads = d.get("read_threads", {})
	choices = d.get("choices", {})
	dating_votes = d.get("dating_votes", {})
