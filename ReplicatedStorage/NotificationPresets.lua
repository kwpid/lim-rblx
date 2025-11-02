local notificationPresets = {}

notificationPresets.ERROR = {
  DEFAULT_TITLE = "Error!",
  DEFAULT_BODY = "Uh oh!\nSomething went wrong..",
  DEFAULT_IMAGE = "rbxassetid://240664703",
  DEFAULT_SOUND = "rbxassetid://550209561",
  DEFAULT_COLOR = Color3.fromRGB(198, 34, 34),
}

notificationPresets.GIFT = {
  DEFAULT_TITLE = "Gift received!",
  DEFAULT_BODY = "Someone sent you a gift!",
  DEFAULT_IMAGE = "rbxassetid://8150337440",
  DEFAULT_SOUND = "rbxassetid://10066947742",
  DEFAULT_COLOR = Color3.fromRGB(111, 218, 40),
}

notificationPresets.VICTORY = {
  DEFAULT_TITLE = "Victory!",
  DEFAULT_BODY = "You won the game!",
  DEFAULT_IMAGE = "rbxassetid://11197857311",
  DEFAULT_SOUND = "rbxassetid://12222253",
  DEFAULT_COLOR = Color3.fromRGB(255, 162, 1),
}

notificationPresets.EQUIP = {
  DEFAULT_TITLE = "Item Equipped!",
  DEFAULT_BODY = "You equipped an item",
  DEFAULT_IMAGE = "rbxassetid://8150337440",
  DEFAULT_SOUND = "rbxassetid://10066947742",
  DEFAULT_COLOR = Color3.fromRGB(85, 170, 255),
}

notificationPresets.UNEQUIP = {
  DEFAULT_TITLE = "Item Unequipped",
  DEFAULT_BODY = "You unequipped an item",
  DEFAULT_IMAGE = "rbxassetid://240664703",
  DEFAULT_SOUND = "rbxassetid://550209561",
  DEFAULT_COLOR = Color3.fromRGB(170, 170, 170),
}

notificationPresets.SELL = {
  DEFAULT_TITLE = "Item Sold!",
  DEFAULT_BODY = "You sold an item",
  DEFAULT_IMAGE = "rbxassetid://8150337440",
  DEFAULT_SOUND = "rbxassetid://10066947742",
  DEFAULT_COLOR = Color3.fromRGB(111, 218, 40),
}

notificationPresets.DATA_LOADED = {
  DEFAULT_TITLE = "Welcome Back!",
  DEFAULT_BODY = "Your data loaded successfully",
  DEFAULT_IMAGE = "rbxassetid://8150337440",
  DEFAULT_SOUND = "rbxassetid://10066947742",
  DEFAULT_COLOR = Color3.fromRGB(111, 218, 40),
}

notificationPresets.DATA_ERROR = {
  DEFAULT_TITLE = "Data Load Error",
  DEFAULT_BODY = "Failed to load your data",
  DEFAULT_IMAGE = "rbxassetid://240664703",
  DEFAULT_SOUND = "rbxassetid://550209561",
  DEFAULT_COLOR = Color3.fromRGB(198, 34, 34),
}

notificationPresets.EVENT_START = {
  DEFAULT_TITLE = "Event Started!",
  DEFAULT_BODY = "A new event has begun!",
  DEFAULT_IMAGE = "rbxassetid://8150337440",
  DEFAULT_SOUND = "rbxassetid://10066947742",
  DEFAULT_COLOR = Color3.fromRGB(255, 215, 0),
}

notificationPresets.EVENT_END = {
  DEFAULT_TITLE = "Event Ended",
  DEFAULT_BODY = "The event has ended!",
  DEFAULT_IMAGE = "rbxassetid://8150337440",
  DEFAULT_SOUND = "rbxassetid://550209561",
  DEFAULT_COLOR = Color3.fromRGB(170, 170, 170),
}

notificationPresets.EVENT_COLLECT = {
  DEFAULT_TITLE = "Event Item Collected!",
  DEFAULT_BODY = "You collected an item from the event!",
  DEFAULT_IMAGE = "rbxassetid://8150337440",
  DEFAULT_SOUND = "rbxassetid://10066947742",
  DEFAULT_COLOR = Color3.fromRGB(255, 215, 0),
}

return notificationPresets
