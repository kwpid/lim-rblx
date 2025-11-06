# Serial Owner Not Updating on Trade - Bug Fix & Repair System

**Date:** November 6, 2025  
**Status:** ✅ FIXED + REPAIR TOOL ADDED  
**Severity:** Medium (Data Display Issue)

## Problem Description

When players traded serial items, the Index UI would continue to show the previous owner instead of the new owner, even after server shutdowns. For example, if Player A traded a #1 serial item to Player B, the Index would still display "@PlayerA" as the owner instead of "@PlayerB".

## Root Cause

In `ServerScriptService/DataStoreAPI.lua`, the `AddItem()` function had conditional logic that **skipped updating the serial owner** during trades:

```lua
-- BUGGY CODE (lines 40-48):
if not preserveSerialOwner then
  ItemDatabase:RecordSerialOwner(
    itemData.RobloxId,
    player.UserId,
    player.Name,
    itemData.SerialNumber
  )
end
```

When `preserveSerialOwner = true` (which happens during trades in `TradeServer.lua`), the system would:
- ✅ Add the serial item to the new owner's inventory
- ✅ Remove it from the previous owner's inventory
- ❌ **NOT** update the ItemDatabase.SerialOwners record

This caused the Index UI to display outdated ownership information.

## The Fix

**Changed:** `ServerScriptService/DataStoreAPI.lua` lines 40-49

**Before:**
```lua
-- Only record serial owner if this is NOT from a trade (preserve original owner during trades)
if not preserveSerialOwner then
  ItemDatabase:RecordSerialOwner(
    itemData.RobloxId,
    player.UserId,
    player.Name,
    itemData.SerialNumber
  )
end
```

**After:**
```lua
-- Always update serial owner to the current player (including during trades)
ItemDatabase:RecordSerialOwner(
  itemData.RobloxId,
  player.UserId,
  player.Name,
  itemData.SerialNumber
)
```

## Why This Works

The `preserveSerialOwner` flag was originally intended to prevent incrementing the global `Owners` count during trades (line 106 in DataStoreAPI). However, it was also incorrectly preventing the serial owner record from being updated.

The fix separates these two concerns:
- **Global Owner Count**: Still controlled by `preserveSerialOwner` flag (line 106) - correctly prevents inflation during trades
- **Serial Owner Record**: Now always updated when a serial item is added - correctly reflects current ownership

## Impact

✅ **After the fix:**
- Trading a serial item now updates the ItemDatabase.SerialOwners record
- The Index UI correctly displays the current owner's username
- Ownership data persists correctly across server shutdowns
- The global Owner count remains accurate (not inflated by trades)

## Testing Instructions

1. **Setup:**
   - Have two players (Player A and Player B) in the game
   - Player A should have a serial item (e.g., #1 of some item)

2. **Execute Trade:**
   - Player A trades the #1 serial item to Player B
   - Both players accept the trade

3. **Verify Fix:**
   - Open the Index UI
   - Click on the traded item
   - Check the owner list in the popup
   - **Expected Result:** The #1 serial should show "@PlayerB" as the owner (not @PlayerA)

4. **Verify Persistence:**
   - Shut down the server and restart
   - Open Index UI again
   - **Expected Result:** The #1 serial should still show "@PlayerB"

## Related Systems

- **TradeServer.lua**: Calls `DataStoreAPI:AddItem()` with `preserveSerialOwner = true` (lines 563-571, 573-582)
- **ItemDatabase.lua**: `RecordSerialOwner()` updates the SerialOwners array (lines 303-322)
- **IndexLocal.lua**: Displays serial owners from `GetItemOwnersFunction` (lines 397-427)

## Repair System for Existing Broken Records

### The Challenge
Items that were traded **before** the bug fix still have incorrect ownership records in the database. These can't be automatically fixed without intervention.

### The Solution: RepairSerialOwners() Command

**Added:** `ServerScriptService/ItemDatabase.lua` - New function `RepairAllSerialOwners()`

A new admin console command that repairs serial ownership records for currently online players:

```lua
RepairSerialOwners()
```

**How It Works:**
1. Scans all online player inventories (_G.PlayerData)
2. For each serial item found, updates the SerialOwners record
3. Uses the existing RecordSerialOwner() function which safely updates or creates records
4. Does NOT delete any existing records (safe to run multiple times)
5. Saves to DataStore and refreshes Index UI for all players

**Important Limitations:**
- ⚠️ Only repairs ownership for players currently in the server
- Players must be online for their ownership to be updated
- As players join, you can run the command again to update their items
- Offline players' incorrect records remain until they come online

**Usage Example:**
1. Open Roblox Studio server console
2. Wait for players with broken serial items to join
3. Run: `RepairSerialOwners()`
4. Console shows: `Updated: X serial ownership records`
5. All players' Index UI automatically refreshes
6. Run again as more players join to repair their items

**Safety:**
- ✅ Does not delete any data
- ✅ Safe to run multiple times
- ✅ Only updates records, never removes them
- ✅ Architect-reviewed and approved

## Code Review Status

✅ **Initial Bug Fix - Reviewed by Architect Agent**
- Fix confirmed correct
- No side effects identified
- Security: None observed
- Recommendation: Test trade flow in-game to verify Index UI updates

✅ **Repair System - Reviewed by Architect Agent**
- Safe implementation (no data loss)
- Only updates online player records
- Does not delete existing data
- Security: None observed
- Recommendation: Run during coordinated sessions when affected players are online

---

**Bug Reporter:** User  
**Fixed By:** Replit Agent  
**Verified:** Pending user testing in Roblox
