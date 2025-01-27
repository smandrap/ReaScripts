-- @description Create AUX track from selected tracks
-- @author smandrap
-- @version 1.0
-- @donation https://paypal.me/smandrap
-- @about
--   Creates a track and add sends from all selected tracks to the new track.

local AUX_NAME = "AUX"

local sel_tr_cnt = reaper.CountSelectedTracks(0)
if sel_tr_cnt == 0  then return end


reaper.Undo_BeginBlock()

local function CreateAuxTrack()
  local first_tr = reaper.GetSelectedTrack(0, 0)
  local first_idx = reaper.GetMediaTrackInfo_Value(first_tr, 'IP_TRACKNUMBER') - 1
  reaper.InsertTrackInProject(0, first_idx, 1)
  local aux_track = reaper.GetTrack(0, first_idx)
  reaper.GetSetMediaTrackInfo_String(aux_track, 'P_NAME', AUX_NAME, true)
  return aux_track
end


local aux_track = CreateAuxTrack()

for i = 0, reaper.CountSelectedTracks(0, i) do
  reaper.CreateTrackSend(reaper.GetTrack(0, i), aux_track)
end

reaper.Undo_EndBlock("Create AUX from selected tracks", 0)
