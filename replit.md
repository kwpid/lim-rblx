# Project Memory

## Overview
This project is a Roblox crate opening/unboxing game simulating a virtual economy. It allows players to unbox items of varying rarities, trade with others, and manage their inventory. Key features include a weighted probability system for item drops, player-to-player trading, comprehensive admin tools, robust data persistence, an interactive inventory, Discord webhook notifications, and a mastery/collection tracking system. The game aims to provide a dynamic and engaging experience within Roblox, focusing on item acquisition, trading, and collection.

## User Preferences
- User will test the game in Roblox and provide feedback
- Agent cannot test in Roblox, so user is responsible for testing
- Iterative development: User tests → Reports bugs/requests → Agent implements → Repeat
- User wants a living documentation file that tracks game details

## System Architecture

### Core Game Systems
-   **Item System**: Supports regular and "Limited" rarity items. Regular items have stack limits (100 for common, no limit for Epic+), while Limited items are event-exclusive with stock or timer-based availability.
-   **Crate Opening**: Features weighted random selection, visual animations, serial number display, "Fast Roll," "AutoRoll," and "HideRolls" options. High-value unboxes trigger server-wide notifications. Limited items are not rollable via crates.
-   **Luck System**: A three-tier system providing multiplicative luck multipliers for different rarity groups (Regular, Mythic, Insane) to boost Epic+ item probabilities.
-   **Event System**: Dynamic, modular system with automatic and manual triggers. Only one event can be active at a time. Examples include "Random Item Drops" and "Scavenger Hunt," utilizing actual Roblox item models with rarity-colored highlights.
-   **Barrel Event System**: Players can pull items from barrels for in-game currency. Features weighted RNG (including a rare chance for a Chroma Valkyrie), camera animations, item spawning, and transaction safety with refunds. Primarily for hat items.
-   **Admin Tools**: A whitelisted graphical interface for item management (create, edit, give, delete) with live previews, confirmation, and manual event triggering.
-   **Data Persistence**: Uses Roblox DataStore Service for player inventories, currency, rolls, value, settings, luck multipliers, trade history, and pending notifications. Includes auto-save, data versioning, and a debounced/batched save system. Features retry logic with exponential backoff for data load/save operations to prevent data loss. Pending notifications are stored in DataStore and delivered on login.
-   **Anti-AFK System**: Automatically rejoins inactive players after 15 minutes.
-   **Inventory Display**: Shows owned items with thumbnails, rarity colors, serial numbers, search/filter, detailed info, and "RareText"/"LimText" badges. Equipped items are prioritized.
-   **View Other Players' Inventories**: Allows inspection of other users' inventories via GUI.
-   **Equipping Items**: Players can equip/unequip accessories, hats, and tools that persist and are visible to others.
-   **Selling Items**: Regular items can be sold for 80% of their value; stock items cannot.
-   **Index System**: Displays all game items with details, owner lists (including serial numbers), roll percentages, and "RareText"/"LimText."
-   **Trading System**: Player-to-player trading with requests, stacked/serial item support, dual acceptance, item transfer (preserving serial numbers and ownership), and cancellation. Features real-time value tracking and persistent trade history.
-   **Mastery System**: Tracks player progress across themed item collections. Displays completion percentages, locked/unlocked items, and roll chances. Collections are defined in `MasteryCollections.lua`.
-   **Marketplace System**: Player-driven economy allowing sale of high-value items (250k+ Robux value). Sellers can list items for in-game cash (1 to 1 billion range) or Robux via gamepass (30% tax). Features persistent listing storage, real-time validation, serial number preservation, buyer/seller notifications, and support for cancelling own listings. Players can purchase their own listings. **Gamepass Purchase Flow**: When buying a Robux listing, buyers are automatically prompted to purchase the required gamepass using Roblox's native purchase dialog. After successful purchase, the item transaction completes automatically with server-side ownership validation. **Studio Testing Mode**: Gamepass validation is automatically bypassed in Studio for testing with test players (Player1, Player2, etc.), while production games enforce full ownership validation. **Pending Notifications**: Notifications for sold items are saved to DataStore for offline sellers and delivered when they log in. Uses atomic UpdateAsync operations to prevent notification loss during concurrent sales or player reconnections. Integrates with notification system and inventory management.

### UI/UX Decisions
-   Item names are color-coded by rarity; Limited items use gold.
-   Graphical admin panel.
-   Notification system for trade requests.
-   Hover effects for viewing other players' inventories.
-   Unified MainUI for Inventory and Index.
-   Smooth slide-in/out animations for popups.
-   UIStroke colors indicate button states (AutoRoll, HideRolls).
-   Event status displayed in MainUI.
-   Trade offers display item images with quantity/serial text.
-   Real-time value updates during trading.
-   Trade history interface with player avatars and details.

### Technical Implementations
-   `RemoteEvents` and `RemoteFunctions` for client-server communication.
-   Asynchronous ItemDatabase loading.
-   Debounced DataStore saves.
-   Roblox `InsertService` for equipping items and displaying models in events.
-   Roblox `MarketplaceService` for gamepass checks, purchase prompting, and ownership validation.
-   Roblox `MessagingService` for cross-server notifications.
-   Roblox `TeleportService` for auto-rejoin.
-   `Humanoid:AddAccessory()` for equipping accessories.

## External Dependencies
-   **Roblox DataStore Service**: Persistent data storage.
-   **Roblox API Services**: Requires "Studio Access to API Services" enabled.
-   **Roblox InsertService**: Loads and attaches accessories/tools, and displays event items.
-   **Roblox MarketplaceService**: Checks gamepass ownership.
-   **Roblox MessagingService**: Cross-server notifications.
-   **Roblox TeleportService**: Handles automatic player rejoining.
-   **Discord Webhooks**: For new item releases, high-value drops, and out-of-stock notifications.