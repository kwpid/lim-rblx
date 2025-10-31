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



return notificationPresets