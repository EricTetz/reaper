local targetEffect = 'Melodyne'
local removeUntunedTake = false
local removeMelodyneAfter = true -- otherwise just disable it
local tunedTakeSuffix = ' tuned' -- set to nil for no renaming
local tunedTakeColor = { 255, 255, 0 } -- {r,g,b}, or nil for no color

--[[
    Print tuning to selected media items. Made for Melodyne, but the target
    effect is configurable (see above) in case it's useful for something else.

    Why? There are circumstances where Reaper or ARA2 screws up and you can
    lose your tuning data (e.g. accidentally undo tuning, or delete a tuned
    item, then redo fails to restore tuning work).  By printing it, you save
    yourself from that heartache.

    This script will find all selected tracks containing an active Melodyne
    instance. It will disable all effects other than Melodyne on those tracks,
    print FX to selected media items on those track, restore all disabled
    effects, then disable or delete Melodyne.

    If removeUntunedTake is true, the untuned take will be removed from the media item.

    If removeMelodyneAfter is true, Melodyne is removed after printing, otherwise it's disabled.

    If tunedTakeSuffix is not nil, the printed take will have that suffix added to its name.

    If tunedTakeColor is not nil, the printed take will be set to that color.
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
function getSelectedItemsOnTunedTracks()
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
        local tunedTake = reaper.GetActiveTake(item)
        if tunedTakeSuffix then
            local newName = smartRename(take.name, tunedTakeSuffix)
            reaper.GetSetMediaItemTakeInfo_String(tunedTake, 'P_NAME', newName, true)
        end
        if tunedTakeColor then
            reaper.SetMediaItemTakeInfo_Value(tunedTake, 'I_CUSTOMCOLOR', reaper.ColorToNative(table.unpack(tunedTakeColor))|0x1000000)
        end
    end

    if removeUntunedTake then
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
    for track, items in pairs(getSelectedItemsOnTunedTracks()) do
        local disabledFX = setEnabledEffectsOffline(track)
        applyEffectsToSelectedTakesOnTrack(track, items,' - tuned')
        restoreDisabledEffects(track, disabledFX)
        local effectIndex = reaper.TrackFX_GetByName(track, targetEffect, false)
        if removeMelodyneAfter then
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
