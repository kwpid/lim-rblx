# Project Memory

## Overview
This project is a Roblox crate opening/unboxing game where players can open crates to receive virtual items of varying rarities and values. It features weighted probability rolls, comprehensive admin tools for item management, robust data persistence, and an interactive inventory system. The game aims to provide an engaging unboxing experience within the Roblox platform, allowing players to collect, equip, and trade unique virtual goods.

## User Preferences
- User will test the game in Roblox and provide feedback
- Agent cannot test in Roblox, so user is responsible for testing
- Iterative development: User tests → Reports bugs/requests → Agent implements → Repeat
- User wants a living documentation file that tracks game details

## System Architecture

### Core Game Systems
-   **Item System**: Items have Roblox asset IDs, names, values, and rarities (8 tiers from Common to Insane). Supports both stackable regular items and limited stock items with serial numbers. Weighted probability ensures higher value items are rarer.
-   **Crate Opening**: Free rolls with weighted random selection. Includes visual scrolling animation with rarity-colored item names, serial number display for stock items, and a "continue" button after each roll. The roll animation only displays items that are currently available (excludes sold-out stock items). High-value unboxes trigger chat notifications (250k+ server-wide, 5M+ cross-server global). Features:
    - **Roll Time**: 5 seconds for normal players, 2 seconds for Fast Roll gamepass owners (2.5x faster)
    - **Fast Roll Gamepass**: Players who own gamepass ID 1242040274 from the old game get faster roll animations
    - **AutoRoll**: Toggle button that continuously rolls crates. Green text when ON, red text when OFF. Can be stopped mid-roll, and the button remains visible during rolls for easy toggling.
    - **HideRolls**: Toggle button to hide/show the rolling animation. OFF (default, RGB 170,0,0) shows the rolling animation. ON (RGB 255,0,0) hides the frame while still awarding items. Speeds up auto-rolling when hidden.
-   **Admin Tools**: Whitelisted admin system with a GUI for creating, giving, and deleting items. Features include:
    - Create items with live item previews and auto-fill item names from Roblox marketplace
    - Give items to players (by User ID or username) with notifications for both admin and recipient
    - Delete items with confirmation dialog (double-click required), removes from all players' inventories with automatic cleanup for offline players
    - Global "New Item" notification system and console commands for database checks
-   **Data Persistence**: Utilizes Roblox DataStore Service for player inventories (with auto-stacking), rolls, cash, and inventory value. Auto-saves every 2 minutes. Includes a data version system to manage wipes and resets. Features automatic cleanup of deleted items when offline players rejoin.
-   **Inventory Display**: Shows owned items with thumbnails, rarity colors, and serial numbers. Displays stock item counts ("X / Y copies" using CurrentStock) and regular item counts ("X copies" using TotalCopies instead of unique owners). RareText appears only on items with less than 25 copies. Includes search/filter functionality and detailed item info on click.
-   **View Other Players' Inventories**: Players can hover over other players to see a yellow glow effect, then click to open a GUI showing that player's full inventory. Features structured error handling with retry logic for reliable data loading. Shows items sorted by value with accurate copy counts.
-   **Equipping Items**: Players can equip/unequip items from their inventory, which are then visible to all players. Uses Roblox asset IDs to load and attach items (accessories, hats, and tools) to the character, with equipped items persisting across sessions. Headless items are handled by setting head transparency instead of replacing the head mesh.
-   **Selling Items**: Players can sell regular items for 80% of their value. Features a confirmation step and options to sell single items or all copies of an item. Selling stock items is prevented. Cash is added to the player's wallet, and inventory value updates automatically.
-   **Index System**: Displays all items in the game database with detailed information. Shows item name, total owners, and value. For stock items, displays an owner list with player avatars, @usernames, and #serial numbers, sorted by serial number. Owner data persists in the database (SerialOwners array) so it works even when players are offline. The index automatically refreshes every 3 minutes when open, whenever manually opened, and when new items are created. Owner data is always fetched fresh from the server to ensure accuracy.

### UI/UX Decisions
-   Item names are color-coded by rarity in the crate animation.
-   Inventory displays thumbnails, rarity labels, and serial numbers.
-   Admin panel provides a graphical interface for item management.
-   Notification system provides feedback for admin actions and player interactions.

### Technical Implementations
-   All client-server communication uses `RemoteEvents` and `RemoteFunctions` within `ReplicatedStorage`.
-   Uses Roblox `InsertService` for equipping items to player characters.
-   Uses Roblox `MarketplaceService:UserOwnsGamePassAsync()` to check Fast Roll gamepass ownership from old game.
-   DataStore operations are handled with detailed error logging and validation.
-   Inventory value (`InvValue`) is automatically calculated and updated.

### File Structure (Key Directories)
-   `ReplicatedStorage/`: `ItemRarityModule.lua`
-   `ServerScriptService/`: `AdminConfig.lua`, `AdminItemHandler.lua`, `CratesServer.lua`, `DataStoreAPI.lua`, `DataStoreManager.lua`, `ItemDatabase.lua`, `PlayerDataHandler.lua`, `EquipSellHandler.lua`, `ServerShutdownHandler.lua`
-   `StarterGUI/`: `AdminGUI.lua`, `CratesClient.lua`, `InventorySystem.lua`, `IndexLocal.lua`, `ViewPlayerInventory.lua`

## External Dependencies
-   **Roblox DataStore Service**: Used for all persistent data storage, including player inventories, cash, cases opened, and the global item database.
-   **Roblox API Services**: Requires "Studio Access to API Services" to be enabled for DataStore functionality and leaderstats to work.
-   **Roblox InsertService**: Used for dynamically loading and attaching accessories/tools to player characters when items are equipped.
-   **Roblox MarketplaceService**: Used to check gamepass ownership for the Fast Roll feature (gamepass ID: 1242040274 from old game).
-   **Roblox MessagingService**: Used for cross-server notifications when ultra-rare items (5M+) are unboxed.

## Recent Updates (November 1, 2025)
-   **Hide Rolls Feature**: Added HideRolls toggle button in MainUI (next to Roll and AutoRoll buttons). When OFF (default, darker red RGB 170,0,0), the rolling animation is shown normally. When ON (brighter red RGB 255,0,0), the rolling frame is hidden but items are still awarded. Speeds up auto-rolling when hidden (0.5s delay vs 1.5s). Players can toggle visibility mid-roll for faster unboxing experience.
-   **View Player Inventory Fix**: Fixed issue where players could only view one person's inventory. Now properly resets search bar and highlight state when opening/closing, allowing unlimited consecutive player inventory views without requiring page refresh.
-   **TotalCopies Tracking System**: Changed from tracking unique owners to tracking total copies for regular items. Shows "X copies" instead of "X owners" in inventory and index. Stock items continue using CurrentStock. System automatically increments on roll/give and decrements on sell.
-   **View Other Players' Inventories**: Added hover detection with yellow glow effect on other players. Click to open a GUI showing their complete inventory with items sorted by value. Features robust error handling with retry logic (waits up to 1 second for data to load) and structured response pattern ({success, inventory/error}) for reliable cross-player viewing. Uses raycast-based detection with camera lifecycle handling for consistent hover/click detection even after respawns.
-   **Tool Equipping Fix**: Fixed tools not equipping properly - tools now correctly go to the player's Backpack instead of being placed in the character, allowing them to be used normally.
-   **Headless Support**: Simplified headless implementation - when a headless item is equipped, the player's head and face decal are set to transparency 1 (invisible). When unequipped, transparency is restored to 0. Works seamlessly with character respawns. Headless items are detected by name (contains "headless").
-   **AutoRoll Persistence**: AutoRoll state now persists across sessions and server shutdowns. When a player rejoins, AutoRoll automatically resumes if it was enabled. Server shutdowns automatically enable AutoRoll for all players, ensuring continuous rolling after reconnection.
-   **Equipped Item Visual Feedback**: Equipped items now display with an orange border in the inventory. Equipping or unequipping an item triggers an automatic inventory refresh to update sorting (equipped items first) and border colors.
-   **Improved Inventory Sorting**: Inventory refreshes automatically when items are equipped or unequipped, ensuring the sorting stays up-to-date with equipped items appearing first.
-   **Inventory Sorting**: Equipped items now appear first in inventory, followed by highest to lowest value items
-   **Clearer Labels**: Stock items show "X / Y copies", regular items show "X owners" for accurate tracking
-   **High-Value Chat Notifications**: When players unbox items worth 250k+ Robux, a colored chat message appears server-wide. 5M+ items announce to the entire server AND broadcast globally across all servers using MessagingService. Shows item name, value, serial # (for stock items), and color-coded by rarity. Global messages are prefixed with [GLOBAL].
-   **Auto-Rejoin on Server Shutdown**: Added TeleportService integration that automatically reconnects players to a new server when the current server shuts down for updates or restarts. Players no longer get kicked out.
-   **Balanced Roll Percentages**: Roll chances adjusted using power of 0.75 scaling for lower, more balanced distribution
-   **Rarity Indicator**: Inventory now shows RareText only for items with less than 25 copies in existence (works for both regular and stock items)
-   **Accurate Copy Count**: Both inventory and index now show CurrentStock (actual serials claimed) for stock items instead of unique owners
-   **Roll Percentage Display**: Index shows roll percentage with smart decimal handling - minimum 4 decimals or up to first non-zero digit (e.g., "Uncommon | 0.25%" or "Insane | 0.000004%")
-   **Admin Panel Preview**: When creating items, the admin panel now shows a live preview of rarity and roll percentage as you type the value in `info_preview`
-   **Delete Confirmation**: When deleting an item, `delete_name` now shows the item name for confirmation
-   **Fast Roll Gamepass**: Added support for fast roll gamepass (ID: 1242040274) that reduces roll time from 5 seconds to 2 seconds for owners
-   **AutoRoll Enhancement**: Changed autoroll to toggle button that no longer stops on player movement. Button stays visible during rolls with green (ON) and red (OFF) color coding
-   **Index Auto-Refresh**: Index now automatically refreshes every 3 minutes when open to show current owner counts and stock levels
-   **Index Bug Fix**: Fixed owners list showing old data - now always fetches fresh owner data from server and updates when index refreshes
-   **Leaderstats Update**: Renamed "Cases Opened" to "Rolls" and reordered leaderstats to: InvValue, Rolls, Cash
-   **Head Accessory Fix**: Fixed equipping system to properly handle head accessories (like headless) using Humanoid:AddAccessory() for all accessory types