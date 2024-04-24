-- @description Smart Rec-Arm
-- @author smandrap
-- @version 1.2
-- @changelog
--  + Warn if tracks are recording and using the action would unarm the currently recording tracks (yes, i'm THAT dumb)
-- @donation https://paypal.me/smandrap
-- @about
--   Makes the record arm workflow similar to Pro Tools/Cubase/Etc.

WARN_WHILE_RECORDING = true

if not reaper.CF_GetSWSVersion then
  reaper.MB("This script requires SWS Extensions. Download here: https://www.sws-extension.org/", "Missing Dependency", 0)
  return
end

local function CheckIfTracksRecording()
  if reaper.GetPlayState() ~= 5 then return true end
  
  local rec_arm_cnt = 0
  for i = 0, reaper.CountTracks(0) - 1 do
    if reaper.GetMediaTrackInfo_Value(reaper.GetTrack(0, i), 'I_RECARM') == 1 then
      rec_arm_cnt = rec_arm_cnt + 1
    end
  end
  
  if rec_arm_cnt == 0 then return true end
  
  local ok = reaper.MB("Some tracks are recording.\nProceed anyway?", "Disarming tracks",1) == 1 and true or false
  return ok
end

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
local ok = true
if WARN_WHILE_RECORDING then ok = CheckIfTracksRecording() end
if ok then main() end
reaper.Undo_EndBlock("Smart Rec Arm", 0)