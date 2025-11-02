local EventSystem = require(script.Parent.EventSystem)

print("🎮 EventSystem has been initialized and is now running!")
print("   - Random events will spawn every 5-10 minutes")
print("   - Use StartEvent(\"RandomItemDrops\") to manually trigger events")

_G.EventSystem = EventSystem
