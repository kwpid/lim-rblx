-- EchoAUS' Custom PlayerList

local GroupId = 5662718
local UseGroupRanks = false -- Displays the rank name next to the player's name
local UseRankTitles = false -- Uses the name of the rank in the group instead of Group_Ranks
local TitlesEnabled = false

local Player_Ranks = { -- Custom titles next to player's names
  Player1 = { Title = "Dev", Color = Color3.fromRGB(44, 210, 255) }
}
local Group_Ranks = {
  [255] = { Title = "Cody", Color = Color3.fromRGB(222, 121, 255) },
  [254] = { Title = "Ian", Color = Color3.fromRGB(44, 210, 255) },
}
local PlayerIcons = { -- Custom icons (like the premium and friend icons)
  EchoAUS = { "rbxassetid://5585574829" },
  Player1 = { "rbxassetid://5590163573" }
}

------------- You can ignore everything below -------------
game.StarterGui:SetCoreGuiEnabled("PlayerList", false)
local LocalPlayer = game.Players.LocalPlayer

local Players = {}
local Leaderstats = {}

local frame = script.Parent:WaitForChild("PlayerList")
local scrollframe = frame:WaitForChild("ScrollingFrame")
local list = scrollframe:WaitForChild("UIListLayout")
local sizecons = frame:WaitForChild("UISizeConstraint")

local title = script.Parent:WaitForChild("Title")
local titleValues = title:WaitForChild("Stats")
local PlayerProfile = script.Parent:WaitForChild("PlayerProfile")

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")


local Icons = {
  Premium = { "rbxasset://textures/ui/PlayerList/PremiumIcon.png" },
  Developer = { "rbxassetid://5585528768", Scale = 0.85 }, --
  Admin = { "rbxassetid://5585467418" },                 --rbxasset://textures/ui/PlayerList/AdminIcon.png
  Friend = { "rbxassetid://5585520019" },                --rbxasset://textures/ui/PlayerList/FriendIcon.png
}

local Backgrounds = {
  Full = "rbxassetid://5164761021",
  Top = "rbxassetid://5598910690",
  Bottom = "rbxassetid://5598904295"
}

local bPlayer
local minWidth = 200
local lastTitlePos = -10
local function SizeConstraintUpdate()
  local l = 0
  for _, v in ipairs(scrollframe:GetChildren()) do
    local p = v:FindFirstChild("Player")
    if p then
      local width = p.Position.X.Offset + p.TextBounds.X
      if width > l then
        l = width
      end
    end
  end
  local width = l + (-lastTitlePos) + 30

  sizecons.MaxSize = Vector2.new(math.max(minWidth, width), script.Parent.AbsoluteSize.Y * 0.5)
  title.Size = UDim2.new(0, frame.AbsoluteSize.X, 0, 25)
  PlayerProfile.Position = UDim2.new(1, -frame.AbsoluteSize.X - 10, 0, PlayerProfile.Position.Y.Offset)
end

local function NewTitle(t)
  local pos = lastTitlePos - t.TextBounds.X - 10
  lastTitlePos = pos
  t.Position = UDim2.new(1, pos, 0, 0)
end
titleValues.ChildAdded:Connect(function(t)
  NewTitle(t)
  SizeConstraintUpdate()
end)
titleValues.ChildRemoved:Connect(function()
  lastTitlePos = -10
  for _, t in ipairs(titleValues:GetChildren()) do
    NewTitle(t)
  end
  SizeConstraintUpdate()
end)

local TextService = game:GetService("TextService")
local function UpdateSize()
  if #Leaderstats > 0 then
    frame.Image = Backgrounds.Bottom
    frame.Position = UDim2.new(1, -5, 0, 31)
    for _, stat in ipairs(Leaderstats) do
      if not titleValues:FindFirstChild(stat) then
        local t = script.Title:Clone()
        local size = TextService:GetTextSize(stat, t.TextSize, t.Font, script.Parent.AbsoluteSize)
        t.Name = stat
        t.Text = stat
        t.Size = UDim2.new(0, size.X + 10, 1, 0)
        t.Parent = titleValues
      end
    end
    title.Visible = true
  else
    title.Visible = false
    frame.Image = Backgrounds.Full
    frame.Position = UDim2.new(1, -5, 0, 5)
  end
  scrollframe.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y)
  if #scrollframe:GetChildren() <= 2 and bPlayer then
    bPlayer.Size = UDim2.new(1, 0, 0, 45)
    frame.Size = UDim2.new(1, 0, 0, 45)
  else
    if bPlayer then
      bPlayer.Size = UDim2.new(1, 0, 0, 40)
    end
    frame.Size = UDim2.new(1, 0, 0, list.AbsoluteContentSize.Y + 10)
  end
  local i = 0
  local orS = {}
  for _, v in ipairs(scrollframe:GetChildren()) do
    if v:IsA("ImageButton") then
      table.insert(orS, v.Name)
    end
  end
  table.sort(orS)

  local largestSize = 0
  for _, name in ipairs(orS) do
    local v = scrollframe:FindFirstChild(name)
    if v then
      local text = v:WaitForChild("Player")
      local size = text.TextBounds.X + text.Position.X.Offset + 20
      if size > largestSize then
        largestSize = size
      end

      i += 1
      local z = 0
      local rs = false
      for _, fName in ipairs(orS) do
        local f = scrollframe:FindFirstChild(fName)
        if f then
          z += 1
          if i < z then
            rs = true
          end
        end
      end
      local s = v:WaitForChild("Separator")
      v:WaitForChild("Separator").Visible = rs
    end
  end
  minWidth = math.max(largestSize, 200)
  SizeConstraintUpdate()
end
list.Changed:Connect(UpdateSize)

script.Parent.Changed:Connect(SizeConstraintUpdate)

local TextService = game:GetService("TextService")

local CurrentButton
local function SetupStateOverlay(B)
  local IsHovered, IsPressed = false, false
  local SO = B:FindFirstChild("StateOverlay", true)
  local function SetImage(t, c)
    SO.ImageTransparency = t
    SO.ImageColor3 = c
  end

  local function UpdateState()
    if IsPressed then
      SetImage(0.7, Color3.new(0, 0, 0))
    elseif IsHovered then
      SetImage(0.9, Color3.new(1, 1, 1))
    else
      SetImage(1, Color3.new(1, 1, 1))
    end
  end

  local function MouseButton1Down()
    if CurrentButton ~= B then
      IsPressed = true
      UpdateState()
    end
  end
  local function MouseButton1Up()
    IsHovered = false
    IsPressed = false
    UpdateState()
  end

  local function MouseLeave()
    IsHovered = false
    IsPressed = false
    UpdateState()
  end
  local function MouseEnter()
    if CurrentButton ~= B then
      IsHovered = true
      UpdateState()
    end
  end

  B.MouseButton1Down:Connect(MouseButton1Down)
  B.MouseButton1Up:Connect(MouseButton1Up)
  B.MouseEnter:Connect(MouseEnter)
  B.MouseLeave:Connect(MouseLeave)
end

local function SetImage(icon, textlabel, image)
  icon.Image = image[1]
  local xscale = image.Scale or 1
  local s1 = 20 * xscale
  local s2 = 20 * (image.YScale or 1)
  icon.Size = UDim2.new(0, s1, 0, s2)
  local xdif = 20 - s1
  local ydif = 20 - s2
  icon.Position = UDim2.new(0, 15 + xdif, 0.5, 0)
  icon.Visible = true
  textlabel.Position = UDim2.new(0, 42, 0, 0)
end

local FriendCache = {}

local function SetIcon(player, icon, textlabel)
  local c1 = game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
  local c2 = game.CreatorType == Enum.CreatorType.Group and player:GetRankInGroup(game.CreatorId) == 255
  if PlayerIcons[player.Name] then
    SetImage(icon, textlabel, PlayerIcons[player.Name])
  elseif c1 or c2 then
    SetImage(icon, textlabel, Icons.Developer)
  elseif FriendCache[player.UserId] then
    SetImage(icon, textlabel, Icons.Friend)
  elseif player:IsInGroup(1200769) then
    SetImage(icon, textlabel, Icons.Admin)
  elseif player.MembershipType == Enum.MembershipType.Premium then
    SetImage(icon, textlabel, Icons.Premium)
  else
    icon.Visible = false
    textlabel.Position = UDim2.new(0, 20, 0, 0)
  end
end

local function GetRank(player)
  if UseGroupRanks and tonumber(GroupId) then
    local success, rank = pcall(function()
      return player:GetRankInGroup(GroupId)
    end)
    if success then
      return rank
    end
  end
  return 0
end

local B = PlayerProfile:WaitForChild("Buttons")
local PlayerProfileList = B:WaitForChild("UIListLayout")
local Cancel = script.Parent:WaitForChild("Cancel")

local Buttons = {
  Friend = B:WaitForChild("0-FriendRequest"),
  Avatar = B:WaitForChild("1-InspectAvatar")
}

for _, button in pairs(Buttons) do
  SetupStateOverlay(button)
end

local Text = {
  Friend = Buttons.Friend:WaitForChild("TextLabel"),
  Avatar = Buttons.Avatar:WaitForChild("TextLabel"),
  Title = PlayerProfile:WaitForChild("Title")
}

local function SetProfileEnabled(enabled, pos)
  if typeof(enabled) ~= "boolean" then enabled = false end

  local height = PlayerProfileList.AbsoluteContentSize.Y + B.Position.Y.Offset + 10
  local width = 200

  if enabled then
    PlayerProfile.Size = UDim2.new(0, 0, 0, height)
    PlayerProfile.Position = UDim2.new(1, -frame.AbsoluteSize.X - 10, 0, pos or 5)
  else
    CurrentButton = nil
  end

  local info = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
  local Tweens = {
    [true] = TweenService:Create(PlayerProfile, info, { Size = UDim2.new(0, width, 0, height) }),
    [false] = TweenService:Create(PlayerProfile, info, { Size = UDim2.new(0, 0, 0, height) })
  }
  Tweens[enabled]:Play()
  Cancel.Visible = enabled
end
Cancel.MouseButton1Click:Connect(SetProfileEnabled)


local CurrentUser
local function Profile(player, button)
  if CurrentButton ~= button then
    CurrentUser = player
    CurrentButton = button
    Text.Title.Text = player.Name

    if player == LocalPlayer then
      Buttons.Friend.Parent = script
    else
      Buttons.Friend.Parent = B
    end

    if player.UserId > 0 then
      if FriendCache[player.UserId] then
        Text.Friend.Text = "Unfriend"
      else
        Text.Friend.Text = "Send Friend Request"
      end
    else
      warn("Invalid UserId")
    end

    SetProfileEnabled(true, button.AbsolutePosition.Y)
  else
    SetProfileEnabled(false)
  end
end

Buttons.Avatar.MouseButton1Click:Connect(function()
  SetProfileEnabled(false)
  if CurrentUser and CurrentUser.UserId > 0 then
    GuiService:InspectPlayerFromUserId(CurrentUser.UserId)
  end
end)
Buttons.Friend.MouseButton1Click:Connect(function()
  SetProfileEnabled(false)
  if CurrentUser and CurrentUser.UserId > 0 then
    if LocalPlayer:IsFriendsWith(CurrentUser.UserId) then
      game.StarterGui:SetCore("PromptUnfriend", CurrentUser)
    else
      game.StarterGui:SetCore("PromptSendFriendRequest", CurrentUser)
    end
  end
end)

local function UpdateFriendStatus(player)
  if Players[player.Name] then
    local p = Players[player.Name]:WaitForChild("Player")
    local r = Players[player.Name]:WaitForChild("Rank")
    local icon = Players[player.Name]:WaitForChild("Icon")
    SetIcon(player, icon, p)
    if r.Visible then
      r.Position = UDim2.new(0, p.Position.X.Offset + p.TextBounds.X, 0, 0)
    end
  end
end

game.StarterGui:GetCore("PlayerFriendedEvent").Event:Connect(function(player)
  FriendCache[player.UserId] = true
  UpdateFriendStatus(player)
end)
game.StarterGui:GetCore("PlayerUnfriendedEvent").Event:Connect(function(player)
  FriendCache[player.UserId] = nil
  UpdateFriendStatus(player)
end)

local function Preload(...)
  local t = {}
  for _, v in ipairs({ ... }) do
    local i = Instance.new("ImageLabel")
    i.Image = v
    table.insert(t, i)
  end
  game:GetService("ContentProvider"):PreloadAsync(t, function()
    for _, v in ipairs(t) do
      v:Destroy()
    end
  end)
end
Preload(Backgrounds.Full, Backgrounds.Top, Backgrounds.Bottom)
Preload(Icons.Admin[1], Icons.Developer[1], Icons.Friend[1], Icons.Premium[1])

function Leaderstats:InArray(n)
  for pos, s in ipairs(self) do
    if s == n then
      return true, pos
    end
  end
  return false
end

local function NewStat(player, stat, statFolder)
  if stat:IsA("ValueBase") then
    if not Leaderstats:InArray(stat.Name) then
      table.insert(Leaderstats, stat.Name)
    end
    delay(0, function()
      local value = titleValues:WaitForChild(stat.Name, math.huge)
      local s = script.Stat:Clone()
      s.Name = stat.Name
      s.Text = stat.Value
      s.Position = UDim2.new(1, value.Position.X.Offset, 0.5, 0)
      s.Size = UDim2.new(0, value.Size.X.Offset, 0, 14)
      if player == LocalPlayer then
        s.TextTransparency = 0
      end
      s.Parent = statFolder

      stat.Changed:Connect(function(val)
        s.Text = val
      end)
    end)
  end
end

local function LeaderstatAdded(player, stats, statFolder)
  for _, stat in ipairs(stats:GetChildren()) do
    NewStat(player, stat, statFolder)
  end
  stats.ChildAdded:Connect(function(v)
    NewStat(player, v, statFolder)
  end)
end

local function TagColor3(color)
  local r = math.floor(color.R * 255)
  local g = math.floor(color.G * 255)
  local b = math.floor(color.B * 255)
  return string.format('<font color="rgb(%s,%s,%s)">', r, g, b)
end


local function PlayerAdded(player)
  FriendCache[player.UserId] = player:IsFriendsWith(LocalPlayer.UserId)
  if not Players[player.Name] then
    local button = script.ImageButton:Clone()
    local icon = button.Icon
    local value = button:WaitForChild("User")
    local statFolder = button:WaitForChild("Stats")
    Players[player.Name] = button
    value.Value = player.UserId

    local stats = player:FindFirstChild("leaderstats")
    if stats then
      LeaderstatAdded(player, stats, statFolder)
    else
      player.ChildAdded:Connect(function(t)
        if t:IsA("Folder") and t.Name == "leaderstats" then
          LeaderstatAdded(player, t, statFolder)
        end
      end)
    end



    local rank = GetRank(player)
    local sortOrder = ((rank - 256) * -1) + 1000

    button.Name = tostring(sortOrder) .. "." .. player.Name

    local stateOverlay = button.StateOverlay
    local textlabel = button.Player

    textlabel.Text = player.Name

    SetIcon(player, icon, textlabel)

    if player == LocalPlayer then
      bPlayer = button
      textlabel.TextTransparency = 0
    end

    if TitlesEnabled then
      if Player_Ranks[player.Name] then
        local t = Player_Ranks[player.Name]
        textlabel.Text = textlabel.Text .. " [" .. TagColor3(t.Color) .. t.Title .. "</font>]"
      elseif UseRankTitles and player:IsInGroup(GroupId) then
        local t = { Title = player:GetRoleInGroup(GroupId), Color = 92, 225, 255 }
        textlabel.Text = textlabel.Text .. " [" .. TagColor3(t.Color) .. t.Title .. "</font>]"
      elseif Group_Ranks[rank] then
        local t = Group_Ranks[rank]
        textlabel.Text = textlabel.Text .. " [" .. TagColor3(t.Color) .. t.Title .. "</font>]"
      end
    end

    SetupStateOverlay(button)
    button.MouseButton1Click:Connect(function()
      Profile(player, button)
    end)
    button.Parent = scrollframe
  end
end

local function PlayerRemoving(player)
  local s = {}
  for _, l in ipairs(Leaderstats) do
    s[l] = true
  end
  if Players[player.Name] then
    Players[player.Name]:Destroy()
    Players[player.Name] = nil
  end
  for _, v in ipairs(scrollframe:GetChildren()) do
    local stats = v:FindFirstChild("Stats")
    if stats and #stats:GetChildren() > 0 then
      for _, x in ipairs(stats:GetChildren()) do
        s[x.Name] = false
      end
    end
  end
  for stat, val in pairs(s) do
    local v = titleValues:FindFirstChild(stat)
    if v and val then
      print(game:GetService("HttpService"):JSONEncode(Leaderstats))
      for i, v in ipairs(Leaderstats) do
        if v == stat then
          table.remove(Leaderstats, i)
        end
      end
      print(game:GetService("HttpService"):JSONEncode(Leaderstats))
      v:Destroy()
    end
  end
  UpdateSize()
end

local tweenTime = 0.25
local info = TweenInfo.new(tweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local frame_tweens = {
  [true] = TweenService:Create(frame, info, { AnchorPoint = Vector2.new(1, 0) }),
  [false] = TweenService:Create(frame, info, { AnchorPoint = Vector2.new(0, 0) })
}
local title_tweens = {
  [true] = TweenService:Create(title, info, { AnchorPoint = Vector2.new(1, 0) }),
  [false] = TweenService:Create(title, info, { AnchorPoint = Vector2.new(0, 0) })
}
local open = true
local debounce = true

local function SetPlayerList(enabled)
  local y = title.Visible and 31 or 5
  local position = enabled and UDim2.new(1, -5, 0, y) or UDim2.new(1, 5, 0, y)
  local tPos = enabled and UDim2.new(1, -5, 0, 5) or UDim2.new(1, 5, 0, 5)
  frame:TweenPosition(position, "Out", "Quad", tweenTime, true)
  title:TweenPosition(tPos, "Out", "Quad", tweenTime, true)
  frame_tweens[enabled]:Play()
  title_tweens[enabled]:Play()
end

UserInputService.InputBegan:Connect(function(input)
  if debounce and input.KeyCode == Enum.KeyCode.Tab then
    debounce = false
    if Cancel.Visible then
      SetProfileEnabled(false)
    else
      open = not open
      SetPlayerList(open)
      wait(tweenTime + 0.1)
    end
    debounce = true
  end
end)

local GuiService = game:GetService("GuiService")
GuiService.MenuOpened:Connect(function()
  SetPlayerList(false)
end)
GuiService.MenuClosed:Connect(function()
  if open then
    SetPlayerList(true)
  end
end)

game.Players.PlayerAdded:Connect(PlayerAdded)
game.Players.PlayerRemoving:Connect(PlayerRemoving)

for _, player in ipairs(game.Players:GetPlayers()) do
  PlayerAdded(player)
end

--- EchoChat Support
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = ReplicatedStorage:FindFirstChild("EchoChatEvents")

if Events then

end
