-- @description Group selected overlapping items
-- @author smandrap
-- @version 1.0
-- @donation https://paypal.me/smandrap


local function items_overlap(it1, it2)
  local s1 = reaper.GetMediaItemInfo_Value(it1, "D_POSITION")
  local e1 = s1 + reaper.GetMediaItemInfo_Value(it1, "D_LENGTH")
  local s2 = reaper.GetMediaItemInfo_Value(it2, "D_POSITION")
  local e2 = s2 + reaper.GetMediaItemInfo_Value(it2, "D_LENGTH")
  return (s1 < e2) and (s2 < e1)
end

local function main()
  local item_count = reaper.CountSelectedMediaItems(0)
  if item_count == 0 then return end
  
  local group_id = 1
  
  for i = 0, item_count-1 do
    local it1 = reaper.GetSelectedMediaItem(0, i)
   
    for j = i+1, item_count-1 do
      local it2 = reaper.GetSelectedMediaItem(0, j)
      
      if items_overlap(it1, it2) then
        reaper.SetMediaItemInfo_Value(it1, "I_GROUPID", group_id)
        reaper.SetMediaItemInfo_Value(it2, "I_GROUPID", group_id)
      end
    end
    
    group_id = group_id + 1
  end
end


reaper.PreventUIRefresh(1)

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Group selected overlapping items", 0)

reaper.UpdateArrange()
reaper.PreventUIRefresh(-1)
