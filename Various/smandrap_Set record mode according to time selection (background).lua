-- @description Set record mode according to time selection (background)
-- @author smandrap
-- @version 1.1
-- @changelog
--  # Change state only when not recording
-- @donation https://paypal.me/smandrap
-- @about
--  mlprod request. https://forum.cockos.com/showthread.php?t=284064
--  
--  Auto change record mode to Time selection autopunch if there's a time selection
--  Does not change record mode during record if time selection is changed

local GetPlayState = reaper.GetPlayState
local GetTimeRange = reaper.GetSet_LoopTimeRange
local OnCommand = reaper.Main_OnCommand
local defer = reaper.defer

local function IsTimeSel()
  local s, e = GetTimeRange(false, false, nil, nil, false)
  return s ~= e
end

local function main()
  if GetPlayState() ~= 5 then OnCommand(IsTimeSel() and 40076 or 40252, 0) end
  defer(main)
end

main()
