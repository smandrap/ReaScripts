-- @description Show equivalent BPM when changing playrate
-- @author smandrap
-- @version 1.0
-- @donation https://paypal.me/smandrap
-- @about
--   https://forum.cockos.com/showthread.php?t=291877


local r = reaper
local script_name = "Playrate Boi"

if not r.ImGui_GetVersion then
  local ok = reaper.MB('Install now?', 'ReaImGui Missing', 1)
  if ok == 1 then reaper.ReaPack_BrowsePackages("ReaImGui API") end
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9'


-- GUI

local settings = {
  title_font_size = 12,
  font_size = 20,
}

local proj_change_cnt = r.GetProjectStateChangeCount(0)
local first_frame = true

local ctx = ImGui.CreateContext(script_name)
local visible, open
local window_flags =
    ImGui.WindowFlags_NoCollapse
-- | ImGui.WindowFlags_AlwaysAutoResize

local getinfo = debug.getinfo(1, 'S');
local script_path = getinfo.source:match [[^@?(.*[\/])[^\/]-$]];
package.path = script_path .. "?.lua;" .. package.path -- GET DIRECTORY FOR REQUIRE

local os = r.GetOS():match('^Win') and 0 or 1
local os_sep = package.config:sub(1, 1)


local font = ImGui.CreateFont('sans-serif', settings.font_size)
local title_font = ImGui.CreateFont('sans-serif', settings.title_font_size)
ImGui.Attach(ctx, font)
ImGui.Attach(ctx, title_font)

local cur_bpm = 0

local function IsProjectChanged()
  local n = r.GetProjectStateChangeCount(0)
  if n ~= proj_change_cnt then
    proj_change_cnt = n
    return true
  end
  return false
end

local function CalcPlayrateShit()
  local t = r.GetPlayPosition()
  return r.TimeMap_GetDividedBpmAtTime(t) * r.Master_GetPlayRateAtTime(t, 0)
end

local function frame()
  --if IsProjectChanged() then cur_bpm = CalcPlayrateShit() end
  cur_bpm = CalcPlayrateShit()
  ImGui.Text(ctx, cur_bpm)
end

local function PrepWindow()
  ImGui.SetNextWindowSize(ctx, 95, 60, ImGui.Cond_FirstUseEver)
  ImGui.PushFont(ctx, title_font)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding, 5)
end

local function guiloop()
  PrepWindow()
  visible, open = ImGui.Begin(ctx, script_name, true, window_flags)
  ImGui.PopStyleVar(ctx)
  ImGui.PopFont(ctx)

  if visible then
    ImGui.PushFont(ctx, font)
    frame()
    ImGui.End(ctx)
  ImGui.PopFont(ctx)
  end

  if open then
    reaper.defer(guiloop)
  end
end

local function init()
  cur_bpm = CalcPlayrateShit()
end

local function Exit()
  return
end

init()
reaper.atexit(Exit)
reaper.defer(guiloop)
