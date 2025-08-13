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


func Interact():
    """
    Called when the player interacts (e.g., sleeps).
    Updates time-of-day, weather, and applies these changes to the game world.
    """

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


# ===== DEBUG HELPER =====
func _debug(message: String):
    if DEBUG:
        print("Mod: %s" % message)
