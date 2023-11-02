-- @description Set record mode according to time selection (background)
-- @author smandrap
-- @version 1.2.1
-- @changelog
--  # Prevent user error with poll rate
-- @donation https://paypal.me/smandrap
-- @about
--  mlprod request. https://forum.cockos.com/showthread.php?t=284064 \n
--  REQUIRES SWS \n
--  
--  Auto change record mode to Time selection autopunch if there's a time selection\n
--  Does not change record mode during record if time selection is changed\n

-----------------------

local poll_rate = 11  -- Decrease this value if you want the script to update faster

-----------------------

if not reaper.CF_GetSWSVersion then
  reaper.MB('Download at \n https://www.sws-extension.org/', 'SWS Required', 0)
  return
end

local GetPlayState = reaper.GetPlayState
local GetTimeRange = reaper.GetSet_LoopTimeRange
local SetIntConfigVar = reaper.SNM_SetIntConfigVar
local Refresh = reaper.ThemeLayout_RefreshAll
local defer = reaper.defer
local call_cnt = 0

local function IsTimeSel()
  local s, e = GetTimeRange(false, false, nil, nil, false)
  return s ~= e
end

local function main()
  call_cnt = call_cnt + 1
  
  if call_cnt >= poll_rate then
    if GetPlayState() ~= 5 then 
      SetIntConfigVar('projrecmode', IsTimeSel() and 2 or 1)
      Refresh()
    end
    call_cnt = 0
  end
  
  defer(main)
end

main()
