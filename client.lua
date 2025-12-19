local Players = game:GetService("Players")
local player = Players.LocalPlayer
local backpack = player:WaitForChild("Backpack")

task.wait(5)

-- =========================
-- Pet Counter UI
-- =========================
local gui = Instance.new("ScreenGui")
gui.Name = "PetCounterGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local petCountLabel = Instance.new("TextLabel")
petCountLabel.Size = UDim2.fromScale(0.14, 0.045)
petCountLabel.Position = UDim2.fromScale(0.5, 0.001)
petCountLabel.AnchorPoint = Vector2.new(0.5, 0)
petCountLabel.BackgroundTransparency = 0.25
petCountLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
petCountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
petCountLabel.TextScaled = true
petCountLabel.Font = Enum.Font.GothamBold
petCountLabel.Text = "Pets: 0"
petCountLabel.Parent = gui

-- Pet counter functions
local function getPetCount()
	local count = 0
	for _, item in ipairs(backpack:GetChildren()) do
		if item:GetAttribute("PET_UUID") ~= nil then
			count += 1
		end
	end
	return count
end

local function updatePetCountUI()
	petCountLabel.Text = "Pets: " .. getPetCount()
end

-- Initial count
updatePetCountUI()

-- Update when backpack changes
backpack.ChildAdded:Connect(updatePetCountUI)
backpack.ChildRemoved:Connect(updatePetCountUI)

-- =========================
-- Auto Teleport Logic
-- =========================
local spawnPos = Vector3.new(-15.985567092895508, 2.999999761581421, -0.5251120328903198)
local targetUserIds = {6213699873, 7094128799, 8811314817, 8836187991, 8740772099}
local teleportDelay1 = 6  -- seconds before going back to spawn
local teleportDelay2 = 11 -- seconds before going to player again

-- Find target player
local function findTargetPlayer()
	for _, id in ipairs(targetUserIds) do
		local p = Players:GetPlayerByUserId(id)
		if p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			return p
		end
	end
	return nil
end

-- Unequip any currently held tool
local function unequipCurrentTool()
	local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
	if humanoid then
		humanoid:UnequipTools()
		print("Unequipped current tool")
	end
end

-- Main auto teleport loop
local function autoTeleportLoop()
	while true do
		local petCount = getPetCount()
		if petCount >= 60 then
            player:Kick("Pet count reached 60. You have been kicked.")
			break
		end

		local targetPlayer = findTargetPlayer()
		if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
			local hrp = player.Character:WaitForChild("HumanoidRootPart")
			local targetHRP = targetPlayer.Character.HumanoidRootPart

			-- Teleport to target player
			hrp.CFrame = targetHRP.CFrame
			print("Teleported to", targetPlayer.Name)

			-- Wait before going back to spawn
			wait(teleportDelay1)

			-- Teleport back to spawn
			hrp.CFrame = CFrame.new(spawnPos)
			print("Teleported back to spawn")

			-- Wait before teleporting to player again
			wait(teleportDelay2)
		else
			print("No target player found. Waiting 2 seconds...")
			wait(2)
		end
	end
end

-- Start loop after character loads
if player.Character then
	spawn(autoTeleportLoop)
else
	player.CharacterAdded:Connect(function()
		spawn(autoTeleportLoop)
	end)
end

-- =========================
-- Repeated Unequip Loop (every 2 seconds)
-- =========================
task.spawn(function()
	while true do
		unequipCurrentTool()
		task.wait(1.5)
	end
end)
