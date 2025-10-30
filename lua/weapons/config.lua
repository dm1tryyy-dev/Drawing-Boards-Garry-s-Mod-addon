-- config.lua
ChalkMarkerConfig = ChalkMarkerConfig or {}

-- серверная часть
if SERVER then

    if not ChalkMarkerConfig then
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
                print("[DB_UI Server] config.lua loaded from: " .. path)
                configLoaded = true
                break
            end
        end

        if not configLoaded then
            print("DB_UI Server] WARNING: config.lua not found on server")
        end
    end

    net.Receive("ChalkMarkerUI_UpdateWeapon", function(len, ply)
        local colorName = net.ReadString()
        local sizeValue = net.ReadUInt(8)
        

        
        local weapon = ply:GetActiveWeapon()
        if IsValid(weapon) and (weapon:GetClass() == "chalk_tool" or weapon:GetClass() == "marker_tool") then

            weapon.CurrentColor = colorName
            weapon.CurrentSizeValue = sizeValue
            
        
            local weaponType
            if weapon:GetClass() == "chalk_tool" then
                weaponType = "chalk"
            else
                weaponType = "marker"
            end
            local sizeName = "medium"
            for name, data in pairs(ChalkMarkerConfig.Sizes[weaponType .. "_draw"]) do
                if data.value == sizeValue then
                    sizeName = name
                    break
                end
            end
            weapon.CurrentSize = sizeName

            if weapon.SetChalkColor then
                weapon:SetChalkColor(colorName)

            elseif weapon.SetMarkerColor then
                weapon:SetMarkerColor(colorName)

            end
            

            if weapon:GetClass() == "chalk_tool" then
                net.Start("ChalkColorUpdate")
                    net.WriteEntity(weapon)
                    net.WriteString(colorName)
                net.Send(ply)

            else
                net.Start("MarkerColorUpdate")
                    net.WriteEntity(weapon)
                    net.WriteString(colorName)
                net.Send(ply)
            end
        else
            print("[DB_UI Server] ERROR: Weapon not valid for player " .. ply:Nick())
        end
    end)

     net.Receive("ChalkMarkerUI_UpdateEraseSize", function(len, ply)
        local eraseSizeValue = net.ReadUInt(8)
        
        local weapon = ply:GetActiveWeapon()
        if IsValid(weapon) and (weapon:GetClass() == "chalk_tool" or weapon:GetClass() == "marker_tool") then

            weapon.CurrentEraseSizeValue = eraseSizeValue

            local weaponType
            if weapon:GetClass() == "chalk_tool" then
                weaponType = "chalk"
            else
                weaponType = "marker"
            end
            
            local eraseSizeName = "medium"
            if ChalkMarkerConfig.Sizes[weaponType .. "_erase"] then
                for name, data in pairs(ChalkMarkerConfig.Sizes[weaponType .. "_erase"]) do
                    if data.value == eraseSizeValue then
                        eraseSizeName = name
                        break
                    end
                end
            end
            weapon.CurrentEraseSize = eraseSizeName
        end
    end)
end


ChalkMarkerConfig.Colors = {
    -- Цвета для мела
    chalk = {
        white = {
            name = "white", 
            display = "White", 
            color = Color(240, 240, 230), 
            tool_color = Vector(0.95, 0.95, 0.9)
        },
        yellow = {
            name = "yellow", 
            display = "Yellow", 
            color = Color(255, 255, 150), 
            tool_color = Vector(0.98, 0.95, 0.4)
        },
        orange = {
            name = "orange", 
            display = "Orange", 
            color = Color(255, 200, 100), 
            tool_color = Vector(0.95, 0.7, 0.3)
        },
        pink = {
            name = "pink", 
            display = "Pink", 
            color = Color(255, 180, 200), 
            tool_color = Vector(0.95, 0.7, 0.8)
        },
        blue = {
            name = "blue", 
            display = "Blue", 
            color = Color(150, 200, 255), 
            tool_color = Vector(0.5, 0.7, 0.9)
        },
        green = {
            name = "green", 
            display = "Green", 
            color = Color(150, 220, 150),
            tool_color = Vector(0.5, 0.8, 0.5)
        }
    },
    
    -- Цвета для маркера
    marker = {
        black = {
            name = "black", 
            display = "Black", 
            color = Color(0, 0, 0), 
            tool_color = Vector(0, 0, 0),
            texture = "models/tools_materials/marker/colors/marker_base_texture"
        },
        red = {
            name = "red", 
            display = "Red", 
            color = Color(255, 0, 0), 
            tool_color = Vector(1, 0, 0),
            texture = "models/tools_materials/marker/colors/marker_red_texture"
        },
        blue = {
            name = "blue", 
            display = "Blue", 
            color = Color(0, 0, 255), 
            tool_color = Vector(0, 0, 1),
            texture = "models/tools_materials/marker/colors/marker_blue_texture"
        },
        green = {
            name = "green", 
            display = "Green", 
            color = Color(0, 255, 0), 
            tool_color = Vector(0, 1, 0),
            texture = "models/tools_materials/marker/colors/marker_green_texture"
        },
        yellow = {
            name = "yellow", 
            display = "Yellow", 
            color = Color(255, 255, 0), 
            tool_color = Vector(1, 1, 0),
            texture = "models/tools_materials/marker/colors/marker_yellow_texture"
        },
        orange = {
            name = "orange", 
            display = "Orange", 
            color = Color(255, 165, 0), 
            tool_color = Vector(1, 0.5, 0),
            texture = "models/tools_materials/marker/colors/marker_orange_texture"
        },
        cian = {
            name = "cian", 
            display = "Cian", 
            color = Color(0, 255, 255), 
            tool_color = Vector(0, 1, 1),
            texture = "models/tools_materials/marker/colors/marker_cian_texture"
        },
        purple = {
            name = "purple", 
            display = "Purple", 
            color = Color(128, 0, 128), 
            tool_color = Vector(0.5, 0, 0.5),
            texture = "models/tools_materials/marker/colors/marker_purple_texture"
        },
        pink = {
            name = "pink", 
            display = "Pink", 
            color = Color(255, 192, 203), 
            tool_color = Vector(1, 0.5, 0.8),
            texture = "models/tools_materials/marker/colors/marker_pink_texture"
        },
        brown = {
            name = "brown", 
            display = "Brown", 
            color = Color(158,83,0), 
            tool_color = Vector(0.62, 0.32, 0),
            texture = "models/tools_materials/marker/colors/marker_brown_texture"
        }
    }
}

ChalkMarkerConfig.Sizes = {
    -- Размеры для рисования мелом
    chalk_draw = {
        small = {name = "small", display = "Маленький", value = 5},
        medium = {name = "medium", display = "Средний", value = 7},
        large = {name = "large", display = "Большой", value = 10}
    },
    
    -- Размеры для стирания мелом
    chalk_erase = {
        small = {name = "small", display = "Маленький", value = 10},
        medium = {name = "medium", display = "Средний", value = 15},
        large = {name = "large", display = "Большой", value = 20}
    },
    
    -- Размеры для рисования маркером
    marker_draw = {
        small = {name = "small", display = "Тонкий", value = 5},
        medium = {name = "medium", display = "Средний", value = 7},
        large = {name = "large", display = "Толстый", value = 10}
    },

    -- Размеры для стирания маркером
    marker_erase = {
        small = {name = "small", display = "Маленький", value = 10},
        medium = {name = "medium", display = "Средний", value = 15},
        large = {name = "large", display = "Большой", value = 20}
    }
}

-- Порядок цветов для быстрой смены (R)
ChalkMarkerConfig.ColorOrder = {
    chalk = {"white", "yellow", "orange", "pink", "blue", "green"},
    marker = {"black", "red", "blue", "green", "yellow", "orange", "cian", "purple", "pink", "brown"}
}

-- Порядок смены размеров
ChalkMarkerConfig.SizeOrder = {
    chalk_draw = {"small", "medium", "large"},
    chalk_erase = {"small", "medium", "large"},
    marker_draw = {"small", "medium", "large"},
    marker_erase = {"small", "medium", "large"}
}


function ChalkMarkerConfig.GetColorData(weaponType, colorName)
    if ChalkMarkerConfig.Colors[weaponType] and ChalkMarkerConfig.Colors[weaponType][colorName] then
        return ChalkMarkerConfig.Colors[weaponType][colorName]
    end
    return ChalkMarkerConfig.Colors[weaponType]["white"] or ChalkMarkerConfig.Colors[weaponType]["black"]
end

function ChalkMarkerConfig.GetSizeData(weaponType, action, sizeName)
    local sizeKey = weaponType .. "_" .. action
    if ChalkMarkerConfig.Sizes[sizeKey] and ChalkMarkerConfig.Sizes[sizeKey][sizeName] then
        return ChalkMarkerConfig.Sizes[sizeKey][sizeName]
    end

    return ChalkMarkerConfig.Sizes[sizeKey]["medium"] or {name = "medium", display = "Средний", value = 6}
end

-- Получить список цветов для интерфейса
function ChalkMarkerConfig.GetColorsForUI(weaponType)
    local colors = {}
    
    if ChalkMarkerConfig.ColorOrder[weaponType] and ChalkMarkerConfig.Colors[weaponType] then
        -- ColorOrder
        for _, colorName in ipairs(ChalkMarkerConfig.ColorOrder[weaponType]) do
            local data = ChalkMarkerConfig.Colors[weaponType][colorName]
            if data then
                table.insert(colors, {
                    name = data.name,
                    display = data.display,
                    color = data.color
                })
            end
        end
    else
        -- если ColorOrder не задан
        if ChalkMarkerConfig.Colors[weaponType] then
            for name, data in pairs(ChalkMarkerConfig.Colors[weaponType]) do
                table.insert(colors, {
                    name = data.name,
                    display = data.display,
                    color = data.color
                })
            end
        end
    end
    
    return colors
end

-- Получение списка размеров для интерфейса
function ChalkMarkerConfig.GetSizesForUI(weaponType, action)
    local sizes = {}
    local sizeKey = weaponType .. "_" .. action
    if ChalkMarkerConfig.Sizes[sizeKey] then
        for name, data in pairs(ChalkMarkerConfig.Sizes[sizeKey]) do
            table.insert(sizes, {
                name = data.name,
                display = data.display,
                value = data.value
            })
        end
    end
    return sizes
end

-- Получение данных цвета для инструмента
function ChalkMarkerConfig.GetColorForTool(weaponType, colorName)
    local data = ChalkMarkerConfig.GetColorData(weaponType, colorName)
    return data.tool_color
end

-- Получение текстуры для маркера
function ChalkMarkerConfig.GetMarkerTexture(colorName)
    local data = ChalkMarkerConfig.GetColorData("marker", colorName)
    return data.texture or "models/tools_materials/marker/colors/marker_base_texture"
end

-- Получение цвета для рисования на доске
function ChalkMarkerConfig.GetDrawColor(weaponType, colorName)
    local data = ChalkMarkerConfig.GetColorData(weaponType, colorName)
    return data.color
end

-- Получение значения размера
function ChalkMarkerConfig.GetSizeValue(weaponType, action, sizeName)
    local data = ChalkMarkerConfig.GetSizeData(weaponType, action, sizeName)
    return data.value
end

-- Получение цвета в порядке смены
function ChalkMarkerConfig.GetNextColor(weaponType, currentColor)
    local order = ChalkMarkerConfig.ColorOrder[weaponType]
    if not order then return currentColor end
    
    local currentIndex = 1
    for i, colorName in ipairs(order) do
        if colorName == currentColor then
            currentIndex = i
            break
        end
    end
    
    local nextIndex = (currentIndex % #order) + 1
    return order[nextIndex]
end

-- Получение размера в порядке смены
function ChalkMarkerConfig.GetNextSize(weaponType, action, currentSize)
    local sizeKey = weaponType .. "_" .. action
    local order = ChalkMarkerConfig.SizeOrder[sizeKey]
    if not order then return currentSize end
    
    local currentIndex = 1
    for i, sizeName in ipairs(order) do
        if sizeName == currentSize then
            currentIndex = i
            break
        end
    end
    
    local nextIndex = (currentIndex % #order) + 1
    return order[nextIndex]
end

print("[DB_UI Config] Configuration loaded successfully")