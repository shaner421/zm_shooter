extends SubViewportContainer

## Renders whatever 3D content lives inside its SubViewport at a reduced
## internal resolution, then stretches the result back up using
## nearest-neighbor filtering instead of smoothing, producing the blocky,
## low-res look associated with PSX-era 3D games. UI placed as a sibling
## outside this node, not inside the SubViewport, renders at full native
## resolution and is entirely unaffected by this.

## How many times smaller than this container's actual size the SubViewport
## renders internally. 4 means a 1280x720 container renders its 3D content
## at 320x180 before stretching back up. Higher values look chunkier and
## render faster, lower values look closer to native resolution.
@export_range(1, 16, 1) var resolution_divisor: int = 4:
	set(value):
		resolution_divisor = value
		stretch_shrink = value

@onready var world: SubViewport = %World


func _ready() -> void:
	stretch = true
	stretch_shrink = resolution_divisor
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
