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
-   **Crate Opening**: Free rolls with weighted random selection. Includes visual scrolling animation with rarity-colored item names, serial number display for stock items, and a "continue" button after each roll. The roll animation only displays items that are currently available (excludes sold-out stock items). Features:
    - **Roll Time**: 5 seconds for normal players, 2 seconds for Fast Roll gamepass owners (2.5x faster)
    - **Fast Roll Gamepass**: Players who own gamepass ID 1242040274 from the old game get faster roll animations
    - **AutoRoll**: Toggle button that continuously rolls crates. Green text when ON, red text when OFF. Can be stopped mid-roll, and the button remains visible during rolls for easy toggling.
-   **Admin Tools**: Whitelisted admin system with a GUI for creating, giving, and deleting items. Features include:
    - Create items with live item previews and auto-fill item names from Roblox marketplace
    - Give items to players (by User ID or username) with notifications for both admin and recipient
    - Delete items with confirmation dialog (double-click required), removes from all players' inventories with automatic cleanup for offline players
    - Global "New Item" notification system and console commands for database checks
-   **Data Persistence**: Utilizes Roblox DataStore Service for player inventories (with auto-stacking), cases opened, cash, and inventory value. Auto-saves every 2 minutes. Includes a data version system to manage wipes and resets. Features automatic cleanup of deleted items when offline players rejoin.
-   **Inventory Display**: Shows owned items with thumbnails, rarity colors, and serial numbers. Displays stock item counts ("copies: X / Y exist") and regular item counts ("copies: X"). Includes search/filter functionality and detailed item info on click.
-   **Equipping Items**: Players can equip/unequip items from their inventory, which are then visible to all players. Uses Roblox asset IDs to load and attach items (accessories, hats, tools) to the character, with equipped items persisting across sessions.
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
-   `ServerScriptService/`: `AdminConfig.lua`, `AdminItemHandler.lua`, `CratesServer.lua`, `DataStoreAPI.lua`, `DataStoreManager.lua`, `ItemDatabase.lua`, `PlayerDataHandler.lua`, `EquipSellHandler.lua`
-   `StarterGUI/`: `AdminGUI.lua`, `CratesClient.lua`, `InventorySystem.lua`, `IndexLocal.lua`

## External Dependencies
-   **Roblox DataStore Service**: Used for all persistent data storage, including player inventories, cash, cases opened, and the global item database.
-   **Roblox API Services**: Requires "Studio Access to API Services" to be enabled for DataStore functionality and leaderstats to work.
-   **Roblox InsertService**: Used for dynamically loading and attaching accessories/tools to player characters when items are equipped.
-   **Roblox MarketplaceService**: Used to check gamepass ownership for the Fast Roll feature (gamepass ID: 1242040274 from old game).

## Recent Updates (October 31, 2025)
-   **Fast Roll Gamepass**: Added support for fast roll gamepass (ID: 1242040274) that reduces roll time from 5 seconds to 2 seconds for owners
-   **AutoRoll Enhancement**: Changed autoroll to toggle button that no longer stops on player movement. Button stays visible during rolls with green (ON) and red (OFF) color coding
-   **Index Auto-Refresh**: Index now automatically refreshes every 3 minutes when open to show current owner counts and stock levels
-   **Index Bug Fix**: Fixed owners list showing old data - now always fetches fresh owner data from server and updates when index refreshes