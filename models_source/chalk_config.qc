$modelname "drawing_boards/models/tools/chalk_tool.mdl"
$cdmaterials "models/tools_materials/chalk"
$surfaceprop "plastic"
$scale 39.37
$mostlyopaque
$ambientboost

$model "chalk" "models/chalk.smd"
$texturegroup "skins"
{
	{ "Main" }
}

$collisionmodel "models/chalk.smd"
{
	$mass 0.4
	$concave
	$maxconvexpieces 8
}

$sequence idle "models/chalk.smd" act_idle 1 fps 30.00