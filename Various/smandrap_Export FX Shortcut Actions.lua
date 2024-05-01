-- @description Export FX shortcut Actions
-- @author smandrap
-- @version 1.0.3
-- @changelog
--  # Fix script generation on windows (fuck reserved chars)
-- @donation https://paypal.me/smandrap
-- @about
--   Select FX and run Export to add actions to open/show said fx

local r = reaper
local script_name = "FX Shortcut Export"

if not r.ImGui_GetVersion then
  local ok = r.MB('Install now?', 'ReaImGui Missing', 1)
  if ok == 1 then r.ReaPack_BrowsePackages("ReaImGui API") end
  return
elseif select(2, r.ImGui_GetVersion()) < 0.9 then
  local ok = r.MB('Requires ReaImGui v0.9 or later.\n\nUpdate now?', 'ReaImGui Outdated', 1)
  if ok == 1 then r.ReaPack_BrowsePackages("ReaImGui API") end
  return
end

package.path = r.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9'

local getinfo = debug.getinfo(1, 'S');
local script_path = getinfo.source:match [[^@?(.*[\/])[^\/]-$]];
package.path = script_path .. "?.lua;" .. package.path -- GET DIRECTORY FOR REQUIRE

--local os = r.GetOS():match('^Win') and 0 or 1
local os_sep = package.config:sub(1, 1)

local export_path = script_path .. 'Exported FX Shortcuts' .. os_sep


-- Get radial menu
local radial_fn = "Lokasenna_Radial Menu - user settings.txt"
local radial_path = table.concat({ r.GetResourcePath(), 'Scripts', 'ReaTeam Scripts', 'Various' }, os_sep) .. os_sep
local radial_found

local radial_file = radial_path .. radial_fn
if r.file_exists(radial_file) then
    radial_found = true
    --reaper.ShowConsoleMsg('ok')
end


-- APP

local FX_LIST = {}
--local FILTERED_FXLIST = {}

local SEL_IDX = {}

local export_options = {
  ALWAYS_INSTANTIATE = false,
  SHOW = true,
  FLOAT_WND = true,
}

local export_cnt = 0
local can_export = false
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

local function GenerateScript(FX_NAME)
  local export_str = ([[
  FX_NAME = "%s"
  ALWAYS_INSTANTIATE = %s
  SHOW = %s
  FLOAT_WND = %s

  for i = 0, reaper.CountSelectedTracks(0) - 1 do
    local t = reaper.GetSelectedTrack(0, 0)
    local fxidx = reaper.TrackFX_AddByName(t, FX_NAME, false, ALWAYS_INSTANTIATE and -1 or 1)
    if SHOW then reaper.TrackFX_Show(t, fxidx, FLOAT_WND and 3 or 1) end
  end
  ]]):format(FX_NAME, export_options.ALWAYS_INSTANTIATE, export_options.SHOW, export_options.FLOAT_WND)

  local fn = 'Insert FX - ' .. FX_NAME .. '.lua'
  local full_path = export_path .. fn

  local f = io.open(full_path, 'w+')
  if f == nil then return end
  f:write(export_str)
  f:close()


  return full_path
end

local function UpdateCanExport()
  export_cnt = 0
  for i = 1, #SEL_IDX do
    if SEL_IDX[i] == true then
      export_cnt = export_cnt + 1
    end
  end
  can_export = export_cnt > 0
end

local function main()
  local paths = {}
  for i = 1, #SEL_IDX do
    if SEL_IDX[i] == true then
      paths[#paths + 1] = GenerateScript(FX_LIST[i])
    end
  end
  for i = 1, #paths - 1 do
    r.AddRemoveReaScript(true, 0, paths[i] or '', false)
  end
  local cmdid = r.AddRemoveReaScript(true, 0, paths[#paths] or '', false)
  r.PromptForAction(1, cmdid, 0)
  r.PromptForAction(-1, cmdid, 0)
end


-- GUI

local settings = {
  font_size = 12,
}

local btn_w = 80
local wnd_h = 410
local wnd_w = 300
local list_w = wnd_w * 0.95
local list_h = wnd_h * 0.5

local ctx = ImGui.CreateContext(script_name)
local visible, open
local window_flags =
    ImGui.WindowFlags_None | ImGui.WindowFlags_NoResize

local child_flags = ImGui.ChildFlags_Border

local font = ImGui.CreateFont('sans-serif', settings.font_size)
ImGui.Attach(ctx, font)

local function DrawSearchFilter()
  local change = false
  ImGui.PushItemWidth(ctx, list_w)
  change, filter = ImGui.InputText(ctx, '##DrawSearchFilter', filter)
  return change
end

local function DrawFXList()
  _ = ImGui.BeginChild(ctx, '##fxlist', list_w, list_h, child_flags)
  for i = 1, #FX_LIST do
    if not FX_LIST[i]:lower():match(filter:lower()) then goto continue end
    local rv = false
    rv, SEL_IDX[i] = ImGui.Checkbox(ctx, '##fx' .. i, SEL_IDX[i])
    if rv then UpdateCanExport() end
    ImGui.SameLine(ctx)
    ImGui.Text(ctx, FX_LIST[i])
    if ImGui.IsItemClicked(ctx) then 
      SEL_IDX[i] = not SEL_IDX[i]
      UpdateCanExport()
    end
    ::continue::
  end
  ImGui.EndChild(ctx)
end

--[[ local function UpdateList()
  if filter == '' then
    FILTERED_FXLIST = table_copy(FX_LIST)
    return
  end
  table_delete(FILTERED_FXLIST)
  for i = 1, #FX_LIST do
    if FX_LIST[i]:lower():match(filter:lower()) then table.insert(FILTERED_FXLIST, FX_LIST[i]) end
  end
end ]]

local function DrawOptions()
  ImGui.Dummy(ctx, 0, 20)
  ImGui.SeparatorText(ctx, 'Options:')
  _, export_options.ALWAYS_INSTANTIATE = ImGui.Checkbox(ctx, 'Always Instantiate##opt1',
    export_options.ALWAYS_INSTANTIATE)
  _, export_options.SHOW = ImGui.Checkbox(ctx, 'Show FX##opt2', export_options.SHOW)
  _, export_options.FLOAT_WND = ImGui.Checkbox(ctx, 'Float Window##opt3', export_options.FLOAT_WND)
end

local function DrawExportButton()
  reaper.ImGui_SetCursorPosX(ctx, reaper.ImGui_GetWindowWidth(ctx) - btn_w - 10)
  if not can_export then
    ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0x5D5D5DAA)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, 0x5D5D5DAA)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, 0x5D5D5DAA)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x5D5D5DFF)
  end
  if reaper.ImGui_Button(ctx, "Export", btn_w) and can_export then
    main()
    open = false
  end
  if not can_export then ImGui.PopStyleColor(ctx, 4) end
end

local function DrawExportCnt()
  if export_cnt > 0 then
    ImGui.AlignTextToFramePadding(ctx)
    ImGui.Text(ctx, ('Exporting %d shortcut(s)'):format(export_cnt))
  else
    ImGui.Dummy(ctx, 0, 10)
  end
end

local function DrawWindow()
  local changed = DrawSearchFilter()
  --if changed then UpdateList() end
  DrawFXList()
  DrawOptions()

  ImGui.Dummy(ctx, 0, 10)

  DrawExportCnt()
  ImGui.SameLine(ctx)
  DrawExportButton()
end

local function PrepWindow()
  ImGui.SetNextWindowSize(ctx, wnd_w, wnd_h, ImGui.Cond_Appearing)
  ImGui.PushFont(ctx, font)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding, 5)
end

local function guiloop()
  PrepWindow()
  visible, open = ImGui.Begin(ctx, script_name, true, window_flags)
  ImGui.PopStyleVar(ctx)

  if visible then
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameRounding, 5)
    DrawWindow()
    ImGui.PopStyleVar(ctx)
    ImGui.End(ctx)
  end
  ImGui.PopFont(ctx)

  if open then
    r.defer(guiloop)
  end
end

local function init()
  FX_LIST = GetFXList()

  for i = 1, #FX_LIST do
    SEL_IDX[i] = false
  end

  r.RecursiveCreateDirectory(export_path, 1)

end

local function Exit()
  return
end

init()
r.atexit(Exit)
r.defer(guiloop)


