-- @description Export FX shortcut Actions
-- @author smandrap
-- @version 1.0
-- @donation https://paypal.me/smandrap
-- @about
--   ABOUT



local r = reaper
local script_name = "FX Shortcut Export"

package.path = r.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9'


if not ImGui.GetVersion then
  local ok = r.MB('Install now?', 'ReaImGui Missing', 1)
  if ok == 1 then r.ReaPack_BrowsePackages("ReaImGui API") end
  return
end

-- APP

local FX_LIST = nil
local FILTERED_FXLIST = nil

local function GetFXList()
  local rv = true
  local i = 0
  local s = nil
  
  local fx_list = {}
  
  while rv  do
    rv, s = r.EnumInstalledFX(i)
    if rv then fx_list[#fx_list + 1] = s end
    i = i + 1
  end
  
  return fx_list
end


-- GUI

local settings = {
  font_size = 12,
}

local ctx = ImGui.CreateContext(script_name)
local visible, open
local window_flags =
    ImGui.WindowFlags_None
-- | ImGui.WindowFlags_AlwaysAutoResize


local font = ImGui.CreateFont('sans-serif', settings.font_size)
ImGui.Attach(ctx, font)

local function DrawSearchFilter()
  
end

local function DrawFXList()
  ImGui.BeginListBox(ctx, '##fxlist', ImGui.GetWindowWidth(ctx) - 40, ImGui.GetWindowHeight(ctx) - 60)
    for i = 1, #FX_LIST do
      ImGui.Checkbox(ctx, '##fx'..i, false)
      ImGui.SameLine(ctx)
      ImGui.Text(ctx, FX_LIST[i])
    end
  ImGui.EndListBox(ctx)
end

local function DrawWindow()
  DrawSearchFiletr()
  DrawFXList()
end

local function PrepWindow()
  ImGui.SetNextWindowSize(ctx, 300, 400, ImGui.Cond_FirstUseEver)
  ImGui.PushFont(ctx, font)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding, 5)
end

local function guiloop()
  PrepWindow()
  visible, open = ImGui.Begin(ctx, script_name, true, window_flags)
  ImGui.PopStyleVar(ctx)

  if visible then
    DrawWindow()
    ImGui.End(ctx)
  end
  ImGui.PopFont(ctx)

  if open then
    r.defer(guiloop)
  end
end

local function init()
  FX_LIST = GetFXList()
  FILTERED_FXLIST = FX_LIST
end

local function Exit()
  return
end

init()
r.atexit(Exit)
r.defer(guiloop)
