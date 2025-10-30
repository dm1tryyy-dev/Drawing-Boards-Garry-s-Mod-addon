print("[DB_UI] Loading interface...")

ChalkMarkerUI = ChalkMarkerUI or {}
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

-- Если config.lua еще не загружен
if not ChalkMarkerConfig.Colors then
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

if not ChalkMarkerConfig.Colors then
    return
end

-- Конфигурация интерфейса
ChalkMarkerUI.Config = {
    BlurIntensity = 8,
    BackgroundAlpha = 200,
    AccentColor = Color(70, 130, 200, 220),
    TextColor = Color(240, 240, 240, 240),
    BackgroundColor = Color(30, 35, 45, 200),
}

-- Состояние интерфейса
ChalkMarkerUI.State = {
    IsOpen = false,
    CurrentWeapon = nil,
    WeaponType = nil, -- "chalk" или "marker"
    ActiveTab = "color"
}

-- Данные для интерфейса
ChalkMarkerUI.Data = {
    chalk = {
        name = "Chalk",
        colors = ChalkMarkerConfig.GetColorsForUI("chalk"),
        sizes = ChalkMarkerConfig.GetSizesForUI("chalk", "draw")
    },
    marker = {
        name = "Marker", 
        colors = ChalkMarkerConfig.GetColorsForUI("marker"),
        sizes = ChalkMarkerConfig.GetSizesForUI("marker", "draw")
    }
}

-- Переменная для отслеживания состояния клавиши T
ChalkMarkerUI.LastTState = false

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

-- главное окно
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

-- вкладки
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

-- контент для вкладки цвета
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
            local isSelected = weapon.CurrentColor == colorData.name
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
            local colorDataForTool = ChalkMarkerConfig.GetColorData(ChalkMarkerUI.State.WeaponType, colorData.name)
            
            weapon.CurrentColor = colorData.name
            
            if ChalkMarkerUI.State.WeaponType == "chalk" then
                if weapon.SetChalkColor then
                    weapon:SetChalkColor(colorData.name)
                end
            else
                if weapon.SetMarkerColor then
                    weapon:SetMarkerColor(colorData.name)
                end
            end
            
            local currentSize = weapon.CurrentSize or "medium"
            local sizeValue = weapon.CurrentSizeValue or ChalkMarkerConfig.GetSizeValue(ChalkMarkerUI.State.WeaponType, "draw", currentSize)
            
            net.Start("ChalkMarkerUI_UpdateWeapon")
                net.WriteString(colorData.name)
                net.WriteUInt(sizeValue, 8)
            net.SendToServer()
            
            updateCurrentColorDisplay(colorData.name)
        end
    end
    
    return scroll
end

-- контент для вкладки размера
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
    local currentDrawSize = weapon.CurrentSizeValue or ChalkMarkerConfig.GetSizeValue(ChalkMarkerUI.State.WeaponType, "draw", "medium")
    local currentEraseSize = weapon.CurrentEraseSizeValue or ChalkMarkerConfig.GetSizeValue(ChalkMarkerUI.State.WeaponType, "erase", "medium")
    
    -- Ползунок для размера рисования
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
    drawSlider:SetMin(5)
    drawSlider:SetMax(10)
    drawSlider:SetDecimals(0)
    drawSlider:SetValue(currentDrawSize)

    drawSlider.Label:SetFont("ChalkMarkerUI_LabelFont")
    drawSlider.Label:SetTextColor(ChalkMarkerUI.Config.TextColor)

    
    drawSlider.OnValueChanged = function(self, value)
        local intValue = math.Round(value)
        weapon.CurrentSizeValue = intValue
        
        local sizes = ChalkMarkerConfig.GetSizesForUI(ChalkMarkerUI.State.WeaponType, "draw")
        for _, sizeData in ipairs(sizes) do
            if sizeData.value == intValue then
                weapon.CurrentSize = sizeData.name
                break
            end
        end

        local colorName = weapon.CurrentColor or "white"
        net.Start("ChalkMarkerUI_UpdateWeapon")
            net.WriteString(colorName)
            net.WriteUInt(intValue, 8)
        net.SendToServer()
    end
    
    -- Ползунок для размера стирания
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
    eraseSlider:SetMin(10)
    eraseSlider:SetMax(20)
    eraseSlider:SetDecimals(0)
    eraseSlider:SetValue(currentEraseSize)

    eraseSlider.Label:SetFont("ChalkMarkerUI_LabelFont")
    eraseSlider.Label:SetTextColor(ChalkMarkerUI.Config.TextColor)

    
    eraseSlider.OnValueChanged = function(self, value)
        local intValue = math.Round(value)
        weapon.CurrentEraseSizeValue = intValue
        
        local sizes = ChalkMarkerConfig.GetSizesForUI(ChalkMarkerUI.State.WeaponType, "erase")
        for _, sizeData in ipairs(sizes) do
            if sizeData.value == intValue then
                weapon.CurrentEraseSize = sizeData.name
                break
            end
        end
        
        net.Start("ChalkMarkerUI_UpdateEraseSize")
            net.WriteUInt(intValue, 8)
        net.SendToServer()
    end
    
    -- Кнопка сброса настроек
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
                local weapon = ChalkMarkerUI.State.CurrentWeapon
                if IsValid(weapon) then
                    weapon.CurrentColor = ChalkMarkerUI.State.WeaponType == "chalk" and "white" or "black"
                    weapon.CurrentSize = "medium"
                    weapon.CurrentSizeValue = 6
                    weapon.CurrentEraseSize = "medium"
                    weapon.CurrentEraseSizeValue = 12
                    

                    drawSlider:SetValue(6)
                    eraseSlider:SetValue(12)
                    
                    if ChalkMarkerUI.State.WeaponType == "chalk" and weapon.SetChalkColor then
                        weapon:SetChalkColor("white")
                    elseif ChalkMarkerUI.State.WeaponType == "marker" and weapon.SetMarkerColor then
                        weapon:SetMarkerColor("black")
                    end
                    

                    net.Start("ChalkMarkerUI_UpdateWeapon")
                        net.WriteString(weapon.CurrentColor)
                        net.WriteUInt(weapon.CurrentSizeValue or 6, 8)
                    net.SendToServer()
                end
            end,
            "No", function() end
        )
    end
    
    return panel
end

-- Обновление контента интерфейса
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

-- Открытие меню
function ChalkMarkerUI.OpenMenu(weapon)
    if ChalkMarkerUI.State.IsOpen then 
        return 
    end
    
    if not IsValid(weapon) then
        return
    end
    
    
    if ChalkMarkerUI.OpenCooldown and CurTime() - ChalkMarkerUI.OpenCooldown < 0.5 then
        return
    end
    ChalkMarkerUI.OpenCooldown = CurTime()
    
    local weaponName = weapon:GetPrintName() or ""
    
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
    
    if not weapon.CurrentColor then
        weapon.CurrentColor = ChalkMarkerUI.State.WeaponType == "chalk" and "white" or "black"
    end
    if not weapon.CurrentSize then
        weapon.CurrentSize = "medium"
        weapon.CurrentSizeValue = ChalkMarkerConfig.GetSizeValue(ChalkMarkerUI.State.WeaponType, "draw", "medium")
    end
    if not weapon.CurrentEraseSize then
        weapon.CurrentEraseSize = "medium"
        weapon.CurrentEraseSizeValue = ChalkMarkerConfig.GetSizeValue(ChalkMarkerUI.State.WeaponType, "erase", "medium")
    end
    
    weapon:SetNoDraw(true)
    gui.EnableScreenClicker(true)
    
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

-- Закрытие меню
function ChalkMarkerUI.CloseMenu()
    if not ChalkMarkerUI.State.IsOpen then 
        return 
    end
    
    if ChalkMarkerUI.CloseCooldown and CurTime() - ChalkMarkerUI.CloseCooldown < 0.5 then
        return
    end
    
    if IsValid(ChalkMarkerUI.State.CurrentWeapon) then
        local weapon = ChalkMarkerUI.State.CurrentWeapon
        local colorName = weapon.CurrentColor or (ChalkMarkerUI.State.WeaponType == "chalk" and "white" or "black")
        local sizeValue = weapon.CurrentSizeValue or ChalkMarkerConfig.GetSizeValue(ChalkMarkerUI.State.WeaponType, "draw", "medium")
        
        net.Start("ChalkMarkerUI_UpdateWeapon")
            net.WriteString(colorName)
            net.WriteUInt(sizeValue, 8)
        net.SendToServer()
        
        local activeWeapon = LocalPlayer():GetActiveWeapon()
        if IsValid(activeWeapon) then
            activeWeapon.CurrentColor = colorName
            activeWeapon.CurrentSize = weapon.CurrentSize
            activeWeapon.CurrentSizeValue = sizeValue
            
            if ChalkMarkerUI.State.WeaponType == "chalk" and activeWeapon.SetChalkColor then
                activeWeapon:SetChalkColor(colorName)
            elseif ChalkMarkerUI.State.WeaponType == "marker" and activeWeapon.SetMarkerColor then
                activeWeapon:SetMarkerColor(colorName)
            end
        end
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
end

function ChalkMarkerUI.UpdateColorDisplay()
    if not ChalkMarkerUI.State.IsOpen then return end
    
    local weapon = ChalkMarkerUI.State.CurrentWeapon
    if not IsValid(weapon) then return end
    
    if ChalkMarkerUI.State.ActiveTab == "color" and ChalkMarkerUI.ContentPanel then
        ChalkMarkerUI.ContentPanel:InvalidateLayout()
    end
end

-- клиентская часть
if CLIENT then    
    hook.Add("Think", "ChalkMarkerUI_Main", function()
        local currentTState = input.IsKeyDown(KEY_T)
        if currentTState and not ChalkMarkerUI.LastTState then

            local ply = LocalPlayer()
            if not IsValid(ply) then return end
            
            local weapon = ply:GetActiveWeapon()
            if not IsValid(weapon) then return end
            
            local weaponName = weapon:GetPrintName() or ""
            
            if weaponName == "Chalk" or weaponName == "Marker" then
                if not ChalkMarkerUI.State.IsOpen then
                    ChalkMarkerUI.OpenMenu(weapon)
                end
            end
        end
        
        ChalkMarkerUI.LastTState = currentTState
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
end