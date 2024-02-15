-- @description smandrap_Select next track in TCP or in Mixer.lua
-- @author smandrap
-- @noindex
-- @about Select next visible track in TCP or Mixer.
-- @readme_skip

local mixer_hwnd = reaper.JS_Window_Find("Mixer", true)
local focus = reaper.JS_Window_GetParent(reaper.JS_Window_GetFocus())

local function next_in_mcp()
  local first_sel_t = reaper.GetSelectedTrack(-1, 0) or reaper.GetLastTouchedTrack()
  local id = 0
  
  if first_sel_t then id = reaper.GetMediaTrackInfo_Value(first_sel_t, 'IP_TRACKNUMBER') end

  local tr_cnt = reaper.CountTracks()
  --if id >= tr_cnt then return end
  
  for i = id, tr_cnt - 1 do
    local t = reaper.GetTrack(-1, i)
    
    if reaper.IsTrackVisible(t, true) and reaper.GetMediaTrackInfo_Value(t, 'I_MCPW') > 0 then
      reaper.SetOnlyTrackSelected(t)
      return
    end
  end
  
  reaper.SetOnlyTrackSelected(first_sel_t) -- if everything fails
  
end


if focus == mixer_hwnd then
  reaper.Undo_BeginBlock()
  next_in_mcp()
  reaper.Undo_EndBlock("Select Next Track in Mixer", 0)
else
  reaper.Main_OnCommand(40285, 0)
end
