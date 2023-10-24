-- @description Set record mode according to time selection (background)
-- @author smandrap
-- @version 1.0
-- @donation https://paypal.me/smandrap


local GetPlayState = reaper.GetPlayState
local GetTimeRange = reaper.GetSet_LoopTimeRange
local OnCommand = reaper.Main_OnCommand
local defer = reaper.defer

local prev_rec_state = 0

local function IsTimeSel()
  local s, e = GetTimeRange(false, false, nil, nil, false)
  return s ~= e
end

local function main()
  
  local rec_state = GetPlayState()
  
  if prev_rec_state ~= rec_state and rec_state == 5 then
    OnCommand(IsTimeSel() and 40076 or 40252, 0)
  end
  
  prev_rec_state = rec_state
  
  defer(main)
end

main()
