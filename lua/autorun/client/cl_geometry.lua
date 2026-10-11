-- ============================================================
-- DrawingGeometry: клиентская часть
-- HUD, превью, переключение режимов, отправка финальной фигуры
-- ============================================================

if not CLIENT then return end

if not DrawingGeometry or not DrawingGeometry.IsValidBoard then
    include("autorun/geometry_shared.lua")
end

if not DrawingGeometry or not DrawingGeometry.IsValidBoard then
    print("[DB] ERROR: geometry_shared.lua not loaded!")
    return
end

DrawingGeometry.State = DrawingGeometry.State or {
    Mode           = 0,
    Holding        = false,
    StartPos       = nil,
    StartEnt       = nil,
    EndPos         = nil,
    EndEnt         = nil,
    ShiftHeld      = false,
    HudAlpha       = 0,
    ModeScale      = {},
    _middlePressed = false,
}

-- ============================================================
-- Шрифты
-- ============================================================

surface.CreateFont("DrawingGeometry_IndexFont", {
    font = "Verdana", size = 16, weight = 700, antialias = true,
})

surface.CreateFont("DrawingGeometry_LabelFont", {
    font = "Verdana", size = 25, weight = 600, antialias = true,
})

surface.CreateFont("DrawingGeometry_HintFont", {
    font = "Verdana", size = 15, weight = 700, antialias = true,
})

-- ============================================================
-- Иконки
-- ============================================================

local ICON_SIZE  = 23
local ICON_PAD   = 8
local CELL_GAP   = 11
local HUD_PADDING = 10
local HUD_Y_OFFSET = 50
local ICON_OFFSET_X = 1
local ICON_OFFSET_Y = 0

-- ============================================================
-- Иконки из PNG (materials/vgui/icons/)
-- ============================================================

DrawingGeometry.IconMaterials = DrawingGeometry.IconMaterials or {
    [0] = Material("vgui/icons/brush.png",  "mips smooth"),
    [1] = Material("vgui/icons/line.png",   "mips smooth"),
    [2] = Material("vgui/icons/circle.png", "mips smooth"),
    [3] = Material("vgui/icons/arrow.png",  "mips smooth"),
    [4] = Material("vgui/icons/rect.png",   "mips smooth"),
}

-- Индивидуальный масштаб картинки внутри ячейки для каждой иконки.
-- 1.0 = стандарт, >1.0 = картинка крупнее, <1.0 = мельче.
local ICON_INNER_SCALE = {
    [0] = 1.30,  -- brush  (увеличил, т.к. линии тонкие)
    [1] = 1.00,  -- line
    [2] = 1.00,  -- circle
    [3] = 1.00,  -- arrow
    [4] = 1.00,  -- rect
}

local function DrawIconFromMaterial(modeId)
    return function(x, y, s, a, col)
        local mat = DrawingGeometry.IconMaterials[modeId]
        if not mat or mat:IsError() then
            surface.SetDrawColor(255, 0, 0, a)
            surface.DrawLine(x, y, x + s, y + s)
            surface.DrawLine(x + s, y, x, y + s)
            return
        end

        -- Индивидуальный масштаб
        local innerScale = ICON_INNER_SCALE[modeId] or 1.0
        local ds = s * innerScale
        local dx = x + (s - ds) / 2
        local dy = y + (s - ds) / 2

        surface.SetMaterial(mat)

        -- Чёрный контур (со сдвигом тоже учитываем масштаб)
        surface.SetDrawColor(0, 0, 0, a)
        local offsets = {
            {-1, 0}, {1, 0}, {0, -1}, {0, 1},
            {-1, -1}, {1, -1}, {-1, 1}, {1, 1},
        }
        for _, off in ipairs(offsets) do
            surface.DrawTexturedRect(dx + off[1], dy + off[2], ds, ds)
        end

        -- Сама иконка
        local iconCol = col or Color(255, 255, 255)
        surface.SetDrawColor(iconCol.r, iconCol.g, iconCol.b, a)
        surface.DrawTexturedRect(dx, dy, ds, ds)
    end
end

DrawingGeometry.IconDrawers = DrawingGeometry.IconDrawers or {
    [0] = DrawIconFromMaterial(0),
    [1] = DrawIconFromMaterial(1),
    [2] = DrawIconFromMaterial(2),
    [3] = DrawIconFromMaterial(3),
    [4] = DrawIconFromMaterial(4),
}

DrawingGeometry.MODES = DrawingGeometry.MODES or {
    [0] = { id = 0, name = "brush",     label = "Brush"     },
    [1] = { id = 1, name = "line",      label = "Line"      },
    [2] = { id = 2, name = "circle",    label = "Circle"    },
    [3] = { id = 3, name = "arrow",     label = "Arrow"     },
    [4] = { id = 4, name = "rectangle", label = "Rectangle" },
}

-- ============================================================
-- Утилиты
-- ============================================================

local function GetActiveDrawingWeapon()
    local ply = LocalPlayer()
    if not IsValid(ply) then return nil end
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return nil end
    local class = wep:GetClass()
    if class == "chalk_tool" or class == "marker_tool" then
        return wep
    end
    return nil
end

local function GetPlayerMarkColor()
    local wep = GetActiveDrawingWeapon()
    if not IsValid(wep) then return Color(255, 255, 255) end
    if wep.GetDrawColor then
        local c = wep:GetDrawColor()
        if c then return c end
    end
    return Color(255, 255, 255)
end

-- ============================================================
-- IsGeometryMode
-- ============================================================

function DrawingGeometry.IsGeometryMode()
    if not DrawingGeometry.State then return false end
    if DrawingGeometry.State.Mode == nil then return false end
    local brush = DrawingGeometry.MODE_BRUSH or 0
    return DrawingGeometry.State.Mode ~= brush
end

-- ============================================================
-- HUD
-- ============================================================

function DrawingGeometry.DrawHUD()
    local wep = GetActiveDrawingWeapon()
    if not IsValid(wep) then
        DrawingGeometry.State.HudAlpha = math.max(
            0, DrawingGeometry.State.HudAlpha - FrameTime() * 4
        )
        if DrawingGeometry.State.HudAlpha <= 0 then return end
    else
        DrawingGeometry.State.HudAlpha = math.min(
            1, DrawingGeometry.State.HudAlpha + FrameTime() * 4
        )
    end

    local alpha = DrawingGeometry.State.HudAlpha
    if alpha <= 0.01 then return end

    local mode = DrawingGeometry.State.Mode
    local accent = GetPlayerMarkColor()

    local count = DrawingGeometry.MODE_COUNT
    local cellW = ICON_SIZE + ICON_PAD * 2
    local cellH = ICON_SIZE + ICON_PAD * 2
    local gap = CELL_GAP

    local totalW = count * cellW + (count - 1) * gap

    -- Высоты отдельных строк
    local INDEX_H = 22   -- строка с номерами 00-04
    local HINT_H  = 26   -- строка с SHIFT + SCROLL

    -- Фон охватывает иконки + строку индексов
    local bgH = cellH + INDEX_H + HUD_PADDING

    local baseX = ScrW() / 2 - totalW / 2
    local baseY = ScrH() - HUD_Y_OFFSET - (bgH + HINT_H + 8)

    -- Фон HUD
    draw.RoundedBox(10,
        baseX - HUD_PADDING,
        baseY - HUD_PADDING,
        totalW + HUD_PADDING * 2,
        bgH,
        Color(20, 22, 28, 150 * alpha))

    -- Иконки
    for i = 0, count - 1 do
        local modeData = DrawingGeometry.MODES[i]
        if modeData then
            local isActive = (i == mode)

            DrawingGeometry.State.ModeScale[i] = DrawingGeometry.State.ModeScale[i]
                or (isActive and 1.15 or 0.95)
            local targetScale = isActive and 1.15 or 0.95
            DrawingGeometry.State.ModeScale[i] = Lerp(
                FrameTime() * 10,
                DrawingGeometry.State.ModeScale[i],
                targetScale
            )

            local scale = DrawingGeometry.State.ModeScale[i]
            local cx = baseX + i * (cellW + gap) + cellW / 2 + ICON_OFFSET_X
            local cy = baseY + cellH / 2 + ICON_OFFSET_Y

            local drawW = cellW * scale
            local drawH = cellH * scale
            local dx = cx - drawW / 2
            local dy = cy - drawH / 2

            -- Фон ячейки — тот же цвет, что и рамка
            local bgCol = isActive
                and Color(accent.r, accent.g, accent.b, 60 * alpha)
                or  Color(50, 55, 65, 200 * alpha)

            -- Фон ячейки (прямые углы, без скруглений)
            surface.SetDrawColor(bgCol)
            surface.DrawRect(dx, dy, drawW, drawH)

            -- Рамка (тот же цвет, что и фон, но плотнее)
            local borderCol = isActive
                and Color(accent.r, accent.g, accent.b, 240 * alpha)
                or  Color(90, 100, 115, 200 * alpha)

            surface.SetDrawColor(borderCol)
            surface.DrawOutlinedRect(dx, dy, drawW, drawH)

            
                        
            local iconAlpha = isActive and (255 * alpha) or (200 * alpha)
            local iconCol
            if isActive then
                iconCol = Color(accent.r, accent.g, accent.b, 255)
            else
                iconCol = Color(220, 220, 220, 220)
            end

            local drawer = DrawingGeometry.IconDrawers[i]
            if drawer then
                drawer(dx + ICON_PAD * scale, dy + ICON_PAD * scale,
                    ICON_SIZE * scale, iconAlpha, iconCol)
            end
        end
    end

    -- Номера 00-04 — ВНУТРИ фона, под иконками
    for i = 0, count - 1 do
        local isActive = (i == mode)
        local cx = baseX + i * (cellW + gap) + cellW / 2 + ICON_OFFSET_X

        local idxText = string.format("%02d", i)
        local idxCol
        if isActive then
            idxCol = Color(accent.r, accent.g, accent.b, 255 * alpha)
        else
            idxCol = Color(250, 250, 250, 180 * alpha)
        end

        local idxCenterY = baseY + cellH + INDEX_H / 2 + ICON_OFFSET_Y

        draw.SimpleText(idxText, "DrawingGeometry_IndexFont",
            cx, idxCenterY,
            idxCol,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Подпись режима — над фоном
        -- Подпись режима — над фоном, с чёрным контуром
    local modeData = DrawingGeometry.MODES[mode]
    if modeData then
        local labelX = ScrW() / 2
        local labelY = baseY - HUD_PADDING - 10
        local labelText = modeData.label
        local labelFont = "DrawingGeometry_LabelFont"

        local outlineCol = Color(0, 0, 0, 255 * alpha)
        local fillCol    = Color(accent.r, accent.g, accent.b, 255 * alpha)

        -- Чёрный контур: 8 направлений вокруг текста
        local offsets = {
            {-1,  0}, { 1,  0}, { 0, -1}, { 0,  1},
            {-1, -1}, { 1, -1}, {-1,  1}, { 1,  1},
        }
        for _, off in ipairs(offsets) do
            draw.SimpleText(labelText, labelFont,
                labelX + off[1], labelY + off[2],
                outlineCol,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
        end

        -- Сам текст поверх контура
        draw.SimpleText(labelText, labelFont,
            labelX, labelY,
            fillCol,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
    end

    -- Жёлтая подсказка SHIFT + SCROLL — под фоном HUD
    local hintText = "SHIFT + SCROLL"
    surface.SetFont("DrawingGeometry_HintFont")
    local hintTw = surface.GetTextSize(hintText)

    local hintPadX = 13
    local hintW = hintTw + hintPadX * 3
    local hintH = HINT_H

    local hintY = baseY - HUD_PADDING + bgH + 10

    local yellow = Color(255, 212, 0, 255 * alpha)

    -- Мягкое свечение
    for k = 2, 1, -1 do
        draw.RoundedBox(6,
            ScrW() / 2 - hintW / 2 - k * 2,
            hintY - k * 2,
            hintW + k * 4,
            hintH + k * 4,
            Color(255, 212, 0, (15 * alpha) / k))
    end

    -- Фон подсказки
    draw.RoundedBox(6,
        ScrW() / 2 - hintW / 2,
        hintY,
        hintW, hintH,
        Color(30, 28, 15, 220 * alpha))

    -- Жёлтая рамка
    surface.SetDrawColor(255, 212, 0, 220 * alpha)
    surface.DrawOutlinedRect(
        ScrW() / 2 - hintW / 2,
        hintY,
        hintW, hintH)

    draw.SimpleText(hintText, "DrawingGeometry_HintFont",
        ScrW() / 2, hintY + hintH / 2,
        yellow,
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

hook.Add("HUDPaint", "DrawingGeometry_HUD", DrawingGeometry.DrawHUD)

-- ============================================================
-- SetMode
-- ============================================================

function DrawingGeometry.SetMode(modeId)
    if modeId < 0 or modeId >= DrawingGeometry.MODE_COUNT then return end
    if DrawingGeometry.State.Mode == modeId then return end

    DrawingGeometry.State.Mode = modeId
    DrawingGeometry.State.Holding = false
    DrawingGeometry.State.StartPos = nil
    DrawingGeometry.State.EndPos = nil
    DrawingGeometry.State.StartEnt = nil
    DrawingGeometry.State.EndEnt = nil

    surface.PlaySound("garrysmod/ui_click.wav")
end

-- ============================================================
-- Блокировка смены оружия при Shift+Scroll
-- ============================================================

hook.Add("PlayerBindPress", "DrawingGeometry_BlockWeaponSwitch", function(ply, bind, pressed)
    if not pressed then return end
    if not DrawingGeometry.State.ShiftHeld then return end
    if bind == "invnext" or bind == "invprev" then
        return true
    end
end)

hook.Add("PlayerSwitchWeapon", "DrawingGeometry_ShiftBlock", function(ply, oldWep, newWep)
    if DrawingGeometry.State.ShiftHeld
       and DrawingGeometry.IsGeometryMode() then
        return true
    end
end)

-- ============================================================
-- CreateMove: вырезаем IN_ATTACK из CUserCmd
-- ============================================================

hook.Add("CreateMove", "DrawingGeometry_BlockLMB", function(cmd)
    if not DrawingGeometry or not DrawingGeometry.IsGeometryMode then return end
    if not DrawingGeometry.IsGeometryMode() then return end
    if not GetActiveDrawingWeapon() then return end

    cmd:RemoveKey(IN_ATTACK)
end)

-- ============================================================
-- Перехват колеса мыши (Shift + Scroll = смена режима)
-- ============================================================

hook.Add("InputMouseApply", "DrawingGeometry_MouseWheel", function(cmd, x, y, ang)
    if not DrawingGeometry.State.ShiftHeld then return end

    local wep = GetActiveDrawingWeapon()
    if not IsValid(wep) then return end
    if gui.IsGameUIVisible() then return end
    if ChalkMarkerUI and ChalkMarkerUI.State and ChalkMarkerUI.State.IsOpen then return end

    local wheelDelta = cmd:GetMouseWheel()
    if wheelDelta ~= 0 then
        local dir = (wheelDelta > 0) and 1 or -1
        local newMode = (DrawingGeometry.State.Mode + dir) % DrawingGeometry.MODE_COUNT
        if newMode < 0 then newMode = DrawingGeometry.MODE_COUNT - 1 end
        DrawingGeometry.SetMode(newMode)
    end
end)

-- ============================================================
-- Основной Think: hold/release
-- ============================================================

hook.Add("Think", "DrawingGeometry_Input", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if gui.IsGameUIVisible() then return end
    if ChalkMarkerUI and ChalkMarkerUI.State and ChalkMarkerUI.State.IsOpen then return end

    local wep = GetActiveDrawingWeapon()
    if not IsValid(wep) then
        DrawingGeometry.State.ShiftHeld = false
        DrawingGeometry.State.Holding = false
        return
    end

    DrawingGeometry.State.ShiftHeld = ply:KeyDown(IN_SPEED)

    if input.IsMouseDown(MOUSE_MIDDLE) then
        if not DrawingGeometry.State._middlePressed then
            DrawingGeometry.State._middlePressed = true
            if DrawingGeometry.IsGeometryMode() then
                DrawingGeometry.SetMode(DrawingGeometry.MODE_BRUSH)
            end
        end
    else
        DrawingGeometry.State._middlePressed = false
    end

    if not DrawingGeometry.IsGeometryMode() then
        DrawingGeometry.State.Holding = false
        DrawingGeometry.State.StartPos = nil
        DrawingGeometry.State.EndPos = nil
        return
    end

    local lmbDown = input.IsMouseDown(MOUSE_LEFT)

    if lmbDown and not DrawingGeometry.State.Holding then
        local tr = ply:GetEyeTrace()
        if IsValid(tr.Entity) then
            DrawingGeometry.State.Holding = true
            DrawingGeometry.State.StartPos = tr.HitPos
            DrawingGeometry.State.StartEnt = tr.Entity
            DrawingGeometry.State.EndPos = tr.HitPos
            DrawingGeometry.State.EndEnt = tr.Entity
        end
    elseif lmbDown and DrawingGeometry.State.Holding then
        local tr = ply:GetEyeTrace()
        if IsValid(tr.Entity) and tr.Entity == DrawingGeometry.State.StartEnt then
            DrawingGeometry.State.EndPos = tr.HitPos
            DrawingGeometry.State.EndEnt = tr.Entity
        end
    elseif not lmbDown and DrawingGeometry.State.Holding then
        DrawingGeometry.FinalizeShape()
    end
end)

-- ============================================================
-- Превью фигуры
-- ============================================================

hook.Add("PostDrawTranslucentRenderables", "DrawingGeometry_Preview", function()
    if not DrawingGeometry.State.Holding then return end
    local startPos = DrawingGeometry.State.StartPos
    local endPos = DrawingGeometry.State.EndPos
    if not startPos or not endPos then return end

    local mode = DrawingGeometry.State.Mode
    local accent = GetPlayerMarkColor()
    local col = Color(accent.r, accent.g, accent.b, 200)

    render.SetColorMaterial()

    if mode == 1 then
        render.DrawLine(startPos, endPos, col, true)

    elseif mode == 2 then
        local radius = startPos:Distance(endPos)
        local ent = DrawingGeometry.State.StartEnt
        if IsValid(ent) and radius > 0.01 then
            local ang = ent:GetAngles()
            ang:RotateAroundAxis(ang:Up(), 180)
            local right = ang:Right()
            local up = ang:Up()
            local seg = 48
            local prev = nil
            for i = 0, seg do
                local a = (i / seg) * math.pi * 2
                local p = startPos
                    + right * math.cos(a) * radius
                    + up * math.sin(a) * radius
                if prev then
                    render.DrawLine(prev, p, col, true)
                end
                prev = p
            end
        end

    elseif mode == 3 then
        render.DrawLine(startPos, endPos, col, true)
        local ent = DrawingGeometry.State.StartEnt
        if IsValid(ent) then
            local ang = ent:GetAngles()
            ang:RotateAroundAxis(ang:Up(), 180)
            local dist = startPos:Distance(endPos)
            if dist > 0.01 then
                local dir = (endPos - startPos):GetNormalized()
                local perp = dir:Cross(ang:Forward()):GetNormalized()
                if perp:Length() < 0.01 then perp = ang:Right() end
                local len = dist * 0.15
                local p1 = endPos - dir * len + perp * len * 0.5
                local p2 = endPos - dir * len - perp * len * 0.5
                render.DrawLine(endPos, p1, col, true)
                render.DrawLine(endPos, p2, col, true)
            end
        end

    elseif mode == 4 then
        local ent = DrawingGeometry.State.StartEnt
        if IsValid(ent) then
            local ang = ent:GetAngles()
            ang:RotateAroundAxis(ang:Up(), 180)
            local right = ang:Right()
            local up = ang:Up()

            local d = endPos - startPos
            local dx = d:Dot(right)
            local dy = d:Dot(up)

            local p1 = startPos
            local p2 = startPos + right * dx
            local p3 = startPos + right * dx + up * dy
            local p4 = startPos + up * dy

            render.DrawLine(p1, p2, col, true)
            render.DrawLine(p2, p3, col, true)
            render.DrawLine(p3, p4, col, true)
            render.DrawLine(p4, p1, col, true)
        end
    end
end)

-- ============================================================
-- FinalizeShape
-- ============================================================

function DrawingGeometry.FinalizeShape()
    local startPos = DrawingGeometry.State.StartPos
    local endPos = DrawingGeometry.State.EndPos
    local ent = DrawingGeometry.State.StartEnt

    DrawingGeometry.State.Holding = false
    DrawingGeometry.State.StartPos = nil
    DrawingGeometry.State.EndPos = nil
    DrawingGeometry.State.EndEnt = nil

    if not startPos or not endPos or not IsValid(ent) then return end

    local wep = GetActiveDrawingWeapon()
    if not IsValid(wep) then return end

    local mode = DrawingGeometry.State.Mode
    local points = DrawingGeometry.ComputeShapePoints(mode, startPos, endPos, ent)
    if not points or #points == 0 then return end

    if #points > 2048 then
        local step = #points / 2048
        local reduced = {}
        for i = 1, 2048 do
            local idx = math.floor((i - 1) * step) + 1
            reduced[i] = points[idx]
        end
        points = reduced
    end

    net.Start("DrawingGeometry_FinalizeShape")
        net.WriteEntity(ent)
        net.WriteUInt(mode, 4)
        net.WriteUInt(#points, 16)
        for i = 1, #points do
            net.WriteVector(points[i])
        end
    net.SendToServer()

    local color = wep.GetDrawColor and wep:GetDrawColor() or Color(255, 255, 255)
    local size = wep.GetDrawSizeValue and wep:GetDrawSizeValue() or 7

    if ent.DrawOnBoard then
        if ent.PlayerLastDrawPos and ent.GetPlayerID then
            local pid = ent:GetPlayerID(LocalPlayer())
            ent.PlayerLastDrawPos[pid] = nil
        end

        local first = true
        for i = 1, #points do
            ent:DrawOnBoard(points[i], color, size, first, LocalPlayer())
            first = false
        end
    end
end

-- ============================================================
-- ComputeShapePoints
-- ============================================================

local POINT_STEP = 2.0

local MIN_LINE_DIST   = 0.5
local MIN_CIRCLE_R    = 1.0
local MIN_ARROW_DIST  = 1.0
local MIN_RECT_SIDE   = 1.0

function DrawingGeometry.ComputeShapePoints(mode, startPos, endPos, ent)
    local points = {}
    if not IsValid(ent) then return points end

    local ang = ent:GetAngles()
    ang:RotateAroundAxis(ang:Up(), 180)
    local right = ang:Right()
    local up = ang:Up()

    local function toLocal(p)
        local d = p - startPos
        return d:Dot(right), d:Dot(up)
    end

    local function fromLocal(lx, ly)
        return startPos + right * lx + up * ly
    end

    if mode == 1 then
        local dist = startPos:Distance(endPos)
        if dist < MIN_LINE_DIST then
            return points
        end
        local steps = math.max(2, math.floor(dist / POINT_STEP))
        for i = 0, steps do
            local t = i / steps
            points[#points + 1] = startPos + (endPos - startPos) * t
        end

    elseif mode == 2 then
        local radius = startPos:Distance(endPos)
        if radius < MIN_CIRCLE_R then return points end
        local circumference = 2 * math.pi * radius
        local seg = math.max(16, math.floor(circumference / POINT_STEP))
        for i = 0, seg do
            local a = (i / seg) * math.pi * 2
            points[#points + 1] = startPos
                + right * math.cos(a) * radius
                + up * math.sin(a) * radius
        end

    elseif mode == 3 then
        local delta = endPos - startPos
        local dist = delta:Length()

        if dist < MIN_ARROW_DIST then
            return points
        end

        local dir = delta / dist
        local normal = ang:Forward()

        local perp = dir:Cross(normal)

        if perp:LengthSqr() < 0.0001 then
            perp = right - dir * dir:Dot(right)
        end

        if perp:LengthSqr() < 0.0001 then
            return points
        end

        perp:Normalize()

        local steps = math.max(2, math.floor(dist / POINT_STEP))

        for i = 0, steps do
            local t = i / steps
            points[#points + 1] = startPos + delta * t
        end

        local headLen = math.min(dist * 0.25, 12)
        local headHalf = headLen * 0.45

        local leftTip = endPos - dir * headLen + perp * headHalf
        local rightTip = endPos - dir * headLen - perp * headHalf

        local headSteps = math.max(2, math.floor(headLen / POINT_STEP))

        for i = 0, headSteps do
            local t = i / headSteps
            points[#points + 1] = endPos + (leftTip - endPos) * t
        end

        for i = 0, headSteps do
            local t = i / headSteps
            points[#points + 1] = endPos + (rightTip - endPos) * t
        end

    elseif mode == 4 then
        local dx, dy = toLocal(endPos)
        if math.abs(dx) < MIN_RECT_SIDE or math.abs(dy) < MIN_RECT_SIDE then
            return points
        end

        local corners = {
            {0, 0}, {dx, 0}, {dx, dy}, {0, dy}, {0, 0}
        }
        for i = 1, #corners - 1 do
            local x1, y1 = corners[i][1], corners[i][2]
            local x2, y2 = corners[i + 1][1], corners[i + 1][2]
            local p1 = fromLocal(x1, y1)
            local p2 = fromLocal(x2, y2)
            local dist = p1:Distance(p2)
            local steps = math.max(1, math.floor(dist / POINT_STEP))
            for k = 0, steps - 1 do
                local t = k / steps
                points[#points + 1] = fromLocal(
                    x1 + (x2 - x1) * t,
                    y1 + (y2 - y1) * t
                )
            end
        end
        points[#points + 1] = fromLocal(0, 0)
    end

    return points
end