extends Node

# Game data reference (persistent settings & world state)
var gameData = preload("res://Resources/GameData.tres")

# Constants for sofa handling
const INTERACTABLE_GROUP := "Interactable"
const MOD_SCRIPT_PATH := "res://LetMeSleep/Sofa_Leather.gd"
const SOFA_PATH := "/root/Map/Content/Props/Sofa_Leather" # Exact sofa path if known
const STATIC_BODY_PATH := "Collider/StaticBody3D"         # Path to collision body in sofa

# Tracks if our mod has already been attached to a sofa
var sofa_hooked := false


func _ready():
    # Enable processing only if we start inside a shelter
    if gameData.shelter:
        set_process(true)


func _process(delta):
    # If not in a shelter, don't hook sofas and reset state
    if not gameData.shelter:
        sofa_hooked = false
        return
    
    # Try to find a sofa in the scene
    var sofa = _find_sofa()

    # If we find a sofa and it's not yet hooked, attach our mod
    if sofa and not sofa_hooked:
        _apply_mod_to_sofa(sofa)
        sofa_hooked = true

    # If no sofa found, mark it unhooked so we can reattach later
    elif not sofa:
        sofa_hooked = false


func _find_sofa():
    """
    Attempts to locate the target sofa in the scene.
    First tries the exact known path, then searches recursively by name.
    Returns the sofa Node if found, otherwise null.
    """
    # Try exact path first
    var sofa = get_node_or_null(SOFA_PATH)
    if sofa:
        return sofa
    
    # If exact path fails, search inside the map
    var map = get_node_or_null("/root/Map")
    if map:
        for node in map.get_children():
            var found = node.find_child("Sofa_Leather", true, false)
            if found:
                return found
    return null


func _apply_mod_to_sofa(sofa: Node):
    """
    Attaches the mod script to the sofa if not already present,
    and adds its collider to the interactable group.
    """
    # Attach our mod script if sofa has no script already
    if not sofa.get_script():
        sofa.set_script(load(MOD_SCRIPT_PATH))

    # Add the collision body to the interactable group
    var collision = sofa.get_node_or_null(STATIC_BODY_PATH)
    if collision:
        collision.add_to_group(INTERACTABLE_GROUP)
