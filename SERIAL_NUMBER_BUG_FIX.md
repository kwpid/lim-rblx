# Serial Number Skipping Bug - FIXED

## The Problem

Serial numbers were being skipped when event items weren't collected. For example:
- You rolled #1 Fedora (1/10)
- Later CurrentStock shows 2/10, but owner list only shows you with #1
- Event gave you #3, and #2 is permanently missing

## Root Cause

The bug was in **ServerScriptService/Events/RandomItemDrops.lua**:

1. **Event spawns item** → `IncrementStock()` called immediately, claiming serial #2
2. **Item drops in world** → Physical item spawned with serial #2
3. **Item despawns** → Nobody picked it up before the lifetime expired (60 seconds)
4. **Serial #2 lost forever** → CurrentStock = 2, but no owner recorded for serial #2!

### The Core Issue:
Serial numbers were claimed at **drop creation** instead of at **collection**. When items despawned uncollected, the serial number was wasted - CurrentStock incremented but `RecordSerialOwner` never called.

## The Fix

**Changed the flow:**

### Before (BROKEN):
```lua
-- When event creates drop:
1. IncrementStock() → Claims serial #2
2. Spawn item in world with serial #2
3. If nobody collects → Serial #2 lost forever
```

### After (FIXED):
```lua
-- When event creates drop:
1. Store IsStockItem flag (don't claim serial yet)
2. Spawn item in world
3. If nobody collects → No serial was claimed, no waste!

-- When player collects item:
1. IncrementStock() → Claims next available serial
2. RecordSerialOwner() → Links player to that serial
3. AddItem() → Adds to inventory
```

## Changes Made

### File: ServerScriptService/Events/RandomItemDrops.lua

**1. Drop Creation (lines 453-472):**
- ✅ Removed IncrementStock call from drop creation
- ✅ Added `IsStockItem` flag to itemData
- ✅ Serial numbers no longer claimed when item spawns

**2. Item Collection (lines 331-372):**
- ✅ Added serial claiming logic in `handleItemCollection()`
- ✅ IncrementStock() only called when player actually collects
- ✅ Added sellout protection (if stock sells out between drop and pickup)
- ✅ Player gets notification if item sold out before they could collect

## Benefits

✅ **No More Skipped Serials** - Every serial number corresponds to an actual owner
✅ **No Wasted Serials** - Uncollected items don't waste serial numbers
✅ **Better User Experience** - Players notified if an item sells out before collection
✅ **Cleaner Owner Lists** - Every serial #1-10 has an owner, no gaps

## Edge Cases Handled

1. **Stock sells out between drop and collection:**
   - Player gets notification: "Item sold out before you could collect it!"
   - No serial is claimed or wasted

2. **Multiple players try to collect same stock item:**
   - First player gets the next available serial
   - Other players see regular behavior (item already collected)

3. **Item despawns uncollected:**
   - No serial claimed, no CurrentStock increment
   - Next collected item gets the correct sequential serial

## Testing Recommendations

1. **Test Normal Collection:**
   - Spawn event with stock items
   - Collect all items
   - Verify serials are sequential (#1, #2, #3, etc.)

2. **Test Uncollected Items:**
   - Spawn event with stock items
   - Let some items despawn without collecting
   - Verify CurrentStock doesn't increment for uncollected items

3. **Test Sellout Between Drop and Pickup:**
   - Spawn event with stock item that's nearly sold out
   - Have multiple players roll the item to sell it out
   - Try to collect the event drop
   - Verify player gets sellout notification

4. **Test Owner List:**
   - After collecting several stock items from events
   - Check the owner list in Index
   - Verify no gaps in serial numbers (no missing #2, #3, etc.)

## Files Modified

- `ServerScriptService/Events/RandomItemDrops.lua` - Fixed serial claiming logic

## Related Systems

- `ServerScriptService/CratesServer.lua` - Uses IncrementStock correctly (at roll time)
- `ServerScriptService/AdminItemHandler.lua` - Uses IncrementStock correctly (at give time)
- `ServerScriptService/DataStoreAPI.lua` - RecordSerialOwner tracks ownership
- `ServerScriptService/ItemDatabase.lua` - IncrementStock manages CurrentStock counter
