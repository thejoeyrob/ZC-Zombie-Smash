extends RefCounted
## Stable appearance IDs; the existing IK, controls and networking remain in charge.
const MODELS := {
    "human_joeyrob": "joeyrob",
    "human_drmantis": "drmantis",
    "human_fatamy": "fatamy",
    "human_glowing": "glowinghumanity",
    "human_caffeinatedsloth": "caffeinatedsloth"
}
static func model_path(profile: String) -> String:
    if not MODELS.has(profile): return ""
    return "res://avatars/stage1/" + MODELS[profile] + "/avatar.glb"
