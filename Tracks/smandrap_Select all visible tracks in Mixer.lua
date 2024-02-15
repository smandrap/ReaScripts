-- @description Select all visible tracks in Mixer
-- @author smandrap
-- @version 1.0
-- @donation https://paypal.me/smandrap
-- @about
--  Does what it says.

reaper.Undo_BeginBlock()
reaper.Main_OnCommand(40297, 0) -- Unselect All

for i = 0, reaper.CountTracks(-1) - 1 do
  local t = reaper.GetTrack(-1, i)
  if reaper.IsTrackVisible(t, true) and reaper.GetMediaTrackInfo_Value(t, 'I_MCPW') > 0 then 
    reaper.SetTrackSelected(t, true) 
  end
end

reaper.Undo_EndBlock("Select All visible tracks in Mixer", 0)
