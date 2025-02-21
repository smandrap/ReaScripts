-- @description Shrink right edge of items by grid unit
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
--  If relative snap is on, then grow/shrink by grid unit.
--  Got some stuff from X-Raym, thanks

-- XRAYM FUNC
function RoundToX(number, interval)
  return math.floor( number/interval) * interval
end

local function GetNewTargetPosition(pos)
  -- if not relative snap
  if reaper.GetToggleCommandState(41054) == 0 then return reaper.BR_GetPrevGridDivision(pos) end
  
  if reaper.GetToggleCommandState(41885) == 1 then -- if frame grid
    -- XRAYM FUNC
    local frameRate, dropFrameOut = reaper.TimeMap_curFrameRate(0)
    local frame_duration = 1/frameRate
    local pos_quantized = RoundToX(pos - frame_duration + 0.000000000001, frame_duration)
    return pos_quantized
  end
  
  local _, qn_grid = reaper.GetSetProjectGrid(0, false)
  
  local grid_duration = (60 / reaper.Master_GetTempo(pos)) * qn_grid * 4
  return pos - grid_duration
end

local function IsSnapOrGridDisabled()
 return reaper.GetToggleCommandState(40145, 0) == 0 or 
        reaper.GetToggleCommandState(1157, 0) == 0
end

local function ShrinkRightEdge(item)
  if not item then return end
  if IsSnapOrGridDisabled() then
    reaper.Main_OnCommand(40227, 0) -- shrink right edge of item
    return
  end
  
  local pos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
  local len = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
  local snapoffs = reaper.GetMediaItemInfo_Value(item, 'D_SNAPOFFSET')
  
  local newpos = GetNewTargetPosition(pos + len)
  local newlen = newpos - pos
  if newlen < 0 then return end
  
  reaper.SetMediaItemInfo_Value(item, 'D_LENGTH', newlen)
end

local function IsItemFullLocking()
  return reaper.GetToggleCommandState(40576) == 1 or reaper.GetToggleCommandState(40597, 0) == 1
end

if IsItemFullLocking() then return end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)


for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
  local itm = reaper.GetSelectedMediaItem(0, i)
  if reaper.GetMediaItemInfo_Value(itm, 'C_LOCK') == 1 then goto continue end
  ShrinkRightEdge(itm)
  
  ::continue::
end
reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("Shrink right edge of items by grid unit", 0)
