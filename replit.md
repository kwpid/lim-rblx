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
-   **Item System**: Supports regular, "Limited", and "Vanity" rarity items. Regular items have stack limits (100 for common, no limit for Epic+), while Limited items are event-exclusive with stock or timer-based availability. Vanity items are exclusive to the Tix Shop and cannot be rolled, traded, or sold. **Vanity items do not contribute to player inventory value (InvValue)**. Body parts from Roblox bundles are stored as individual Vanity items with BundleId and BodyPartType metadata.
-   **Crate Opening**: Features weighted random selection, visual animations, camera shake effects (intensity scales with rarity), serial number display, "Fast Roll," "AutoRoll," and "HideRolls" options. High-value unboxes trigger server-wide notifications. Limited and Vanity items are not rollable via crates.
-   **Tix Shop System**: Hourly rotating shop featuring exclusive Vanity items purchasable with in-game cash. Shop displays 3-6 unique items per rotation (no duplicates) with weighted selection (higher value = rarer appearance). Features proximity prompt interaction, countdown timer, purchase confirmation UI, close button, success notifications, and server-wide rotation notifications. Admins can force manual shop rotation via ForceRefreshTixShopEvent. Vanity items cannot be traded or sold, only equipped and kept in inventory. **Bundle Support**: Supports item bundles (e.g., Korblox) configured manually with an ImageId (for thumbnail display) and BundleItems array (containing all item IDs included in the bundle). When purchased, players receive all items in the BundleItems array. Ownership is tracked by checking if all items are owned. This manual configuration approach avoids API fetching issues and provides full control over bundle contents.
-   **Luck System**: A three-tier system providing multiplicative luck multipliers for different rarity groups (Regular, Mythic, Insane) to boost Epic+ item probabilities.
-   **Event System**: Dynamic, modular system with automatic and manual triggers. Only one event can be active at a time. Examples include "Random Item Drops" and "Scavenger Hunt," utilizing actual Roblox item models with rarity-colored highlights.
-   **Barrel Event System**: Players can pull items from barrels for in-game currency. Features weighted RNG (including a rare chance for a Chroma Valkyrie), camera animations, item spawning, and transaction safety with refunds. Primarily for hat items.
-   **Admin Tools**: A whitelisted graphical interface for item management (create, edit, give, delete) with live previews, confirmation, and manual event triggering.
-   **Data Persistence**: Uses Roblox DataStore Service for player inventories, currency, rolls, value, settings, luck multipliers, trade history, and pending notifications. Includes auto-save, data versioning, and a debounced/batched save system. Features retry logic with exponential backoff for data load/save operations to prevent data loss. Pending notifications are stored in DataStore and delivered on login.
-   **Anti-AFK System**: Automatically rejoins inactive players after 15 minutes.
-   **Inventory Display**: Shows owned items with thumbnails, rarity colors, serial numbers, search/filter, detailed info, and "RareText"/"LimText" badges. Equipped items are prioritized.
-   **View Other Players' Inventories**: Allows inspection of other users' inventories via GUI.
-   **Equipping Items**: Players can equip/unequip accessories, hats, and tools that persist and are visible to others.
-   **Selling Items**: Regular items can be sold for 80% of their value; stock items and Vanity items cannot be sold.
-   **Index System**: Displays all game items with details, owner lists (including serial numbers), roll percentages, and "RareText"/"LimText." Vanity items are excluded from the Index display.
-   **Trading System**: Player-to-player trading with requests, stacked/serial item support, dual acceptance, item transfer (preserving serial numbers and ownership), and cancellation. Features real-time value tracking and persistent trade history. Vanity items are excluded from trading.
-   **Mastery System**: Tracks player progress across themed item collections with **persistent badge-based completion**. When a player completes a mastery (owns all items in a collection), they receive a Roblox badge. Badge ownership is the source of truth for completion - masteries stay completed forever even if items are lost/traded. Collections show CompletedFrame overlay and remain at 100% once badge is earned. Progress caps at 99% when all items owned but badge not confirmed (BadgeId=0 or award failure). Uses BadgeService for verification and awards. Collections are defined in `MasteryCollections.lua` with BadgeId fields.
-   **Marketplace System**: Player-driven economy allowing sale of high-value items (250k+ Robux value). Sellers can list items for in-game cash (1 to 1 billion range) or Robux via gamepass (30% tax). Features persistent listing storage, real-time validation, serial number preservation, buyer/seller notifications, and support for cancelling own listings. Players can purchase their own listings. **Gamepass Purchase Flow**: When buying a Robux listing, buyers are automatically prompted to purchase the required gamepass using Roblox's native purchase dialog. After successful purchase, the item transaction completes automatically with server-side ownership validation. **Studio Testing Mode**: Gamepass validation is automatically bypassed in Studio for testing with test players (Player1, Player2, etc.), while production games enforce full ownership validation. **Pending Cash & Notifications**: When items sell for cash, the money is saved to the seller's DataStore whether they're online or offline. When sellers log in, they receive all pending cash and a notification showing the total earned while offline. Robux sales work via gamepass ownership (handled by Roblox). Uses atomic UpdateAsync operations to prevent cash/notification loss during concurrent sales or player reconnections. Integrates with notification system and inventory management.
-   **Lock System**: Item protection system allowing players to lock individual items (including specific serial numbers) to prevent accidental selling. Features persistent lock state in DataStore (LockedItems array), Lock button in inventory popup with emoji indicators (🔒 locked, 🔓 unlocked), visual "Locked" indicator on inventory items, and complete sell protection across all selling mechanisms (regular sell, sell all, sell by rarity, and marketplace listings). Locked items are sorted at the top of inventory (right after equipped items) for easy identification. Inventory UI automatically refreshes when items are locked/unlocked via InventoryUpdatedEvent. Server-side validation ensures security.

### UI/UX Decisions
-   Item names are color-coded by rarity; Limited items use gold, Vanity items use hot pink (RGB 255, 105, 180).
-   Graphical admin panel.
-   Tix Shop UI with item display, countdown timer, and purchase confirmation dialog.
-   Notification system for trade requests.
-   Hover effects for viewing other players' inventories.
-   **Unified Tab System**: All main UI sections (Inventory, Index, Mastery, Marketplace, Trading) are consolidated into a single ScreenGUI with dedicated open buttons (InventoryOpen, IndexOpen, MasteryOpen, MarketplaceOpen, TradingOpen). The TabManager automatically ensures only one tab is visible at a time - opening a new tab closes any currently open tab. Managed by `TabManager.lua` in StarterGUI.
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
-   Roblox `InsertService` for equipping items, displaying models in events, and loading R6 body part meshes/textures for CharacterMesh objects.
-   Roblox `MarketplaceService` for gamepass checks, purchase prompting, and ownership validation.
-   Roblox `BadgeService` for mastery badge awards and ownership verification.
-   Roblox `MessagingService` for cross-server notifications.
-   Roblox `TeleportService` for auto-rejoin.
-   `Humanoid:AddAccessory()` for equipping accessories.

## External Dependencies
-   **Roblox DataStore Service**: Persistent data storage.
-   **Roblox API Services**: Requires "Studio Access to API Services" enabled.
-   **Roblox InsertService**: Loads and attaches accessories/tools, displays event items, and extracts mesh/texture data from R6 body part assets.
-   **Roblox MarketplaceService**: Checks gamepass ownership.
-   **Roblox MessagingService**: Cross-server notifications.
-   **Roblox TeleportService**: Handles automatic player rejoining.
-   **Discord Webhooks**: For new item releases, high-value drops, out-of-stock notifications, and marketplace sales.

### Discord Webhook Configuration
The game supports Discord webhooks for various events. Webhook URLs are configured in the `WebhookConfig.lua` module in ServerScriptService.

**Supported Webhooks:**
-   `ITEM_RELEASE_WEBHOOK`: Notifications when new items are added to the game
-   `ITEM_DROP_WEBHOOK`: Notifications for high-value unboxes and out-of-stock items
-   `MARKETPLACE_WEBHOOK`: Notifications when items are sold on the marketplace (cash or Robux)

**Setup Instructions:**
1. Open `ServerScriptService/WebhookConfig.lua` in Roblox Studio
2. Add your Discord webhook URLs to each field:
   ```lua
   local WebhookConfig = {
       ITEM_RELEASE_WEBHOOK = "https://discord.com/api/webhooks/...",
       ITEM_DROP_WEBHOOK = "https://discord.com/api/webhooks/...",
       MARKETPLACE_WEBHOOK = "https://discord.com/api/webhooks/..."
   }
   ```
3. Save the file
4. If you don't want to use webhooks, leave the URLs as empty strings ""

**⚠️ Security Note:**
- **Do NOT commit `WebhookConfig.lua` with real webhook URLs to public version control** (GitHub, etc.)
- Add `ServerScriptService/WebhookConfig.lua` to your `.gitignore` if using Git
- If a webhook URL is exposed, regenerate it in Discord immediately
- Roblox does not support environment variables, so WebhookConfig.lua is the standard approach for webhook management

**Marketplace Webhook Features:**
-   Shows buyer name and avatar
-   Shows seller username
-   Displays item details (name, rarity, serial number, value)
-   Shows sale price and type (cash or Robux)
-   Calculates and displays seller's actual payout (after 30% Robux tax)