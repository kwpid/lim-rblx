# Project Memory

## Overview
This project is a Roblox crate opening/unboxing game. It allows players to open virtual crates to acquire items of varying rarities and values. Key features include weighted probability rolls, comprehensive admin tools for item management, robust data persistence, an interactive inventory system, Discord webhook notifications, and the ability to equip virtual goods. The game aims to deliver an engaging unboxing experience within the Roblox platform.

## User Preferences
- User will test the game in Roblox and provide feedback
- Agent cannot test in Roblox, so user is responsible for testing
- Iterative development: User tests → Reports bugs/requests → Agent implements → Repeat
- User wants a living documentation file that tracks game details

## Recent Changes (November 2, 2025)
- **NEW - Three-Tier Luck System**: Completely separate luck multipliers for different rarity tiers:
  - **Regular Luck**: Affects Epic+ items (250k+ Robux) - for normal gameplay
  - **Mythic Luck**: Affects ONLY Mythic items (2.5M-9.9M Robux) - admin-only for testing
  - **Insane Luck**: Affects ONLY Insane items (10M+ Robux) - admin-only for testing
  - Each tier **stacks multiplicatively** (e.g., 300x regular + 5000x mythic = 1,500,000x for Mythic items!)
  - New console commands: `SetMythicLuck()`, `SetInsaneLuck()`, `ResetMythicLuck()`, `ResetInsaneLuck()`, `CheckAllLuck()`
  - Perfect for testing - force yourself to get specific rarity items
- **FIXED - Luck System Rewrite**: Completely rewrote how luck works - now it properly boosts Epic+ item probabilities instead of just picking the best one after rolling:
  - **Before**: Roll normally, IF you get Epic+, pick best one (luck useless 99% of the time)
  - **Now**: Epic+ items are directly 300x more likely to appear with 300x luck
  - Luck multiplies the roll weight of Epic+ items (250k+ value), making them actually appear more often
  - Common/Uncommon/Rare items keep normal probabilities
- **NEW - Event Console Command**: Added `StartEvent(eventName)` console command to manually trigger events:
  - Example: `StartEvent("RandomItemDrops")`
  - Complements the existing chat command `/spawn event_RandomItemDrops`
- **NEW - Luck Console Commands**: Added three new console commands for managing player luck multipliers:
  - `SetPlayerLuck(username, multiplier)` - Set a specific player's luck (e.g., `SetPlayerLuck("2kwpid", 300)`)
  - `ResetPlayerLuck(username)` - Reset player's luck to 1.0 (default/normal)
  - `CheckPlayerLuck(username)` - View a player's current luck multiplier
  - Player must be online in the server for commands to work
  - Use **Server Command Bar**, not Client Command Bar (server needs to see the attribute)
- **QOL - Event Status Display**: Added EventText to MainUI that displays when events are happening. Shows "[EventName] Ongoing!" when an event starts and hides when the event ends. Provides clear visual feedback that an event is active.
- **CRITICAL FIX - Shared Inventory Bug**: Fixed critical bug where all players were seeing the same inventory. The issue was in `DataStoreManager:GetDefaultData()` which used `table.clone()` to create a shallow copy of DEFAULT_DATA. This meant the nested `Inventory` and `EquippedItems` arrays were shared references across all players who loaded default data. Now each player gets completely fresh arrays with their own independent data.

## Previous Changes
- **NEW - Reset Ownership Data Command**: Added console command `ResetOwnershipData()` that clears all ownership data (CurrentStock, Owners, TotalCopies, SerialOwners) while preserving all items. This allows you to do a fresh reset without changing DATA_VERSION or deleting items. The command automatically refreshes the Index UI for all players after reset.
- **CHANGED - Manual Reset Only**: Removed automatic data reset on version change. Use the `ResetOwnershipData()` console command when you want to manually reset ownership data. Version changes now just update the version number without affecting data.
- **QOL - Button UIStroke Colors**: AutoRoll and HideRolls buttons now have UIStroke colors that match their text colors:
  - AutoRoll: Green stroke when ON, red stroke when OFF
  - HideRolls: Bright red stroke when ON, dark red stroke when OFF
- **NEW - Event Collection Notifications**: Players now receive a notification when they collect items from events:
  - Shows item name, rarity, and serial number (if the item is a stock item)
  - Notification color matches the item's rarity color
  - Displays the item's thumbnail image
  - Uses the EVENT_COLLECT notification preset
- **IMPROVED - Event Item Drops**: Enhanced the Random Item Drops event:
  - Dropped items now use actual Roblox item models (via InsertService) with rarity-colored Highlight effect
  - Improved model loading with better error handling and fallback to colored neon parts if loading fails
  - Fixed Accessory/Tool/Hat handling - uses Handle part instead of PrimaryPart for proper positioning
  - **ADJUSTED PROBABILITY SYSTEM**: Events now use rarity-based multipliers on normal roll chances:
    - Common: 3x, Uncommon: 6x, Rare: 10x, Ultra Rare: 15x, Epic: 25x, Ultra Epic: 30x, Mythic: 20x, Insane: 12x
    - Epic and Ultra Epic items have good drop rates during events
    - Mythic and especially Insane items kept rare even during events (lower multipliers)
  - Fixed item positioning using CFrame for Accessories/Tools and SetPrimaryPartCFrame for Models
  - Added debug logging to event notification system to diagnose notification issues
- **BUGFIX - Event System**: Fixed critical bugs and improved the event system:
  - Fixed RandomItemDrops event crash: `ItemDatabase.IsReady` is a boolean property, not a function
  - Fixed chat command admin verification: Now properly uses `AdminConfig:IsAdmin(player)` instead of passing just the UserId
  - Fixed stock item claiming in events: Changed `ClaimNextSerial()` to correct method `IncrementStock()`
  - Improved item selection: Event now refreshes rollable items list before each drop to exclude sold-out stock items
  - Added safety checks to skip drops if no rollable items are available
  - Event spawning with `/spawn event_RandomItemDrops` now works correctly for whitelisted admins
- **Random Event System**: Added dynamic event system with Random Item Drops event:
  - Events spawn automatically every 5-10 minutes
  - Admins can manually spawn events with `/spawn event_RandomItemDrops` command
  - **Random Item Drops Event**: 15-20 items drop from the sky (from "dropzone" part) over 3 minutes
    - Items use proximity prompts for collection
    - Event drop probability FAVORS rare items (opposite of normal rolling) - uses value^0.5 weighting
    - Serial items can drop and are handled same as rolling
    - High-value event items show "from the event" in chat/webhooks instead of "rolled"
    - Items stay on ground 1-2 minutes before cleanup
    - Notifications on event start and end
  - Event system is modular - new events can be added to ServerScriptService/Events/
- **Inventory Animation Update**: Removed slide-up/slide-down animations when opening/closing inventory (instant show/hide). Kept item popup slide-in animations.
- **Unified MainUI System**: Combined Inventory and Index into a single MainUI ScreenGui with toggle buttons:
  - MainUI contains: Inventory (Frame), Index (Frame), InventoryOpen (Button), IndexOpen (Button)
  - Clicking InventoryOpen shows Inventory and hides Index
  - Clicking IndexOpen shows Index and hides Inventory
  - Only one can be visible at a time, preventing overlapping GUIs
  - Both frames start hidden by default
- **Index Popup UI System**: Updated Index to use a popup system matching the inventory:
  - Renamed "Frame" to "Popup" and set to invisible by default
  - Selected items have bigger borders (BorderSizePixel = 3) that return to normal (1) when unselected
  - Popup appears when an item is selected (no animation, just show/hide)
  - Added "Close" button that hides popup and deselects the item
  - TotalOwners text now always displays for all items
  - OwnerList and OwnerListText only display for serial items (hidden for regular items)
  - Fixed ImageLabel UICorner preservation - UICorner is no longer destroyed when changing images
- **Serial Item Original Owner Tracking**: Serial items now track and display the original owner (first person to roll that specific serial number):
  - When a serial item is rolled, the player's username is saved as the original owner for that specific serial
  - In the inventory popup, serial items display "Original Owner: @username"
  - Regular (non-serial) items don't show this text
  - If the original owner can't be found, displays "@null"
  - Data is stored in ItemDatabase.SerialOwners array and persists across sessions
- **Inventory Popup UI Rework**: Changed inventory item details frame to a popup system with animations:
  - Renamed "Frame" to "Popup" and set to invisible by default
  - Selected items have bigger borders (BorderSizePixel = 3) that return to normal (1) when unselected
  - Popup slides in from the right when an item is selected (0.3s animation)
  - Added "Close" button that slides popup out and deselects the item
  - Previous selection is automatically cleared when selecting a new item
  - Smooth animations using TweenService with Quart easing
  - **Inventory GUI Animations**: Entire inventory slides up from bottom when opened (0.4s) and slides down when closed (0.3s)
  - **Auto-Refresh on Equip**: Inventory automatically refreshes and re-orders when equipping/unequipping items, showing equipped items at the top immediately
- **Limited Item Type**: Added new Limited item category that can be marked when creating items. Limited items display "LimText" in inventory and index. Items can have both rarity (Common, Rare, etc.) and Limited status.
- **Edit Item Mode**: Admin panel now supports editing existing items. Paste an existing item ID to enter edit mode - auto-fills all fields and allows changing name, value, stock, and Limited status. Button changes from "CreateItem" to "Edit Item".
- **RareText Fix**: Fixed RareText to properly show for items with 25 copies or less (was 24 or less). Applies to both stock and regular items in Index and Inventory.
- **Removed Trading System**: Deleted all trading-related files and code per user request.
- **Discord Webhook Integration**: Added webhook notifications for new item releases, high-value drops (250k+), and items going out of stock. **IMPORTANT**: You must add your Discord webhook URLs to `ServerScriptService/WebhookConfig.lua` for webhooks to work.
- **Anti-AFK Movement Detection**: Fixed Anti-AFK system to only rejoin players who haven't moved in 15 minutes (instead of rejoining all players). Tracks player position and only kicks truly inactive players.
- **Inventory Load Retry Logic**: Fixed inventory not showing when players rejoin. Added exponential backoff retry system that properly retries failed inventory loads up to 10 times.
- **Lower Item Drop Rates**: Changed probability power from 0.75 to 0.9 to make rare items significantly more rare. This creates a steeper rarity curve making high-value items harder to obtain.
- **CRITICAL FIX - DataStore Queue Overload**: Implemented debounced/batched save system for ItemDatabase to prevent "DataStore request queue fills" error. Instead of saving on every single roll/owner change (causing 100+ saves per minute with auto-roll), changes are now batched within a 3-second window. This completely eliminates DataStore throttling issues that were preventing players from rolling.
- **CRITICAL FIX - HideRolls Breaking After 2 Rolls**: Fixed bug where manual rolling with HideRolls enabled would stop working after 2 rolls. The GUI now properly stays disabled when HideRolls is ON (preventing input blocking), and items are properly cleared between rolls even when the animation frame is hidden.
- **Fixed CratesClient Initialization Delay**: Changed ItemDatabase to load asynchronously instead of blocking the require() call. This eliminates the 10-15 second delay before the crate opening UI becomes responsive when players join. RemoteEvents are now created immediately on server startup.
- **Client Optimization**: Reduced WaitForChild timeouts and improved initialization speed in CratesClient.lua for faster UI responsiveness.
- **Fixed SerialOwners Tracking**: Added automatic repair system that scans player inventories on join and adds missing SerialOwner records to ItemDatabase. This fixes the issue where stock items appear in inventories but don't show up in the Index owner list (e.g., migrated data from Studio).

## System Architecture

### Core Game Systems
-   **Item System**: Supports regular and limited stock items with up to 8 rarity tiers. Weighted probability governs item drops. Items can be marked as "Limited" which displays special LimText indicator.
-   **Crate Opening**: Features weighted random selection, visual scrolling animation with rarity-colored item names, and serial number display for stock items. Includes "Fast Roll" for gamepass owners and "AutoRoll" and "HideRolls" toggles with persistence. High-value unboxes trigger chat notifications (server-wide and cross-server global).
-   **Event System**: Random events spawn every 5-10 minutes with modular event modules. Includes Random Item Drops event where actual Roblox item models with rarity-colored Highlights fall from the sky with proximity prompts for collection. Events use rarity-based multipliers on normal roll probability (Common: 2x, Uncommon: 3x, Rare: 5x, Ultra Rare: 7x, Epic: 10x, Ultra Epic: 12x, Mythic: 15x, Insane: 20x normal roll chance). Admins can manually spawn events with `/spawn event_[event_name]` chat command.
-   **Admin Tools**: Whitelisted admin GUI for creating, editing, giving, and deleting items with live previews, auto-fill for item names, and confirmation dialogs. Edit mode auto-detects existing items when pasting item IDs. Includes global "New Item" and "Item Updated" notifications. LimitedToggle button allows marking items as Limited (green = ON, red = OFF). Admins can use `/spawn event_[event_name]` to manually trigger events.
-   **Data Persistence**: Uses Roblox DataStore Service for player inventories (with auto-stacking), rolls, cash, inventory value, AutoRoll state, HideRolls state, and Luck multiplier. Features auto-save, data versioning, and automatic cleanup of deleted items.
-   **Anti-AFK System**: Automatically rejoins players every 15 minutes to prevent AFK disconnection. Perfect for overnight AutoRoll farming sessions.
-   **Inventory Display**: Shows owned items with thumbnails, rarity colors, and serial numbers. Displays accurate copy counts for both stackable and stock items. Includes search/filter functionality and detailed item info on click. RareText appears on items with 25 copies or less. LimText appears only on Limited items. Equipped items appear first and have an orange border.
-   **View Other Players' Inventories**: Allows players to view others' inventories via a GUI activated by clicking on a highlighted player. Features structured error handling and retry logic.
-   **Equipping Items**: Players can equip/unequip items (accessories, hats, tools) which persist across sessions and are visible to other players. Headless items are handled by setting head transparency. Tools are placed in the player's Backpack.
-   **Selling Items**: Players can sell regular items for 80% of their value with confirmation. Stock items cannot be sold.
-   **Index System**: Displays all game items with details, owner lists for stock items (with serial numbers), and refresh capabilities. Includes roll percentage display with smart decimal handling. RareText shows for items with 25 copies or less. LimText shows for Limited items.
-   **Halloween Event Luck System**: A temporary luck system affecting Epic+ rarity items (value 250k+). Player Luck attribute and a Global Luck Modifier combine. Luck > 1.0 performs multiple rolls and picks the highest value Epic+ item; Luck < 1.0 picks the lowest. Maximum 10 rolls for performance.

### UI/UX Decisions
-   Item names are color-coded by rarity in the crate animation and inventory.
-   Admin panel is a graphical interface.
-   Notification system provides feedback for actions.
-   Hover effect with yellow glow for viewing other players' inventories.

### Technical Implementations
-   `RemoteEvents` and `RemoteFunctions` are used for client-server communication.
-   ItemDatabase loads asynchronously (non-blocking) to ensure RemoteEvents are created immediately on server startup.
-   **Debounced DataStore Saves**: ItemDatabase uses a queued save system with 3-second debounce to batch rapid changes and prevent DataStore request queue overflow. Critical operations (AddItem, DeleteItem) still save immediately.
-   Roll handler includes readiness check with graceful 30-second timeout if ItemDatabase is slow to load.
-   SerialOwner repair system automatically fixes missing records when players join (handles migrated/legacy data).
-   **HideRolls System**: When enabled, the crate opening GUI stays completely disabled to prevent input blocking. Items are automatically cleared between rolls even when the animation is hidden.
-   Roblox `InsertService` is used for equipping items.
-   Roblox `MarketplaceService` checks Fast Roll gamepass ownership.
-   DataStore operations include error logging and validation.
-   Inventory value (`InvValue`) is automatically calculated.
-   Uses `MessagingService` for cross-server notifications.
-   Utilizes `TeleportService` for auto-rejoin on server shutdown and every 15 minutes to prevent AFK kicks.
-   Equipping accessories uses `Humanoid:AddAccessory()`.

### File Structure (Key Directories)
-   `ReplicatedStorage/`: `ItemRarityModule.lua`, `NotificationPresets.lua`
-   `ServerScriptService/`: `AdminConfig.lua`, `AdminItemHandler.lua`, `AntiAFKHandler.lua`, `AutoRollHandler.lua`, `ChatCommandHandler.lua`, `CratesServer.lua`, `DataStoreAPI.lua`, `DataStoreManager.lua`, `EquipSellHandler.lua`, `EventSystem.lua`, `ItemDatabase.lua`, `PlayerDataHandler.lua`, `ServerShutdownHandler.lua`, `WebhookHandler.lua`
-   `ServerScriptService/Events/`: `RandomItemDrops.lua` (event modules are loaded automatically)
-   `StarterGUI/`: `AdminGUI.lua`, `CratesClient.lua`, `EventTextHandler.lua`, `IndexLocal.lua`, `InventorySystem.lua`, `MainUIToggle.lua`, `NotificationHandler.lua`, `ViewPlayerInventory.lua`

## External Dependencies
-   **Roblox DataStore Service**: Persistent data storage for player data and global item database.
-   **Roblox API Services**: Requires "Studio Access to API Services" enabled.
-   **Roblox InsertService**: Loads and attaches accessories/tools.
-   **Roblox MarketplaceService**: Checks gamepass ownership (ID: 1242040274).
-   **Roblox MessagingService**: Cross-server notifications for ultra-rare unboxes.
-   **Roblox TeleportService**: Handles automatic player rejoining on server shutdowns.