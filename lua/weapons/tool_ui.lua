print("[DB_UI] Loading interface...")

ChalkMarkerUI = ChalkMarkerUI or {}
ChalkMarkerUI.Keybind = KEY_T
ChalkMarkerUI.KeybindBlocked = false

if CLIENT then
    -- Обработчики синхронизации размеров
    net.Receive("ChalkMarkerUI_SyncSize", function()
        local weapon = net.ReadEntity()
        local sizeName = net.ReadString()
        local sizeValue = net.ReadUInt(8)
        
        if IsValid(weapon) then
            -- Обновляем на клиенте
            if weapon.SetPlayerSize then
                weapon:SetPlayerSize(sizeName)
            else
                weapon.CurrentSize = sizeName
                weapon.CurrentSizeValue = sizeValue
            end
            
            -- Обновляем UI если он открыт
            if ChalkMarkerUI.State.IsOpen and IsValid(ChalkMarkerUI.State.CurrentWeapon) and 
               ChalkMarkerUI.State.CurrentWeapon == weapon then
                ChalkMarkerUI.UpdateContent()
            end
        end
    end)
    
    net.Receive("ChalkMarkerUI_SyncEraseSize", function()
        local weapon = net.ReadEntity()
        local sizeName = net.ReadString()
        local sizeValue = net.ReadUInt(8)
        
        if IsValid(weapon) then
            -- Обновляем на клиенте
            if weapon.SetPlayerEraseSize then
                weapon:SetPlayerEraseSize(sizeName)
            else
                weapon.CurrentEraseSize = sizeName
                weapon.CurrentEraseSizeValue = sizeValue
            end
            
            -- Обновляем UI если он открыт
            if ChalkMarkerUI.State.IsOpen and IsValid(ChalkMarkerUI.State.CurrentWeapon) and 
               ChalkMarkerUI.State.CurrentWeapon == weapon then
                ChalkMarkerUI.UpdateContent()
            end
        end
    end)

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
    blurPanel:SetSize(ScrW(), ScrH())
    blurPanel:SetPos(0, 0)
    blurPanel:SetZPos(-100)
    blurPanel:SetMouseInputEnabled(true)
    
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
    
    frame.Think = function() end
    
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
    closeBtn:SetText("×")
    closeBtn:SetFont("DermaDefaultBold")
    closeBtn:SetTextColor(Color(200, 200, 200))
    closeBtn.Paint = function(self, w, h)
        draw.RoundedBox(15, 0, 0, w, h, Color(80, 80, 80, 150))
        if self:IsHovered() then
            draw.RoundedBox(15, 0, 0, w, h, Color(255, 50, 50, 100))
        end
    end
    closeBtn.DoClick = function()
        ChalkMarkerUI.CloseMenu()
    end
    
    return frame
end

-- ============ ВКЛАДКИ ============

function ChalkMarkerUI.CreateTabs(parent)
    local tabContainer = vgui.Create("DPanel", parent)
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
    local scroll = vgui.Create("DScrollPanel", parent)
    scroll:SetSize(460, 400)
    scroll:SetPos(0, 0)
    
    local colors = ChalkMarkerUI.Data[ChalkMarkerUI.State.WeaponType].colors
    local weapon = ChalkMarkerUI.State.CurrentWeapon
    
    local function updateCurrentColorDisplay(newColor)
        for i, colorData in ipairs(colors) do
            local colorBtn = scroll:GetChild(i)
            if IsValid(colorBtn) then
                colorBtn:SetText("")
            end
        end
    end
    
    for i, colorData in ipairs(colors) do
        local colorBtn = vgui.Create("DButton", scroll)
        colorBtn:SetSize(420, 50)
        colorBtn:SetPos(10, (i-1) * 60)
        colorBtn:SetText("")
        
        colorBtn.Paint = function(self, w, h)
            -- Получаем текущий цвет
            local currentColor
            if weapon.GetPlayerColor then
                currentColor = weapon:GetPlayerColor()
            else
                currentColor = weapon.CurrentColor or (ChalkMarkerUI.State.WeaponType == "chalk" and "white" or "black")
            end
            
            local isSelected = currentColor == colorData.name
            local isHovered = self:IsHovered()
            
            if isSelected then
                draw.RoundedBox(8, 0, 0, w, h, Color(70, 130, 200, 50))
            elseif isHovered then
                draw.RoundedBox(8, 0, 0, w, h, Color(255, 255, 255, 20))
            end
            
            draw.RoundedBox(6, 10, 10, 30, 30, colorData.color)
            
            draw.SimpleText(
                colorData.display,
                "ChalkMarkerUI_TabFont",
                50, 
                25,
                ChalkMarkerUI.Config.TextColor,
                TEXT_ALIGN_LEFT,
                TEXT_ALIGN_CENTER
            )
            
            if isSelected then
                surface.SetDrawColor(ChalkMarkerUI.Config.AccentColor)
                surface.DrawOutlinedRect(0, 0, w, h, 2)
            end
        end
        
        colorBtn.DoClick = function()
            local weapon = ChalkMarkerUI.State.CurrentWeapon
            local colorName = colorData.name
            
            -- Получаем текущий цвет для сравнения
            local currentColor
            if weapon.GetPlayerColor then
                currentColor = weapon:GetPlayerColor()
            else
                currentColor = weapon.CurrentColor or (ChalkMarkerUI.State.WeaponType == "chalk" and "white" or "black")
            end
            
            -- Если цвет уже выбран, не делаем ничего
            if currentColor == colorName then return end
            
            -- Устанавливаем цвет
            if weapon.SetPlayerColor then
                weapon:SetPlayerColor(colorName)
            else
                -- Совместимость со старой версией
                weapon.CurrentColor = colorName
                if ChalkMarkerUI.State.WeaponType == "chalk" and weapon.SetChalkColor then
                    weapon:SetChalkColor(colorName)
                elseif ChalkMarkerUI.State.WeaponType == "marker" and weapon.SetMarkerColor then
                    weapon:SetMarkerColor(colorName)
                end
            end
            
            -- Получаем текущий размер
            local sizeValue = 7
            if weapon.GetDrawSizeValue then
                sizeValue = weapon:GetDrawSizeValue()
            elseif weapon.CurrentSizeValue then
                sizeValue = weapon.CurrentSizeValue
            elseif weapon.GetPlayerSize then
                local sizeName = weapon:GetPlayerSize()
                sizeValue = ChalkMarkerConfig.GetSizeValue(ChalkMarkerUI.State.WeaponType, "draw", sizeName)
            end
            
            -- Синхронизируем с сервером
            net.Start("ChalkMarkerUI_UpdateWeapon")
                net.WriteString(colorName)
                net.WriteUInt(sizeValue, 8)
            net.SendToServer()
            
            updateCurrentColorDisplay(colorName)
        end
    end
    
    return scroll
end

-- ============ ВКЛАДКА РАЗМЕРА ================

-- В функции CreateSizeTab заменяем код слайдеров:
function ChalkMarkerUI.CreateSizeTab(parent)
    local panel = vgui.Create("DPanel", parent)
    panel:SetSize(460, 400)
    panel:SetPos(0, 0)
    panel.Paint = function(self, w, h)
        draw.SimpleText(
            "Size settings",
            "ChalkMarkerUI_TabFont",
            w/2, 
            30,
            ChalkMarkerUI.Config.TextColor,
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
    end
    
    local weapon = ChalkMarkerUI.State.CurrentWeapon
    if not IsValid(weapon) then return panel end
    
    -- Определяем тип оружия
    local weaponType = ChalkMarkerUI.State.WeaponType
    
    -- Получаем текущие значения
    local currentDrawSizeValue, currentEraseSizeValue
    
    -- Для размера рисования
    if weapon.CurrentSizeValue then
        currentDrawSizeValue = weapon.CurrentSizeValue
    elseif weapon.GetDrawSizeValue then
        currentDrawSizeValue = weapon:GetDrawSizeValue()
    else
        currentDrawSizeValue = 7 -- значение по умолчанию
    end
    
    -- Для размера стирания
    if weapon.CurrentEraseSizeValue then
        currentEraseSizeValue = weapon.CurrentEraseSizeValue
    elseif weapon.GetEraseSizeValue then
        currentEraseSizeValue = weapon:GetEraseSizeValue()
    else
        currentEraseSizeValue = 15 -- значение по умолчанию
    end
    
    -- Получаем минимальные и максимальные значения
    local drawMin, drawMax = ChalkMarkerConfig.GetMinMaxSizes(weaponType, "draw")
    local eraseMin, eraseMax = ChalkMarkerConfig.GetMinMaxSizes(weaponType, "erase")
    
    -- Ограничиваем значения
    currentDrawSizeValue = math.Clamp(currentDrawSizeValue, drawMin, drawMax)
    currentEraseSizeValue = math.Clamp(currentEraseSizeValue, eraseMin, eraseMax)
    
    -- ====== РАЗМЕР РИСОВАНИЯ ======
    local drawLabel = vgui.Create("DLabel", panel)
    drawLabel:SetPos(30, 86)
    drawLabel:SetText("Draw size:")
    drawLabel:SetFont("ChalkMarkerUI_LabelFont")
    drawLabel:SetTextColor(ChalkMarkerUI.Config.TextColor)
    drawLabel:SizeToContents()
    
    local drawSlider = vgui.Create("DNumSlider", panel)
    drawSlider:SetPos(20, 80)
    drawSlider:SetSize(420, 40)
    drawSlider:SetText("")
    drawSlider:SetMin(drawMin)
    drawSlider:SetMax(drawMax)
    drawSlider:SetDecimals(0)
    drawSlider:SetValue(currentDrawSizeValue)
    drawSlider:SetDark(true)

    -- Простая настройка цвета текста
    if drawSlider.Label then
        drawSlider.Label:SetTextColor(Color(200, 200, 200))
    end
    
    if drawSlider.TextArea then
        drawSlider.TextArea:SetTextColor(Color(200, 200, 200))
        drawSlider.TextArea:SetNumeric(true)
        drawSlider.TextArea:SetValue(tostring(currentDrawSizeValue))
        drawSlider.TextArea:SetEditable(true)
    end
    
    local lastDrawValue = currentDrawSizeValue
    
    drawSlider.OnValueChanged = function(self, value)
        local intValue = math.Round(value)
        
        -- Обновляем TextArea
        if self.TextArea then
            self.TextArea:SetValue(tostring(intValue))
        end
        
        -- Сохраняем в оружии
        weapon.CurrentSizeValue = intValue
        
        -- Получаем текущий цвет
        local colorName
        if weapon.GetPlayerColor then
            colorName = weapon:GetPlayerColor()
        else
            colorName = weapon.CurrentColor or (weaponType == "chalk" and "white" or "black")
        end
        
        -- Синхронизируем с сервером
        net.Start("ChalkMarkerUI_UpdateWeapon")
            net.WriteString(colorName)
            net.WriteUInt(intValue, 8)
        net.SendToServer()
        
        lastDrawValue = intValue
    end
    
    -- ====== РАЗМЕР СТИРАНИЯ ======
    local eraseLabel = vgui.Create("DLabel", panel)
    eraseLabel:SetPos(30, 167)
    eraseLabel:SetText("Erase size:")
    eraseLabel:SetFont("ChalkMarkerUI_LabelFont")
    eraseLabel:SetTextColor(ChalkMarkerUI.Config.TextColor)
    eraseLabel:SizeToContents()
    
    local eraseSlider = vgui.Create("DNumSlider", panel)
    eraseSlider:SetPos(20, 160)
    eraseSlider:SetSize(420, 40)
    eraseSlider:SetText("")
    eraseSlider:SetMin(eraseMin)
    eraseSlider:SetMax(eraseMax)
    eraseSlider:SetDecimals(0)
    eraseSlider:SetValue(currentEraseSizeValue)
    eraseSlider:SetDark(true)

    if eraseSlider.TextArea then
        eraseSlider.TextArea:SetTextColor(Color(200, 200, 200))
        eraseSlider.TextArea:SetNumeric(true)
        eraseSlider.TextArea:SetValue(tostring(currentEraseSizeValue))
        eraseSlider.TextArea:SetEditable(true)
    end
    
    local lastEraseValue = currentEraseSizeValue
    
    eraseSlider.OnValueChanged = function(self, value)
        local intValue = math.Round(value)
        
        -- Обновляем TextArea
        if self.TextArea then
            self.TextArea:SetValue(tostring(intValue))
        end
        
        -- Сохраняем в оружии
        weapon.CurrentEraseSizeValue = intValue
        
        -- Синхронизируем с сервером
        net.Start("ChalkMarkerUI_UpdateEraseSize")
            net.WriteUInt(intValue, 8)
        net.SendToServer()
        
        lastEraseValue = intValue
    end
    
    -- ====== КНОПКА СБРОСА ======
    local resetBtn = vgui.Create("DButton", panel)
    resetBtn:SetSize(200, 40)
    resetBtn:SetPos(130, 350)
    resetBtn:SetText("Reset settings")
    resetBtn:SetFont("ChalkMarkerUI_LabelFont") 
    resetBtn:SetTextColor(Color(255, 100, 100))
    resetBtn.Paint = function(self, w, h)
        if self:IsHovered() then
            draw.RoundedBox(8, 0, 0, w, h, Color(255, 50, 50, 50))
        else
            draw.RoundedBox(8, 0, 0, w, h, Color(80, 80, 80, 100))
        end
    end
    
    resetBtn.DoClick = function()
        Derma_Query("Reset all tool settings?", "Confirmation",
            "Yes", function()
                local defaultColor = weaponType == "chalk" and "white" or "black"
                local defaultDrawValue = 7
                local defaultEraseValue = 15
                
                -- Сбрасываем значения
                weapon.CurrentSizeValue = defaultDrawValue
                weapon.CurrentEraseSizeValue = defaultEraseValue
                
                -- Обновляем слайдеры
                drawSlider:SetValue(defaultDrawValue)
                if drawSlider.TextArea then
                    drawSlider.TextArea:SetValue(tostring(defaultDrawValue))
                end
                lastDrawValue = defaultDrawValue
                
                eraseSlider:SetValue(defaultEraseValue)
                if eraseSlider.TextArea then
                    eraseSlider.TextArea:SetValue(tostring(defaultEraseValue))
                end
                lastEraseValue = defaultEraseValue
                
                -- Сбрасываем цвет
                if weapon.SetPlayerColor then
                    weapon:SetPlayerColor(defaultColor)
                else
                    weapon.CurrentColor = defaultColor
                end
                
                -- Обновляем визуал оружия
                if weaponType == "chalk" and weapon.SetChalkColor then
                    weapon:SetChalkColor(defaultColor)
                elseif weaponType == "marker" and weapon.SetMarkerColor then
                    weapon:SetMarkerColor(defaultColor)
                end
                
                -- Синхронизируем с сервером
                net.Start("ChalkMarkerUI_UpdateWeapon")
                    net.WriteString(defaultColor)
                    net.WriteUInt(defaultDrawValue, 8)
                net.SendToServer()
                
                net.Start("ChalkMarkerUI_UpdateEraseSize")
                    net.WriteUInt(defaultEraseValue, 8)
                net.SendToServer()
                
                -- Обновляем интерфейс
                if IsValid(ChalkMarkerUI.ContentPanel) then
                    ChalkMarkerUI.ContentPanel:InvalidateLayout()
                end
            end,
            "No", function() end
        )
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
    
    -- Защита от слишком частого закрытия
    if ChalkMarkerUI.CloseCooldown and CurTime() - ChalkMarkerUI.CloseCooldown < 0.5 then
        return
    end
    
    -- Синхронизируем последние изменения с сервером
    if IsValid(ChalkMarkerUI.State.CurrentWeapon) then
        local weapon = ChalkMarkerUI.State.CurrentWeapon
        
        -- Получаем текущий цвет
        local colorName
        if weapon.GetPlayerColor then
            colorName = weapon:GetPlayerColor()
        else
            colorName = weapon.CurrentColor or (ChalkMarkerUI.State.WeaponType == "chalk" and "white" or "black")
        end
        
        -- Получаем текущий размер
        local sizeValue
        if weapon.GetDrawSizeValue then
            sizeValue = weapon:GetDrawSizeValue()
        elseif weapon.CurrentSizeValue then
            sizeValue = weapon.CurrentSizeValue
        else
            sizeValue = ChalkMarkerConfig.GetSizeValue(ChalkMarkerUI.State.WeaponType, "draw", "medium")
        end
        
        -- Синхронизируем с сервером
        net.Start("ChalkMarkerUI_UpdateWeapon")
            net.WriteString(colorName)
            net.WriteUInt(sizeValue, 8)
        net.SendToServer()
        
        -- Также синхронизируем размер стирания
        local eraseSizeValue
        if weapon.GetEraseSizeValue then
            eraseSizeValue = weapon:GetEraseSizeValue()
        elseif weapon.CurrentEraseSizeValue then
            eraseSizeValue = weapon.CurrentEraseSizeValue
        else
            eraseSizeValue = ChalkMarkerConfig.GetSizeValue(ChalkMarkerUI.State.WeaponType, "erase", "medium")
        end
        
        net.Start("ChalkMarkerUI_UpdateEraseSize")
            net.WriteUInt(eraseSizeValue, 8)
        net.SendToServer()
    end
    
    ChalkMarkerUI.State.IsOpen = false
    
    -- Показываем оружие и скрываем курсор
    if IsValid(ChalkMarkerUI.State.CurrentWeapon) then
        ChalkMarkerUI.State.CurrentWeapon:SetNoDraw(false)
    end
    gui.EnableScreenClicker(false)
    
    -- Удаляем интерфейс
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
    if not ChalkMarkerUI.State.IsOpen then return end
    
    local weapon = ChalkMarkerUI.State.CurrentWeapon
    if not IsValid(weapon) then return end
    
    if ChalkMarkerUI.State.ActiveTab == "color" and ChalkMarkerUI.ContentPanel then
        ChalkMarkerUI.ContentPanel:InvalidateLayout()
    end
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