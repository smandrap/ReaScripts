-- @description Snap take markers in selected items to grid
-- @author smandrap
-- @version 1.0
-- @donation https://paypal.me/smandrap
-- @about
--   Does what it says, in all takes.


local function main()
  for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
    local itm = reaper.GetSelectedMediaItem(0, i)
    local itm_pos = reaper.GetMediaItemInfo_Value(itm, 'D_POSITION')
    
    for tk_idx = 0, reaper.CountTakes(itm) - 1 do
      local tk = reaper.GetTake(itm, tk_idx)
    
      for mrk_idx = 0, reaper.GetNumTakeMarkers(tk) - 1 do
        local mrk_pos, name = reaper.GetTakeMarker(tk, mrk_idx)
        local snap_pos = reaper.SnapToGrid(0, itm_pos + mrk_pos) - itm_pos
        
        reaper.SetTakeMarker(tk, mrk_idx, name, snap_pos)
        
      end
    end
  end
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Snap take markers in selected items to grid", -1)
