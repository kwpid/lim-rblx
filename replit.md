# Project Memory

## Overview
This project is a Roblox crate opening/unboxing game designed to provide an engaging unboxing experience. Players can open virtual crates to acquire items of varying rarities and values, managed by a weighted probability system. Key features include a player-to-player trading system, comprehensive admin tools for item management, robust data persistence, an interactive inventory, Discord webhook notifications, and the ability to equip virtual goods. The project aims to offer a feature-rich and dynamic virtual economy within Roblox.

## Recent Changes
**November 6, 2025 - Serial Owner Repair System:**
- **NEW FEATURE**: Added RepairSerialOwners() console command to fix serial item ownership records
- **Purpose**: Repairs ownership data for items that were traded before the bug fix
- **How It Works**: Scans online player inventories and updates SerialOwners in ItemDatabase to match current ownership
- **Safety**: Does not delete existing records, only updates them - safe to run multiple times
- **Limitation**: Only repairs ownership for players currently in the server (works as players join)
- **Usage**: Run `RepairSerialOwners()` in server console when affected players are online
- **Output**: Shows count of serial ownership records updated
- **Auto-Refresh**: Automatically refreshes Index UI for all players after repair completes

**November 6, 2025 - Serial Owner Not Updating on Trade Bug Fix:**
- **BUG FIX**: Serial item ownership now properly updates in Index UI after trades
- **Root Cause**: DataStoreAPI was skipping RecordSerialOwner() call when `preserveSerialOwner=true` during trades
- **Solution**: Always call RecordSerialOwner() for serial items, regardless of trade flag
- **Behavior**: When a serial item is traded, the Index now correctly shows the new owner's username
- **Impact**: Index UI owner list now accurately reflects current serial item owners after trades and server shutdowns

**November 6, 2025 - Critical Data Loss Bug Fix:**
- **CRITICAL FIX**: Fixed data loss bug where players would lose their data when joining
- **Root Cause**: DataStore errors (Studio API access disabled, temporary outages) were immediately returning empty data
- **Solution**: Added retry logic with 3 attempts and exponential backoff (1s, 2s, 3s delays)
- **Load Protection**: System now retries failed loads before falling back to default data
- **Save Protection**: Added retry logic to save operations to prevent data loss on server issues
- **Better Warnings**: Clear console messages when data operations fail, including attempt counts
- **Studio-Specific**: Data loss was most common in Studio when API access wasn't enabled

**November 6, 2025 - Trade Total Owners Bug Fix:**
- **BUG FIX**: Total Owners no longer incremented during player-to-player trades
- **Root Cause**: AddItem() was incrementing owners even when `preserveSerialOwner=true` (trade flag)
- **Solution**: Skip IncrementOwners() when items are transferred via trade
- **Behavior**: Total Owners only increases when items are FIRST obtained (crates, barrels, admin gifts)
- **Trade Logic**: Trades now properly TRANSFER ownership without creating new owners

**November 6, 2025 - Barrel Event Out-of-Stock Prevention:**
- **IMPROVEMENT**: Out-of-stock items now completely excluded from barrel event pool
- **Prevention Points**: Filtered at getAllRollableItems(), pickWeightedItem(), and createEventPool()
- **Stock Check**: Items with Stock > 0 and CurrentStock >= Stock are skipped
- **Chroma Valk**: Special check ensures sold-out Chroma Valk can't be pulled
- **Refund Safety**: Refund logic remains as backup, but should never be needed now

**November 6, 2025 - Barrel Event Multi-Player Pull Fix:**
- **BUG FIX**: Fixed barrel event so multiple players can pull simultaneously
- **Root Cause**: Code was disabling ALL proximity prompts globally when any player pulled
- **Solution**: Removed global prompt disabling since pulls are client-side (each player sees their own)
- **Per-Player Prevention**: Still prevents individual players from pulling multiple times simultaneously
- **Performance**: Multiple players can now interact with barrels at the same time without blocking

**November 6, 2025 - Barrel Event Chat Messages & Webhooks:**
- **Chat Notifications**: Barrel pulls now send colored chat messages (like crate system)
  - Local chat for 250k+ Robux items
  - Cross-server [GLOBAL] announcements for 5M+ Robux items (especially Chroma Valk!)
  - Shows player name, item name, serial number, and formatted value
- **Discord Webhooks**: High-value barrel pulls (250k+) now send Discord notifications
  - Labeled as "Barrel Pull" source to distinguish from crates and events
  - Shows player avatar, item image, value, and serial number

**November 6, 2025 - Barrel Event Complete Overhaul:**
- **CRITICAL FIX**: Removed slow MarketplaceService API calls that were causing 30+ second delays
- **Fast Pooling**: Now uses getAllRollableItems() which filters directly from ItemDatabase (instant)
- **Instant Barrel Visibility**: Barrels now appear immediately when event starts (before pooling)
- **Reduced Pool Size**: Changed from 50 to 25 items as requested for faster pooling
- **Function Order Fix**: Fixed Lua function order issue that was causing pool creation to fail silently
- **Event Duration Fixed**: Event now properly runs for full 10 minutes instead of ending immediately
- **Real Item Models**: Barrels now display actual item models using InsertService instead of colored boxes
- **Smart Model Detection**: Properly handles Accessories, Hats, Models, and BaseParts with fallback for failures
- **Performance**: Event startup now takes <1 second instead of 30+ seconds
- **QoL: Always Visible Barrels**: Barrels remain visible at all times, only GUI and prompts toggle based on event state
- **QoL: BillboardGui Toggle**: GUI_Stand.BillboardGui properly enabled during events, disabled when inactive
- **QoL: No Line of Sight**: Proximity prompts no longer require line of sight for better interaction
- **Code Cleanup**: Removed all debug print statements from barrel event system for cleaner console output

**November 5, 2025 - Barrel Event Pool & Animation Fix:**
- **Event Pool System**: Pre-selects 50 random weighted items when event starts (eliminates slow MarketplaceService calls during pulls)
- **Chroma Valkyrie**: Always included in the pool regardless of random selection
- **Instant Animation**: Camera and animation start immediately when prompt is activated (0.1s replication wait)
- **Fixed Animation**: Properly creates colored neon part with correct rarity before starting animation
- **Player Hiding**: Both own player and other players hidden during barrel pull
- **Item Timing**: Item stays in barrel for 1 second before floating out
- **Camera Shake**: Rarity-based shake effects (Common: 0.05 → Insane: 1.2) with smooth fade-out oscillation
- **Notification Style**: EVENT_COLLECT type matching item rain event format
- **Synchronized Timing**: 6 seconds total (1s hold + 2s float + 1.5s shake + 1.5s wait)

**November 5, 2025 - Barrel Event System Complete Fix:**
- Fixed barrel visibility: Barrels and decorations now properly hidden when event is inactive
- Made cam, spawn, and final parts always transparent (even during active events)
- Added GUI_Stand billboard GUI toggle: disabled when event inactive, enabled when active
- Implemented client-side barrel pulls allowing multiple players to pull simultaneously
- Added player hiding system during pull animations (other players hidden, then restored after pull)
- Added pull prevention while already pulling (both client and server-side checks)
- Fixed InsertService asset loading (server-side only, client receives replicated model)
- Fixed Accessory/Hat handling: explicit Handle detection and positioning for all item types
- Fixed ItemRarityModule colon syntax error (was using dot instead of colon)
- Added proximity prompt hiding during pulls (prevents pulling from multiple barrels)
- Added comprehensive error recovery: camera always restores even on animation errors
- Fixed particle effect restoration (properly saves and restores original Enabled states)

## User Preferences
- User will test the game in Roblox and provide feedback
- Agent cannot test in Roblox, so user is responsible for testing
- Iterative development: User tests → Reports bugs/requests → Agent implements → Repeat
- User wants a living documentation file that tracks game details

## System Architecture

### Core Game Systems
-   **Item System**: Supports regular items across eight rarity tiers with weighted probability drops, plus a special "Limited" rarity for event-exclusive items. Regular items have a max stack limit of 100 copies; excess are sold at 80% value. Epic+ items have no stack limit. Limited items can have either stock-based or timer-based availability (OffsaleAt field).
-   **Crate Opening**: Features weighted random selection, visual scrolling animations, serial number display for stock items, and options for "Fast Roll," "AutoRoll," and "HideRolls." High-value unboxes trigger server-wide notifications. Limited items are NOT rollable through crates; they're only obtainable through special events.
-   **Luck System**: A three-tier system allowing separate, multiplicatively stacking luck multipliers for different rarity groups (Regular, Mythic, Insane) to boost Epic+ item probabilities.
-   **Event System**: Dynamic, modular system with automatic spawning (5-10 minute intervals) and manual admin triggers. Only one event can be active at a time. Events include "Random Item Drops" and "Scavenger Hunt." Events use actual Roblox item models with rarity-colored highlights and proximity prompts.
-   **Barrel Event System**: Players can pull items from barrels in Workspace.Barrels for 5,000 Cash. Features weighted RNG (0.5% chance for Chroma Valkyrie, mostly commons-rares, rare epics), camera animation switching, item spawning with floating/spinning effects, and full transaction safety with cash refunds on failures. Only hat items can be pulled (no tools or faces). Includes stock rollback and refund verification.
-   **Admin Tools**: A whitelisted graphical interface for creating, editing, giving, and deleting items with live previews and confirmation dialogs. Admins can manually trigger events.
-   **Data Persistence**: Utilizes Roblox DataStore Service for player inventories, rolls, cash, inventory value, AutoRoll/HideRolls state, Luck multipliers, and trade history. Features auto-save, data versioning, and a debounced/batched save system.
-   **Anti-AFK System**: Automatically rejoins players inactive for 15 minutes.
-   **Inventory Display**: Shows owned items with thumbnails, rarity colors, serial numbers, search/filter, and detailed info, including "RareText" and "LimText" badges. Equipped items are prioritized.
-   **View Other Players' Inventories**: Allows inspection of other users' inventories via GUI.
-   **Equipping Items**: Players can equip/unequip accessories, hats, and tools that persist across sessions and are visible to others.
-   **Selling Items**: Players can sell regular items for 80% of their value; stock items cannot be sold.
-   **Index System**: Displays all game items with details, owner lists (including serial numbers), roll percentages (or "Not Rollable" for Limited items), and "RareText"/"LimText."
-   **Trading System**: Player-to-player trading with trade requests, stacked/serial item support, dual acceptance, item transfer (preserving serial numbers and ownership), and cancellation features. Max 8 items per player per trade with a 0.5s confirmation delay. Features real-time value tracking and persistent trade history (last 50 trades) with full details.

### UI/UX Decisions
-   Item names are color-coded by rarity in animations and inventory. Limited items use gold color (RGB 255, 215, 0).
-   Graphical admin panel.
-   Notification system for trade requests, acceptances, and rejections.
-   Hover effects for viewing other players' inventories.
-   Unified MainUI system combines Inventory and Index.
-   Smooth slide-in/out animations for popups.
-   UIStroke colors indicate AutoRoll and HideRolls button states.
-   Event status displayed in the MainUI.
-   Trade offers display item images with QtySerial text for stacked/serial items. Inventory items show "x0/5" format; offer slots show "x2." Serial items display "#1."
-   Real-time value displays update dynamically during trading.
-   Trade history interface shows past trades with player avatars and details.
-   Accept button dynamically changes text to "Accepted" during trades.

### Technical Implementations
-   `RemoteEvents` and `RemoteFunctions` for client-server communication.
-   Asynchronous ItemDatabase loading.
-   Debounced DataStore saves with a 3-second debounce.
-   SerialOwner repair system.
-   `HideRolls` system for crate opening GUI.
-   Roblox `InsertService` for equipping items.
-   Roblox `MarketplaceService` for gamepass checks.
-   Roblox `MessagingService` for cross-server notifications.
-   Roblox `TeleportService` for auto-rejoin.
-   `Humanoid:AddAccessory()` for equipping accessories.

## External Dependencies
-   **Roblox DataStore Service**: Persistent data storage.
-   **Roblox API Services**: Requires "Studio Access to API Services" enabled.
-   **Roblox InsertService**: Loads and attaches accessories/tools.
-   **Roblox MarketplaceService**: Checks gamepass ownership.
-   **Roblox MessagingService**: Cross-server notifications.
-   **Roblox TeleportService**: Handles automatic player rejoining.
-   **Discord Webhooks**: For new item releases, high-value drops, and out-of-stock notifications.