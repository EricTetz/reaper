-- @description Studio Fade Out
-- @author etetz
-- @version 1.0
-- @provides
--   [effect] StudioFadeOut.jsfx
-- @about
--   Port of Audacity's "Studio Fade Out" (by Steve Daulton).
--   Applies a raised-cosine gain curve combined with a sweeping
--   low-pass filter (Nyquist → 100 Hz) for a musical fade out
--   where high frequencies disappear before lows.
--
--   Select one or more media items, optionally set a time selection
--   within them, then run this script from the Actions menu.

local JSFX_NAME   = "StudioFadeOut"   -- matches the desc: line in the JSFX
local SCRIPT_NAME = "Studio Fade Out"

-----------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------

local function msg(text)
  reaper.ShowMessageBox(text, SCRIPT_NAME, 0)
end

--- Determine the fade region for an item.
--- Returns fade_start and fade_dur relative to the item's timeline position.
--- If a time selection overlaps the item, use the overlap.
--- Otherwise use the full item bounds.
local function get_fade_region(item)
  local item_start  = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_end    = item_start + item_length

  local ts_start, ts_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  local has_time_sel = (ts_end - ts_start) > 0.001

  if has_time_sel then
    -- Clamp time selection to item bounds
    local fade_start = math.max(ts_start, item_start)
    local fade_end   = math.min(ts_end,   item_end)
    if fade_end > fade_start then
      -- Return offset from item start and duration
      return fade_start - item_start, fade_end - fade_start
    end
  end

  -- No usable time selection → fade the whole item
  return 0, item_length
end

-----------------------------------------------------------------------
-- Main
-----------------------------------------------------------------------

local item_count = reaper.CountSelectedMediaItems(0)
if item_count == 0 then
  msg("No media items selected.")
  return
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local processed = 0

for i = 0, item_count - 1 do
  local item = reaper.GetSelectedMediaItem(0, i)
  local take = reaper.GetActiveTake(item)

  if take and not reaper.TakeIsMIDI(take) then
    local fade_offset, fade_dur = get_fade_region(item)

    if fade_dur < 0.001 then
      goto continue
    end

    -- Add the JSFX to the take's FX chain
    local fx_idx = reaper.TakeFX_AddByName(take, JSFX_NAME, -1)
    if fx_idx < 0 then
      msg("Could not load JSFX '" .. JSFX_NAME .. "'.\n\n"
        .. "Make sure StudioFadeOut.jsfx is in your REAPER Effects directory\n"
        .. "(Options → Show REAPER resource path → Effects).")
      goto cleanup
    end

    -- Set parameters: slider1 = fade_start offset, slider2 = fade_dur
    reaper.TakeFX_SetParam(take, fx_idx, 0, fade_offset)
    reaper.TakeFX_SetParam(take, fx_idx, 1, fade_dur)

    -- Save and restore selection around the glue
    local sel_items = {}
    for s = 0, reaper.CountSelectedMediaItems(0) - 1 do
      sel_items[#sel_items + 1] = reaper.GetSelectedMediaItem(0, s)
    end

    reaper.SelectAllMediaItems(0, false)
    reaper.SetMediaItemSelected(item, true)

    -- Glue the item — renders take FX into the audio destructively,
    -- preserving the source channel count (mono stays mono).
    reaper.Main_OnCommand(40362, 0)  -- Item: Glue items

    -- Restore selection
    reaper.SelectAllMediaItems(0, false)
    for _, sel_item in ipairs(sel_items) do
      if reaper.ValidatePtr(sel_item, "MediaItem*") then
        reaper.SetMediaItemSelected(sel_item, true)
      end
    end

    processed = processed + 1
  end

  ::continue::
end

::cleanup::

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock(SCRIPT_NAME, -1)

if processed > 0 then
  reaper.defer(function() end)  -- prevent "finished" dialog
end
