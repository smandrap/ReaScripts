-- @description Grow right edge of items by grid unit
-- @author smandrap
-- @donation https://paypal.me/smandrap
-- @version 1.0
-- @noindex
-- @changelog
--  + init
-- @about
--  Similar to native action, but works by grid unit.
--  If grid or snap is disabled, uses native action. 
--  If relative snap is off, then grow/shrink to previous/next grid.
--  If relative snap is on, then grow/shrink by grid unit
--  Got some stuff from X-Raym, thanks

local items = {}

-- XRAYM FUNC
function RoundToX(number, interval)
  return math.floor( number/interval) * interval
end

local function GetNewTargetPosition(pos)
  -- if not relative snap
  if reaper.GetToggleCommandState(41054) == 0 then return reaper.BR_GetNextGridDivision(pos) end
  
  if reaper.GetToggleCommandState(41885) == 1 then -- if frame grid
    -- XRAYM FUNC
    local frameRate, dropFrameOut = reaper.TimeMap_curFrameRate(0)
    local frame_duration = 1 / frameRate
    local pos_quantized = RoundToX(pos + frame_duration + 0.000000000001, frame_duration)
    return pos_quantized
  end
  
  local _, qn_grid = reaper.GetSetProjectGrid(0, false)
  
  local grid_duration = (60 / reaper.Master_GetTempo(pos)) * qn_grid * 4
  return pos + grid_duration
end

local function IsSnapOrGridDisabled()
 return reaper.GetToggleCommandState(40145, 0) == 0 or 
        reaper.GetToggleCommandState(1157, 0) == 0
end

local function GrowRightEdge(item)
  if not item then return end
  if IsSnapOrGridDisabled() then
    reaper.Main_OnCommand(40228, 0) -- grow right edge of item
    return
  end
  
  local pos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
  local len = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
  
  local newpos = GetNewTargetPosition(pos + len)
  local newlen = newpos - pos
  
  -- reaper.SetMediaItemInfo_Value(item, 'D_POSITION', newpos)
  reaper.SetMediaItemInfo_Value(item, 'D_LENGTH', newlen)

  -- Adjust Takes
  for i = 0, reaper.CountTakes(item) - 1 do
    local tk = reaper.GetTake(item, i)
    if not tk then goto continue end
    
    local st_offs = reaper.GetMediaItemTakeInfo_Value(tk, 'D_STARTOFFS')
    --reaper.SetMediaItemTakeInfo_Value(tk, 'D_STARTOFFS', st_offs - offs)
    
    if reaper.TakeIsMIDI(tk) then
      reaper.Main_OnCommand(40225, 0)
      reaper.Main_OnCommand(40226, 0)
    else
      local medialen = reaper.GetMediaSourceLength(reaper.GetMediaItemTake_Source(tk))
      if medialen - st_offs < newlen then
        reaper.Main_OnCommand(40612, 0) -- Item: Set item start to source media end
      end
    end
      
      
    ::continue::
  end
end

local function IsItemFullLocking()
  return reaper.GetToggleCommandState(40576) == 1 or reaper.GetToggleCommandState(40597, 0) == 1
end

if IsItemFullLocking() then return end


reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)
for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
  items[#items + 1] = reaper.GetSelectedMediaItem(0, i)
end

for i = 1, #items do
  if reaper.GetMediaItemInfo_Value(items[i], 'C_LOCK') == 1 then goto continue end
  
  reaper.Main_OnCommand(40289, 0) -- unselect all items
  reaper.SetMediaItemSelected(items[i], true)
  GrowRightEdge(items[i])
  
  ::continue::
end

for i = 1, #items do
  reaper.SetMediaItemSelected(items[i], true)
end
reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("Grow right edge of items by grid unit", 0)
