function OpenEffect(effectName, effectType)
    local track = reaper.GetSelectedTrack(0,0)
    if not track then
        return
    end

    local effectIndex = reaper.TrackFX_GetByName(track, effectName, false)
    if effectIndex ~= -1 then
        reaper.TrackFX_SetEnabled(track, effectIndex, true)
    else
        reaper.TrackFX_AddByName(track, effectType..":"..effectName, false, 1)
        effectIndex = reaper.TrackFX_GetByName(track, effectName, false)
    end
    reaper.TrackFX_Show(track, effectIndex, 3)
end

OpenEffect("Melodyne", "VST3")
