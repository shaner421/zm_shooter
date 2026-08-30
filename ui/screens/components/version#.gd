extends Label

## Shows the current git commit description in the corner of the screen
## while testing from the editor. Does nothing in exported builds, since
## there is no .git folder to query once the project has been exported, and
## this is only meant as a local development aid.

## Arguments passed to git. --always falls back to a short commit hash if no
## tags exist yet. --dirty appends "-dirty" if there are uncommitted changes
## at the moment this runs, which matters more day to day than the commit
## itself, since it flags "this is not exactly what's committed."
const GIT_DESCRIBE_ARGS: PackedStringArray = ["describe", "--always", "--dirty"]

## Text color when the working tree has uncommitted changes.
const DIRTY_COLOR: Color = Color(0.9, 0.25, 0.25)

## Text color when the working tree matches the shown commit exactly.
const CLEAN_COLOR: Color = Color(0.35, 0.85, 0.35)

## Text color when git could not be queried at all, distinct from both clean
## and dirty since neither of those is actually known in this case.
const UNKNOWN_COLOR: Color = Color(0.7, 0.7, 0.7)


func _ready() -> void:
	if not OS.has_feature("editor"):
		hide()
		return

	var version_string: String = _get_git_version_string()
	text = "Version #" + version_string
	add_theme_color_override("font_color", _get_color_for(version_string))
	tooltip_text = _get_tooltip_for(version_string)


## Runs git describe once and returns its trimmed output, or a fallback
## string if git is not installed, this is not a git repository, or the
## command otherwise fails for any reason. Called once at startup, not
## re-queried while the game runs, since shelling out is not free and the
## version does not change mid-session anyway.
func _get_git_version_string() -> String:
	var output: Array = []
	var exit_code: int = OS.execute("git", GIT_DESCRIBE_ARGS, output, true)

	if exit_code != 0 or output.is_empty():
		return "unknown build"

	var result: String = String(output[0]).strip_edges()
	return result if not result.is_empty() else "unknown build"


## Picks a text color based on what version_string reports. Checked as a
## suffix rather than an equality check, since the dirty flag from git
## describe is always appended at the end of whatever hash or tag precedes
## it, never on its own.
func _get_color_for(version_string: String) -> Color:
	if version_string == "unknown build":
		return UNKNOWN_COLOR

	if version_string.ends_with("-dirty"):
		return DIRTY_COLOR

	return CLEAN_COLOR


## Builds the hover explanation shown alongside the color, spelling out what
## clean, dirty, and unknown actually mean, since the color alone does not
## explain itself to anyone glancing at it for the first time.
func _get_tooltip_for(version_string: String) -> String:
	if version_string == "unknown build":
		return "Git could not be queried. Git may not be installed, or this is not a git repository."

	if version_string.ends_with("-dirty"):
		return "Uncommitted changes are present. This build does not exactly match commit %s." % version_string.trim_suffix("-dirty")

	return "Working tree is clean. This build exactly matches commit %s." % version_string
