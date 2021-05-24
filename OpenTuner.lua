local input = 0 -- which mono input to monitor (zero offset: 0 = first, 1 = second, ...)
local tuner = "ReaTune" -- name of tuner effect to use
local tunerTrackName = "tuner"

function findTunerTrack()
  for i=0,reaper.CountTracks(-1)-1 do
    local track = reaper.GetTrack(-1, i)
    local _, name = reaper.GetTrackName(track)
    if name == tunerTrackName then
      return track
    end
  end
end

function createTunerTrack()
  reaper.Main_OnCommandEx(40702, 0) -- add track at end of mixer
  reaper.Main_OnCommandEx(41593, 0) -- hide from TCP and mixer
  local track = reaper.GetTrack(-1, reaper.CountTracks()-1)
  reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', tunerTrackName, true)
  reaper.SetMediaTrackInfo_Value(track, "I_RECMON", 1) -- record monitoring enabled
  reaper.SetMediaTrackInfo_Value(track, "I_RECMODE", 2) -- record: disable (input monitoring only)
  reaper.SetMediaTrackInfo_Value(track, "B_MAINSEND", 0) -- disable master send
  reaper.SetMediaTrackInfo_Value(track, "I_RECINPUT", input) -- choose input channel
  reaper.TrackFX_AddByName(track, tuner, false, 1)
  return track
end

function toggleTunerTrack()
  local track = findTunerTrack()
  if track then
    if reaper.TrackFX_GetFloatingWindow(track, 0) then
       reaper.DeleteTrack(track)
       return
    end
    reaper.TrackFX_Show(track, 0, 3)
  else
    track = createTunerTrack()
    reaper.TrackFX_Show(track, 0, 3)
    reaper.SetCursorContext(0, null)
  end
  reaper.SetMediaTrackInfo_Value(track, "I_RECARM", 1) -- record arm
end

reaper.Undo_BeginBlock()
toggleTunerTrack()
reaper.Undo_EndBlock("Open tuner", 0)
