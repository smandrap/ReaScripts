-- @description Track lanes: Delete lanes (including media items) that are playing
-- @author smandrap
-- @version 1.0
-- @donation https://paypal.me/smandrap
-- @about
--   https://forum.cockos.com/showthread.php?p=2889040


local r = reaper

local sel_tr_cnt = r.CountSelectedTracks(0)
if sel_tr_cnt == 0 then return end

local function DeleteActiveLanes(track)
  local numlanes = r.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")
  if numlanes == 1 then
    if r.GetMediaTrackInfo_Value(track, "C_LANEPLAYS:0") > 0 then
      for i = r.CountTrackMediaItems(track) - 1, 0, -1 do
        r.DeleteTrackMediaItem(track, r.GetTrackMediaItem(track, i))
      end
    end
    return
  end

  for i = 0, numlanes - 1 do
    local laneplays = r.GetMediaTrackInfo_Value(track, "C_LANEPLAYS:" .. i)
    r.SetMediaTrackInfo_Value(track, "C_LANEPLAYS:" .. i, laneplays == 0 and 2 or 0)
  end

  r.Main_OnCommand(42691, 0) --Track lanes: Delete lanes (including media items) that are not playing

  numlanes = r.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")
  for i = 0, numlanes - 1 do
    r.SetMediaTrackInfo_Value(track, "C_LANEPLAYS:" .. i, 0)
  end
end

r.PreventUIRefresh(1)
for i = 0, sel_tr_cnt - 1 do DeleteActiveLanes(r.GetSelectedTrack(0, i)) end
r.PreventUIRefresh(-1)
