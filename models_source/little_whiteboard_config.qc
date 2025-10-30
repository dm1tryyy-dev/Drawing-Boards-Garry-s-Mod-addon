$modelname "drawing_boards/models/boards/little_whiteboard/little_whiteboard.mdl"
$cdmaterials "models/boards_materials/whiteboard"
$cdmaterials "models/boards_materials/whiteboard/little_whiteboard"
$surfaceprop "metal"
$scale 39.37
$mostlyopaque
$ambientboost

$body base "models/little_whiteboard/little_whiteboard.smd"
$body back "models/little_whiteboard/back.smd"
$body gears "models/little_whiteboard/gears.smd"
$body screws "models/little_whiteboard/screws.smd"

$texturegroup "skins"
{
	{ "Frame", "Front", "Back", "Screws", "Legs", "Gears" }
}

$collisionmodel "models/little_whiteboard/little_whiteboard.smd"
{
	$mass 6.0
	$concave
	$maxconvexpieces 160
}

$sequence idle "models/little_whiteboard/little_whiteboard.smd" act_idle 1 fps 30.00