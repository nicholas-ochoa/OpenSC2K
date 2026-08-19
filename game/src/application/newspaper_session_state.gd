class_name NewspaperSessionState
extends RefCounted


var session_seed := 0
var session_state := PackedByteArray()
# the founding newspaper opens after the new city view is visible
var founding_pending := false
