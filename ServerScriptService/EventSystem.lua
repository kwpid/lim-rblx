local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")

local sendNotificationEvent = remoteEvents:FindFirstChild("CreateNotification")
if not sendNotificationEvent then
  sendNotificationEvent = Instance.new("RemoteEvent")
  sendNotificationEvent.Name = "CreateNotification"
  sendNotificationEvent.Parent = remoteEvents
end

local EventSystem = {}
EventSystem.ActiveEvents = {}
EventSystem.EventModules = {}

-- Config: Random events spawn every 5-10 minutes
local MIN_EVENT_INTERVAL = 5 * 60
local MAX_EVENT_INTERVAL = 10 * 60

function EventSystem:LoadEventModules()
  local eventFolder = script.Parent:FindFirstChild("Events")
  if not eventFolder then
    warn("⚠️ Events folder not found in ServerScriptService")
    return
  end
  
  for _, module in ipairs(eventFolder:GetChildren()) do
    if module:IsA("ModuleScript") then
      local success, eventModule = pcall(require, module)
      if success then
        self.EventModules[module.Name] = eventModule
        print("✅ Loaded event module: " .. module.Name)
      else
        warn("❌ Failed to load event module " .. module.Name .. ": " .. tostring(eventModule))
      end
    end
  end
end

function EventSystem:StartEvent(eventName)
  local eventModule = self.EventModules[eventName]
  if not eventModule then
    warn("⚠️ Event module not found: " .. eventName)
    return false
  end
  
  if self.ActiveEvents[eventName] then
    warn("⚠️ Event already running: " .. eventName)
    return false
  end
  
  print("🎉 Starting event: " .. eventName)
  
  local success, eventInfo = pcall(function()
    return eventModule.GetEventInfo()
  end)
  
  if success and eventInfo then
    print("📢 Sending event notification to all clients...")
    print("   Type: EVENT_START")
    print("   Title: " .. tostring(eventInfo.Name))
    print("   Body: " .. tostring(eventInfo.Description))
    
    sendNotificationEvent:FireAllClients({
      Type = "EVENT_START",
      Title = eventInfo.Name,
      Body = eventInfo.Description,
      ImageId = eventInfo.Image
    })
    
    print("✅ Event notification sent!")
  else
    warn("❌ Failed to get event info: " .. tostring(eventInfo))
  end
  
  self.ActiveEvents[eventName] = true
  
  task.spawn(function()
    local success, err = pcall(function()
      eventModule.Start(function()
        self:EndEvent(eventName)
      end)
    end)
    
    if not success then
      warn("❌ Error running event " .. eventName .. ": " .. tostring(err))
      self:EndEvent(eventName)
    end
  end)
  
  return true
end

function EventSystem:EndEvent(eventName)
  if not self.ActiveEvents[eventName] then
    return
  end
  
  print("✅ Event ended: " .. eventName)
  self.ActiveEvents[eventName] = nil
  
  sendNotificationEvent:FireAllClients({
    Type = "EVENT_END",
    Title = "Event Ended",
    Body = eventName .. " has ended!",
    ImageId = "rbxassetid://8150337440"
  })
end

function EventSystem:StartRandomEventSpawner()
  task.spawn(function()
    while true do
      local waitTime = math.random(MIN_EVENT_INTERVAL, MAX_EVENT_INTERVAL)
      task.wait(waitTime)
      
      local eventNames = {}
      for eventName, _ in pairs(self.EventModules) do
        table.insert(eventNames, eventName)
      end
      
      if #eventNames > 0 then
        local randomEvent = eventNames[math.random(1, #eventNames)]
        self:StartEvent(randomEvent)
      end
    end
  end)
  
  print("✅ Random event spawner started")
end

function EventSystem:Initialize()
  self:LoadEventModules()
  self:StartRandomEventSpawner()
  print("✅ EventSystem initialized")
end

EventSystem:Initialize()

return EventSystem
