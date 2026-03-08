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
    --frame.IsMyUIElement = true
    frame:SetSize(500, 600)
    frame:Center()
    frame:SetTitle("Tool Menu")
    frame.lblTitle:SetVisible(false)
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
    closeBtn:SetText("") -- Убираем стандартный текст, нарисуем его сами для точности
    
    closeBtn.Paint = function(self, w, h)
        -- Радиус 8 даст отличный "мягкий квадрат"
        local radius = 8 
        local bgColor = self:IsHovered() and Color(255, 50, 50, 150) or Color(80, 80, 80, 150)
        
        -- Рисуем фон
        draw.RoundedBox(radius, 0, 0, w, h, bgColor)
        
        local xoffset = -0.45
        local yoffset = -1
        draw.SimpleText("×", "ChalkMarkerUI_CloseIcon", w/2 + xoffset, h/2 + yoffset, Color(220, 220, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    closeBtn.DoClick = function()
        surface.PlaySound("garrysmod/ui_click.wav") -- Твой любимый звук
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
    local scroll = vgui.Create("DScrollPanel", parent)
    --scroll.IsMyUIElement = true
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
        --colorBtn.IsMyUIElement = true
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
                net.WriteFloat(sizeValue)
            net.SendToServer()
            
            updateCurrentColorDisplay(colorName)
        end
    end
    
    return scroll
end

function ChalkMarkerUI.CreateSizeTab(parent)
    local panel = vgui.Create("DPanel", parent)
    --panel.IsMyToolUI = true
    panel:SetSize(460, 400)
    panel:SetPos(0, 0)
    panel.Paint = function(self, w, h)
        draw.SimpleText("Size settings", "ChalkMarkerUI_TabFont", w/2, 30, ChalkMarkerUI.Config.TextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    local weapon = ChalkMarkerUI.State.CurrentWeapon
    if not IsValid(weapon) then return panel end
    local weaponType = ChalkMarkerUI.State.WeaponType
    
    local drawMin, drawMax = ChalkMarkerConfig.GetMinMaxSizes(weaponType, "draw")
    local eraseMin, eraseMax = ChalkMarkerConfig.GetMinMaxSizes(weaponType, "erase")

    -- ========= НАСТРОЙКИ ПОДГОНКИ ЧИСЕЛ ПОД ПОЛОСКУ =========
    local labelOffset = 185 -- Смещение ПЕРВОГО числа вправо (под начало полоски)
    local scaleWidth = 225  -- РАССТОЯНИЕ между первым и последним числом
    local textYPos = 30     -- На сколько пикселей число ниже линии ползунка
    -- =========================================================

        local function ApplySliderScale(slider, isErase)
        slider:SetSize(420, 45)
        slider:SetText("")
        if slider.TextArea then slider.TextArea:SetVisible(false) end
        slider:SetDecimals(1)  -- Оставляем 1 знак после запятой для отображения
        
        -- Сохраняем оригинальный метод GetValue
        local oldGetValue = slider.GetValue
        
        -- Переопределяем GetValue чтобы гарантировать получение точного значения
        slider.GetValue = function(self)
            return self.m_fValue or (oldGetValue and oldGetValue(self) or 0)
        end
        
        local oldPaint = slider.Paint
        slider.Paint = function(self, w, h)
            if oldPaint then oldPaint(self, w, h) end
            
            local min, max = self:GetMin(), self:GetMax()
            local range = max - min
            local steps = range
            local curVal = self:GetValue()

            -- ========= СИНИЙ ИНДИКАТОР ЗНАЧЕНИЯ =========
            local displayText = string.format("%.1f", curVal)
            local accentBlue = Color(70, 160, 255, 255)
            
            draw.SimpleText(displayText, "ChalkMarkerUI_LabelFont", w - 5, -2, accentBlue, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            -- =============================================

            for i = 0, steps do
                local numVal = min + i
                local xPos = labelOffset + (i / steps) * scaleWidth
                
                local shouldDraw = false
                
                if range <= 6 then
                    shouldDraw = true
                else
                    if i % 2 == 0 then 
                        shouldDraw = true 
                    end
                    if i == steps then shouldDraw = true end
                end

                if shouldDraw then
                    draw.SimpleText(tostring(math.Round(numVal)), "DefaultFixed", xPos, textYPos, Color(200, 200, 200, 130), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                end
            end
        end

        slider.OnValueChanged = function(self, value)
            -- Получаем точное значение из слайдера
            local exactValue = self:GetValue()
            
            if isErase then
                weapon.CurrentEraseSizeValue = exactValue
                net.Start("ChalkMarkerUI_UpdateEraseSize")
                net.WriteFloat(exactValue)
                net.SendToServer()
            else
                weapon.CurrentSizeValue = exactValue
                local colorName = weapon.GetPlayerColor and weapon:GetPlayerColor() or (weapon.CurrentColor or "white")
                net.Start("ChalkMarkerUI_UpdateWeapon")
                net.WriteString(colorName)
                net.WriteFloat(exactValue)
                net.SendToServer()
            end
        end
    end

    -- ====== РИСОВАНИЕ ======
    local drawLabel = vgui.Create("DLabel", panel)
    drawLabel:SetPos(30, 86)
    drawLabel:SetText("Draw size:")
    drawLabel:SetFont("ChalkMarkerUI_LabelFont")
    drawLabel:SetTextColor(ChalkMarkerUI.Config.TextColor)
    drawLabel:SizeToContents()

    local drawSlider = vgui.Create("DNumSlider", panel)
    ChalkMarkerUI.DrawSlider = drawSlider
    drawSlider:SetPos(20, 80)
    drawSlider:SetMin(drawMin)
    drawSlider:SetMax(drawMax)
    drawSlider:SetValue(weapon.CurrentSizeValue or 7)
    ApplySliderScale(drawSlider, false)
    

    -- ====== СТИРАНИЕ ======
    local eraseLabel = vgui.Create("DLabel", panel)
    eraseLabel:SetPos(30, 167)
    eraseLabel:SetText("Erase size:")
    eraseLabel:SetFont("ChalkMarkerUI_LabelFont")
    eraseLabel:SetTextColor(ChalkMarkerUI.Config.TextColor)
    eraseLabel:SizeToContents()

    local eraseSlider = vgui.Create("DNumSlider", panel)
    ChalkMarkerUI.EraseSlider = eraseSlider
    eraseSlider:SetPos(20, 160)
    eraseSlider:SetMin(eraseMin)
    eraseSlider:SetMax(eraseMax)
    eraseSlider:SetValue(weapon.CurrentEraseSizeValue or 15)
    ApplySliderScale(eraseSlider, true)
    

    -- ====== КНОПКА СБРОСА ======
    local resetBtn = vgui.Create("DButton", panel)
    --resetBtn.IsMyUIElement = true
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
                local defaultColor = (weaponType == "chalk") and "white" or "black"
                local defaultDrawValue = 7
                local defaultEraseValue = 15
            
                if not IsValid(weapon) then return end

                -- 1. Обновляем локальные данные
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
            
                -- Пакет размера стирания
                net.Start("ChalkMarkerUI_UpdateEraseSize")
                    net.WriteFloat(defaultEraseValue)
                net.SendToServer()
            
                surface.PlaySound("buttons/button14.wav")
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
            net.WriteFloat(sizeValue)
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
            net.WriteFloat(eraseSizeValue)
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