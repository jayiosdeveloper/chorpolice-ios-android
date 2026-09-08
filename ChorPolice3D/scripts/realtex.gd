## RealTex — builds PBR StandardMaterial3D from the downloaded ambientCG texture sets
## (assets/real/tex/<name>/<ID>_Color|NormalGL|Roughness|AmbientOcclusion|Metalness.jpg).
## Materials are cached and shared. `uv` is the world-space tile size in metres.
class_name RealTex
extends RefCounted

const DIR := "res://assets/real/tex/"
# folder name → the ambientCG asset id prefix inside it
const IDS := {
	"ground_sand": "Ground054", "ground_gravel": "Gravel022", "ground_dirt": "Ground037",
	"rock": "Rock030", "concrete": "Concrete034", "metal_rusted": "Metal046A",
	"metal_plate": "MetalPlates006", "wood_planks": "Planks011", "sandbag_fabric": "Fabric063",
	"brick": "Bricks075A", "roof_tiles": "RoofingTiles005", "asphalt": "Asphalt014",
	"desert_sand": "desert_sand", "sand_gravel": "sand_gravel", "ground_rock": "ground_rock",
	"meadow_grass": "meadow_grass", "leafy_grass": "leafy_grass",
	"forest_grass": "forest_grass", "forest_floor": "forest_floor", "forest_leaves": "forest_leaves", "mud_leaves": "mud_leaves", "rocky_ground": "rocky_ground", "forest_moss": "forest_moss",
}

static var _cache := {}

static func _load(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null

## Build (or fetch) a material. name = folder key. uv = tiles in metres (bigger = larger pattern).
## triplanar covers boxes/terrain without UVs; tint multiplies the albedo (Color.WHITE = none).
static func mat(name: String, uv := 2.0, triplanar := true, tint := Color.WHITE, rough_mul := 1.0, parallax := false) -> StandardMaterial3D:
	var key := "%s|%.2f|%s|%s|%.2f|%s" % [name, uv, triplanar, tint.to_html(), rough_mul, parallax]
	if _cache.has(key):
		return _cache[key]
	var id: String = IDS.get(name, "")
	var base := "%s%s/%s_1K-JPG_" % [DIR, name, id]
	var m := StandardMaterial3D.new()
	var col := _load(base + "Color.jpg")
	if col:
		m.albedo_texture = col
	m.albedo_color = tint
	var nrm := _load(base + "NormalGL.jpg")
	if nrm:
		m.normal_enabled = true
		m.normal_texture = nrm
	var rgh := _load(base + "Roughness.jpg")
	if rgh:
		m.roughness_texture = rgh
		m.roughness = rough_mul
	var ao := _load(base + "AmbientOcclusion.jpg")
	if ao:
		m.ao_enabled = true
		m.ao_texture = ao
	var met := _load(base + "Metalness.jpg")
	if met:
		m.metallic_texture = met
		m.metallic = 1.0
	if triplanar and not parallax:
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE / uv
	else:
		m.uv1_scale = Vector3(uv, uv, uv)
	if parallax:
		var disp := _load(base + "Displacement.jpg")
		if disp:
			m.heightmap_enabled = true
			m.heightmap_texture = disp
			m.heightmap_scale = 0.35
			m.heightmap_deep_parallax = true
			m.heightmap_min_layers = 4
			m.heightmap_max_layers = 16
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[key] = m
	return m

static func has_assets() -> bool:
	return ResourceLoader.exists(DIR + "ground_sand/Ground054_1K-JPG_Color.jpg")

## The HDRI sky panorama for a named sky (assets/real/sky/<name>.hdr), or null.
static func sky(name: String) -> Texture2D:
	var p := "res://assets/real/sky/%s.hdr" % name
	return load(p) if ResourceLoader.exists(p) else null
