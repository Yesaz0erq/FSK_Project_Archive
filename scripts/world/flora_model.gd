extends Node3D
## Rigid meshes share one draw surface per moving organ. Pivots retain the
## axes, local rest transforms and phase offsets from the source model.
const PAINT := preload("res://assets/models/flora/surface_paint.tres")
static var _finishes: Dictionary = {}
var _joints: Array[Dictionary] = []
var _meshes: Array[MeshInstance3D] = []
var _finish := Color.WHITE

func _ready() -> void:
	for part: Node in find_children("*", "MeshInstance3D", true, false):
		_meshes.append(part)
	for pivot: Node3D in find_children("Pivot*", "Node3D", true, false):
		_joints.append({"node": pivot, "rest":pivot.transform, "kind":pivot.get_meta("motion"),
			"axis":pivot.get_meta("axis"), "amount":pivot.get_meta("amount"), "offset":pivot.get_meta("offset")})
	pose(0.0)

func pose(cycles: float) -> void:
	for joint: Dictionary in _joints:
		var next: Transform3D = joint.rest
		var angle := TAU * (cycles + float(joint.offset))
		var axis: Vector3 = joint.axis
		var amount: float = joint.amount
		if joint.kind == "slide":
			next.origin += axis * sin(angle) * amount
		else:
			var turn := angle * amount if joint.kind == "spin" else sin(angle) * amount
			next.basis = next.basis * Basis(axis, turn)
		joint.node.transform = next

func set_finish(tint: Color) -> void:
	if _finish == tint: return
	_finish = tint
	if tint != Color.WHITE and not _finishes.has(tint):
		var finish: ShaderMaterial = PAINT.duplicate()
		finish.set_shader_parameter("finish", tint)
		_finishes[tint] = finish
	for part in _meshes:
		part.material_override = _finishes.get(tint)
