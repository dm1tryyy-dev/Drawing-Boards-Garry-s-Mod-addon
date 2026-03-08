TOOL.Category = "Drawing Boards"
TOOL.Name = "#Options"
TOOL.Mode = "db_opt"
TOOL.Command = nil
TOOL.ConfigName = ""

if CLIENT then
    language.Add("tool.db_opt.name", "Drawing Boards Options")
    language.Add("tool.db_opt.desc", "Configure settings")
    language.Add("tool.db_opt.0", "Board Options")
end

TOOL.ClientConVar = {
    ["render_qlt"] = "2"
}

function TOOL:LeftClick(trace)
    return false
end

function TOOL:RightClick(trace)
    return false
end

function TOOL.BuildCPanel(CPanel)
    CPanel:AddControl("Header", {
        Text = "#tool.db.name",
        Description = "#tool.db.desc"
    })
    
    -- Кнопка для смены клавиши открытия меню
    local keybindButton = vgui.Create("DButton")
    keybindButton:SetText("Change Menu Key (Current: T)")
    keybindButton:SetTall(30)
    
    -- Функция для обновления текста кнопки
    local function UpdateButtonText()
        if file.Exists("chalk_marker_keybind.txt", "DATA") then
            local savedKey = tonumber(file.Read("chalk_marker_keybind.txt", "DATA"))
            if savedKey then
                local keyName = input.GetKeyName(savedKey)
                keybindButton:SetText("Change Menu Key (Current: " .. keyName .. ")")
                return
            end
        end
        keybindButton:SetText("Change Menu Key (Current: T)")
    end
    
    UpdateButtonText()
    
    keybindButton.DoClick = function()
        keybindButton:SetText("Press any key...")
        keybindButton:SetDisabled(true)
        
        local keybindFrame = vgui.Create("DFrame")
        keybindFrame:SetSize(350, 150)
        keybindFrame:SetTitle("Press any keyboard key")
        keybindFrame:SetVisible(true)
        keybindFrame:SetDraggable(false)
        keybindFrame:ShowCloseButton(false)
        keybindFrame:MakePopup()
        keybindFrame:Center()
        
        local instructionLabel = vgui.Create("DLabel", keybindFrame)
        instructionLabel:SetText("Press any key on the keyboard to bind\n\n(Release Q to cancel or click in any place)")
        instructionLabel:SetPos(20, 30)
        instructionLabel:SetSize(310, 80)
        instructionLabel:SetContentAlignment(5)
        instructionLabel:SetTextColor(Color(255, 255, 255))
        instructionLabel:SetWrap(true)
        
        local wasQPressed = input.IsKeyDown(KEY_Q)
        
        keybindFrame.OnKeyCodePressed = function(self, keyCode)
            if keyCode == KEY_ESCAPE or keyCode == KEY_Q or keyCode == KEY_R then
                return true
            end
            
            if keyCode == KEY_LWIN or keyCode == KEY_RWIN then
                return true
            end
            
            local keyName = input.GetKeyName(keyCode)
            file.Write("chalk_marker_keybind.txt", tostring(keyCode))
            
            if ChalkMarkerUI then
                ChalkMarkerUI.Keybind = keyCode
                ChalkMarkerUI.KeybindBlocked = true
                timer.Simple(0.5, function()
                    if ChalkMarkerUI then
                        ChalkMarkerUI.KeybindBlocked = false
                    end
                end)
            end
            
            keybindFrame:Remove()
            UpdateButtonText()
            keybindButton:SetDisabled(false)
            
            print("[DB] Menu key set to: " .. keyName .. " ")
            return true
        end
        
        keybindFrame.Think = function()
            local isQPressedNow = input.IsKeyDown(KEY_Q)
            if wasQPressed and not isQPressedNow then
                keybindFrame:Remove()
                UpdateButtonText()
                keybindButton:SetDisabled(false)
                return
            end
            wasQPressed = isQPressedNow
            
            if keybindFrame:IsValid() and keybindFrame:IsMouseInputEnabled() then
                if input.IsMouseDown(MOUSE_LEFT) then
                    local x, y = keybindFrame:GetPos()
                    local w, h = keybindFrame:GetSize()
                    local mouseX, mouseY = gui.MousePos()
                    
                    if mouseX < x or mouseX > x + w or mouseY < y or mouseY > y + h then
                        keybindFrame:Remove()
                        UpdateButtonText()
                        keybindButton:SetDisabled(false)
                    end
                end
            end
        end
        
        keybindFrame:RequestFocus()
    end
    
    CPanel:AddItem(keybindButton)
    
    -- Кнопка сброса клавиши на T
    local resetKeyButton = vgui.Create("DButton")
    resetKeyButton:SetText("Reset Menu Key to Default (T)")
    resetKeyButton:SetTall(30)
    resetKeyButton.DoClick = function()
        file.Write("chalk_marker_keybind.txt", tostring(KEY_T))
        if ChalkMarkerUI then
            ChalkMarkerUI.Keybind = KEY_T
            ChalkMarkerUI.KeybindBlocked = true
            timer.Simple(0.5, function()
                if ChalkMarkerUI then
                    ChalkMarkerUI.KeybindBlocked = false
                end
            end)
        end
        UpdateButtonText()
        print("[DB] Menu key reset to: T")
    end
    
    CPanel:AddItem(resetKeyButton)
    CPanel:ControlHelp("")
    CPanel:AddControl("Label", {
        Text = "Change Tool Menu key for chalk and marker.\nClick and press any keyboard key to bind it."
    })
    CPanel:ControlHelp("")
    
    -- Загрузка текущей клавиши при открытии панели
    if file.Exists("chalk_marker_keybind.txt", "DATA") then
        local savedKey = tonumber(file.Read("chalk_marker_keybind.txt", "DATA"))
        if savedKey then
            local keyName = input.GetKeyName(savedKey)
            keybindButton:SetText("Change Menu Key (Current: " .. keyName .. ")")
        end
    end
    
    -- Быстрая очистка досок на всей карте через кнопку
    CPanel:AddControl("Button", {
        Label = "Cleanup All Boards",
        Command = "db_cleanup"
    })
    CPanel:ControlHelp("")
    CPanel:AddControl("Label", {
        Text = "To completely clear the boards, use these console commands:"
    })
    CPanel:ControlHelp("")
    CPanel:ControlHelp("chalk_clear - clears chalkboards")
    CPanel:ControlHelp("")
    CPanel:ControlHelp("marker_clear - clears whiteboards and little whiteboards")
    CPanel:ControlHelp("")

    local lowQualityCheckbox = vgui.Create("DCheckBoxLabel")
    lowQualityCheckbox:SetText("Low Quality Mode (Recommended for weak PCs!)")
    lowQualityCheckbox:SetIndent(5)
    lowQualityCheckbox:SetTall(30)
    
    -- Загружаем сохраненное значение
    local isLowQuality = false
    if file.Exists("db_render_quality_low.txt", "DATA") then
        isLowQuality = tobool(file.Read("db_render_quality_low.txt", "DATA")) or false
    end
    lowQualityCheckbox:SetValue(isLowQuality)
    
    -- Устанавливаем конвар
    RunConsoleCommand("db_opt_render_qlt", isLowQuality and "1" or "2")
    cvars.AddChangeCallback("db_opt_render_qlt", function(name, old, new)
        if IsValid(lowQualityCheckbox) then
            lowQualityCheckbox:SetValue(new == "1")
        end
    end)
    
    lowQualityCheckbox.OnChange = function(self, value)
        file.Write("db_render_quality_low.txt", tostring(value))
        RunConsoleCommand("db_opt_render_qlt", value and "1" or "2")
        print("[DB] Low Quality Mode: " .. (value and "Enabled (512x512)" or "Disabled (1024x1024)"))
    end
    
    CPanel:AddItem(lowQualityCheckbox)
    CPanel:ControlHelp("")
    CPanel:ControlHelp("  Enable = 512x512 (better FPS)")
    CPanel:ControlHelp("  Disable = 1024x1024 (default)")
    CPanel:ControlHelp("")
end