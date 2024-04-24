-- @description Auto-Solo selected Tracks
-- @author smandrap
-- @version 1.0
-- @changelog
--  + first commit
-- @donation https://paypal.me/smandrap
-- @about
--   Cubase style Auto-solo. Automatically solo exclusive selected tracks, clear on exit


local reaper = reaper

reaper.set_action_options(5)

local proj_state_cnt = 0
local sel_tracks = {}


local function IsProjStateChange()
  local new_state = reaper.GetProjectStateChangeCount(0)
  if new_state ~= proj_state_cnt then
    proj_state_cnt = new_state
    return true
  end
  return false
end

local function GetSelTracks()
  local t = {}
  for i = 0, reaper.CountSelectedTracks() - 1 do
    t[#t + 1] = reaper.GetSelectedTrack(0, i)
  end
  return t
end

local function IsTrackSelChange()
  local new_t = GetSelTracks()
  for i = 1, #new_t do
    if sel_tracks[i] ~= new_t[i] then 
      sel_tracks = new_t
      return true 
    end
  end
  return false
end


local function main()
  if IsProjStateChange() and IsTrackSelChange() then
    reaper.Main_OnCommand(40340, 0)
    reaper.Main_OnCommand(7, 0)
  end

  reaper.defer(main)
end

local function exit()
  reaper.Main_OnCommand(40340, 0)
  reaper.set_action_options(8)
end

local function init()
  proj_state_cnt = reaper.GetProjectStateChangeCount(0)
  sel_track = GetSelTracks()
  reaper.Main_OnCommand(40340, 0)
  reaper.Main_OnCommand(7, 0)
end

reaper.atexit(exit)
init()
main()
