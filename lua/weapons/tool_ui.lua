print("[DB_UI] Loading interface...")

ChalkMarkerUI = ChalkMarkerUI or {}
ChalkMarkerUI.Keybind = KEY_T
ChalkMarkerUI.KeybindBlocked = false


if CLIENT then
    -- Очистку делаем ТОЛЬКО если файл загружается "сверху" (при сохранении кода)
    -- Мы проверяем, не вызван ли файл внутри функции открытия меню
    for _, pnl in ipairs(vgui.GetWorldPanel():GetChildren()) do
        if pnl.GetTitle and pnl:GetTitle() == "Tool Menu" then
            pnl:Remove()
        end
        
        -- Блюр удаляем аккуратно
        if pnl:GetName() == "DPanel" and pnl:GetWide() == ScrW() and pnl:GetTall() == ScrH() then
            pnl:Remove()
        end
    end

    -- ВАЖНО: Не обнуляй IsOpen здесь принудительно, если это обычный вызов
    -- ChalkMarkerUI.State.IsOpen = false  <-- Эту строку пока закомментируй или удали
end


if CLIENT then
    -- Обработчики синхронизации размеров
    -- net.Receive("ChalkMarkerUI_SyncSize", function()
    --     local weapon = net.ReadEntity()
    --     local sizeName = net.ReadString()
    --     local sizeValue = net.ReadUInt(8)
        
    --     if IsValid(weapon) then
    --         -- Обновляем на клиенте
    --         if weapon.SetPlayerSize then
    --             weapon:SetPlayerSize(sizeName)
    --         else
    --             weapon.CurrentSize = sizeName
    --             weapon.CurrentSizeValue = sizeValue
    --         end
            
    --         -- Обновляем UI если он открыт
    --         if ChalkMarkerUI.State.IsOpen and IsValid(ChalkMarkerUI.State.CurrentWeapon) and 
    --            ChalkMarkerUI.State.CurrentWeapon == weapon then
    --             ChalkMarkerUI.UpdateContent()
    --         end
    --     end
    -- end)
    
    -- net.Receive("ChalkMarkerUI_SyncEraseSize", function()
    --     local weapon = net.ReadEntity()
    --     local sizeName = net.ReadString()
    --     local sizeValue = net.ReadUInt(8)
        
    --     if IsValid(weapon) then
    --         -- Обновляем на клиенте
    --         if weapon.SetPlayerEraseSize then
    --             weapon:SetPlayerEraseSize(sizeName)
    --         else
    --             weapon.CurrentEraseSize = sizeName
    --             weapon.CurrentEraseSizeValue = sizeValue
    --         end
            
    --         -- Обновляем UI если он открыт
    --         if ChalkMarkerUI.State.IsOpen and IsValid(ChalkMarkerUI.State.CurrentWeapon) and 
    --            ChalkMarkerUI.State.CurrentWeapon == weapon then
    --             ChalkMarkerUI.UpdateContent()
    --         end
    --     end
    -- end)

    if file.Exists("chalk_marker_keybind.txt", "DATA") then
        local keyData = file.Read("chalk_marker_keybind.txt", "DATA")
        if keyData then
            ChalkMarkerUI.Keybind = tonumber(keyData) or KEY_T
        else
            ChalkMarkerUI.Keybind = KEY_T
        end
    else
        ChalkMarkerUI.Keybind = KEY_T
    end
end

if SERVER then
    util.AddNetworkString("ChalkMarkerUI_UpdateWeapon")
    util.AddNetworkString("ChalkMarkerUI_UpdateEraseSize")
end

ChalkMarkerUI.LastTState = false
ChalkMarkerUI.OpenCooldown = 0
ChalkMarkerUI.CloseCooldown = 0

if not CLIENT then
    return
end

-- ============ ЗАГРУЗКА КОНФИГУРАЦИИ ============

-- Если config.lua еще не загружен
if not ChalkMarkerConfig or not ChalkMarkerConfig.Colors then
    local configPaths = {
        "config.lua",
        "chalk_tool/config.lua", 
        "marker_tool/config.lua",
        "lua/config.lua"
    }
    
    local configLoaded = false
    for _, path in ipairs(configPaths) do
        if file.Exists(path, "LUA") then
            include(path)
            configLoaded = true
            break
        end
    end

    if not configLoaded then
        include("config.lua")
    end
end

if not ChalkMarkerConfig or not ChalkMarkerConfig.Colors then
    print("[DB_UI] ERROR: Configuration not loaded!")
    return
end

-- ============ КОНФИГУРАЦИЯ ИНТЕРФЕЙСА (шрифты) ============

-- Создание кастомных шрифтов для интерфейса
surface.CreateFont("ChalkMarkerUI_TabFont", {
    font = "Verdana",
    size = 16,
    weight = 600, -- полужирный
    antialias = true,
    additive = false
})

surface.CreateFont("ChalkMarkerUI_TitleFont", {
    font = "Verdana",
    size = 20,
    weight = 700,    -- жирный
    antialias = true,
    additive = false
})

surface.CreateFont("ChalkMarkerUI_LabelFont", {
    font = "Verdana",
    size = 14,
    weight = 500,      -- средняя жирность
    antialias = true
})
surface.CreateFont("ChalkMarkerUI_CloseIcon", {
    font = "Verdana",
    size = 20,
    weight = 700,
    antialias = true
})
surface.CreateFont("ChalkMarkerUI_HexRGBFont", {
    font = "Verdana",
    size = 16,
    weight = 500,
    antialias = true
})

ChalkMarkerUI.Config = {
    BlurIntensity = 8,
    BackgroundAlpha = 200,
    AccentColor = Color(70, 130, 200, 220),
    TextColor = Color(240, 240, 240, 240),
    BackgroundColor = Color(30, 35, 45, 200),
}

-- ============ СОСТОЯНИЕ ИНТЕРФЕЙСА ============

ChalkMarkerUI.State = {
    IsOpen = false,
    CurrentWeapon = nil,
    WeaponType = nil, -- "chalk" или "marker"
    ActiveTab = "color"
}

-- ============ ДАННЫЕ ДЛЯ ИНТЕРФЕЙСА ============

ChalkMarkerUI.Data = {
    chalk = {
        name = "Chalk",
        colors = ChalkMarkerConfig.GetColorsForUI("chalk"),
        sizes = ChalkMarkerConfig.GetSizesForUI("chalk", "draw"),
        erase_sizes = ChalkMarkerConfig.GetSizesForUI("chalk", "erase")
    },
    marker = {
        name = "Marker", 
        colors = ChalkMarkerConfig.GetColorsForUI("marker"),
        sizes = ChalkMarkerConfig.GetSizesForUI("marker", "draw"),
        erase_sizes = ChalkMarkerConfig.GetSizesForUI("marker", "erase")
    }
}

-- ============ ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ============

-- функция размытия
function ChalkMarkerUI.DrawBlur(panel, layers, density, alpha)
    local blur = Material("pp/blurscreen")
    local x, y = panel:LocalToScreen(0, 0)

    surface.SetDrawColor(255, 255, 255, alpha or 255)
    surface.SetMaterial(blur)

    for i = 1, layers do
        blur:SetFloat("$blur", (i / layers) * density)
        blur:Recompute()
        render.UpdateScreenEffectTexture()
        surface.DrawTexturedRect(-x, -y, ScrW(), ScrH())
    end
end

-- размытый фон
function ChalkMarkerUI.CreateBlurBackground()
    local blurPanel = vgui.Create("DPanel")
    --blurPanel.IsMyUIElement = true
    blurPanel:SetSize(ScrW(), ScrH())
    blurPanel:SetPos(0, 0)
    blurPanel:SetZPos(-100)
    blurPanel:SetMouseInputEnabled(false)
    
    blurPanel.Think = function() end
    
    blurPanel.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 180))
        ChalkMarkerUI.DrawBlur(self, 3, 5, 255)
    end
    
    blurPanel.OnMousePressed = function()
        ChalkMarkerUI.CloseMenu()
    end
    
    return blurPanel
end

-- ============ ОСНОВНОЕ ОКНО ============

function ChalkMarkerUI.CreateMainFrame()
    local frame = vgui.Create("DFrame")
    frame:SetSize(500, 600)
    frame:Center()
    frame:SetTitle("")
    frame:SetDraggable(false)
    frame:ShowCloseButton(false)
    frame:SetDeleteOnClose(false)
    frame:MakePopup()
    
    -- Кастомная панель для перетаскивания
    local dragPanel = vgui.Create("DPanel", frame)
    dragPanel:SetSize(frame:GetWide(), 40)
    dragPanel:SetPos(0, 0)
    dragPanel:SetMouseInputEnabled(true)
    dragPanel:SetCursor("sizeall")
    dragPanel.Paint = function(self, w, h) end
    
    -- Ручное перетаскивание
    dragPanel.OnMousePressed = function(self, mcode)
        if mcode == MOUSE_LEFT then
            self.Dragging = true
            self.DragStartX, self.DragStartY = input.GetCursorPos()
            self.FrameStartX, self.FrameStartY = frame:GetPos()
            self:MouseCapture(true)
        end
    end
    
    dragPanel.OnMouseReleased = function(self, mcode)
        if mcode == MOUSE_LEFT then
            self.Dragging = false
            self:MouseCapture(false)
        end
    end
    
    dragPanel.Think = function(self)
        if self.Dragging and input.IsMouseDown(MOUSE_LEFT) then
            local cx, cy = input.GetCursorPos()
            local dx = cx - self.DragStartX
            local dy = cy - self.DragStartY
            frame:SetPos(self.FrameStartX + dx, self.FrameStartY + dy)
        end
    end
    
    frame.Think = function()
        dragPanel:SetSize(frame:GetWide(), 40)
    end
    
    frame.OnKeyCodePressed = function(self, keyCode)
        if keyCode == KEY_ESCAPE then
            ChalkMarkerUI.CloseMenu()
            return true
        end
        return true
    end
    
    frame.Paint = function(self, w, h)
        draw.RoundedBox(16, 0, 0, w, h, ChalkMarkerUI.Config.BackgroundColor)
        draw.RoundedBox(16, 0, 0, w, h, Color(255, 255, 255, 10))
        
        draw.SimpleText(
            ChalkMarkerUI.Data[ChalkMarkerUI.State.WeaponType].name, 
            "ChalkMarkerUI_TitleFont",
            w/2, 
            25, 
            ChalkMarkerUI.Config.TextColor, 
            TEXT_ALIGN_CENTER, 
            TEXT_ALIGN_CENTER
        )
    end
    
    -- Кнопка закрытия
    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetSize(30, 30)
    closeBtn:SetPos(frame:GetWide() - 40, 10)
    closeBtn:SetText("")
    closeBtn:SetZPos(200)
    
    closeBtn.Paint = function(self, w, h)
        local radius = 8 
        local bgColor = self:IsHovered() and Color(255, 50, 50, 150) or Color(80, 80, 80, 150)
        draw.RoundedBox(radius, 0, 0, w, h, bgColor)
        
        local xoffset = -0.45
        local yoffset = -1
        draw.SimpleText("×", "ChalkMarkerUI_CloseIcon", w/2 + xoffset, h/2 + yoffset, Color(220, 220, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    closeBtn.DoClick = function()
        surface.PlaySound("garrysmod/ui_click.wav")
        ChalkMarkerUI.CloseMenu()
    end

    return frame
end

-- ============ ВКЛАДКИ ============

function ChalkMarkerUI.CreateTabs(parent)
    local tabContainer = vgui.Create("DPanel", parent)
    --tabContainer.IsMyUIElement = true
    tabContainer:SetSize(460, 40)
    tabContainer:SetPos(20, 60)
    tabContainer.Paint = function() end
    
    local tabs = {
        {id = "color", name = "Color"},
        {id = "size", name = "Size"}
    }
    
    local btnWidth = 460 / #tabs
    
    for i, tab in ipairs(tabs) do
        local tabBtn = vgui.Create("DButton", tabContainer)
        tabBtn:SetSize(btnWidth - 4, 35)
        tabBtn:SetPos((i-1) * btnWidth + 2, 0)
        tabBtn:SetText(tab.name)
        tabBtn:SetFont("ChalkMarkerUI_TabFont")
        tabBtn:SetTextColor(ChalkMarkerUI.State.ActiveTab == tab.id and ChalkMarkerUI.Config.AccentColor or Color(150, 150, 150))

        tabBtn.Paint = function(self, w, h)
            if self:IsHovered() and ChalkMarkerUI.State.ActiveTab ~= tab.id then
                tabBtn:SetTextColor(ChalkMarkerUI.Config.AccentColor)
            elseif ChalkMarkerUI.State.ActiveTab == tab.id then
                tabBtn:SetTextColor(ChalkMarkerUI.Config.AccentColor)
            else
                tabBtn:SetTextColor(Color(150, 150, 150))
            end
            
            if ChalkMarkerUI.State.ActiveTab == tab.id then
                surface.SetDrawColor(ChalkMarkerUI.Config.AccentColor)
                surface.DrawRect(0, h-3, w, 3)
            elseif self:IsHovered() then
                surface.SetDrawColor(ChalkMarkerUI.Config.AccentColor.r, ChalkMarkerUI.Config.AccentColor.g, ChalkMarkerUI.Config.AccentColor.b, 100)
                surface.DrawRect(0, h-3, w, 2)
            end
        end
        
        tabBtn.DoClick = function()
            ChalkMarkerUI.State.ActiveTab = tab.id
            ChalkMarkerUI.UpdateContent()
        end
    end
    
    return tabContainer
end

-- ============ ВКЛАДКА ЦВЕТА ============

function ChalkMarkerUI.CreateColorTab(parent)
    local panel = vgui.Create("DPanel", parent)
    panel:SetSize(460, 400)
    panel:SetPos(0, 0)
    panel.Paint = function(self, w, h)
        draw.SimpleText("Color settings (Standart colors)", "ChalkMarkerUI_TabFont", w/2, 30, ChalkMarkerUI.Config.TextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    if not ChalkMarkerUI.PickerLastColors then
        ChalkMarkerUI.PickerLastColors = {}
    end
    
    local colors = ChalkMarkerUI.Data[ChalkMarkerUI.State.WeaponType].colors
    local weapon = ChalkMarkerUI.State.CurrentWeapon
    
    local btnSize = 55
    local spacing = 30
    local cols = 4
    local startY = 70
    
    local totalWidth = cols * btnSize + (cols - 1) * spacing
    local startX = (460 - totalWidth) / 2
    
    local colorButtons = {}
    
    local function updateCurrentColorDisplay()
        for _, btn in ipairs(colorButtons) do
            if IsValid(btn) then btn:SetText("") end
        end
    end
    
    for i, colorData in ipairs(colors) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        
        local x = startX + col * (btnSize + spacing)
        local y = startY + row * (btnSize + 25)
        
        local colorBtn = vgui.Create("DButton", panel)
        colorBtn:SetSize(btnSize, btnSize)
        colorBtn:SetPos(x, y)
        colorBtn:SetText("")
        colorBtn.colorData = colorData
        
        colorBtn.Paint = function(self, w, h)
            local currentColor
            if weapon.GetPlayerColor then
                currentColor = weapon:GetPlayerColor()
            else
                currentColor = weapon.CurrentColor or (ChalkMarkerUI.State.WeaponType == "chalk" and "white" or "black")
            end
            
            local isSelected = currentColor == self.colorData.name
            local isHovered = self:IsHovered()
            
            if isSelected then
                draw.RoundedBox(8, 0, 0, w, h, Color(70, 130, 200, 50))
            elseif isHovered then
                draw.RoundedBox(8, 0, 0, w, h, Color(255, 255, 255, 20))
            else
                draw.RoundedBox(8, 0, 0, w, h, Color(40, 45, 55, 200))
            end
            
            draw.RoundedBox(6, 8, 8, w - 16, h - 16, self.colorData.color)
            
            if isSelected then
                surface.SetDrawColor(ChalkMarkerUI.Config.AccentColor)
                surface.DrawOutlinedRect(0, 0, w, h, 2)
            end
        end
        
        colorBtn.DoClick = function(self)
            local colorName = self.colorData.name
            local currentColor = weapon.GetPlayerColor and weapon:GetPlayerColor() or (weapon.CurrentColor or (ChalkMarkerUI.State.WeaponType == "chalk" and "white" or "black"))
            if currentColor == colorName then return end
            
            if weapon.SetPlayerColor then
                weapon:SetPlayerColor(colorName)
            else
                weapon.CurrentColor = colorName
                if ChalkMarkerUI.State.WeaponType == "chalk" and weapon.SetChalkColor then
                    weapon:SetChalkColor(colorName)
                elseif ChalkMarkerUI.State.WeaponType == "marker" and weapon.SetMarkerColor then
                    weapon:SetMarkerColor(colorName)
                end
            end
            
            local sizeValue = weapon.GetDrawSizeValue and weapon:GetDrawSizeValue() or (weapon.CurrentSizeValue or 7)
            net.Start("ChalkMarkerUI_UpdateWeapon")
                net.WriteString(colorName)
                net.WriteFloat(sizeValue)
            net.SendToServer()
            updateCurrentColorDisplay()
        end
        
        table.insert(colorButtons, colorBtn)
        
        local label = vgui.Create("DLabel", panel)
        label:SetPos(x - 5, y + btnSize + 3)
        label:SetSize(btnSize + 10, 20)
        label:SetText(colorData.display)
        label:SetFont("ChalkMarkerUI_LabelFont")
        label:SetTextColor(ChalkMarkerUI.Config.TextColor)
        label:SetContentAlignment(5)
    end
    
    local otherColorBtn = vgui.Create("DButton", panel)
    otherColorBtn:SetSize(300, 35)
    otherColorBtn:SetPos((460 - 300) / 2, 350)
    otherColorBtn:SetText("Choose other color")
    otherColorBtn:SetFont("ChalkMarkerUI_TabFont")
    otherColorBtn:SetTextColor(ChalkMarkerUI.Config.TextColor)

    otherColorBtn.Paint = function(self, w, h)
        if self:IsHovered() then
            draw.RoundedBox(6, 0, 0, w, h, Color(70, 130, 200, 80))
            otherColorBtn:SetTextColor(Color(200, 220, 255))
        else
            draw.RoundedBox(6, 0, 0, w, h, Color(80, 85, 95, 200))
            otherColorBtn:SetTextColor(ChalkMarkerUI.Config.TextColor)
        end
        if self:IsDown() then
            draw.RoundedBox(6, 0, 0, w, h, Color(70, 130, 200, 120))
            otherColorBtn:SetTextColor(Color(220, 235, 255))
        end
    end

    otherColorBtn.DoClick = function()
        if IsValid(ChalkMarkerUI.ColorPickerFrame) then
            ChalkMarkerUI.ColorPickerFrame:MakePopup()
            return
        end
        
        surface.PlaySound("buttons/button14.wav")
        
        local currentColor
        if weapon.GetPlayerColor then
            currentColor = weapon:GetPlayerColor()
        else
            currentColor = weapon.CurrentColor or (ChalkMarkerUI.State.WeaponType == "chalk" and "white" or "black")
        end
        
        local colorData = ChalkMarkerConfig.GetColorData(ChalkMarkerUI.State.WeaponType, currentColor)
        local startColor = colorData and colorData.color or Color(255, 255, 255)
        
        local frame = vgui.Create("DFrame")
        ChalkMarkerUI.ColorPickerFrame = frame
        frame:SetSize(720, 520)
        frame:Center()
        frame:SetTitle("")
        frame:SetDraggable(true)
        frame:ShowCloseButton(false)
        frame:MakePopup()
        frame:SetDeleteOnClose(true)
        
        frame.OnRemove = function()
            ChalkMarkerUI.ColorPickerFrame = nil
            timer.Remove("ChalkPickerUIUpdate")
        end

        frame.Paint = function(self, w, h)
            draw.RoundedBox(12, 0, 0, w, h, ChalkMarkerUI.Config.BackgroundColor)
            draw.RoundedBox(12, 0, 0, w, h, Color(255, 255, 255, 10))
            draw.SimpleText("Color Picker", "ChalkMarkerUI_TitleFont", w/2, 25, ChalkMarkerUI.Config.TextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        
        local closeBtn = vgui.Create("DButton", frame)
        closeBtn:SetSize(30, 30)
        closeBtn:SetPos(frame:GetWide() - 40, 10)
        closeBtn:SetText("")
        closeBtn.Paint = function(self, w, h)
            local radius = 8
            local bgColor = self:IsHovered() and Color(255, 50, 50, 150) or Color(80, 80, 80, 150)
            draw.RoundedBox(radius, 0, 0, w, h, bgColor)
            local xoffset = -0.45
            local yoffset = -1
            draw.SimpleText("×", "ChalkMarkerUI_CloseIcon", w/2 + xoffset, h/2 + yoffset, Color(220, 220, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        closeBtn.DoClick = function()
            surface.PlaySound("garrysmod/ui_click.wav")
            frame:Remove()
        end

        local activeTab = "hex"
        local hue, sat, val = 0, 1, 1
        local rVal, gVal, bVal = startColor.r, startColor.g, startColor.b
        local currentColor = Color(rVal, gVal, bVal)
        local isDragging = false
        local isBarDragging = false
        local needsUIRefresh = false
        
        local function RGBtoHSV(r, g, b)
            local h, s, v = Color(r, g, b):ToHSV()
            return h, s, v
        end
        
        hue, sat, val = RGBtoHSV(rVal, gVal, bVal)

        local hexInput, rInput, gInput, bInput, rLabel, gLabel, bLabel
        local palette, barPanel, lastPanel
        
        local function requestUIUpdate()
            needsUIRefresh = true
        end
        
        local function doUpdateUI()
            if not needsUIRefresh then return end
            needsUIRefresh = false
            if not IsValid(frame) then return end
            
            rVal, gVal, bVal = currentColor.r, currentColor.g, currentColor.b
            
            if IsValid(hexInput) then
                local hexText = string.format("%02X%02X%02X", rVal, gVal, bVal)
                if hexInput:GetValue() ~= "#" .. hexText then
                    hexInput:SetText("#" .. hexText)
                end
            end
            if IsValid(rInput) then rInput:SetText(tostring(rVal)) end
            if IsValid(gInput) then gInput:SetText(tostring(gVal)) end
            if IsValid(bInput) then bInput:SetText(tostring(bVal)) end
            
            local wheelVisible = activeTab == "wheel"
            if IsValid(rLabel) then rLabel:SetVisible(wheelVisible) end
            if IsValid(rInput) then rInput:SetVisible(wheelVisible) end
            if IsValid(gLabel) then gLabel:SetVisible(wheelVisible) end
            if IsValid(gInput) then gInput:SetVisible(wheelVisible) end
            if IsValid(bLabel) then bLabel:SetVisible(wheelVisible) end
            if IsValid(bInput) then bInput:SetVisible(wheelVisible) end
        end
        
        timer.Create("ChalkPickerUIUpdate", 0.016, 0, function()
            if IsValid(frame) then doUpdateUI() else timer.Remove("ChalkPickerUIUpdate") end
        end)

        local function CreateTab(text, x, id)
            local t = vgui.Create("DButton", frame)
            t:SetSize(160, 30)
            t:SetPos(x, 45)
            t:SetText(text)
            t:SetFont("ChalkMarkerUI_LabelFont")
            t:SetTextColor(Color(255, 255, 255))
            t.Paint = function(self, w, h)
                draw.RoundedBox(6, 0, 0, w, h, activeTab == id and ChalkMarkerUI.Config.AccentColor or Color(60, 60, 60, 200))
            end
            t.DoClick = function()
                activeTab = id
                requestUIUpdate()
            end
        end

        CreateTab("RGB Hexagon", 200, "hex")
        CreateTab("RGB Round palette", 380, "wheel")

        local content = vgui.Create("DPanel", frame)
        content:SetPos(0, 85)
        content:SetSize(720, 365)
        content.Paint = function() end

        local left = vgui.Create("DPanel", content)
        left:Dock(LEFT)
        left:SetWide(360)
        left:DockMargin(20, 10, 10, 20)
        left.Paint = function() end

        local right = vgui.Create("DPanel", content)
        right:Dock(FILL)
        right:DockMargin(10, 10, 20, 20)
        right.Paint = function() end

        -- Рендерим палитры ОДИН РАЗ
        local rt_wheel = GetRenderTarget("rt_colorwheel", 512, 512, false)
        local mat_wheel = CreateMaterial("mat_colorwheel", "UnlitGeneric", {
            ["$basetexture"] = rt_wheel:GetName(),
            ["$translucent"] = 1,
            ["$vertexcolor"] = 1,
            ["$vertexalpha"] = 1
        })

        render.PushRenderTarget(rt_wheel)
        local bg = ChalkMarkerUI.Config.BackgroundColor
        render.Clear(bg.r, bg.g, bg.b, 255)
        render.OverrideAlphaWriteEnable(true, true)
        cam.Start2D()
            local size = 512
            local cx, cy = size / 2, size / 2
            local radius = size / 2 - 30
            for x = 0, size, 2 do
                for y = 0, size, 2 do
                    local dx = x - cx
                    local dy = y - cy
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist <= radius then
                        local s = dist / radius
                        local h = (math.deg(math.atan2(dy, dx)) + 360) % 360
                        local col = HSVToColor(h, s, 1)
                        surface.SetDrawColor(col)
                        surface.DrawRect(x, y, 2, 2)
                    end
                end
            end
        cam.End2D()
        render.OverrideAlphaWriteEnable(false)
        render.PopRenderTarget()

        local rt_hex = GetRenderTarget("rt_hex", 512, 512, false)
        local mat_hex = CreateMaterial("mat_hex", "UnlitGeneric", {
            ["$basetexture"] = rt_hex:GetName(),
            ["$translucent"] = 1,
            ["$vertexcolor"] = 1,
            ["$vertexalpha"] = 1
        })

        local function DrawHex(x, y, sz, col)
            local pts = {}
            for i = 0, 5 do
                local a = math.rad(60 * i + 30)
                pts[#pts + 1] = {x = x + math.cos(a) * sz, y = y + math.sin(a) * sz}
            end
            surface.SetDrawColor(col)
            draw.NoTexture()
            surface.DrawPoly(pts)
        end

        render.PushRenderTarget(rt_hex)
        render.Clear(bg.r, bg.g, bg.b, 255)
        render.OverrideAlphaWriteEnable(true, true)
        cam.Start2D()
            local radius = 6
            local hexSize = 16
            local spacing = 1.3
            local function hexToPixel(q, r)
                return hexSize * spacing * (3/2 * q), hexSize * spacing * (math.sqrt(3)/2 * q + math.sqrt(3) * r)
            end
            for q = -radius, radius do
                for r = -radius, radius do
                    local s = -q - r
                    if math.abs(s) <= radius then
                        local x, y = hexToPixel(q, r)
                        local dx = x / 256
                        local dy = y / 256
                        local dist = math.sqrt(dx*dx + dy*dy)
                        local satVal = math.min(dist, 1)
                        local angle = (math.deg(math.atan2(dy, dx)) + 360) % 360
                        local col = HSVToColor(angle, satVal, 1)
                        DrawHex(x + 256, y + 256, hexSize, col)
                    end
                end
            end
        cam.End2D()
        render.OverrideAlphaWriteEnable(false)
        render.PopRenderTarget()
        
        palette = vgui.Create("DPanel", left)
        palette:Dock(FILL)
        palette:SetMouseInputEnabled(true)

        local radiusX = 0
        local radiusY = 0

        local function updateColorFromPalette(x, y)
            local w, h = palette:GetSize()
            if not w or not h then return end
            
            radiusX = w / 2 - 42
            radiusY = h / 2 - 12
            
            local dx = x - w / 2
            local dy = y - h / 2
            
            local normalizedX = dx / radiusX
            local normalizedY = dy / radiusY
            local normDist = math.sqrt(normalizedX * normalizedX + normalizedY * normalizedY)
            
            if normDist > 1 then
                dx = normalizedX / normDist * radiusX
                dy = normalizedY / normDist * radiusY
            end
            
            local dist = math.sqrt(dx * dx + dy * dy)
            local maxRadius = math.max(radiusX, radiusY)
            
            sat = math.min(dist / maxRadius, 1)
            hue = (math.deg(math.atan2(dy, dx)) + 360) % 360
            currentColor = HSVToColor(hue, sat, val)
            requestUIUpdate()
        end

        palette.Paint = function(self, w, h)
            local mat = activeTab == "wheel" and mat_wheel or mat_hex
            surface.SetMaterial(mat)
            surface.SetDrawColor(255, 255, 255, 255)
            surface.DrawTexturedRect(0, 0, w, h)
            
            if activeTab == "wheel" then
                radiusX = w / 2
                radiusY = h / 2 - 20
                
                local angle = math.rad(hue)
                local normX = math.cos(angle) * sat
                local normY = math.sin(angle) * sat
                
                local ix = w / 2 + normX * radiusX
                local iy = h / 2 + normY * radiusY
                
                surface.SetDrawColor(255, 255, 255, 255)
                surface.DrawCircle(ix, iy, 8, Color(255, 255, 255, 255))
                surface.SetDrawColor(70, 160, 255, 255)
                surface.DrawCircle(ix, iy, 6, Color(70, 160, 255, 255))
                surface.SetDrawColor(255, 255, 255, 255)
                surface.DrawCircle(ix, iy, 2, Color(255, 255, 255, 255))
            end
        end

        palette.OnMousePressed = function(self)
            local x, y = input.GetCursorPos()
            x, y = self:ScreenToLocal(x, y)
            updateColorFromPalette(x, y)
            isDragging = true
            self:MouseCapture(true)
        end
        
        palette.OnMouseReleased = function(self)
            if isDragging then
                local x, y = input.GetCursorPos()
                x, y = self:ScreenToLocal(x, y)
                updateColorFromPalette(x, y)
            end
            isDragging = false
            self:MouseCapture(false)
        end
        
        palette.Think = function(self)
            if isDragging and input.IsMouseDown(MOUSE_LEFT) then
                local x, y = input.GetCursorPos()
                x, y = self:ScreenToLocal(x, y)
                updateColorFromPalette(x, y)
            end
        end

        barPanel = vgui.Create("DPanel", right)
        barPanel:SetSize(30, 350)
        barPanel:SetPos(0, 10)
        barPanel:SetMouseInputEnabled(true)

        local function updateColorFromBar(y)
            local h = barPanel:GetTall()
            if not h then return end
            y = math.Clamp(y, 0, h)
            val = 1 - (y / h)
            currentColor = HSVToColor(hue, sat, val)
            requestUIUpdate()
        end

        barPanel.Paint = function(self, w, h)
            for i = 0, h do
                local v = 1 - i / h
                local col = HSVToColor(hue, sat, v)
                surface.SetDrawColor(col)
                surface.DrawRect(0, i, w, 1)
            end
            
            local yPos = math.Clamp((1 - val) * h, 2, h - 27)
            surface.SetDrawColor(255, 255, 255, 255)
            surface.DrawRect(-2, yPos - 3, w + 4, 6)
            surface.SetDrawColor(70, 160, 255, 255)
            surface.DrawRect(-1, yPos - 2, w + 2, 4)
        end

        barPanel.OnMousePressed = function(self)
            local _, y = input.GetCursorPos()
            _, y = self:ScreenToLocal(0, y)
            updateColorFromBar(y)
            isBarDragging = true
            self:MouseCapture(true)
        end

        barPanel.OnMouseReleased = function(self)
            if isBarDragging then
                local _, y = input.GetCursorPos()
                _, y = self:ScreenToLocal(0, y)
                updateColorFromBar(y)
            end
            isBarDragging = false
            self:MouseCapture(false)
        end

        barPanel.Think = function(self)
            if isBarDragging and input.IsMouseDown(MOUSE_LEFT) then
                local _, y = input.GetCursorPos()
                _, y = self:ScreenToLocal(0, y)
                updateColorFromBar(y)
            end
        end

        -- Last colors panel
        local cols = 4
        local size = 36
        local spacing = 15
        local startX = 5
        local startY = 5
        
        lastPanel = vgui.Create("DPanel", right)
        lastPanel:SetPos(40, 10)
        lastPanel:SetSize(240, 100)
        lastPanel.Paint = function(self, w, h)
            draw.SimpleText("Last colors", "ChalkMarkerUI_LabelFont", 0, -15, Color(255, 255, 255))
            for i = 1, 8 do
                local col = (i - 1) % cols
                local row = math.floor((i - 1) / cols)
                local x = startX + col * (size + spacing)
                local y = startY + row * (size + spacing)
                local colColor = ChalkMarkerUI.PickerLastColors[i]
                if colColor then
                    draw.RoundedBox(4, x, y, size, size, colColor)
                else
                    draw.RoundedBox(4, x, y, size, size, Color(60, 60, 60, 150))
                end
                surface.SetDrawColor(100, 100, 100, 100)
                surface.DrawOutlinedRect(x, y, size, size, 1)
            end
        end
        
        lastPanel.OnMousePressed = function(self)
            local x, y = self:CursorPos()
            for i = 1, 8 do
                local col = (i - 1) % cols
                local row = math.floor((i - 1) / cols)
                local btnX = startX + col * (size + spacing)
                local btnY = startY + row * (size + spacing)
                if x >= btnX and x <= btnX + size and y >= btnY and y <= btnY + size then
                    if ChalkMarkerUI.PickerLastColors[i] then
                        local pickedColor = ChalkMarkerUI.PickerLastColors[i]
                        currentColor = Color(pickedColor.r, pickedColor.g, pickedColor.b, 255)
                        rVal, gVal, bVal = currentColor.r, currentColor.g, currentColor.b
                        hue, sat, val = RGBtoHSV(rVal, gVal, bVal)
                        requestUIUpdate()
                    end
                    break
                end
            end
        end
        
        local hexLabel = vgui.Create("DLabel", right)
        hexLabel:SetPos(45, 127)
        hexLabel:SetText("Hex:")
        hexLabel:SetFont("ChalkMarkerUI_LabelFont")
        hexLabel:SetTextColor(Color(200, 200, 200))
        hexLabel:SizeToContents()

        hexInput = vgui.Create("DTextEntry", right)
        hexInput:SetPos(80, 120)
        hexInput:SetSize(100, 30)
        hexInput:SetFont("ChalkMarkerUI_HexRGBFont")
        hexInput:SetPlaceholderText("RRGGBB")
        hexInput:SetValue("#")
        hexInput.OnGetFocus = function(self)
            if self:GetValue() == "#" then self:SetCaretPos(1) end
        end
        hexInput.OnValueChange = function(self)
            local val = self:GetValue()
            if val == "" then
                self:SetText("#")
                self:SetCaretPos(1)
            elseif not val:match("^#") then
                self:SetText("#" .. val:gsub("#", ""))
                self:SetCaretPos(#self:GetText())
            end
        end
        hexInput.OnEnter = function(self)
            local hex = self:GetValue():gsub("#", "")
            if #hex == 6 then
                rVal = tonumber(hex:sub(1, 2), 16) or 255
                gVal = tonumber(hex:sub(3, 4), 16) or 255
                bVal = tonumber(hex:sub(5, 6), 16) or 255
                currentColor = Color(rVal, gVal, bVal)
                hue, sat, val = RGBtoHSV(rVal, gVal, bVal)
                requestUIUpdate()
            end
        end
                
        rLabel = vgui.Create("DLabel", right)
        rLabel:SetPos(45, 160)
        rLabel:SetText("R:")
        rLabel:SetFont("ChalkMarkerUI_HexRGBFont")
        rLabel:SetTextColor(Color(255, 100, 100))
        
        rInput = vgui.Create("DTextEntry", right)
        rInput:SetPos(65, 158)
        rInput:SetSize(50, 25)
        rInput.OnEnter = function(self)
            rVal = tonumber(self:GetValue()) or 255
            rVal = math.Clamp(rVal, 0, 255)
            currentColor = Color(rVal, gVal, bVal)
            hue, sat, val = RGBtoHSV(rVal, gVal, bVal)
            requestUIUpdate()
        end
        
        gLabel = vgui.Create("DLabel", right)
        gLabel:SetPos(125, 160)
        gLabel:SetText("G:")
        gLabel:SetFont("ChalkMarkerUI_HexRGBFont")
        gLabel:SetTextColor(Color(100, 255, 100))
        
        gInput = vgui.Create("DTextEntry", right)
        gInput:SetPos(145, 158)
        gInput:SetSize(50, 25)
        gInput.OnEnter = function(self)
            gVal = tonumber(self:GetValue()) or 255
            gVal = math.Clamp(gVal, 0, 255)
            currentColor = Color(rVal, gVal, bVal)
            hue, sat, val = RGBtoHSV(rVal, gVal, bVal)
            requestUIUpdate()
        end
        
        bLabel = vgui.Create("DLabel", right)
        bLabel:SetPos(205, 160)
        bLabel:SetText("B:")
        bLabel:SetFont("ChalkMarkerUI_HexRGBFont")
        bLabel:SetTextColor(Color(100, 100, 255))
        
        bInput = vgui.Create("DTextEntry", right)
        bInput:SetPos(225, 158)
        bInput:SetSize(50, 25)
        bInput.OnEnter = function(self)
            bVal = tonumber(self:GetValue()) or 255
            bVal = math.Clamp(bVal, 0, 255)
            currentColor = Color(rVal, gVal, bVal)
            hue, sat, val = RGBtoHSV(rVal, gVal, bVal)
            requestUIUpdate()
        end

        local apply = vgui.Create("DButton", frame)
        apply:SetSize(120, 40)
        apply:SetPos(250, 465)
        apply:SetText("Apply")
        apply:SetFont("ChalkMarkerUI_LabelFont")
        apply.Paint = function(self, w, h)
            if self:IsHovered() then
                draw.RoundedBox(6, 0, 0, w, h, Color(70, 130, 200, 200))
            else
                draw.RoundedBox(6, 0, 0, w, h, Color(70, 130, 200, 150))
            end
            draw.SimpleText("Apply", "ChalkMarkerUI_LabelFont", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        apply.DoClick = function()
            local savedColor = Color(currentColor.r, currentColor.g, currentColor.b, 255)
            table.insert(ChalkMarkerUI.PickerLastColors, 1, savedColor)
            if #ChalkMarkerUI.PickerLastColors > 8 then
                table.remove(ChalkMarkerUI.PickerLastColors, 9)
            end
            
            weapon.CustomColor = savedColor
            weapon.CurrentColor = "__custom__"
            
            if ChalkMarkerUI.State.WeaponType == "chalk" and weapon.SetChalkColor2 then
                weapon:SetChalkColor2(Vector(savedColor.r/255, savedColor.g/255, savedColor.b/255))
            elseif ChalkMarkerUI.State.WeaponType == "marker" and weapon.SetMarkerColor2 then
                weapon:SetMarkerColor2(Vector(savedColor.r/255, savedColor.g/255, savedColor.b/255))
                if weapon.SetBodyTexture then
                    weapon:SetBodyTexture("models/tools_materials/marker/colors/marker_base_texture")
                end
            end
            
            local sizeValue = 7.0
            if weapon.GetDrawSizeValue then
                sizeValue = weapon:GetDrawSizeValue()
            elseif weapon.CurrentSizeValue then
                sizeValue = weapon.CurrentSizeValue
            end
            
            net.Start("ChalkMarkerUI_UpdateWeapon")
                net.WriteString("__custom__")
                net.WriteFloat(sizeValue)
                net.WriteColor(savedColor)
            net.SendToServer()
            
            frame:Remove()
            surface.PlaySound("buttons/button15.wav")
        end

        local cancel = vgui.Create("DButton", frame)
        cancel:SetSize(120, 40)
        cancel:SetPos(380, 465)
        cancel:SetText("Cancel")
        cancel:SetFont("ChalkMarkerUI_LabelFont")
        cancel.Paint = function(self, w, h)
            if self:IsHovered() then
                draw.RoundedBox(6, 0, 0, w, h, Color(100, 100, 100, 150))
            else
                draw.RoundedBox(6, 0, 0, w, h, Color(80, 80, 80, 100))
            end
            draw.SimpleText("Cancel", "ChalkMarkerUI_LabelFont", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        cancel.DoClick = function()
            frame:Remove()
            surface.PlaySound("buttons/button14.wav")
        end
        
        requestUIUpdate()
    end

    return panel
end

-- ============ ВКЛАДКА РАЗМЕРОВ ==========

function ChalkMarkerUI.CreateSizeTab(parent)
    local panel = vgui.Create("DPanel", parent)
    panel:SetSize(460, 400)
    panel:SetPos(0, 0)
    
    local weapon = ChalkMarkerUI.State.CurrentWeapon
    if not IsValid(weapon) then return panel end
    local weaponType = ChalkMarkerUI.State.WeaponType
    
    local drawMin, drawMax = ChalkMarkerConfig.GetMinMaxSizes(weaponType, "draw")
    local eraseMin, eraseMax = ChalkMarkerConfig.GetMinMaxSizes(weaponType, "erase")

    local drawSlider, eraseSlider

    local function CreateCleanSlider(parent, min, max, default, isErase)
        local sliderPanel = vgui.Create("DPanel", parent)
        sliderPanel:SetSize(420, 50)
        sliderPanel.value = default
        
        -- Кнопка-ползунок (синяя, круглая, меньше)
        local knob = vgui.Create("DButton", sliderPanel)
        knob:SetSize(10, 10)
        knob:SetText("")
        knob.Paint = function(self, w, h)
            draw.RoundedBox(w/2, 0, 0, w, h, Color(70, 160, 255, 255))
        end
        knob:SetCursor("sizewe")
        
        local function updateKnobPosition(val)
            local range = max - min
            local t = (val - min) / range
            local xPos = 40 + t * 340
            knob:SetPos(xPos - 5, 13)
        end
        
        knob.OnMousePressed = function()
            knob.Dragging = true
            knob:MouseCapture(true)
        end
        
        knob.OnMouseReleased = function()
            knob.Dragging = false
            knob:MouseCapture(false)
        end
        
        knob.Think = function()
            if knob.Dragging and input.IsMouseDown(MOUSE_LEFT) then
                local x, y = sliderPanel:CursorPos()
                local t = math.Clamp((x - 40) / 340, 0, 1)
                local newVal = min + t * (max - min)
                newVal = math.Round(newVal * 10) / 10
                sliderPanel.value = math.Clamp(newVal, min, max)
                updateKnobPosition(sliderPanel.value)
                
                if sliderPanel.OnValueChanged then
                    sliderPanel.OnValueChanged(sliderPanel.value)
                end
            end
        end
        
        sliderPanel.Paint = function(self, w, h)
            local sliderY = 18
            
            -- Серая линия слайдера (фон)
            surface.SetDrawColor(Color(80, 80, 80, 200))
            surface.DrawLine(40, sliderY, 40 + 340, sliderY)
            
            -- Заполненная часть (синяя)
            local fillT = (sliderPanel.value - min) / (max - min)
            local fillX = 40 + fillT * 340
            surface.SetDrawColor(Color(70, 160, 255, 255))
            surface.DrawLine(40, sliderY, fillX, sliderY)
            
            -- Шкала с делениями НА ЛИНИИ
            local stepSize = isErase and 5 or 1
            for val = min, max, stepSize do
                local t = (val - min) / (max - min)
                local xPos = 40 + t * 340
                
                local isCurrent = math.abs(sliderPanel.value - val) < 0.05
                
                -- Рисуем деление (насечки на линии)
                if isCurrent then
                    surface.SetDrawColor(Color(70, 160, 255, 255))
                    surface.DrawLine(xPos, sliderY - 4, xPos, sliderY + 4)  -- Пересекает линию
                else
                    surface.SetDrawColor(Color(200, 200, 200, 150))
                    surface.DrawLine(xPos, sliderY - 3, xPos, sliderY + 3)  -- Пересекает линию
                end
                
                -- Подписи ПОД линией
                local shouldDraw = isErase or (val == math.floor(val))
                if shouldDraw then
                    if isCurrent then
                        draw.SimpleText(tostring(val), "DefaultFixed", xPos, sliderY + 8, Color(70, 160, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    else
                        draw.SimpleText(tostring(val), "DefaultFixed", xPos, sliderY + 8, Color(200, 200, 200, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    end
                end
            end
        end
                
        sliderPanel.SetValue = function(self, val)
            self.value = math.Clamp(val, min, max)
            updateKnobPosition(self.value)
        end
        
        sliderPanel.GetValue = function(self)
            return self.value
        end
        
        updateKnobPosition(default)
        return sliderPanel
    end

    -- ====== РИСОВАНИЕ ======
    local drawLabel = vgui.Create("DLabel", panel)
    drawLabel:SetPos(30, 90)
    drawLabel:SetText("Draw size:")
    drawLabel:SetFont("ChalkMarkerUI_LabelFont")
    drawLabel:SetTextColor(ChalkMarkerUI.Config.TextColor)
    drawLabel:SizeToContents()

    drawSlider = CreateCleanSlider(panel, drawMin, drawMax, weapon.CurrentSizeValue or 7, false)
    drawSlider:SetPos(20, 100)
    drawSlider.OnValueChanged = function(val)
        weapon.CurrentSizeValue = val
        local colorName = weapon.GetPlayerColor and weapon:GetPlayerColor() or (weapon.CurrentColor or "white")
        net.Start("ChalkMarkerUI_UpdateWeapon")
        net.WriteString(colorName)
        net.WriteFloat(val)
        net.SendToServer()
    end
    ChalkMarkerUI.DrawSlider = drawSlider

    -- ====== СТИРАНИЕ ======
    local eraseLabel = vgui.Create("DLabel", panel)
    eraseLabel:SetPos(30, 190)
    eraseLabel:SetText("Erase size:")
    eraseLabel:SetFont("ChalkMarkerUI_LabelFont")
    eraseLabel:SetTextColor(ChalkMarkerUI.Config.TextColor)
    eraseLabel:SizeToContents()

    eraseSlider = CreateCleanSlider(panel, eraseMin, eraseMax, weapon.CurrentEraseSizeValue or 15, true)
    eraseSlider:SetPos(20, 200)
    eraseSlider.OnValueChanged = function(val)
        weapon.CurrentEraseSizeValue = val
        net.Start("ChalkMarkerUI_UpdateEraseSize")
        net.WriteFloat(val)
        net.SendToServer()
    end
    ChalkMarkerUI.EraseSlider = eraseSlider

    -- ====== КНОПКА СБРОСА ======
    
    local resetBtn = vgui.Create("DButton", panel)
    resetBtn:SetSize(200, 40)
    resetBtn:SetPos(130, 350)
    resetBtn:SetText("Reset settings")
    resetBtn:SetFont("ChalkMarkerUI_TabFont")  -- Жирный шрифт
    resetBtn:SetTextColor(Color(255, 100, 100))
    resetBtn.Paint = function(self, w, h)
        if self:IsHovered() then
            draw.RoundedBox(8, 0, 0, w, h, Color(255, 80, 80, 80))
            resetBtn:SetTextColor(Color(255, 150, 150))
        else
            draw.RoundedBox(8, 0, 0, w, h, Color(80, 80, 80, 100))
            resetBtn:SetTextColor(Color(255, 100, 100))
        end
        
        if self:IsDown() then
            draw.RoundedBox(8, 0, 0, w, h, Color(255, 100, 100, 100))
            resetBtn:SetTextColor(Color(255, 180, 180))
        end
    end

    resetBtn.DoClick = function()
        Derma_Query("Reset all tool settings?", "Confirmation",
            "Yes", function()
                local defaultColor = (weaponType == "chalk") and "white" or "black"
                local defaultDrawValue = 7
                local defaultEraseValue = 15
            
                if not IsValid(weapon) then return end

                weapon.CurrentSizeValue = defaultDrawValue
                weapon.CurrentEraseSizeValue = defaultEraseValue

                if IsValid(drawSlider) then drawSlider:SetValue(defaultDrawValue) end
                if IsValid(eraseSlider) then eraseSlider:SetValue(defaultEraseValue) end

                if weapon.SetPlayerColor then
                    weapon:SetPlayerColor(defaultColor)
                else
                    weapon.CurrentColor = defaultColor
                end

                net.Start("ChalkMarkerUI_UpdateWeapon")
                    net.WriteString(defaultColor)
                    net.WriteFloat(defaultDrawValue)
                net.SendToServer()
            
                net.Start("ChalkMarkerUI_UpdateEraseSize")
                    net.WriteFloat(defaultEraseValue)
                net.SendToServer()
            
                surface.PlaySound("buttons/button14.wav")
            end,
            "No", function() end
        )
    end

    -- Отрисовка заголовка и индикаторов поверх всего
    panel.Paint = function(self, w, h)
        draw.SimpleText("Size settings", "ChalkMarkerUI_TabFont", w/2, 30, ChalkMarkerUI.Config.TextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        -- Индикаторы значений поверх всего (не обрезаются)
        if IsValid(drawSlider) then
            local displayText = string.format("%.1f", drawSlider:GetValue())
            local x, y = drawSlider:GetPos()
            draw.SimpleText(displayText, "ChalkMarkerUI_TitleFont", x + 415, y - 15, Color(70, 160, 255, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        end
        
        if IsValid(eraseSlider) then
            local displayText = string.format("%.1f", eraseSlider:GetValue())
            local x, y = eraseSlider:GetPos()
            draw.SimpleText(displayText, "ChalkMarkerUI_TitleFont", x + 415, y - 15, Color(70, 160, 255, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        end
    end

    return panel
end

-- ============ ОБНОВЛЕНИЕ КОНТЕНТА ============

function ChalkMarkerUI.UpdateContent()
    if not ChalkMarkerUI.MainFrame or not ChalkMarkerUI.MainFrame:IsValid() then 
        return 
    end
    
    if ChalkMarkerUI.ContentPanel then
        ChalkMarkerUI.ContentPanel:Remove()
    end
    
    ChalkMarkerUI.ContentPanel = vgui.Create("DPanel", ChalkMarkerUI.MainFrame)
    ChalkMarkerUI.ContentPanel:SetSize(460, 400)
    ChalkMarkerUI.ContentPanel:SetPos(20, 120)
    ChalkMarkerUI.ContentPanel.Paint = function() end
    
    if ChalkMarkerUI.State.ActiveTab == "color" then
        ChalkMarkerUI.CreateColorTab(ChalkMarkerUI.ContentPanel)
    elseif ChalkMarkerUI.State.ActiveTab == "size" then
        ChalkMarkerUI.CreateSizeTab(ChalkMarkerUI.ContentPanel)
    end
end

-- ============ ОТКРЫТИЕ МЕНЮ ============

function ChalkMarkerUI.OpenMenu(weapon)
    if ChalkMarkerUI.State.IsOpen then 
        return 
    end
    
    if not IsValid(weapon) then
        return
    end
    
    -- Защита от слишком частого открытия
    if ChalkMarkerUI.OpenCooldown and CurTime() - ChalkMarkerUI.OpenCooldown < 0.5 then
        return
    end
    ChalkMarkerUI.OpenCooldown = CurTime()
    
    local weaponName = weapon:GetPrintName() or ""
    
    -- Определяем тип оружия
    if weaponName == "Chalk" then
        ChalkMarkerUI.State.WeaponType = "chalk"
    elseif weaponName == "Marker" then
        ChalkMarkerUI.State.WeaponType = "marker"
    else
        return
    end
    
    ChalkMarkerUI.State.CurrentWeapon = weapon
    ChalkMarkerUI.State.IsOpen = true
    ChalkMarkerUI.State.ActiveTab = "color"
    
    -- ВАЖНО: Проверяем и инициализируем переменные размера
    -- Если переменные не установлены, устанавливаем их из текущих значений
    
    -- Для цвета
    if not weapon.CurrentColor then
        if weapon.GetPlayerColor then
            weapon.CurrentColor = weapon:GetPlayerColor()
        else
            weapon.CurrentColor = ChalkMarkerUI.State.WeaponType == "chalk" and "white" or "black"
        end
    end
    
    -- Для размера рисования
    if not weapon.CurrentSizeValue then
        if weapon.GetDrawSizeValue then
            weapon.CurrentSizeValue = weapon:GetDrawSizeValue()
        else
            weapon.CurrentSizeValue = ChalkMarkerConfig.GetSizeValue(ChalkMarkerUI.State.WeaponType, "draw", "medium")
        end
    end
    
    if not weapon.CurrentSize then
        weapon.CurrentSize = "medium"
    end
    
    -- Для размера стирания
    if not weapon.CurrentEraseSizeValue then
        if weapon.GetEraseSizeValue then
            weapon.CurrentEraseSizeValue = weapon:GetEraseSizeValue()
        else
            weapon.CurrentEraseSizeValue = ChalkMarkerConfig.GetSizeValue(ChalkMarkerUI.State.WeaponType, "erase", "medium")
        end
    end
    
    if not weapon.CurrentEraseSize then
        weapon.CurrentEraseSize = "medium"
    end
    
    -- Скрываем оружие и включаем курсор
    weapon:SetNoDraw(true)
    gui.EnableScreenClicker(true)
    
    -- Создаем интерфейс
    ChalkMarkerUI.BlurBackground = ChalkMarkerUI.CreateBlurBackground()
    if not IsValid(ChalkMarkerUI.BlurBackground) then
        ChalkMarkerUI.State.IsOpen = false
        weapon:SetNoDraw(false)
        gui.EnableScreenClicker(false)
        return
    end
    
    ChalkMarkerUI.MainFrame = ChalkMarkerUI.CreateMainFrame()
    if not IsValid(ChalkMarkerUI.MainFrame) then
        ChalkMarkerUI.State.IsOpen = false
        weapon:SetNoDraw(false)
        gui.EnableScreenClicker(false)
        ChalkMarkerUI.BlurBackground:Remove()
        return
    end
    
    ChalkMarkerUI.MainFrame:SetZPos(100)
    ChalkMarkerUI.TabContainer = ChalkMarkerUI.CreateTabs(ChalkMarkerUI.MainFrame)
    ChalkMarkerUI.UpdateContent()
end

-- ============ ЗАКРЫТИЕ МЕНЮ ============

function ChalkMarkerUI.CloseMenu()
    if not ChalkMarkerUI.State.IsOpen then 
        return 
    end
    
    if ChalkMarkerUI.CloseCooldown and CurTime() - ChalkMarkerUI.CloseCooldown < 0.5 then
        return
    end
    
    if IsValid(ChalkMarkerUI.State.CurrentWeapon) then
        local weapon = ChalkMarkerUI.State.CurrentWeapon
        
        local colorName
        if weapon.GetPlayerColor then
            colorName = weapon:GetPlayerColor()
        else
            colorName = weapon.CurrentColor or (ChalkMarkerUI.State.WeaponType == "chalk" and "white" or "black")
        end
        
        local sizeValue
        if weapon.GetDrawSizeValue then
            sizeValue = weapon:GetDrawSizeValue()
        elseif weapon.CurrentSizeValue then
            sizeValue = weapon.CurrentSizeValue
        else
            sizeValue = ChalkMarkerConfig.GetSizeValue(ChalkMarkerUI.State.WeaponType, "draw", "medium")
        end
        
        -- Отправляем с учетом кастомного цвета
        net.Start("ChalkMarkerUI_UpdateWeapon")
            net.WriteString(colorName)
            net.WriteFloat(sizeValue)
            if colorName == "__custom__" and weapon.CustomColor then
                net.WriteColor(weapon.CustomColor)
            end
        net.SendToServer()
        
        local eraseSizeValue
        if weapon.GetEraseSizeValue then
            eraseSizeValue = weapon:GetEraseSizeValue()
        elseif weapon.CurrentEraseSizeValue then
            eraseSizeValue = weapon.CurrentEraseSizeValue
        else
            eraseSizeValue = ChalkMarkerConfig.GetSizeValue(ChalkMarkerUI.State.WeaponType, "erase", "medium")
        end
        
        net.Start("ChalkMarkerUI_UpdateEraseSize")
            net.WriteFloat(eraseSizeValue)
        net.SendToServer()
    end
    
    ChalkMarkerUI.State.IsOpen = false
    
    if IsValid(ChalkMarkerUI.State.CurrentWeapon) then
        ChalkMarkerUI.State.CurrentWeapon:SetNoDraw(false)
    end
    gui.EnableScreenClicker(false)
    
    if IsValid(ChalkMarkerUI.MainFrame) then
        ChalkMarkerUI.MainFrame:Remove()
    end
    
    if IsValid(ChalkMarkerUI.BlurBackground) then
        ChalkMarkerUI.BlurBackground:Remove()
    end
    
    ChalkMarkerUI.CloseCooldown = CurTime()
end

-- ============ ОБНОВЛЕНИЕ ОТОБРАЖЕНИЯ ============

function ChalkMarkerUI.UpdateColorDisplay()
    return
end


-- ============ КЛИЕНТСКИЕ ХУКИ ============

hook.Add("Think", "ChalkMarkerUI_Main", function()
    if ChalkMarkerUI.KeybindBlocked then return end
    local currentKeyState = input.IsKeyDown(ChalkMarkerUI.Keybind)
    if currentKeyState and not ChalkMarkerUI.LastTState then
        
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        
        local weapon = ply:GetActiveWeapon()
        if not IsValid(weapon) then return end
        
        local weaponName = weapon:GetPrintName() or ""
        
        -- Проверяем, поддерживается ли оружие
        if weaponName == "Chalk" or weaponName == "Marker" then
            if not ChalkMarkerUI.State.IsOpen then
                ChalkMarkerUI.OpenMenu(weapon)
            end
        end
    end
    
    ChalkMarkerUI.LastTState = currentKeyState
end)

hook.Add("Think", "ChalkMarkerUI_ESC", function()
    if ChalkMarkerUI.State.IsOpen and input.IsKeyDown(KEY_ESCAPE) then
        ChalkMarkerUI.CloseMenu()
    end
end)

hook.Add("PlayerSwitchWeapon", "ChalkMarkerUI_Switch", function(ply, oldWeapon, newWeapon)
    if ChalkMarkerUI.State.IsOpen then
        ChalkMarkerUI.CloseMenu()
    end
end)

hook.Add("PlayerDeath", "ChalkMarkerUI_Death", function(ply)
    if ChalkMarkerUI.State.IsOpen then
        ChalkMarkerUI.CloseMenu()
    end
end)

hook.Add("Think", "ChalkMarkerUI_ColorUpdate", function()
    if ChalkMarkerUI.State.IsOpen then
        ChalkMarkerUI.UpdateColorDisplay()
    end
end)

print("[DB_UI] Interface loaded successfully")