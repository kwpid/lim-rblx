local container = script.Parent:WaitForChild("NotificationContainer")

local template = script:WaitForChild("NotificationFrame")

local ts = game:GetService("TweenService")
local ti = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local config = game.ReplicatedStorage:WaitForChild("NotificationsConfiguration")
local notificationPresets = require(config:WaitForChild("NotificationPresets"))
local maxNotifications = config:WaitForChild("MaxNotifications")
local notificationLifetime = config:WaitForChild("NotificationLifetime")
local notificationPadding = config:WaitForChild("PaddingBetweenNotifications")

local remotes = game.ReplicatedStorage:WaitForChild("RemoteEvents")
local notificationRE = remotes:WaitForChild("CreateNotification")

local queuedNotifications = {}


function NotificationUpTween(notificationFrame: Frame)

  local offsetY = (container.AbsoluteSize.Y * template.Size.Y.Scale + template.Size.Y.Offset) + notificationPadding.Value
  local scaleY = offsetY / container.AbsoluteSize.Y
  local newY = notificationFrame.Position.Y.Scale - scaleY

  local goalProperties = {
    Position = UDim2.new(0.5, 0, newY, 0);
  }

  local tween = ts:Create(notificationFrame, ti, goalProperties)
  tween:Play()
end

function NotificationInTween(notificationFrame: Frame)

  local goalProperties = {
    Position = UDim2.new(0.5, 0, 1, 0);
  }

  local tween = ts:Create(notificationFrame, ti, goalProperties)
  tween:Play()

  tween.Completed:Wait()
end

function NotificationOutTween(notificationFrame: Frame)

  notificationFrame.Name = "Removing"

  local goalProperties = {
    Position = UDim2.new(1.5, 0, notificationFrame.Position.Y.Scale, 0);
  }

  local tween = ts:Create(notificationFrame, ti, goalProperties)
  tween:Play()

  tween.Completed:Wait()

  notificationFrame:Destroy()
end


function ShiftNotificationsUp()

  local existingNotifications = {}

  for _, child in pairs(container:GetChildren()) do

    if child.ClassName == template.ClassName and child.Name ~= "Removing" then
      table.insert(existingNotifications, child)
    end
  end

  table.sort(existingNotifications, function(a, b)
    return a.AbsolutePosition.Y < b.AbsolutePosition.Y
  end)

  if #existingNotifications >= maxNotifications.Value then

    for i = 1, #existingNotifications - maxNotifications.Value + 1 do

      local existingNotification = existingNotifications[i]
      NotificationOutTween(existingNotification)
    end
  end

  for _, notificationFrame in pairs(existingNotifications) do
    NotificationUpTween(notificationFrame)
  end

  task.wait(ti.Time)
end


function NewNotification(data: {Type: string, Title: string, Body: string, ImageId: string | number, SoundId: string | number, Color: Color3})

  ShiftNotificationsUp()

  local notificationPreset = notificationPresets[data.Type] or {}

  local title = data.Title or notificationPreset.DEFAULT_TITLE or ""
  local body = data.Body or notificationPreset.DEFAULT_BODY or ""
  local image = data.ImageId or notificationPreset.DEFAULT_IMAGE or ""
  local sound = data.SoundId or notificationPreset.DEFAULT_SOUND
  local color = data.Color or notificationPreset.DEFAULT_COLOR or Color3.new(1, 1, 1)   

  if tonumber(image) then
    image = "rbxthumb://type=Asset&id=" .. image .. "&w=150&h=150"
  end
  if tonumber(sound) then
    sound = "rbxassetid://" .. sound
  end

  local notificationFrame = template:Clone()

  notificationFrame.NotificationTitle.Text = title
  notificationFrame.NotificationBody.Text = body
  notificationFrame.NotificationImage.Image = image
  notificationFrame.AccentColor.BackgroundColor3 = color
  notificationFrame.NotificationTitle.TextColor3 = color

  notificationFrame.AnchorPoint = Vector2.new(0.5, 1)
  notificationFrame.Position = UDim2.new(1.5, 0, 1, 0)

  notificationFrame.Parent = container

  if sound and #sound > 0 then
    local soundObject = Instance.new("Sound")
    soundObject.SoundId = sound
    soundObject.Parent = script
    soundObject:Play()

    soundObject.Ended:Connect(function()
      soundObject:Destroy()
    end)
  end

  task.spawn(NotificationInTween, notificationFrame)

  table.remove(queuedNotifications, 1)

  task.spawn(function()

    task.wait(notificationLifetime.Value)
    NotificationOutTween(notificationFrame)
  end)
end


notificationRE.OnClientEvent:Connect(function(notificationData)

  table.insert(queuedNotifications, notificationData)

  while table.find(queuedNotifications, notificationData) ~= 1 do
    game:GetService("RunService").Heartbeat:Wait()
  end

  NewNotification(notificationData)
end)