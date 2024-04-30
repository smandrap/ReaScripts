-- @description Export FX shortcut Actions
-- @author smandrap
-- @version 1.0
-- @donation https://paypal.me/smandrap
-- @about
--   ABOUT



local r = reaper
local script_name = "My cool script"

package.path = r.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'ImGui' '0.9'


if not ImGui.GetVersion then
  local ok = r.MB('Install now?', 'ReaImGui Missing', 1)
  if ok == 1 then r.ReaPack_BrowsePackages("ReaImGui API") end
  return
end

-- APP

local FX_LIST = nil

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


local function DrawFXList()
  ImGui.ListBox()
  
end

local function DrawWindow()
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
end

local function Exit()
  return
end

init()
r.atexit(Exit)
r.defer(guiloop)
