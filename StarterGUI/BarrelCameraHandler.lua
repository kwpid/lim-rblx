local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local originalCameraType = nil
local originalCameraSubject = nil

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local setPlayerCameraEvent = remoteEvents:WaitForChild("SetPlayerCamera")

setPlayerCameraEvent.OnClientEvent:Connect(function(targetPart)
	if targetPart then
		originalCameraType = camera.CameraType
		originalCameraSubject = camera.CameraSubject
		
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = targetPart.CFrame
		
		print("📷 Camera switched to barrel view")
	else
		if originalCameraType then
			camera.CameraType = originalCameraType
		end
		if originalCameraSubject then
			camera.CameraSubject = originalCameraSubject
		end
		
		if player.Character and player.Character:FindFirstChild("Humanoid") then
			camera.CameraSubject = player.Character.Humanoid
		end
		
		originalCameraType = nil
		originalCameraSubject = nil
		
		print("📷 Camera restored to player")
	end
end)
