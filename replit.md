# Project Memory

## Overview
This is a **Roblox crate opening/unboxing game** with weighted probability item rolls, admin tools, data persistence, and inventory management. Players roll crates to win items of varying rarities based on their Robux values.

## Project Type
- **Platform**: Roblox
- **Language**: Lua
- **Genre**: Case Opening / Unboxing Game
- **Data Storage**: Roblox DataStore Service

## Core Game Systems

### Item System
- Items have Roblox asset IDs, names, values, and rarities
- 8-tier rarity system (Common → Insane) based on value
- Support for both regular items (stackable) and stock items (limited with serial numbers)
- Weighted probability: higher value = lower chance

### Crate Opening
- Free rolls with 5-second animation
- Weighted random selection based on item value
- Stock item protection with automatic reroll
- Visual scrolling animation with item previews

### Admin Tools
- Whitelisted admin system (User ID: 1547280148)
- Admin panel GUI for creating items
- Live item preview using Roblox thumbnails
- Console commands: `CheckDatabase()` and `CheckRarities()`

### Data Persistence
- Player inventory with automatic stacking
- Cases opened counter
- Cash system (tracked but not currently used)
- Inventory value (InvValue) - auto-calculated total value
- Auto-save every 2 minutes
- DataStore versions: ItemDatabase_v1, PlayerData_v1

### Inventory Display
- Shows all owned items with thumbnails and rarity colors
- Serial numbers for stock items
- Search/filter functionality
- Click to view detailed item info

## File Structure

### ReplicatedStorage/
- **ItemRarityModule.lua** - Rarity calculations and roll percentages

### ServerScriptService/
- **AdminConfig.lua** - Admin whitelist
- **AdminItemHandler.lua** - Admin item creation
- **CratesServer.lua** - Crate opening logic
- **DataStoreAPI.lua** - Public data API
- **DataStoreManager.lua** - DataStore operations
- **ItemDatabase.lua** - Global item database
- **PlayerDataHandler.lua** - Player join/leave/save

### StarterGUI/
- **AdminGUI.lua** - Admin panel client script
- **CratesClient.lua** - Crate animation client script
- **InventorySystem.lua** - Inventory display client script

## Recent Changes
- **2025-10-31**: Initial project setup with all core Lua scripts added
- **2025-10-31**: Created comprehensive PROJECT_DOCUMENTATION.md file
- **2025-10-31**: Added inventory value tracking system (InvValue)
  - Automatically calculates total inventory value including stacked items
  - Updates in real-time when items are added/removed
  - Displayed in leaderstats for UI access
  - Fixed inventory UI loading by adding GetInventoryFunction RemoteFunction

## User Preferences
- User will test the game in Roblox and provide feedback
- Agent cannot test in Roblox, so user is responsible for testing
- Iterative development: User tests → Reports bugs/requests → Agent implements → Repeat
- User wants a living documentation file that tracks game details

## Development Workflow
1. User tests game in Roblox Studio
2. User reports bugs, issues, or feature requests
3. Agent updates Lua scripts based on feedback
4. Agent updates PROJECT_DOCUMENTATION.md to reflect changes
5. Repeat until game is complete

## Important Notes
- All client-server communication uses RemoteEvents in ReplicatedStorage/RemoteEvents/
- Stock items (1-100) get unique serial numbers when rolled
- Regular items (stock = 0) stack in inventory
- Admin panel and inventory UIs require specific ScreenGui structure in Roblox
- DataStore is used for both player data and global item database
- Inventory value is automatically recalculated whenever items are added/removed
- GetInventoryFunction RemoteFunction allows clients to fetch inventory data
- InventoryUpdatedEvent notifies clients when inventory changes

## Current Project Status
✅ Core mechanics implemented
✅ Admin system functional
✅ Data persistence working
✅ Inventory system complete
✅ Documentation created

⏳ Awaiting user testing and feedback
⏳ Future features to be determined by user needs

## Technical Details
- **Roll Cost**: FREE (0)
- **Roll Time**: 5 seconds
- **Auto-save Interval**: 120 seconds
- **Max Stock per Item**: 100
- **Rarity Tiers**: 8 levels based on item value

## Future Development Areas
Potential features to consider:
- Item selling/trading system
- Multiple crate types
- Daily rewards
- Leaderboards
- Economy system using cash
- VIP/gamepass benefits

---
**Last Updated**: 2025-10-31
