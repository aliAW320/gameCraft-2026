extends Node

# M5: compact pool of players for original synthesized, license-free WAV sounds.
const SOUND_PATHS = {
    "hit": "res://assets/sounds/generated/m5_hit.wav",
    "kill": "res://assets/sounds/generated/m5_kill.wav",
    "pickup": "res://assets/sounds/generated/m5_pickup.wav",
    "hurt": "res://assets/sounds/generated/m5_hurt.wav",
    "surge": "res://assets/sounds/generated/m5_surge.wav",
    "boss": "res://assets/sounds/generated/m5_boss.wav"
}
const MIN_GAPS = {"hit": 0.085, "kill": 0.10, "pickup": 0.055, "hurt": 0.16,
    "surge": 0.25, "boss": 0.25}

var sounds: Dictionary = {}
var last_played: Dictionary = {}
var channels: Array[AudioStreamPlayer] = []

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    for name in SOUND_PATHS:
        var stream: Resource = load(String(SOUND_PATHS[name]))
        if stream is AudioStream:
            sounds[name] = stream
    for i in range(8):
        var channel := AudioStreamPlayer.new()
        add_child(channel)
        channels.append(channel)

func play_event(event_name: String) -> void:
    if not sounds.has(event_name) or get_tree().paused:
        return
    var now: float = float(Time.get_ticks_msec()) / 1000.0
    var previous: float = float(last_played.get(event_name, -100.0))
    if now - previous < float(MIN_GAPS.get(event_name, 0.10)):
        return
    for channel in channels:
        if not channel.playing:
            last_played[event_name] = now
            channel.stream = sounds[event_name]
            channel.pitch_scale = randf_range(0.96, 1.06) if event_name == "hit" else 1.0
            channel.volume_db = -24.0 if event_name == "hit" else (-18.0 if event_name == "pickup" else -13.0)
            channel.play()
            return
