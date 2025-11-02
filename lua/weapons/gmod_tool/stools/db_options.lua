TOOL.Category = "Drawing Boards"
TOOL.Name = "Options"
TOOL.Mode = "db_options"
TOOL.Command = nil
TOOL.ConfigName = ""

if CLIENT then
    language.Add("tool.db_options.name", "Drawing Boards Options")
    language.Add("tool.db_options.desc", "Configure settings")
end

TOOL.ClientConVar = {
    ["nil"] = "0"
}

function TOOL:LeftClick(trace)
    return false
end

function TOOL:RightClick(trace)
    return false
end

function TOOL.BuildCPanel(CPanel)
    CPanel:AddControl("Header", {
        Text = "#tool.db_options.name",
        Description = "#tool.db_options.desc"
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
        
        local keyPressed = false
        local wasQPressed = input.IsKeyDown(KEY_Q)
        
        keybindFrame.OnKeyCodePressed = function(self, keyCode)
            -- Игнор ESC и др. клавишей
            if keyCode == KEY_ESCAPE or keyCode == KEY_Q or keyCode == KEY_R then
                return true
            end
            
            -- Игнор клавишей Windows
            if keyCode == KEY_LWIN or keyCode == KEY_RWIN then
                return true
            end
            
            -- Сохранение в файл
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
end