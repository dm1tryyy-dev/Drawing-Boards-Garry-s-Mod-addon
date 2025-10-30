$modelname "drawing_boards/models/boards/chalkboard/chalkboard.mdl"
$cdmaterials "models/boards_materials/chalkboard/"
$cdmaterials "models/boards_materials/chalkboard/frame"
$cdmaterials "models/boards_materials/chalkboard/etc"
$mostlyopaque
$ambientboost
$scale 39.37
$surfaceprop "metal"

$model chalkboard "models/chalkboard/chalkboard.smd"

$bodygroup lamp
{
	studio  "models/chalkboard/lamp.smd"
	blank
}

$bodygroup chalkshelf
{
	studio "models/chalkboard/chalkshelf.smd"
	blank
}

$texturegroup "skins"
{
	{ "FrameWood", "Face", "Chalks", "ChalkShelf", "Lamp", "LampBody", "Light", "Screw", "Sponge" }
}


$collisionmodel "models/chalkboard/chalkboard.smd"
{
	$mass 20
	$concave
	$maxconvexpieces 200
}

$sequence idle "models/chalkboard/chalkboard.smd" act_idle 1 fps 30.00