local AdminConfig = {}

AdminConfig.AdminUserIds = {
  1547280148,
}

function AdminConfig:IsAdmin(player)
  for _, adminId in ipairs(self.AdminUserIds) do
    if player.UserId == adminId then
      return true
    end
  end
  return false
end

return AdminConfig
