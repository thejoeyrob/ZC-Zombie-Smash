extends SceneTree
const IDS := ["human_joeyrob", "human_drmantis", "human_fatamy", "human_glowing", "human_caffeinatedsloth"]
var failures := 0
func check(ok: bool, message: String) -> void:
    if not ok: push_error(message); failures += 1
func _initialize() -> void:
    run.call_deferred()
func run() -> void:
    for id in IDS:
        var rig := HumanRig.new();root.add_child(rig)
        check(rig.build(id,true), "Missing rig " + id)
        check(rig.skeleton.get_bone_count() == 82, "Wrong bone count")
        for part in ["Head", "LEye", "REye", "L Hand", "R Hand", "L Finger02", "R Finger42"]:
            check(rig.bone(part) >= 0, "Missing joint " + part)
        for mode in ["full", "arms", "hands"]:
            rig.set_body_mode(mode)
            for group in rig.body_parts:
                var expected: bool = group.ends_with("hands") or (group.ends_with("arms") and mode != "hands") or (group == "body" and mode == "full")
                for mesh in rig.body_parts[group]:
                    check(mesh.visible == expected, id + " visibility " + group + " " + mode)
                    for surface in range(mesh.mesh.get_surface_count()):
                        check(mesh.mesh.surface_get_material(surface) != null, "Missing material")
                        var arrays: Array = mesh.mesh.surface_get_arrays(surface)
                        for vertex in arrays[Mesh.ARRAY_VERTEX]: check(vertex.is_finite(), "Nonfinite vertex")
        rig.tracked = [false,true];rig.set_body_mode("hands")
        for mesh in rig.body_parts.left_hands: check(not mesh.visible, "Left tracking-loss visibility")
        for mesh in rig.body_parts.right_hands: check(mesh.visible, "Right tracking-loss visibility")
        rig.free()
    print("STAGE1 VISIBILITY PASS" if failures == 0 else "STAGE1 VISIBILITY FAIL")
    quit(1 if failures else 0)
