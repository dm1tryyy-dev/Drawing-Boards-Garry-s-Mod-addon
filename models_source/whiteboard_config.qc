$modelname "drawing_boards/models/boards/whiteboard/whiteboard.mdl"
$cdmaterials "models/boards_materials/whiteboard"
$mostlyopaque
$ambientboost
$scale 39.37
$surfaceprop "metal"

$model "whiteboard" "models/whiteboard/whiteboard.smd"

$bodygroup lamp
{
	studio "models/whiteboard/lamp.smd"
	blank
}

$texturegroup "skins"
{
	{ "FrameMetall", "Front", "Lamp", "LampBody", "Light", "Screw"}
}

$collisionmodel "models/whiteboard/whiteboard.smd"
{
	$mass 20
	$concave
	$maxconvexpieces 80
}

$sequence idle "models/whiteboard/whiteboard.smd" act_idle 1 fps 30.00