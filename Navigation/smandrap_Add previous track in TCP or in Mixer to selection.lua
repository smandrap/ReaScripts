-- @description smandrap_Add previous track in TCP or in Mixer to selection.lua
-- @author smandrap
-- @noindex
-- @version 1.0.0
-- @about Add previous visible track in TCP or Mixer to selection. 
-- @readme_skip

local mixer_hwnd = reaper.JS_Window_Find("Mixer", true)
local focus = reaper.JS_Window_GetParent(reaper.JS_Window_GetFocus())

local function prev_in_mcp()
  local first_sel_t = reaper.GetSelectedTrack(-1, 0) or reaper.GetLastTouchedTrack()
  local id = 0
  
  if first_sel_t then id = reaper.GetMediaTrackInfo_Value(first_sel_t, 'IP_TRACKNUMBER') end
  
  for i = id -2, 0, -1 do
    local t = reaper.GetTrack(-1, i)
    if reaper.IsTrackVisible(t, true) and not reaper.IsTrackSelected(t) then
      reaper.SetTrackSelected(t, true)
      return
    end
  end
end


if focus == mixer_hwnd then
  reaper.Undo_BeginBlock()
  prev_in_mcp()
  reaper.Undo_EndBlock("Select Previous Track in Mixer", 0)
else
  reaper.Main_OnCommand(40288, 0)
end
