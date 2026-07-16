class_name ResourceJanitor
## M0 (Build 004): los caches ESTÁTICOS de materiales/meshes compartidos
## viven hasta después de que el RenderingServer haga su limpieza — el
## runner de tests salía con «RID leaked» y «resources still in use».
## Este barrendero los suelta a demanda (runner y cierres controlados).


static func release_static_caches() -> void:
	MeshLib._materials.clear()
	TreeGen._canopy_materials.clear()
	TreeGen._scenes.clear()
	TreeGen._trunk_mat = null
	PropGen._wind_materials.clear()
	PropGen._mesh_cache.clear()
	TerrainChunk._grass_mesh = null
	TerrainChunk._grass_material = null
	MapGenerator._shared_material = null
	TreeEntity._outline_hover = null
	TreeEntity._outline_marked = null
	TreeEntity._outline_invalid = null
	PaletteData._instance = null
	SimConfig._instance = null
	CameraConfig._instance = null
