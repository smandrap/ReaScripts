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

local function table_copy(t)
  local t2 = {}
  for k, v in pairs(t) do
    t2[k] = v
  end
  return t2
end

local function table_delete(t)
  for i = 0, #t do t[i] = nil end
end

-- APP

local FX_LIST = nil
local FILTERED_FXLIST = nil

local filter = ''

local function GetFXList()
  local rv = true
  local i = 0
  local s = nil

  local fx_list = {}

  while rv do
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
  local change = false
  change, filter = ImGui.InputText(ctx, '##DrawSearchFilter', filter)
  return change
end

local function DrawFXList()
  ImGui.BeginListBox(ctx, '##fxlist', ImGui.GetWindowWidth(ctx) - 40, ImGui.GetWindowHeight(ctx) - 60)
  for i = 1, #FILTERED_FXLIST do
    if FILTERED_FXLIST[i] == nil then goto continue end
    ImGui.Checkbox(ctx, '##fx' .. i, false)
    ImGui.SameLine(ctx)
    ImGui.Text(ctx, FILTERED_FXLIST[i])
    ::continue::
  end
  ImGui.EndListBox(ctx)
end

local function UpdateList()
  if filter == '' then 
    FILTERED_FXLIST = table_copy(FX_LIST)
    return
  end
  table_delete(FILTERED_FXLIST)
  for i = 1, #FX_LIST do
    if FX_LIST[i]:lower():match(filter:lower()) then table.insert(FILTERED_FXLIST, FX_LIST[i]) end
  end
end

local function DrawWindow()
  local changed = DrawSearchFilter()
  if changed then UpdateList() end
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
  FILTERED_FXLIST = table_copy(FX_LIST)
end

local function Exit()
  return
end

init()
r.atexit(Exit)
r.defer(guiloop)
