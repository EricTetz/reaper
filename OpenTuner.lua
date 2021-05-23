local input = 0 -- which mono input to monitor (zero offset: 0 = first, 1 = second, ...)
local tuner = "ReaTune" -- name of tuner effect to use
local muteWhenTuning = false -- auto mute other tracks until tuner is closed
local windowSize = 30 -- TODO: set "window size" parameter; only applies if using ReaTune
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
  if tuner == "ReaTune" then
    
  end
  return track
end

function exclusiveSoloTunerTrack(tunerTrack)
  local savedSoloStates = {}
  for t=0,reaper.CountTracks(0)-1 do
    local track = reaper.GetTrack(0,t)
    savedSoloStates[track] = reaper.GetMediaTrackInfo_Value(track, "I_SOLO")
    reaper.SetMediaTrackInfo_Value(track, "I_SOLO", track == tunerTrack and 1 or 0)
  end
  return savedSoloStates
end

function restoreSoloStates(states)
  for track, state in pairs(states) do
    reaper.SetMediaTrackInfo_Value(track, "I_SOLO", state);
  end
end

function monitorTunerWindow(tunerTrack)
  local savedSoloStates = exclusiveSoloTunerTrack(tunerTrack)
  local function monitor()
      local window = reaper.TrackFX_GetFloatingWindow(tunerTrack, 0)
      if window then
        reaper.runloop(monitor)
      else
        restoreSoloStates(savedSoloStates);
      end
    end
  reaper.runloop(monitor)
end

function showTunerTrack()
  local track = findTunerTrack() or createTunerTrack()
  reaper.SetMediaTrackInfo_Value(track, "I_RECARM", 1) -- record arm
  reaper.TrackFX_Show(track, 0, 3)
  if muteWhenTuning then
    monitorTunerWindow(track)
  end
end

reaper.Undo_BeginBlock()
showTunerTrack()
reaper.Undo_EndBlock("Open tuner", 0)
