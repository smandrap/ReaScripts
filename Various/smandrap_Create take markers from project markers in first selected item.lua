-- @description Create take markers from project markers in first selected item
-- @author smandrap
-- @version 1.0
-- @donation https://paypal.me/smandrap
-- @about
--   Useful when spotting to video. I just press M like crazy to create project markers and "print" the markers to the video item when finished.

local itm = reaper.GetSelectedMediaItem(0, 0)
if not itm then return end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local itm_start = reaper.GetMediaItemInfo_Value(itm, 'D_POSITION')
local itm_end = itm_start + reaper.GetMediaItemInfo_Value(itm, 'D_LENGTH')
local take = reaper.GetActiveTake(itm)

local mrk_id = 0
local ok = true
while ok do
  local rv, rgn, mrk_pos, _, mrk_name, mrk_num = reaper.EnumProjectMarkers(mrk_id)
  ok = rv > 0
  
  if rgn then goto continue end
  if mrk_pos < itm_start or mrk_pos > itm_end then goto continue end
  
  reaper.SetTakeMarker(take, -1, mrk_name, mrk_pos - itm_start)
  
  ::continue::
  mrk_id = mrk_id + 1
end

reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock('Create take markers from project markers in first selected item', 0)
