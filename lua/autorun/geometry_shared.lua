-- ============================================================
-- DrawingGeometry: общие определения (shared)
-- Геометрические режимы для инструментов рисования (Chalk / Marker)
-- ============================================================
if DrawingGeometry and DrawingGeometry._LOADED then
    return
end

DrawingGeometry = DrawingGeometry or {}

-- Режимы (индексы 00..04)
DrawingGeometry.MODES = {
    [0] = { id = 0, name = "brush",     label = "Brush",     icon = "brush" },
    [1] = { id = 1, name = "line",      label = "Line",      icon = "line" },
    [2] = { id = 2, name = "circle",    label = "Circle",    icon = "circle" },
    [3] = { id = 3, name = "arrow",     label = "Arrow",     icon = "arrow" },
    [4] = { id = 4, name = "rectangle", label = "Rectangle", icon = "rect" },
}

DrawingGeometry.MODE_COUNT = 5
DrawingGeometry.MODE_BRUSH = 0

-- Единый список досок по классам оружия.
-- Используется и на клиенте, и на сервере для валидации цели.
DrawingGeometry.BOARDS = {
    chalk_tool = {
        ["chalkboard"]           = true,
        ["chalkboard_oversized"] = true,
    },
    marker_tool = {
        ["whiteboard"]           = true,
        ["little_whiteboard"]    = true,
        ["whiteboard_oversized"] = true,
        ["tech_panel"]           = true,
        ["tech_panel_oversized"] = true,
    },
}

-- Проверка: является ли entity допустимой доской для данного класса оружия.
-- weaponClass: "chalk_tool" или "marker_tool"
function DrawingGeometry.IsValidBoard(ent, weaponClass)
    if not IsValid(ent) then return false end
    local list = DrawingGeometry.BOARDS[weaponClass]
    if not list then return false end
    return list[ent:GetClass()] == true
end