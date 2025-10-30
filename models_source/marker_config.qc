$modelname "drawing_boards/models/tools/marker_tool.mdl"
$cdmaterials "models/tools_materials/marker"
$surfaceprop "plastic"
$scale 39.37
$mostlyopaque
$ambientboost

$model "marker" "models/marker.smd"

$texturegroup "skins"
{
	{ "Body", "Color", "Marker", "Marker2" }
}

$collisionmodel "models/marker.smd"
{
	$mass 0.4
	$concave
	$maxconvexpieces 20
}

$sequence idle "models/marker.smd" act_idle 1 fps 30.00