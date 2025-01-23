local targetEffect = 'Melodyne'
local removeSourceTake = false
local removeEffect = true -- otherwise just disable it
local printedTakeSuffix = ' tuned' -- set to nil for no renaming
local printedTakeColor = { 255, 255, 0 } -- {r,g,b}, or nil for no color

--[[
    Print an specific effect to selected media items. Made for Melodyne, but
    the target effect is configurable (see above) in case it's useful for something else.

    Why? There are several circumstances where Reaper/ARA2/you screw up and you can
    lose your tuning data. For instance, you can add Melodyne, tune for a half-hour,
    accidentally ctrl+z the Melodyne instance off the track, and it's all gone.
    Reflexively printing your work can save you from that heartache.

    This script will find all selected tracks containing an active instances of
    the target effect. It will disable all effects other than the target on
    those tracks, print FX to selected media items on those track, restore all
    disabled effects, then disable or delete the target effect.

    If removeSourceTake is true, the pre-fx take we just printed will be removed from the media item.

    If removeEffect is true, targetEffect is removed after printing, otherwise it's disabled.

    If printedTakeSuffix is not nil, the printed take will have that suffix added to its name.

    If printedTakeColor is not nil, the printed take will be set to that color.
]]

-- Append a suffix to a name to make a new name.
-- If suffix already exists, add (n) to make it new, e.g.:
--  |  name                |  suffix    |  result
--  |----------------------|------------|------------------
--  |  'Vox 1'             |  ' tuned'  |  'Vox 1 tuned'
--  |  'Vox 1 tuned'       |  ' tuned'  |  'Vox 1 tuned (2)'
--  |  'Vox 1 tuned (2)'   |  ' tuned'  |  'Vox 1 tuned (3)'
function smartRename(name, suffix)
    if type(suffix) ~= 'string' or suffix == '' then
        return name
    end
    local prefix, number = name:match('(.-) %((%d+)%)')
    if prefix and prefix:find(suffix..'$') then
        return string.format('%s (%d)', prefix, number+1)
    end
    if name:find(suffix..'$') then
        return string.format('%s (%d)', name, 2)
    end
    if beforeNumber and beforeNumber:find(suffix..'$') then
        return string.format('%s (%d)', beforeNumber, number+1)
    end
    return name..suffix
end

function hasEnabledEffect(track, effectName)
    local effectIndex = reaper.TrackFX_GetByName(track, effectName, false)
    return effectIndex ~= -1 and reaper.TrackFX_GetEnabled(track, effectIndex)
end

-- returns:  t[track] = { item, ... }
function getSelectedItemsOnTracksContainingTargetEffect()
    local mediaItemsByTrack = {}
    for i=0,reaper.CountSelectedMediaItems(0)-1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local track = reaper.GetMediaItemTrack(item)
        if hasEnabledEffect(track, targetEffect) then
            if not mediaItemsByTrack[track] then
                mediaItemsByTrack[track] = {}
            end
            table.insert(mediaItemsByTrack[track], item)
        end
    end
    return mediaItemsByTrack
end

-- Apply enabled effects to the selected take (as a new take)
-- then color new take (optional) and/or remove the old take (optional)
function applyEffectsToSelectedTakesOnTrack(track, items, newNameSuffix)
    -- remember currently active takes
    local activeTakesByMediaItem = {}
    for i,item in ipairs(items) do
        local take = reaper.GetActiveTake(item)
        local _, name = reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', '', false)
        activeTakesByMediaItem[item] = {name = name, take = take}
    end

    -- apply FX, which will add a new take to the end and select it
    reaper.Main_OnCommand(40361, 0) -- apply track fx to items, mono

    -- rename and/or color new takes
    for item, take in pairs(activeTakesByMediaItem) do
        local printedTake = reaper.GetActiveTake(item)
        if printedTakeSuffix then
            local newName = smartRename(take.name, printedTakeSuffix)
            reaper.GetSetMediaItemTakeInfo_String(printedTake, 'P_NAME', newName, true)
        end
        if printedTakeColor then
            reaper.SetMediaItemTakeInfo_Value(printedTake, 'I_CUSTOMCOLOR', reaper.ColorToNative(table.unpack(printedTakeColor))|0x1000000)
        end
    end

    if removeSourceTake then
        for item, take in pairs(activeTakesByMediaItem) do
            reaper.SetActiveTake(take.take)
        end
        reaper.Main_OnCommand(40129, 0) -- delete active take in items
    end
end

-- Disable all enabled FX but the target effect, remembering what we disabled.
-- Note: if bypass is automated for an effect, SetEnabled(false) WON'T WORK!
-- So we use SetOffline(true) instead. This is a little slower, but always works.
function setEnabledEffectsOffline(track)
    local disabledFX = {}
    for i=0,reaper.TrackFX_GetCount(track) do
        local _, name  = reaper.TrackFX_GetFXName(track, i, '')
        local isEnabled = reaper.TrackFX_GetEnabled(track, i)
        if isEnabled and not name:match(targetEffect) then
            reaper.TrackFX_SetOffline(track, i, true)
            disabledFX[i] = name
        end
    end
    return disabledFX
end

function restoreDisabledEffects(track, disabledFX)
    for i=0,reaper.TrackFX_GetCount(track) do
        if disabledFX[i] then
            reaper.TrackFX_SetOffline(track, i, false)
        end
    end
end

function main()
    for track, items in pairs(getSelectedItemsOnTracksContainingTargetEffect()) do
        local disabledFX = setEnabledEffectsOffline(track)
        applyEffectsToSelectedTakesOnTrack(track, items, printedTakeSuffix)
        restoreDisabledEffects(track, disabledFX)
        local effectIndex = reaper.TrackFX_GetByName(track, targetEffect, false)
        if removeEffect then
            reaper.TrackFX_Delete(track, effectIndex)
        else
            reaper.TrackFX_SetEnabled(track, effectIndex, false)
        end
    end
    reaper.UpdateArrange()
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock('Print '..targetEffect, 0)
