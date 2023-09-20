-- @description Smart Rec-Arm
-- @author smandrap
-- @version 1.0
-- @donation https://paypal.me/smandrap
-- @about
--   Makes the record arm workflow similar to Pro Tools/Cubase/Etc.


local function main()
  local sel_tracks_cnt = reaper.CountSelectedTracks(0)
  if sel_tracks_cnt == 0 then return end
  
  local rec_armed_count = 0
  
  for i = 0, sel_tracks_cnt - 1 do
    local current_rec_arm = reaper.GetMediaTrackInfo_Value(reaper.GetSelectedTrack(0, i), 'I_RECARM')
    if current_rec_arm == 1 then rec_armed_count = rec_armed_count + 1 end
  end
  
  if rec_armed_count == sel_tracks_cnt then 
    reaper.Main_OnCommand(reaper.NamedCommandLookup('_XENAKIOS_SELTRAX_RECUNARMED'), 0)
  else
    reaper.Main_OnCommand(40491, 0) -- UNARM ALL
    reaper.Main_OnCommand(reaper.NamedCommandLookup('_XENAKIOS_SELTRAX_RECARMED'), 0)
  end
  
  
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Smart Rec Arm", 0)
