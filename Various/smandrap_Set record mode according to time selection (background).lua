-- @description Set record mode according to time selection (background)
-- @author smandrap
-- @version 1.2.2
-- @changelog
--  # Revert to previous behavior
--  # Temporarily remove SWS dependency until i find out how tf to do things
-- @donation https://paypal.me/smandrap
-- @about
--  mlprod request. https://forum.cockos.com/showthread.php?t=284064 \n
--
--  Auto change record mode to Time selection autopunch if there's a time selection\n
--  Does not change record mode during record if time selection is changed\n

-----------------------

local poll_rate = 11 -- Decrease this value if you want the script to update faster

-----------------------

--[[ if not reaper.CF_GetSWSVersion then
  reaper.MB('Download at \n https://www.sws-extension.org/', 'SWS Required', 0)
  return
end
 ]]

local call_cnt = 0

local function IsTimeSel()
  local s, e = reaper.GetSet_LoopTimeRange(false, false, nil, nil, false)
  return s ~= e
end

local function main()
  call_cnt = call_cnt + 1

  if call_cnt >= poll_rate then
    call_cnt = 0
    if reaper.GetPlayState() ~= 5 then
      reaper.Main_OnCommand(IsTimeSel() and 40076 or 40252, 0)
    end
  end

  reaper.defer(main)
end

reaper.defer(main)
