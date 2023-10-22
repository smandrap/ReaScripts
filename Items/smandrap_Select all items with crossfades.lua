-- @description Select all items with crossfades
-- @author smandrap
-- @donation https://paypal.me/smandrap
-- @version 0.2
-- @changelog
--  + Support v7 FixedLanes
-- @about
--   Select all crossfaded items in project.

local reaper = reaper
local script_name = "smandrap_Select all items with crossfades"

local reaper_version = tonumber(reaper.GetAppVersion():sub(1, 1))


local overlapping_items = {}
local crossfade_items = {}

local function GetOverlappingItemsNew()
  local tr_cnt = reaper.CountTracks(0)
  if tr_cnt == 0 then return end
  
  local GetItemInfo = reaper.GetMediaItemInfo_Value
  
  for i = 0, tr_cnt - 1 do
    local track = reaper.GetTrack(0, i)
    local item_cnt = reaper.CountTrackMediaItems(track)
    
    local ordered_items = {}
    
    for j = 0, item_cnt - 1 do
      local item = reaper.GetTrackMediaItem(track, j)
      local fl = reaper.GetMediaItemInfo_Value(item, 'I_FIXEDLANE')
      
      if not ordered_items[fl] then ordered_items[fl] = {} end
      
      table.insert(ordered_items[fl], item)
    end
    
    for _, fl_items in pairs(ordered_items) do
      for j = 1, #fl_items do
        if not fl_items[j + 1] then break end
        
        local item_end = GetItemInfo(fl_items[j], 'D_POSITION') + GetItemInfo(fl_items[j], 'D_LENGTH')
        local next_item_start = GetItemInfo(fl_items[j + 1], 'D_POSITION')
        
        if item_end > next_item_start then
          table.insert(overlapping_items, {fl_items[j], fl_items[j + 1]})
        end
      end
    end
    
    ::continue::
  end
end

local function GetOverlappingItemsOld()
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
  if reaper_version < 7 then 
    GetOverlappingItemsOld()
  else 
    GetOverlappingItemsNew()
  end
  
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
