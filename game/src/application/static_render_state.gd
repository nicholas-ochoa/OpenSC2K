class_name StaticRenderState
extends RefCounted


var task: CityRenderTask
var job: CityRenderJob

var epoch := 0
var last_started_msec := -ApplicationStaticRender.ACTIVE_DISASTER_RENDER_INTERVAL_MSEC
# a render was requested while a job ran or during the active disaster interval
var pending := false
