local scriptname = 'Create Sends'

if reaper.CountSelectedTracks(0) < 1 then
    reaper.ShowMessageBox('There are no selected tracks to send from.', scriptname, 0)
    return
end

::getinput::
local okClicked, value = reaper.GetUserInputs('Create sends', 1, 'Destination track #', 1);
if not okClicked then
    return
end

local trackNumber = tonumber(value)
if not trackNumber then
    reaper.ShowMessageBox('"'..value..'" is not a valid number.', scriptname, 0)
    goto getinput
end

if trackNumber  > reaper.CountTracks(0) then
    reaper.ShowMessageBox("There aren't that many tracks.", scriptname, 0)
    goto getinput
end

local receiveTrack = reaper.GetTrack(0, trackNumber-1)
reaper.Undo_BeginBlock()
for i=0,reaper.CountSelectedTracks(0)-1 do
    local sendTrack = reaper.GetSelectedTrack(0, i)
    reaper.CreateTrackSend(sendTrack, receiveTrack)
end
reaper.Undo_EndBlock(scriptname, 1)
