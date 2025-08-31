extends Node3D

# ===== CONFIG =====
const SETTINGS_PATH = "/root/Map/Core/UI/UI_Settings"
const DEBUG = false  # Toggle for debug prints

# ===== GAME DATA =====
var gameData = preload("res://Resources/GameData.tres")
var preferences: Preferences = load("user://Preferences.tres") as Preferences
@onready var settings = get_node_or_null(SETTINGS_PATH) as Settings

# ===== TIME & WEATHER =====
var next_phase = {1: 2, 2: 3, 3: 4, 4: 1}
var phase_names = {1: "Dawn", 2: "Day", 3: "Dusk", 4: "Night"}
var weather_choices = [
    {"id": 1, "chance": 45}, # Neutral
    {"id": 2, "chance": 25}, # Dark
    {"id": 3, "chance": 15}, # Rain
    {"id": 4, "chance": 15}  # Storm
]
var fade_rect: ColorRect = null
var fade_tween: Tween = null

# ===== FUNCTIONS =====
func _ready():
    # Small delay to ensure all nodes are loaded before accessing preferences
    await get_tree().create_timer(1).timeout

    preferences = Preferences.Load()

    if preferences == null:
        _debug("Preferences failed to load, creating new file.")
        preferences = Preferences.new()
        preferences.Save()
        return

    if settings == null:
        settings = _find_settings()
        if settings == null:
            _debug("Settings failed to load or be found!")

    # Create fade rect dynamically if not already present
    _ensure_fade_rect()


func Interact():
    """
    Called when the player interacts (e.g., sleeps).
    Updates time-of-day, weather, and applies these changes to the game world.
    """

    await fade_out(1.0)  # fade to black

    _debug("Current TOD before change: %s" % preferences.TOD)
    preferences.TOD = next_phase.get(preferences.TOD, 1)
    gameData.TOD = preferences.TOD
    _debug("New TOD after change: %s" % preferences.TOD)

    var weather = _pick_weather()
    preferences.weather = weather
    gameData.weather = preferences.weather
    _debug("New weather ID: %s" % preferences.weather)

    preferences.Save()

    settings = _find_settings()

    if settings:
        _debug("Updating world via settings...")
        settings.UpdateWorld()
        settings.preferences = Preferences.Load()
        settings.LoadPreferences()
    else:
        _debug("Settings node is null, world not updated.")

    await fade_in(1.0)  # fade to black

func UpdateTooltip():
    """
    Updates the tooltip text to show the next time-of-day phase.
    """
    if preferences == null:
        gameData.tooltip = "Sleep until Unknown"
        return

    var next_tod = next_phase.get(preferences.TOD, 1)
    var next_name = phase_names.get(next_tod, "Unknown")
    gameData.tooltip = "Sleep until %s" % next_name


func _pick_weather():
    """
    Randomly selects a weather type based on weighted chances.
    """
    var roll = randi() % 100
    var total = 0
    for w in weather_choices:
        total += w.chance
        if roll < total:
            return w.id
    return 1  # Default to Neutral


func _find_settings():
    """
    Attempts to locate the settings UI node.
    First tries the known path, then searches recursively.
    """
    var _settings = get_node_or_null(SETTINGS_PATH)
    if _settings:
        _debug("Settings found at %s" % _settings.get_path())
        return _settings
    
    var map = get_node_or_null("/root/Map")
    if map:
        for node in map.get_children():
            var found = node.find_child("UI_Settings", true, false)
            if found:
                _debug("Settings found at %s" % found.get_path())
                return found
    return null

func fade_out(duration: float = 1.0) -> void:
    """
    Gradually fades the screen to black over `duration` seconds.
    Freezes player movement while fading. Uses a ColorRect overlay with a tween.
    """
    _ensure_fade_rect()
    fade_rect.visible = true
    fade_rect.color.a = 0.0

    gameData.freeze = true  # Prevent player movement during fade.

    if fade_tween:
        fade_tween.kill()  # Stop any ongoing fade to avoid conflicts.

    fade_tween = get_tree().create_tween()  # Create a new tween.
    fade_tween.tween_property(fade_rect, "color:a", 1.0, duration)
    # Animate alpha from 0 → 1 over the given duration.
    await fade_tween.finished  # Wait until the fade is complete.


func fade_in(duration: float = 1.0) -> void:
    """
    Gradually fades the screen from black to visible over `duration` seconds.
    Unfreezes player movement immediately. Hides the overlay after fading.
    """
    _ensure_fade_rect()
    fade_rect.visible = true
    fade_rect.color.a = 1.0

    gameData.freeze = false  # Allow player movement again.

    if fade_tween:
        fade_tween.kill()  # Stop any ongoing fade to avoid conflicts.

    fade_tween = get_tree().create_tween()  # Create a new tween.
    fade_tween.tween_property(fade_rect, "color:a", 0.0, duration)
    # Animate alpha from 1 → 0 over the given duration.
    await fade_tween.finished  # Wait until the fade is complete.
    fade_rect.visible = false  # Hide the overlay once done.


func _ensure_fade_rect():
    """
    Ensures the fade overlay exists and is properly configured.
    Creates a ColorRect that covers the screen and blocks input if needed.
    """
    if fade_rect == null or not is_instance_valid(fade_rect):
        fade_rect = ColorRect.new()
        fade_rect.name = "FadeRect"
        fade_rect.color = Color(0, 0, 0, 0)  # Transparent black
        fade_rect.visible = false
        fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)  # Fill screen
        fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input
        get_tree().root.add_child(fade_rect)  # Add to scene tree
        fade_rect.move_to_front()  # Keep on top of all UI

# ===== DEBUG HELPER =====
func _debug(message: String):
    if DEBUG:
        print("Mod: %s" % message)
