# Roblox Crate Opening Game - Project Documentation

## 🎮 Game Overview
This is a Roblox crate/case opening game where players can roll for random items based on a weighted probability system. Items have different rarities determined by their value, and some items can be limited stock with serial numbers.

## 📋 Current Game Features

### 1. Item System
- **Item Properties:**
  - RobloxId: The Roblox asset ID for the item thumbnail
  - Name: Display name of the item
  - Value: The Robux value (determines rarity and roll chance)
  - Rarity: Auto-calculated from value (8 tiers)
  - Stock: Optional limited quantity (0 = unlimited, 1-100 = stock item)
  - CurrentStock: Tracks how many have been rolled
  - SerialNumber: For stock items (e.g., #1/50)
- **Stack Limits (Anti-Hoarding System):**
  - Regular items (Common to Ultra Rare): Maximum 100 copies per item
  - When adding items would exceed the limit, excess copies are automatically sold at 80% value
  - Cash from auto-sold items is automatically added to player's account
  - Epic, Ultra Epic, Mythic, and Insane items: No stack limit (unlimited)
  - Migration system auto-sells existing excess items when players join the game

### 2. Rarity System (8 Tiers + Limited)
Items are automatically assigned rarity based on their value:
- **Common**: 1 - 2,499 Robux (Gray)
- **Uncommon**: 2,500 - 9,999 Robux (Green)
- **Rare**: 10,000 - 49,999 Robux (Blue)
- **Ultra Rare**: 50,000 - 250,999 Robux (Purple)
- **Epic**: 250,000 - 750,000 Robux (Orange)
- **Ultra Epic**: 750,000 - 2,500,000 Robux (Red-Orange)
- **Mythic**: 2,500,000 - 9,999,999 Robux (Red)
- **Insane**: 10,000,000+ Robux (Magenta)
- **Limited**: Special event-exclusive rarity (Gold) - NOT rollable from crates

**Limited Items:**
- Cannot be obtained through regular crate rolls
- Only available through special events
- Can have stock limits (with serial numbers) or timer-based availability
- Timer system: Items can have an "OffsaleAt" timestamp that makes them unavailable after a certain time
- Display as "Not Rollable" in the Index UI
- Color-coded in gold (RGB 255, 215, 0) across all UI elements

### 3. Probability System
- Higher value items = lower chance to win
- Uses inverse probability weighting with power of 0.75
- Formula: Chance = (1/ItemValue^0.75) / TotalInverseValue
- Balanced scaling ensures rare items are still obtainable while maintaining rarity

### 4. Crate Opening Mechanics
- **Roll Cost**: FREE (currently set to 0)
- **Roll Time**: 5 seconds animation (2 seconds with Fast Roll gamepass)
- **Animation**: Scrolling items with chosen item landing in view
- **Camera Shake**: Screen shake when winning items, intensity scales with rarity:
  - Common & Uncommon: No shake
  - Rare: Light shake (0.15 intensity, 0.4s)
  - Ultra Rare: Medium shake (0.35 intensity, 0.6s)
  - Epic: Strong shake (0.6 intensity, 0.8s)
  - Ultra Epic: Very strong shake (1.0 intensity, 1.0s)
  - Mythic: Intense shake (1.5 intensity, 1.2s)
  - Insane: Maximum shake (2.5 intensity, 1.5s)
  - Shake fades out smoothly over duration
- **Stock Protection**: If a stock item sells out during animation, automatically rerolls
- **Chat Notifications**: 
  - Items worth 250k+ Robux: Colored chat message to the player
  - Items worth 5M+ Robux: Global announcement to entire server
  - Shows item name, value (formatted), serial # (for stock items), color-coded by rarity
- Players can only roll one crate at a time

### 5. Admin System
- **Whitelisted Admins**: Defined by User ID in AdminConfig.lua
  - Current Admin ID: 1547280148
- **Admin Panel Features:**
  - **Create Items**: Create new items with Roblox ID, name, value, and optional stock or Limited rarity
    - Live preview of item thumbnail
    - Auto-fills item name from Roblox marketplace
    - Input validation for all fields
    - **Limited Items**: Toggle to create event-exclusive Limited items
      - Limited items cannot be rolled from crates
      - Optional timer field (in hours) to set when the item goes offsale
      - Timer is converted to Unix timestamp and stored as OffsaleAt field
      - Can still use stock system for serial numbers
  - **Give Items to Players**: Give items directly to players
    - Enter item Roblox ID, amount to give, and player ID/username
    - Supports both User ID (number) and username (case-insensitive)
    - Regular items: Gives specified amount, properly increments owner count
    - Stock items not at max: Gives next available serial number (as if rolled)
    - Stock items at max: Automatically increases stock limit by 1, gives new serial
    - Only works for players currently in the game
- **Console Commands:**
  - `CheckDatabase()` - View all items sorted by value
  - `CheckRarities()` - View item count by rarity tier
  - `ResetOwnershipData()` - Reset all ownership data (CurrentStock, Owners, TotalCopies, SerialOwners) while keeping all items intact. Use this for a fresh reset during testing. Automatically refreshes the Index UI for all players.
  - **Regular Luck (Epic+ items, 250k+):**
    - `SetPlayerLuck(username, multiplier)` - Set a player's luck multiplier (e.g., `SetPlayerLuck("2kwpid", 300)`)
    - `ResetPlayerLuck(username)` - Reset a player's luck to 1.0 (default/normal)
    - `CheckPlayerLuck(username)` - View a player's current luck multiplier
  - **Mythic Luck (Mythic items ONLY, 2.5M-9.9M) - Admin Only:**
    - `SetMythicLuck(username, multiplier)` - Set mythic luck (e.g., `SetMythicLuck("2kwpid", 5000)`)
    - `ResetMythicLuck(username)` - Reset mythic luck to 1.0 (default/normal)
  - **Insane Luck (Insane items ONLY, 10M+) - Admin Only:**
    - `SetInsaneLuck(username, multiplier)` - Set insane luck (e.g., `SetInsaneLuck("2kwpid", 10000)`)
    - `ResetInsaneLuck(username)` - Reset insane luck to 1.0 (default/normal)
  - **Check All Luck Tiers:**
    - `CheckAllLuck(username)` - View all luck values and combined effects
  - `StartEvent(eventName)` - Manually start a random event (e.g., `StartEvent("RandomItemDrops")` or `StartEvent("ScavengerHunt")`)

### 6. Data Persistence (DataStore)
- **Player Data Saved:**
  - Inventory (all owned items)
  - Rolls (total number of crates opened)
  - Cash (currently unused but tracked)
  - InvValue (total inventory value, automatically calculated)
- **Item Database:**
  - All available items stored globally
  - Shared across all players
  - Persists between server restarts
- **Save Intervals:**
  - Auto-save every 2 minutes
  - Save on player leave
  - Save on server shutdown

### 7. Inventory System
- **Display Features:**
  - Shows all owned items with thumbnails
  - **Sorting**: Equipped items first, then highest value to lowest value
  - Color-coded by rarity
  - Shows serial numbers for stock items
  - Shows quantity for stackable items
  - Stock items: Shows "X / Y copies" (serials claimed / total stock)
  - Regular items: Shows "X owners" (unique players who own it)
  - Search bar for filtering
  - Click to view detailed item info
- **Item Stacking:**
  - Regular items stack (shows "3x", "5x", etc.)
  - Stock items never stack (each has unique serial number)
- **Inventory Value Tracking:**
  - Automatically calculates total inventory value
  - Includes stacked items (Value × Amount)
  - Updates in real-time when items are added/removed
  - Displayed in leaderstats as "InvValue"

### 8. Owner Tracking System
- **Unique Ownership:**
  - Tracks how many unique players own each item globally
  - Regular items: +1 owner only when a NEW player gets the item
  - Stock items: +1 owner for each unique stock item acquired
  - Displayed as "copies: X" in inventory UI
- **Smart Counting:**
  - If player already has a regular item and gets it again, it stacks (no owner increment)
  - Stock items always count as new owners since each serial is unique
  - Shows true rarity based on how many players actually own the item

### 9. Equipped Item Persistence
- **Auto-Equip System:**
  - Equipped items are saved to player data in EquippedItems array
  - When player rejoins, all previously equipped items automatically equip to their character
  - Items equip when character spawns or respawns
  - Supports accessories, hats, tools, and head items
- **Head Item Support:**
  - Head items replace the player's existing head when equipped
  - When unequipped, the default Roblox head is restored with a default face
  - Properly handles neck Motor6D connections for head replacement
  - Works seamlessly with character respawns and auto-equip on rejoin
- **Failsafe Protection:**
  - System checks if player still owns each equipped item before equipping
  - Items that are no longer owned are removed from EquippedItems
  - Prevents errors from trying to equip items player no longer has
- **Client-Server Sync:**
  - Client syncs equipped items from server on inventory load
  - Equip button correctly shows "Unequip" for already-equipped items
  - GetEquippedItemsFunction RemoteFunction provides server data to client

### 10. Serial Item Original Owner Tracking
- **Original Owner System:**
  - When a player rolls a serial item (e.g., Serial #1), their username is permanently saved as the original owner
  - Original owner data is stored in ItemDatabase.SerialOwners array: `{UserId, SerialNumber, Username}`
  - Data persists across sessions in DataStore
- **Inventory Display:**
  - Serial items in the inventory popup show "Original Owner: @username"
  - Regular items do not show this text (only serial items)
  - If the original owner can't be found or doesn't exist, displays "@null"
- **Technical Implementation:**
  - DataStoreAPI includes OriginalOwner field when sending inventory to client
  - Client-side popup conditionally shows SerialOwner TextLabel based on item type
  - SerialOwner text is hidden for non-serial items

### 11. Notification System
- **Notification Types:**
  - EQUIP: Shows when player equips an item
  - UNEQUIP: Shows when player unequips an item
  - SELL: Shows when player sells item(s) with cash earned
  - DATA_LOADED: "Welcome Back!" when data loads successfully
  - DATA_ERROR: Error message if data fails to load
  - GIFT: When admin creates new item (all players notified)
  - EVENT_START: When a random event begins
  - EVENT_END: When a random event finishes
  - EVENT_COLLECT: When player collects an item from an event (shows item name, rarity, and serial #)
  - ERROR, VICTORY: Pre-existing notification types
- **Notification Features:**
  - Shows item thumbnail image for equip/unequip/sell/event_collect notifications
  - Displays cash earned for sell notifications
  - Event collection notifications show item name, rarity, and serial number (if applicable)
  - Notification color matches item rarity for event collection notifications
  - 2-second delay on data load notifications to ensure client is ready
  - Queued system handles multiple notifications gracefully

### 12. Index System (All Items Catalog)
- **Display All Game Items:**
  - Shows every item in the game database (not just player's inventory)
  - Sorted by value (highest first), then rarity, then name
  - Displays item thumbnail, name, value, rarity, and owner count
  - Search/filter functionality to find specific items
  - Selected items show with bigger borders (BorderSizePixel = 3)
- **Item Detail Popup:**
  - Popup is hidden by default, appears when clicking an item
  - ItemName: Display name of the selected item
  - TotalOwners: Shows total owners count (always visible for all items)
  - Value: Robux value of the item
  - ImageLabel: Displays item thumbnail with UICorner preserved during image changes
  - Close button: Hides popup and deselects the item
- **Owner List (Stock/Serial Items Only):**
  - OwnerListText: Label/header for the owner list (only visible for serial items)
  - OwnerList: Scrolling frame showing owners (only visible for serial items)
  - Shows scrolling list of all players who own each serial number
  - Each entry displays:
    - PlayerPFP: Player's avatar headshot
    - @Username: Player's username prefixed with @
    - #SerialNumber: Serial number prefixed with #
  - Sorted by serial number (lowest first: #1, #2, #3, etc.)
  - Works even when players are offline (data stored in ItemDatabase)
- **Serial Owner Tracking:**
  - SerialOwners array in ItemDatabase tracks {UserId, SerialNumber, Username}
  - Automatically recorded when stock items are rolled or admin-given
  - GetItemOwnersFunction RemoteFunction provides data to client
  - RecordSerialOwner() called by DataStoreAPI when adding stock items
  - Data persists across sessions in DataStore

### 13. Mastery System
- **Overview:**
  - Collection tracking system that displays player progress across themed item series
  - Shows which items players have collected and which are still locked
  - Progress bars indicate completion percentage for each collection
  - **Persistent Completion:** Masteries stay completed forever via Roblox badges - even if items are lost/traded
- **Collections Configuration:**
  - Defined in ReplicatedStorage/MasteryCollections.lua
  - Each collection has: Name, ImageId (for collection thumbnail), BadgeId (Roblox badge), Items (array of RobloxIds)
  - BadgeId field: Set to the Roblox badge ID for the collection (0 = not configured)
  - Easy to add new collections by editing the MasteryCollections module
- **Badge System (Persistent Completion):**
  - When a player completes a mastery (owns all items), they receive a Roblox badge
  - Badge ownership is the source of truth for mastery completion
  - **Permanent Completion:** Once completed, the mastery stays at 100% forever
  - Even if the player loses/sells/trades items from the collection, it remains completed
  - Server uses BadgeService to check and award badges
  - Completion status is verified on player join by checking badge ownership
- **Main Collection Display:**
  - Shows all available collections using Sample template (buttons)
  - Each collection displays: Name, Image, Progress bar with percentage
  - Progress bar fills based on owned items / total items in collection
  - **CompletedFrame:** Visible overlay on completed masteries (shows completion)
  - If 0% complete, progress bar shows size of 0
  - Completed masteries always show 100% progress
  - Collections are clickable to view details
- **Detailed Item View (Mastery_Info):**
  - Opens when clicking a collection button
  - Shows all items in that collection using ItemSample template
  - Each item displays: Name, Roll percentage, Item image
  - LockedFrame visible for items player doesn't own (shows as locked)
  - LockedFrame hidden for owned items (shows as unlocked)
  - Back button returns to main collection view and clears displayed items
- **Dynamic Updates:**
  - Refreshes automatically when inventory changes
  - Uses InventoryUpdatedEvent to detect when player gets new items
  - Automatically awards badges when a player completes a mastery
  - Closes detail view and updates progress when inventory changes
- **Technical Implementation:**
  - Client-side LocalScript in StarterGUI/MasterySystem.lua
  - Server-side script in ServerScriptService/MasteryHandler.lua
  - Uses CheckMasteryCompletedFunction to verify badge ownership
  - Uses AwardMasteryBadgeEvent to award badges on first completion
  - Uses GetInventoryFunction to fetch player's inventory
  - Uses GetAllItemsFunction to access item database for details
  - Integrates with ItemRarityModule for roll percentage calculations
  - Badge checks run asynchronously on player join for all collections

### 14. Barrel Event System
- **Overview:**
  - Players can pull items from barrels in Workspace.Barrels for 5,000 Cash
  - Only hat-type items can be pulled (no tools or faces)
  - Features camera animation, item spawning with floating/spinning effects
  - Full transaction safety with automatic refunds on failures
- **Pull Cost:** 5,000 Cash per pull
- **Item Pool:**
  - Only Roblox hat/accessory items (AssetTypeIds: 8, 41-48, 61)
  - Weighted RNG favors commons-rares
  - Very rare to get epics
  - 0.5% chance to pull Chroma Valkyrie (Item ID: 88275556285191)
- **Interaction:**
  - Proximity prompt on Barrel.Body part
  - Golden highlight when prompt is visible
  - 0.5 second hold duration
  - 10 stud activation distance
- **Animation Flow:**
  1. Player activates proximity prompt
  2. Camera switches to barrel's "cam" part
  3. Item model spawns at "spawn" part
  4. Item floats up to "final" part (2 second tween)
  5. Item spins for 3 seconds
  6. Camera returns to player
  7. Item is added to inventory
- **Transaction Safety:**
  - Cash deducted FIRST (before item addition)
  - If cash deduction fails: Player notified, no changes made
  - Stock incremented AFTER cash deduction
  - If stock sold out: Cash refunded, player notified with refund status
  - If item addition fails: Stock rolled back, cash refunded, player notified
  - Refund failures logged with UserId for manual support
  - Critical errors include player UserId in notification for support escalation
- **Weighted RNG:**
  - Common: 100x weight
  - Uncommon: 50x weight
  - Rare: 20x weight
  - Ultra Rare: 5x weight
  - Epic: 2x weight
  - Ultra Epic: 0.5x weight
  - Mythic: 0.1x weight
  - Insane: 0.05x weight
  - Chroma Valkyrie: 0.5% override chance (checked before weighted selection)
- **Notifications:**
  - Displays item name, serial number (if applicable), value, and rarity
  - Notification color matches item rarity
  - Error notifications for insufficient cash, sold out items, and transaction failures
- **Technical Details:**
  - Server script: ServerScriptService/Events/BarrelEvent.lua
  - Client script: StarterGUI/BarrelCameraHandler.lua
  - Uses SetPlayerCamera RemoteEvent for camera control
  - Respects serial number system for stock items
  - Prevents multiple simultaneous pulls per player

## 🗂️ File Structure Explained

### ReplicatedStorage/
Contains modules shared between client and server:
- **ItemRarityModule.lua**: Determines rarity from value, calculates roll percentages
- **MasteryCollections.lua**: Defines all item collections for the Mastery system
- **NotificationPresets.lua**: Notification type configurations
- **TradeConfiguration.lua**: Trading system configuration

### ServerScriptService/
Server-side game logic:
- **AdminConfig.lua**: Admin user whitelist and permission checking
- **AdminItemHandler.lua**: Handles admin item creation requests, sets up RemoteEvents
- **CratesServer.lua**: Core crate opening logic, weighted random selection, stock management
- **DataStoreAPI.lua**: Public API for other scripts to modify player data
- **DataStoreManager.lua**: Low-level DataStore save/load operations
- **ItemDatabase.lua**: Global item database, stores all available items
- **MasteryHandler.lua**: Badge-based mastery completion tracking and awards
- **PlayerDataHandler.lua**: Manages player join/leave, creates leaderstats, auto-save

### StarterGUI/
Client-side UI scripts:
- **AdminGUI.lua**: Admin panel for creating items (LocalScript)
- **CratesClient.lua**: Crate opening animation and UI (LocalScript)
- **InventorySystem.lua**: Inventory display and management (LocalScript)
- **MasterySystem.lua**: Collection tracking and progress display (LocalScript)
- **TradeClient.lua**: Player-to-player trading UI and logic (LocalScript)
- **NotificationHandler.lua**: Notification display system (LocalScript)
- **MainUIToggle.lua**: Main UI toggle between Inventory and Index (LocalScript)

## 🔧 How Systems Connect

### Item Creation Flow:
1. Admin opens admin panel (AdminGUI.lua)
2. Admin enters item details and clicks "Create"
3. Client fires CreateItemEvent to server (AdminItemHandler.lua)
4. Server validates admin status and item data
5. ItemDatabase adds item and saves to DataStore
6. Server confirms success back to client

### Crate Opening Flow:
1. Player clicks Roll button (CratesClient.lua)
2. Client fires RollCrateEvent to server (CratesServer.lua)
3. Server gets rollable items from ItemDatabase
4. Server picks random item using weighted probability
5. Server generates animation items and sends to client
6. Client plays 5-second scrolling animation
7. Server waits 5 seconds then awards item
8. Server checks stock and claims serial number if needed
9. Server adds item to player inventory via DataStoreAPI
10. Server increments rolls counter

### Inventory Update Flow:
1. Server adds item to player data (DataStoreAPI.lua)
2. Item either stacks (regular) or adds unique entry (stock)
3. Server recalculates total inventory value automatically
4. Server updates leaderstats InvValue
5. Server fires InventoryUpdatedEvent to notify client
6. Client requests inventory via GetInventoryFunction
7. Server returns player's inventory array
8. Client displays items with thumbnails and info

## 📊 Data Structures

### Player Data (DataStore):
```lua
{
  Inventory = {
    -- Regular item (stackable):
    {RobloxId = 12345, Name = "Item", Value = 1000, Rarity = "Common", Amount = 3, ObtainedAt = timestamp},
    -- Stock item (unique):
    {RobloxId = 67890, Name = "Rare Item", Value = 50000, Rarity = "Ultra Rare", SerialNumber = 5, ObtainedAt = timestamp}
  },
  Rolls = 10,        -- Total number of crates opened
  Cash = 0,
  InvValue = 53000,  -- Auto-calculated: (1000 × 3) + (50000 × 1)
  EquippedItems = {12345, 67890},  -- Array of RobloxIds of equipped items
  DataVersion = "DataVersion.15"
}
```

### Item Database Entry:
```lua
{
  RobloxId = 12345,
  Name = "Cool Item",
  Value = 25000,
  Rarity = "Uncommon",
  Stock = 50,          -- 0 = unlimited, 1-100 = limited
  CurrentStock = 12,   -- How many claimed so far
  Owners = 8,          -- How many unique players own this item
  CreatedAt = timestamp
}
```

## 🎯 What the User Wants

**Current State:**
- Core game mechanics are implemented and functional
- User cannot test in Roblox Studio (using Replit Agent instead)
- User will test and provide feedback on fixes/features

**Development Process:**
1. User tests in Roblox
2. User reports bugs or requests features
3. Agent makes code changes
4. Repeat until game is complete

**User's Testing Responsibilities:**
- Testing all game functionality
- Reporting bugs with details
- Requesting new features or changes
- Providing Roblox-specific feedback (UI, UX, gameplay)

## 🚀 Important Technical Notes

### ⚠️ CRITICAL: Studio API Access Setup
**Before testing in Roblox Studio, you MUST enable DataStore access:**

1. Open your game in Roblox Studio
2. Go to **Game Settings** (Home tab → Game Settings)
3. Navigate to **Security** tab
4. Enable **"Studio Access to API Services"**
5. Click **Save**

**Without this setting:**
- ❌ Leaderstats will not appear on players
- ❌ Inventory will not load or display items
- ❌ Player data won't save between sessions
- ❌ You'll see DataStore error messages in output

**The scripts will now show helpful error messages if this isn't enabled!**

### RemoteEvents Setup:
All client-server communication uses RemoteEvents in ReplicatedStorage/RemoteEvents/:
- `CreateItemEvent` - Admin item creation
- `CheckAdminFunction` - Check if player is admin
- `RollCrateEvent` - Request crate roll
- `CrateOpenedEvent` - Send animation data to client
- `GetInventoryFunction` - Fetch player inventory
- `InventoryUpdatedEvent` - Notify client of inventory changes

### Stock Item Logic:
- Stock items have limited quantity (1-100)
- Each rolled stock item gets unique serial number
- Once CurrentStock >= Stock, item becomes unrollable
- Race condition protection: claims serial during server wait
- If stock sells out during animation, automatically rerolls different item

### Global Variables:
- `_G.PlayerData` - Active player data in memory (PlayerDataHandler.lua)
- `_G.CheckDatabase()` - Console command to view all items
- `_G.CheckRarities()` - Console command to view rarity breakdown

## 🐛 Known Limitations

1. Cash system exists but is not currently used
2. No item deletion/selling system yet (selling system exists, but no admin deletion)
3. Admin panel is client-side GUI (needs to be placed in correct ScreenGui)
4. Inventory UI needs ScreenGui with specific structure
5. Crate opening UI needs ScreenGui with specific structure

## 📝 Future Development Areas

Based on the code structure, potential features to add:
- Different crate types with different item pools
- Daily rewards system
- Leaderboards for most valuable inventory
- Item gifting system
- VIP/gamepass benefits
- Economy system using cash
- Item showcase/display system

## 🔑 Key Configuration Values

**AdminConfig.lua:**
- Admin User IDs: `{1547280148}`

**CratesServer.lua:**
- Roll Cost: `0` (FREE)
- Roll Animation Time: `5 seconds`

**PlayerDataHandler.lua:**
- Auto-save Interval: `120 seconds` (2 minutes)

**ItemDatabase.lua:**
- DataStore Version: `ItemDatabase_v1`

**DataStoreManager.lua:**
- DataStore Version: `PlayerData_v1`

## 🎨 UI Requirements

For the game to work properly in Roblox, you need:

1. **AdminGUI ScreenGui** with structure:
   - Open_Admin button
   - UIFrame (panel)
   - ItemPreview with ActualPreview ImageLabel
   - **Create Item Section:**
     - Item_Id TextBox
     - Item_Name TextBox
     - Item_Value TextBox
     - Item_Stock_Optional TextBox
     - CreateItem button
   - **Give Item Section:**
     - Give_Item_Id TextBox
     - Give_Item_Amount TextBox
     - Player_Id TextBox
     - GiveItem button

2. **MainUI ScreenGui** (Combined Inventory and Index) with structure:
   - **Inventory** (Frame) - Contains entire inventory system:
     - Handler folder
     - Popup with ItemName, Value, TotalValue, ImageLabel, SerialOwner (TextLabel), Equip, Sell, SellAll, and Close buttons
     - Sample button template
     - SearchBar TextBox
     - **Note:** Set Inventory.Visible = false by default
   - **Index** (Frame) - Contains entire index system:
     - Handler folder
     - Popup with ItemName, Value, TotalOwners (TextLabel), ImageLabel, OwnerListText (TextLabel), OwnerList (ScrollingFrame), and Close button
     - Sample button template
     - UserTemplate for owner list entries
     - SearchBar TextBox
     - **Note:** Set Index.Visible = false by default
   - **InventoryOpen** (TextButton) - Opens Inventory, closes Index
   - **IndexOpen** (TextButton) - Opens Index, closes Inventory
   - **MainUIToggle** (LocalScript) - Handles toggling between Inventory and Index

3. **OpenedCrateGui ScreenGui** with structure:
   - CrateFrame
   - ItemsFrame with ItemsContainer
   - ContinueButton
   - OpeningCrateItemFrame template

4. **Other UI Elements:**
   - Roll button

---

**Last Updated:** 2025-10-31
**Project Status:** Core mechanics complete, ready for testing and iteration
**Development Mode:** User tests → Reports feedback → Agent implements → Repeat
