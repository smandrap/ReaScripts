-- @description Export FX shortcut Actions
-- @author smandrap
-- @version 1.1.1
-- @changelog
--  # Fix checkbox for radial export
-- @donation https://paypal.me/smandrap
-- @about
--   Select FX and run Export to add actions to open/show said fx

-- TODO: radial menu direct export
-- TODO: pie menu direct export

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

local os = r.GetOS():match('^Win') and 0 or 1
local os_sep = package.config:sub(1, 1)

-----------------------------
-- HELPERS
-----------------------------


local function StringToTable(str)
  local f, err = load(str)
  return f ~= nil and f() or nil
end

local function SaveToFile(data, fn)
  local file
  file = io.open(fn, "w")
  if file then
    file:write(data)
    file:close()
  end
end

local function ReadFromFile(fn)
  local file = io.open(fn, "r")
  if not file then return end
  local content = file:read("a")
  if content == "" then return end
  return StringToTable(content)
end

local function serializeTable(val, name, skipnewlines, depth)
  skipnewlines = skipnewlines or false
  depth = depth or 0
  local tmp = string.rep(" ", depth)
  if name then
    if type(name) == "number" and math.floor(name) == name then
      name = "[" .. name .. "]"
    elseif not string.match(name, '^[a-zA-z_][a-zA-Z0-9_]*$') then
      name = string.gsub(name, "'", "\\'")
      name = "['" .. name .. "']"
    end
    tmp = tmp .. name .. " = "
  end
  if type(val) == "table" then
    tmp = tmp .. "{" .. (not skipnewlines and "\n" or "")
    for k, v in pairs(val) do
      if k ~= "selected" and k ~= "guid_list" and k ~= "img_obj" then
        tmp = tmp .. serializeTable(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "\n" or "")
      end
    end
    tmp = tmp .. string.rep(" ", depth) .. "}"
  elseif type(val) == "number" then
    tmp = tmp .. tostring(val)
  elseif type(val) == "string" then
    tmp = tmp .. string.format("%q", val)
  elseif type(val) == "boolean" then
    tmp = tmp .. (val and "true" or "false")
  else
    tmp = tmp .. "\"[inserializeable datatype:" .. type(val) .. "]\""
  end
  return tmp
end

local function TableToString(table, new_line)
  local str = serializeTable(table, nil, new_line)
  return str
end


----------------------
-- APP
----------------------

local FX_LIST = {}
local FILTERED_IDX = {}

local SEL_IDX = {}

local export_options = {
  ALWAYS_INSTANTIATE = false,
  SHOW = true,
  FLOAT_WND = true,
  TO_RADIAL = false,
  TO_PIE = false
}
local export_path = script_path .. 'Exported FX Shortcuts' .. os_sep

local export_cnt = 0
local can_export = false

local filter = ''
local filter_lower = ''

local type_filter = {
  VST = true,
  VST3 = true,
  AU = true,
  JSFX = true,
  CLAP = true,
  LV2 = true
}

-- Get radial menu
local radial_fn = "Lokasenna_Radial Menu - user settings.txt"
local radial_path = table.concat({ r.GetResourcePath(), 'Scripts', 'ReaTeam Scripts', 'Various' }, os_sep) .. os_sep
local radial_found

local radial_file = radial_path .. radial_fn
if r.file_exists(radial_file) then
  radial_found = true
end

local RADIAL_TBL = {}
local RADIAL_MENUNAMES = {}
local sel_radmenu = 0

local function GetRadialTable()
  local tmp = ReadFromFile(radial_file)
  if not tmp then return end
  for i = 0, #tmp do
    RADIAL_MENUNAMES[i] = tmp[i].alias or ('Menu ' .. i)
  end
  return tmp
end


local function AddActionToRadial(cmdid, fxname)
  -- Create new 'Add FX' menu if it doesn't exist
  --[[   if sel_radmenu == -1 then
    local tmp = { alias = 'Add FX' }
    tmp[-1] = {
      act = 'back',
      lbl = 'Back'
    }
    table.insert(RADIAL_TBL, { alias = 'Add FX' })
    sel_radmenu = #RADIAL_TBL
  end
 ]]

  if RADIAL_TBL[sel_radmenu].alias == 'Add FX' then
    fxname = fxname:gsub('^.+:%s+(.*)(%s+%(.+%))$', '%1')
  else
    fxname = 'Add FX: ' .. fxname:gsub('^.+:%s+(.*)(%s+%(.+%))$', '%1')
  end
  local tmp = {
    act = '_' .. r.ReverseNamedCommandLookup(cmdid),
    lbl = fxname
  }
  table.insert(RADIAL_TBL[sel_radmenu], tmp)
end

--local pie_found = false
--local PIE_TBL = {}


local function GetPieTable()
  return {}
end

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
  local actions = {}

  for i = 1, #SEL_IDX do
    if SEL_IDX[i] == true then
      local tmp = { cmdid = 0, name = FX_LIST[i] }
      actions[#actions + 1] = tmp
      paths[#paths + 1] = GenerateScript(FX_LIST[i])
    end
  end
  --if true then return end

  local cmdid = 0
  for i = 1, #paths - 1 do
    actions[i].cmdid = r.AddRemoveReaScript(true, 0, paths[i] or '', false)
  end
  actions[#actions].cmdid = r.AddRemoveReaScript(true, 0, paths[#paths] or '', false)
  r.PromptForAction(1, actions[#actions].cmdid, 0)
  r.PromptForAction(-1, actions[#actions].cmdid, 0)

  if export_options.TO_RADIAL then
    for i = 1, #actions do
      AddActionToRadial(actions[i].cmdid, actions[i].name)
    end
    SaveToFile('return' .. TableToString(RADIAL_TBL), radial_file)
  end
end

----------------------
-- GUI
----------------------

local settings = {
  font_size = 12,
}


local ctx = ImGui.CreateContext(script_name)
local visible, open
local window_flags =
    ImGui.WindowFlags_None | ImGui.WindowFlags_AlwaysAutoResize

local child_flags = ImGui.ChildFlags_Border
local table_flags =
    ImGui.TableFlags_None
--| ImGui.TableFlags_RowBg

local font = ImGui.CreateFont('sans-serif', settings.font_size)
ImGui.Attach(ctx, font)

local first_frame = true

local btn_w = 80
local wnd_h = 500
local wnd_w = 300
local list_w = wnd_w * 0.95
local list_h = wnd_h * 0.5

local function UpdateList()
  --[[  if filter == '' then
    for i = 1, #FILTERED_IDX do FILTERED_IDX[i] = true end
    return
  end ]]

  filter_lower = filter:lower()

  for i = 1, #FX_LIST do
    FILTERED_IDX[i] = false
    local type_ok = true
    local str = FX_LIST[i]

    if (not type_filter.VST and str:match('^VSTi?:')) or
        (not type_filter.VST3 and str:match('^VST3i?:')) or
        (not type_filter.AU and str:match('^AUi?:')) or
        (not type_filter.JS and str:match('^JSi?:')) or
        (not type_filter.CLAP and str:match('^CLAPi?:')) or
        (not type_filter.LV2 and str:match('^LV2i?:'))
    then
      type_ok = false
    end

    if type_ok and str:lower():match(filter_lower) then FILTERED_IDX[i] = true end
  end
end

local function DrawSearchFilter()
  local change = false
  local w = ImGui.GetContentRegionAvail(ctx)
  ImGui.PushItemWidth(ctx, w)
  if first_frame then ImGui.SetKeyboardFocusHere(ctx) end
  change, filter = ImGui.InputTextWithHint(ctx, '##SearchFilter', 'Search FX', filter)
  if change then UpdateList() end
end

local function DrawFXListRow(i)
  ImGui.TableNextRow(ctx)
  ImGui.TableSetColumnIndex(ctx, 0)
  local rv = false

  local xcurpos, ycurpos = ImGui.GetCursorPos(ctx)
  rv = ImGui.InvisibleButton(ctx, '##row' .. i, list_w, ImGui.GetFrameHeight(ctx))
  if rv then SEL_IDX[i] = not SEL_IDX[i] end
  if rv then UpdateCanExport() end

  ImGui.SetCursorPos(ctx, xcurpos, ycurpos)
  if ImGui.IsItemHovered(ctx) then ImGui.TableSetBgColor(ctx, 1, 0x15B9FE22) end
  if SEL_IDX[i] == true then ImGui.TableSetBgColor(ctx, 1, 0x15B9FE44) end

  rv, SEL_IDX[i] = ImGui.Checkbox(ctx, '##fx' .. i, SEL_IDX[i])
  ImGui.SameLine(ctx)
  ImGui.Text(ctx, FX_LIST[i])
end

local function DrawFXList()
  _ = ImGui.BeginChild(ctx, '##fxlist', nil, list_h, child_flags)
  _ = ImGui.BeginTable(ctx, '##fxtable', 1, table_flags, nil, list_h)
  for i = 1, #FX_LIST do
    if FILTERED_IDX[i] == true then DrawFXListRow(i) end
  end
  ImGui.EndTable(ctx)
  ImGui.EndChild(ctx)
end

local function DrawOptions()
  local draw_extra_options = radial_found or pie_found

  local w = ImGui.GetContentRegionAvail(ctx)
  w = draw_extra_options and w * 0.5 or w
  local h = 100

  _ = ImGui.BeginChild(ctx, '##optionsBasic', w, h)
  ImGui.SeparatorText(ctx, 'Options:')
  _, export_options.ALWAYS_INSTANTIATE = ImGui.Checkbox(ctx, 'Always Instantiate##opt1',
    export_options.ALWAYS_INSTANTIATE)
  _, export_options.SHOW = ImGui.Checkbox(ctx, 'Show FX##opt2', export_options.SHOW)
  _, export_options.FLOAT_WND = ImGui.Checkbox(ctx, 'Float Window##opt3', export_options.FLOAT_WND)
  ImGui.EndChild(ctx)

  if not draw_extra_options then return end

  ImGui.SameLine(ctx)
  w = ImGui.GetContentRegionAvail(ctx)
  _ = ImGui.BeginChild(ctx, '##optionsExtra', w, h)
  ImGui.SeparatorText(ctx, 'Export To:')
  if radial_found then
    _, export_options.TO_RADIAL = ImGui.Checkbox(ctx, 'Radial   ##tgl_rad_exp', export_options.TO_RADIAL)

    if export_options.TO_RADIAL then
      ImGui.SameLine(ctx)
      local combo_w = ImGui.GetContentRegionAvail(ctx)
      ImGui.PushItemWidth(ctx, combo_w)

      --TODO: fill the menus
      if ImGui.BeginCombo(ctx, '##combo_radMenuSelect', RADIAL_MENUNAMES[sel_radmenu], ImGui.ComboFlags_NoArrowButton) then
        --[[      local clicked = false
        clicked = ImGui.Selectable(ctx, 'New Menu', sel_radmenu == -1)
        if clicked then sel_radmenu = -1 end ]]

        for i = 0, #RADIAL_MENUNAMES do
          local clicked = ImGui.Selectable(ctx, RADIAL_MENUNAMES[i], sel_radmenu == i)
          if clicked then sel_radmenu = i end
        end
        ImGui.EndCombo(ctx)
      end
    end
  end
  --[[
  if pie_found then
    _, export_options.TO_PIE = ImGui.Checkbox(ctx, 'Pie3000##tgl_pie_exp', export_options.TO_PIE)
    if export_options.TO_PIE then
      ImGui.SameLine(ctx)
      local combo_w = ImGui.GetContentRegionAvail(ctx)
      ImGui.PushItemWidth(ctx, combo_w)
      if ImGui.BeginCombo(ctx, '##combo_pieMenuSelect', 'Select Menu', ImGui.ComboFlags_NoArrowButton) then
        ImGui.Selectable(ctx, 'menu1', false)
        ImGui.EndCombo(ctx)
      end
    end
  end ]]
  ImGui.EndChild(ctx)
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
    --open = false
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

local function DrawExportedFXTable()
  _ = ImGui.BeginChild(ctx, '##explist', nil, list_h * 0.5, child_flags)
  _ = ImGui.BeginTable(ctx, '##exptable', 1, table_flags, nil, list_h * 0.5)
  for i = 1, #SEL_IDX do
    if not SEL_IDX[i] == true then goto continue end

    ImGui.TableNextRow(ctx)
    ImGui.TableSetColumnIndex(ctx, 0)
    local rv = false

    local xcurpos, ycurpos = ImGui.GetCursorPos(ctx)
    rv = ImGui.InvisibleButton(ctx, '##exprow' .. i, list_w, ImGui.GetFrameHeight(ctx))
    if rv then
      SEL_IDX[i] = not SEL_IDX[i]
      UpdateCanExport()
    end

    ImGui.SetCursorPos(ctx, xcurpos, ycurpos)
    if ImGui.IsItemHovered(ctx) then
      --ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_NotAllowed)
      ImGui.TableSetBgColor(ctx, 1, 0xFF000055)
    end

    ImGui.AlignTextToFramePadding(ctx)
    ImGui.Text(ctx, FX_LIST[i])

    ::continue::
  end
  ImGui.EndTable(ctx)
  ImGui.EndChild(ctx)
end
local function DrawTypeSelectors()
  local rv = false
  rv, type_filter.VST = ImGui.Checkbox(ctx, 'VST##typeVST', type_filter.VST)
  if rv then UpdateList() end
  ImGui.SameLine(ctx)

  rv, type_filter.VST3 = ImGui.Checkbox(ctx, 'VST3##typeVST3', type_filter.VST3)
  if rv then UpdateList() end
  ImGui.SameLine(ctx)

  if os > 0 then
    rv, type_filter.AU = ImGui.Checkbox(ctx, 'AU##typeAU', type_filter.AU)
    if rv then UpdateList() end
    ImGui.SameLine(ctx)
  end
  rv, type_filter.JSFX = ImGui.Checkbox(ctx, 'JSFX##typeJS', type_filter.JSFX)
  if rv then UpdateList() end
  ImGui.SameLine(ctx)

  rv, type_filter.CLAP = ImGui.Checkbox(ctx, 'CLAP##typeCLAP', type_filter.CLAP)
  if rv then UpdateList() end
  ImGui.SameLine(ctx)

  rv, type_filter.LV2 = ImGui.Checkbox(ctx, 'LV2##typeLV2', type_filter.LV2)
  if rv then UpdateList() end
end

local function DrawWindow()
  DrawSearchFilter()
  DrawTypeSelectors()

  DrawFXList()
  --ImGui.Dummy(ctx, 0, 20)
  ImGui.SeparatorText(ctx, 'Selected:')
  --ImGui.Dummy(ctx, 0, 10)
  DrawExportedFXTable()

  DrawOptions()

  ImGui.SeparatorText(ctx, '')
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

  first_frame = false
end

local function init()
  FX_LIST = GetFXList()

  for i = 1, #FX_LIST do
    SEL_IDX[i] = false
    FILTERED_IDX[i] = true
  end

  if radial_found then RADIAL_TBL = GetRadialTable() end
  --if pie_found then PIE_TBL = GetPieTable() end

  r.RecursiveCreateDirectory(export_path, 1)
end

local function Exit()
  return
end

init()
r.atexit(Exit)
r.defer(guiloop)
