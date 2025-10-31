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
- Item names color-coded by rarity in animation
- Serial numbers displayed when winning stock items (e.g., "You won: Egg (#1)")
- Continue button always shows after every roll

### Admin Tools
- Whitelisted admin system (User ID: 1547280148)
- Admin panel GUI for creating items
- Live item preview using Roblox thumbnails
- Notification system: All players receive "New Item" notification when admin creates an item
- Console commands: `CheckDatabase()` and `CheckRarities()`

### Data Persistence
- Player inventory with automatic stacking
- Cases opened counter
- Cash system (earned from selling items)
- Inventory value (InvValue) - auto-calculated total value
- Auto-save every 2 minutes
- DataStore versions: ItemDatabase_v1, PlayerData_v1
- Data version system: Change DATA_VERSION in both DataStoreManager.lua AND ItemDatabase.lua to wipe all player data AND reset stock/serial numbers (e.g., "DataVersion.10" → "DataVersion.11")

### Inventory Display
- Shows all owned items with thumbnails and rarity colors
- Serial numbers for stock items
- Displays "copies: X / Y exist" for stock items (X = unique owners, Y = total stock)
- Displays "copies: X" for regular items (X = unique owners)
- Search/filter functionality
- Click to view detailed item info

### Equipping Items
- Players can equip items from their inventory to their character
- Equip/Unequip button in inventory detail panel
- Button text changes to "Unequip" when item is equipped
- Click again to unequip and remove from character
- Equipped items are visible to all players (server-side)
- Uses item's Roblox asset ID to load and attach to character
- Works with accessories, hats, and tools
- Items are tagged with OriginalRobloxId for precise unequipping

### Selling Items
- **Sell buttons hidden for stock items** (to prevent breaking limited items)
- **Confirmation required**: Button shows "Are you sure?" on first click
  - Click again within 3 seconds to confirm
  - Automatically resets if not confirmed
  - Resets when selecting a different item
- **Sell**: Sell a single copy of an item for 80% of its value (regular items only)
  - Regular items: Decreases stack count, or removes if only 1 left
  - Players who sell all copies have their owner count decremented
- **Sell All**: Sell all copies of an item at once (regular items only)
  - Calculates total value of all copies and gives 80% cash back
  - Removes all matching items from inventory
- Cash is added to player's wallet after selling
- Inventory value updates automatically after selling

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
- **EquipSellHandler.lua** - Equip and sell item functionality

### StarterGUI/
- **AdminGUI.lua** - Admin panel client script
- **CratesClient.lua** - Crate animation client script
- **InventorySystem.lua** - Inventory display client script
- **IndexLocal.lua** - All items index display (shows entire game catalog)

## Important Setup Requirements

### ⚠️ Studio API Access (REQUIRED)
Before testing in Roblox Studio, you **must** enable DataStore access:
1. Game Settings → Security → Enable "Studio Access to API Services"
2. Without this, leaderstats and inventory will not work

The scripts now include detailed error messages to help diagnose this issue.

## Recent Changes
- **2025-10-31**: Added equipped item persistence and notifications
  - **Equipped Items Persistence**: Equipped items now save to player data and auto-equip on rejoin
    - EquippedItems array added to player data structure (DataStoreManager.lua)
    - Items automatically equip when player spawns or rejoins the game
    - Failsafe: Items that are no longer owned are removed from EquippedItems
    - Equip button reflects equipped state (shows "Unequip" for equipped items)
    - Client syncs equipped items from server on inventory load
  - **Notification System Expanded**: Added notifications for all player actions
    - Equip notification: Shows when item is equipped
    - Unequip notification: Shows when item is unequipped
    - Sell notification: Shows when item is sold (single or all)
    - Data loaded notification: Shows "Welcome Back!" when data loads successfully
    - Data error notification: Shows error if data fails to load
  - New notification presets: EQUIP, UNEQUIP, SELL, DATA_LOADED, DATA_ERROR
  - GetEquippedItemsFunction RemoteFunction for client-server sync
- **2025-10-31**: Added equipping and selling functionality
  - **Equip System**: Players can equip and unequip items to their character using Roblox asset IDs
    - Equip/Unequip button in inventory detail panel (Frame.Equip)
    - Button dynamically changes to "Unequip" when item is equipped
    - Server-side equipping so other players can see equipped items
    - Uses InsertService to load and attach accessories/tools to character
    - Items tagged with OriginalRobloxId for precise unequipping
  - **Sell System**: Players can sell regular items for 80% of their value
    - Confirmation required: Button text changes to "Are you sure?" on first click
    - Must click again within 3 seconds to confirm sale
    - Sell buttons hidden for stock items (prevents breaking limited items)
    - Sell button: Sells one copy of the selected item (regular items only)
    - SellAll button: Sells all copies of the selected item at once (regular items only)
    - Owner counts are decremented when players sell all their copies
    - Cash is automatically added to player's wallet
  - Created EquipSellHandler.lua server script with RemoteEvents:
    - EquipItemEvent - Handles item equipping
    - SellItemEvent - Handles selling single items
    - SellAllItemEvent - Handles selling all copies
  - Added ItemDatabase functions:
    - DecrementStock() - Decreases CurrentStock when stock items are sold
    - DecrementOwners() - Decreases owner count when players sell items
  - Updated InventorySystem.lua to wire up Equip, Sell, and SellAll buttons
    - Stores full item data (RobloxId, Amount, SerialNumber, etc.) when item is selected
    - Buttons automatically refresh inventory after successful operations
- **2025-10-31**: Updated IndexLocal.lua to work with ItemDatabase system
  - Now fetches all items from server via GetAllItemsFunction RemoteFunction
  - Displays items using Roblox thumbnails (RobloxId)
  - Shows item stats: Rarity, Value, Owners, Stock (for stock items)
  - Includes search functionality to filter items by name
  - Auto-refreshes when new items are created
  - Sorted by value (highest first), then rarity, then name
  - Shows special badges (✨ for 3 or less remaining, 💎 for 10 or less remaining)
- **2025-10-31**: Added new features and improvements
  - Added data version system for wiping player data AND resetting item stock/serials (change DATA_VERSION in both DataStoreManager.lua and ItemDatabase.lua)
  - Continue button now shows after every roll (including auto-rolls)
  - Inventory now displays "copies: X / Y exist" for stock items (X = owners, Y = total stock)
  - Serial numbers now displayed when rolling stock items (e.g., "You won: Egg (#1)")
  - Item names in rolling animation are color-coded by rarity
  - Added notification system: All players get notified when new items are created by admins
- **2025-10-31**: Fixed crate animation issues
  - Animation now lands on the correct item (searches for chosen item in array)
  - Fixed animation speed to be consistent (pow = 4 instead of random 2-10)
  - Added logging to show chosen item and position during animation
  - Prevents "wrong item" bug where animation didn't match awarded item
- **2025-10-31**: Fixed inventory Selected value error
  - Detects and replaces ObjectValue with StringValue if wrong type exists
  - Prevents "Instance expected, got string" error when clicking items
- **2025-10-31**: Added comprehensive error logging to inventory system
  - Server-side logging for GetInventory requests
  - Client-side logging for every step of inventory initialization and refresh
  - Protected pcall wrappers around table.clone and ItemDatabase calls
  - Detailed item processing logs to identify where failures occur
- **2025-10-31**: Fixed leaderstats not appearing (timing issue with PlayerAdded event)
  - Created setupPlayer() function to handle both new and existing players
  - Added loop to process players who joined before scripts loaded
- **2025-10-31**: Fixed leaderstats and inventory loading issues
  - Added comprehensive error handling for DataStore failures
  - Added validation for data structure to prevent nil errors
  - Added helpful error messages pointing to Studio API Access requirement
  - Improved logging to show player data on join (Cash, Cases, Inventory count)
  - Fixed inventory refresh with better error handling and pcall protection
  - Inventory now shows diagnostic messages when data fails to load
- **2025-10-31**: Initial project setup with all core Lua scripts added
- **2025-10-31**: Created comprehensive PROJECT_DOCUMENTATION.md file
- **2025-10-31**: Added inventory value tracking system (InvValue)
  - Automatically calculates total inventory value including stacked items
  - Updates in real-time when items are added/removed
  - Displayed in leaderstats for UI access
  - Fixed inventory UI loading by adding GetInventoryFunction RemoteFunction
- **2025-10-31**: Fixed inventory UI issues
  - Fixed image display using Sample.Image property instead of creating children
  - Hide rarity label for Common items
  - Hide serial label when items don't have serial numbers
  - Hide t1 label by default
- **2025-10-31**: Added owner tracking system
  - Tracks how many unique players own each item (not total copies)
  - Regular items only increment owners on first acquisition
  - Stock items always increment owners (each is unique)
  - Displays "copies: X" in inventory UI
  - Properly handles stacking without inflating owner count

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
- GetAllItemsFunction RemoteFunction allows clients to fetch all items in the game
- InventoryUpdatedEvent notifies clients when inventory changes
- EquipItemEvent, SellItemEvent, SellAllItemEvent handle inventory item interactions
- Selling stock items restores their availability in the item pool (decrements CurrentStock)
- Cash system is now active - players earn cash by selling items (80% of value)

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
