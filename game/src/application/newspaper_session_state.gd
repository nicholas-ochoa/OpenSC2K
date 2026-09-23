class_name NewspaperSessionState
extends RefCounted


var session_seed := 0
var session_state := PackedByteArray()
# the founding newspaper opens after the new city view is visible
var founding_pending := false
# a newspaper that the simulation opened. the original shows it as a modal
# window, so the simulation waits until the player closes it
var scheduled_pending := false
