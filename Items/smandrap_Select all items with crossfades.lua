-- @description Select all items with crossfades
-- @author smandrap
-- @version 0.1
-- @about
-- Select all crossfaded items in project.
-- Will likely not work properly with fixed item lanes.

local reaper = reaper

local script_name = "manup_Select all items with crossfades"

local overlapping_items = {}
local crossfade_items = {}

local function GetOverlappingItems()
  local tr_cnt = reaper.CountTracks(0)
  if tr_cnt == 0 then return end
  
  for i = 0, tr_cnt - 1 do
    local track = reaper.GetTrack(0, i)
    local item_cnt = reaper.CountTrackMediaItems(track)
    
    
    for j = 0, item_cnt do
      local next_item = reaper.GetTrackMediaItem(track, j + 1)
      if not next_item then break end
      
      local item = reaper.GetTrackMediaItem(track, j)
    
      
      local item_end = reaper.GetMediaItemInfo_Value(item, 'D_POSITION') + reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
      local next_item_start = reaper.GetMediaItemInfo_Value(next_item, 'D_POSITION')
      
      if item_end > next_item_start then
        table.insert(overlapping_items, {item, next_item})
      end
    end
  end
end

local function CheckCrossfade(first_item, second_item)

  local fadeout =  reaper.GetMediaItemInfo_Value(first_item, 'D_FADEOUTLEN')
  if fadeout == 0 then return false end
  
  local fadein = reaper.GetMediaItemInfo_Value(second_item, 'D_FADEINLEN')
  if fadein == 0 then return false end
  
  return true
end


local function main()
  GetOverlappingItems()
  
  for _, items in pairs(overlapping_items) do
    if CheckCrossfade(items[1], items[2]) then 
      table.insert(crossfade_items, items[1])
      table.insert(crossfade_items, items[2])
    end
  end
  
  for _, item in pairs(crossfade_items) do
    reaper.SetMediaItemSelected(item, true)
  end
end


reaper.Undo_BeginBlock()
main()
reaper.UpdateArrange()
reaper.Undo_EndBlock(script_name, 0)
