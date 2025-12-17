-- ===== Services & Setup =====
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local backpack = player:WaitForChild("Backpack")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local addItem = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("TradeEvents"):WaitForChild("AddItem")
local tradeEvents = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("TradeEvents")

-- ===== Load Rayfield =====
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ===== Version =====
local SCRIPT_VERSION = "1.4.1"

-- ===== Create Window =====
local Window = Rayfield:CreateWindow({          
    Name = "Aai Hub v" .. SCRIPT_VERSION,
    Icon = 0,
    LoadingTitle = "Aai Hub UI v" .. SCRIPT_VERSION,
    ShowText = "Aai Hub",
    Theme = "Default",
    ToggleUIKeybind = "K",
})

-- ===== STARTUP CHANGE DEFAULT GRAPHIC SETTINGS =====
local settingsService = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("SettingsService")

local settings = {
	PetScaling = false,
	PetMutationVFX = false,
	CropMutationVFX = false,
	KeepPetOnGround = true,
	LowerPlantFXQuality = true,
}

for setting, value in pairs(settings) do
	settingsService:FireServer("SetSetting", setting, value)
end

-- ===== Create Tab =====
local PetTradeTab = Window:CreateTab("Pet Trade", 0)

-- ===== Target Player input (partial name supported) =====
local targetPlayerName = ""
local PlayerInput = PetTradeTab:CreateInput({
    Name = "Target Player",
    CurrentValue = "",
    PlaceholderText = "Enter player name (partial OK)...",
    RemoveTextAfterFocusLost = false,
    Flag = "PlayerInput",
    Callback = function(Text)
        targetPlayerName = Text
    end,
})

-- ===== Pet Name input =====
local targetPetName = ""
local PetInput = PetTradeTab:CreateInput({
    Name = "Pet Name",
    CurrentValue = "",
    PlaceholderText = "Enter pet name(s) separated by commas...",
    RemoveTextAfterFocusLost = false,
    Flag = "PetInput",
    Callback = function(Text)
        targetPetName = Text:lower()
    end,
})

-- ===== Toggle for clearing pet input =====
local ClearInputEnabled = false
PetTradeTab:CreateToggle({
    Name = "Clear Input After Sending",
    CurrentValue = false,
    Flag = "ClearInputToggle",
    Callback = function(Value)
        ClearInputEnabled = Value
    end,
})

-- ===== Button to send pets =====
PetTradeTab:CreateButton({
    Name = "Send Pets",
    Callback = function()
        if targetPetName == "" then
            Rayfield:Notify({
                Title = "Pet Trade",
                Content = "Please enter pet name(s).",
                Duration = 3,
                Image = "rewind"
            })
            return
        end

        local petsToFind = {}
        for pet in targetPetName:gmatch("[^,]+") do
            pet = pet:gsub("^%s*(.-)%s*$", "%1")
            table.insert(petsToFind, pet)
        end

        local foundAny = false
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                local itemName = item.Name:lower()
                for _, petName in ipairs(petsToFind) do
                    if itemName:find(petName) then
                        local petId = item:GetAttribute("PET_UUID") or item.Name
                        addItem:FireServer("Pet", petId)
                        foundAny = true
                        break
                    end
                end
            end
        end

        if foundAny then
            Rayfield:Notify({
                Title = "Pet Trade",
                Content = "Sent pets matching: " .. targetPetName,
                Duration = 3,
                Image = "check"
            })
        else
            Rayfield:Notify({
                Title = "Pet Trade",
                Content = "No pets found matching: " .. targetPetName,
                Duration = 3,
                Image = "x"
            })
        end

        if ClearInputEnabled then
            PetInput:Set("")
            targetPetName = ""
        end
    end
})

-- ============================
--   HOLD TRADING TICKET
-- ============================
local function holdTradingTicket()
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") and item.Name:lower():find("trading ticket") then
            if player.Character and player.Character:FindFirstChild("Humanoid") then
                player.Character.Humanoid:EquipTool(item)
                return true
            end
        end
    end
    return false
end

-- ============================
--   SEND TRADE REQUEST
-- ============================
local SendTradeEnabled = false
local autoAddPetsRunning = false

PetTradeTab:CreateToggle({
    Name = "Send Trade Request (Auto Add Pets)",
    CurrentValue = false,
    Flag = "SendTradeToggle",
    Callback = function(Value)
        SendTradeEnabled = Value

        if SendTradeEnabled then
            if targetPlayerName == "" then
                Rayfield:Notify({Title = "Error", Content = "Enter a target player first!", Duration = 4, Image = "x"})
                SendTradeEnabled = false
                return
            end
            if targetPetName == "" then
                Rayfield:Notify({Title = "Error", Content = "Enter pet name(s) first!", Duration = 4, Image = "x"})
                SendTradeEnabled = false
                return
            end

            -- find target player
            local targetPlayer = nil
            local search = targetPlayerName:lower()
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and p.Name:lower():find(search) then
                    targetPlayer = p
                    break
                end
            end

            if not targetPlayer then
                Rayfield:Notify({Title = "Trade", Content = "Player not found: " .. targetPlayerName, Duration = 4, Image = "x"})
                SendTradeEnabled = false
                return
            end

            holdTradingTicket()
            tradeEvents:WaitForChild("SendRequest"):FireServer(targetPlayer)

            Rayfield:Notify({
                Title = "Trade",
                Content = "Request sent to " .. targetPlayer.Name,
                Duration = 5,
                Image = "check"
            })

            -- auto add pets smoothly
            if not autoAddPetsRunning then
                autoAddPetsRunning = true
                spawn(function()
                    local sentAnyPet = false

                    while SendTradeEnabled and not sentAnyPet and task.wait(2) do
                        local petsToFind = {}
                        for pet in targetPetName:gmatch("[^,]+") do
                            pet = pet:gsub("^%s*(.-)%s*$", "%1"):lower()
                            table.insert(petsToFind, pet)
                        end

                        local added = false

                        for _, item in ipairs(backpack:GetChildren()) do
                            if item:IsA("Tool") then
                                local name = item.Name:lower()
                                for _, petName in ipairs(petsToFind) do
                                    if name:find(petName) then
                                        local petId = item:GetAttribute("PET_UUID") or item.Name
                                        pcall(function()
                                            addItem:FireServer("Pet", petId)
                                        end)
                                        added = true
                                        sentAnyPet = true
                                    end
                                end
                            end
                        end

                        if added then
                            Rayfield:Notify({
                                Title = "Pet Trade",
                                Content = "Added pet(s)!",
                                Duration = 4,
                                Image = "check"
                            })
                        end
                    end

                    autoAddPetsRunning = false
                end)
            end

        else
            Rayfield:Notify({Title = "Trade", Content = "Auto-add stopped.", Duration = 3, Image = "info"})
        end
    end,
})

-- ============================
--  AUTO SEND REQUEST WHEN NEAR + AUTO ADD PETS
-- ============================
local AutoNearTrade = false
local lastTradedPlayer = nil
local TRADE_DISTANCE = 5
local RESET_DISTANCE = 7
local autoNearTradeThread = nil

local function addPetsOnce()
    local petsToFind = {}

    for pet in targetPetName:gmatch("[^,]+") do
        pet = pet:gsub("^%s*(.-)%s*$", "%1"):lower()
        table.insert(petsToFind, pet)
    end

    local added = false

    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") then
            local name = item.Name:lower()

            for _, petName in ipairs(petsToFind) do
                if name:find(petName) then
                    local petId = item:GetAttribute("PET_UUID") or item.Name
                    pcall(function()
                        addItem:FireServer("Pet", petId)
                    end)
                    added = true
                end
            end
        end
    end

    if added then
        Rayfield:Notify({
            Title = "Auto Add Pets",
            Content = "Added pet(s) matching: " .. targetPetName,
            Duration = 4,
            Image = "check"
        })
    end
end

PetTradeTab:CreateToggle({
    Name = "Auto Send Trade (When Near Player)",
    CurrentValue = false,
    Flag = "AutoNearTradeToggle",
    Callback = function(Value)
        AutoNearTrade = Value

        if AutoNearTrade then
            if autoNearTradeThread then return end -- prevent double thread

            autoNearTradeThread = spawn(function()
                while AutoNearTrade do
                    task.wait(0.4)

                    local char = player.Character
                    if not char then continue end
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if not hrp then continue end

                    -- Find nearest player
                    local nearest = nil
                    local nearestDist = 999

                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                            local dist = (hrp.Position - p.Character.HumanoidRootPart.Position).Magnitude
                            if dist < nearestDist then
                                nearestDist = dist
                                nearest = p
                            end
                        end
                    end

                    -- Not near anyone
                    if not nearest or nearestDist > TRADE_DISTANCE then
                        if nearestDist > RESET_DISTANCE then
                            lastTradedPlayer = nil
                        end
                        continue
                    end

                    -- Only equip the trading ticket NOW (not every loop)
                    local tool = char:FindFirstChildWhichIsA("Tool")
                    if not tool or not tool.Name:lower():find("trading ticket") then
                        holdTradingTicket()
                        task.wait(0.2) -- give time to equip
                    end

                    -- Don’t trade same player repeatedly
                    if lastTradedPlayer == nearest then
                        continue
                    end
                    lastTradedPlayer = nearest

                    -- Send request
                    tradeEvents:WaitForChild("SendRequest"):FireServer(nearest)
                    Rayfield:Notify({
                        Title = "Auto Near Trade",
                        Content = "Sent trade request to " .. nearest.Name,
                        Duration = 3,
                        Image = "check"
                    })

                    -- Wait before adding pets
                    task.wait(1.5) -- 

                    -- Add pets (1st run)
                    addPetsOnce()

                    -- Add pets again after 5 seconds
                    task.delay(5, addPetsOnce)
                end

                autoNearTradeThread = nil
            end)

        else
            lastTradedPlayer = nil
            Rayfield:Notify({
                Title = "Auto Near Trade",
                Content = "Stopped.",
                Duration = 3,
                Image = "info"
            })
        end
    end
})

local Divider = PetTradeTab:CreateDivider()

-- ============================
--   AUTO ACCEPT TRADING TICKET REQUEST FROM PLAYER
-- ============================

local AutoAcceptRequestEnabled = true -- 🔥 DEFAULT ENABLED
local autoAcceptRequestConnection = nil

-- start enabled immediately
autoAcceptRequestConnection =
    tradeEvents:WaitForChild("SendRequest").OnClientEvent:Connect(function(requestId, fromPlayer)
        if not AutoAcceptRequestEnabled then return end
        if not requestId then return end

        pcall(function()
            tradeEvents:WaitForChild("RespondRequest"):FireServer(requestId, true)
        end)

        Rayfield:Notify({
            Title = "Auto Accept (Request)",
            Content = "Accepted trade from " .. (fromPlayer and fromPlayer.Name or "Unknown"),
            Duration = 3,
            Image = "check"
        })
    end)

PetTradeTab:CreateToggle({
    Name = "Auto Accept Trade (Request)",
    CurrentValue = true,
    Flag = "AutoAcceptRequestToggle",
    Callback = function(Value)
        AutoAcceptRequestEnabled = Value

        if AutoAcceptRequestEnabled then
            -- reconnect if needed
            if not autoAcceptRequestConnection then
                autoAcceptRequestConnection =
                    tradeEvents:WaitForChild("SendRequest").OnClientEvent:Connect(function(requestId, fromPlayer)
                        if not AutoAcceptRequestEnabled then return end
                        if not requestId then return end

                        pcall(function()
                            tradeEvents:WaitForChild("RespondRequest"):FireServer(requestId, true)
                        end)
                    end)
            end

            Rayfield:Notify({
                Title = "Auto Accept (Request)",
                Content = "Enabled",
                Duration = 2,
                Image = "check"
            })
        else
            if autoAcceptRequestConnection then
                autoAcceptRequestConnection:Disconnect()
                autoAcceptRequestConnection = nil
            end

            Rayfield:Notify({
                Title = "Auto Accept (Request)",
                Content = "Disabled",
                Duration = 2,
                Image = "info"
            })
        end
    end
})

-- ============================
--   AUTO ACCEPT & CONFIRM (INSIDE THE TRADING TICKET)
-- ============================
local AutoAcceptEnabled = false

PetTradeTab:CreateToggle({
    Name = "Auto Accept & Confirm",
    CurrentValue = false,
    Flag = "AutoAcceptToggle",
    Callback = function(Value)
        AutoAcceptEnabled = Value
        if AutoAcceptEnabled then
            spawn(function()
                while AutoAcceptEnabled do
                    local ok = pcall(function()
                        tradeEvents:WaitForChild("Accept"):FireServer()
                        tradeEvents:WaitForChild("Confirm"):FireServer()
                    end)
                    task.wait(1)
                end
            end)
        end
    end
})

-- ============================
--   CHAT COMMANDS (!give + !off/clear
-- ============================

local function processGiveCommand(p, pet)
    -- Set pet input
    targetPetName = pet
    PetInput:Set(pet)

    Rayfield:Notify({
        Title = "Pet Command",
        Content = p.Name .. " requested pet: " .. pet,
        Duration = 3,
        Image = "check"
    })
end


local PET_COMMANDS = {
    paradise = "peacock, ostrich, macaw, capybara",
    zen = "tanuki, shiba, tancho, niho, kappa"
}

local function connectPlayer(p)
    p.Chatted:Connect(function(msg)
        local lowered = msg:lower()

        -- Check for !give command
        if lowered:sub(1, 6) == "!give " then
            local command = lowered:sub(7):gsub("^%s*(.-)%s*$", "%1")

            -- If the command is in PET_COMMANDS, replace with mapped pets
            local petList = PET_COMMANDS[command] or command

            if petList ~= "" then
                processGiveCommand(p, petList)
            end
            return
        end

        -- !clear or !off command
        if lowered == "!clear" or lowered == "!off" then
            targetPetName = "clear"
            PetInput:Set("")

            Rayfield:Notify({
                Title = "Pet Command",
                Content = p.Name .. " requested clear input",
                Duration = 3,
                Image = "info"
            })
            return
        end
    end)
end

-- Connect existing + future players
for _, p in ipairs(Players:GetPlayers()) do
    connectPlayer(p)
end
Players.PlayerAdded:Connect(connectPlayer)
