-- @description Insert Subproject
-- @author smandrap
-- @version 1.0
-- @donation https://paypal.me/smandrap
-- @about
--   Noice interface for subproject insertion

local reaper = reaper
local script_name = "Insert Subproject"

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9'

if not ImGui.GetVersion() then
  local ok = reaper.MB('Install now?', 'ReaImGui Missing', 1)
  if ok == 1 then reaper.ReaPack_BrowsePackages("ReaImGui API") end
  return
end

-- APP

local _ = nil
local os = reaper.GetOS():match("Win") and 0 or 1
local os_sep = package.config:sub(1, 1)
local rec_path = reaper.GetProjectPath():gsub("(.+)" .. os_sep .. ".+$", "%1" .. os_sep)

local can_perform = true

local subproject_path = rec_path
local subproject_name = 'New subproject'
local subproject_ext = '.RPP'

local subproject_complete_fn = table.concat({ subproject_name, subproject_ext })

local parent_project_name = reaper.GetProjectName(0)
local append_parent_name = false
local parent_name_position = 0 -- 0 Prefix, 1 PostFix
local file_exists = false

local displayed_filename = subproject_complete_fn

local use_template = false

local template_folder = table.concat({ reaper.GetResourcePath(), os_sep, 'ProjectTemplates' })
local template_path = ''

local function InsertSubprojecFromTemplate()
  --local fileok, fn = reaper.GetUserFileNameForRead('ciao', 'Test', 'Test')

  local ok, template = reaper.JS_Dialog_BrowseForOpenFiles('Template', template_folder, '', '.RPP', false)
  if not ok then return end

  local f = io.open(template, 'r')
  if f == nil then return end

  local buf = f:read('*all')
  f:close()


  local new_file_path = table.concat({ rec_path, os_sep, 'new_subproject.rpp' })

  f = io.open(new_file_path, 'w+')
  if f == nil then return end
  f:write(buf)
  f:close()

  reaper.Main_OnCommand(40289, 0) -- Clear item selection
  reaper.InsertMedia(new_file_path, 0)
  reaper.Main_OnCommand(41816, 0) -- open associated project in tab
end

local function main()
  InsertSubprojecFromTemplate()
end


-- GUI

local ctx = ImGui.CreateContext(script_name)
local visible, open
local window_flags = ImGui.WindowFlags_None | ImGui.WindowFlags_AlwaysAutoResize
local font = ImGui.CreateFont('sans-serif', 12)

local first_frame = true
local btn_w = 80

ImGui.Attach(ctx, font)

local function DrawOkCancelButtons()
  ImGui.Dummy(ctx, 0, 10)
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 2)

  ImGui.SetCursorPosX(ctx, ImGui.GetWindowWidth(ctx) - btn_w * 2 - 15)


  ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0x5D5D5DAA)
  if ImGui.Button(ctx, "Cancel", btn_w) then open = false end
  ImGui.PopStyleColor(ctx)
  ImGui.SameLine(ctx)

  ImGui.SetCursorPosX(ctx, ImGui.GetWindowWidth(ctx) - btn_w - 10)
  if ImGui.Button(ctx, "OK", btn_w) and can_perform then
    main()
    open = false
  end
end

local inputCallback_filename_win = ImGui.CreateFunctionFromEEL([[
  (EventChar == '<') ||
  (EventChar == '>') ||
  (EventChar == ':') ||
  (EventChar == '/') ||
  (EventChar == '\\')||
  (EventChar == '|') ||
  (EventChar == '?') ||
  (EventChar == '*')  ? EventChar = 0;
]])

local inputCallback_filename_unix = ImGui.CreateFunctionFromEEL([[
  (EventChar == '/') ? EventChar = 0;
]])

local function InputTextFileName(label, var)
  local ok = false
  ok, var = ImGui.InputText(ctx, label, var, ImGui.InputTextFlags_CallbackCharFilter,
    os == 0 and inputCallback_filename_win or inputCallback_filename_unix)
  return ok, var
end

-- TODO: Sanitize input and add .RPP extension
local function DrawSubprojNameInput()
  ImGui.Text(ctx, 'SubProject Name :')
  ImGui.PushItemWidth(ctx, 200)
  if first_frame then ImGui.SetKeyboardFocusHere(ctx) end
  local ok = false

  ok, subproject_name = InputTextFileName('##txtin_subprojName', subproject_name)
  ok = ImGui.IsItemDeactivatedAfterEdit(ctx)

  ImGui.SameLine(ctx, nil, 0)
  ImGui.Text(ctx, '.RPP')
  if subproject_name == '' then
    ImGui.SameLine(ctx)
    ImGui.TextColored(ctx, 0xFF0000FF, 'Invalid Name')
    can_perform = false
  end


  -- TODO: move this shit somewhere else, but also refactor
  if ok == true then
    subproject_complete_fn = subproject_name:gsub("(.+)%.[rR][pP][pP]", '%1') .. subproject_ext
    file_exists = reaper.file_exists(subproject_path .. os_sep .. subproject_complete_fn)
  end
  if file_exists then -- TODO: move this shit after path selection
    ImGui.SameLine(ctx)
    ImGui.TextColored(ctx, 0xFF0000FF, 'File already exists')
    can_perform = false
  else
    can_perform = true
  end
end

local function DrawPathSelector()
  ImGui.Text(ctx, 'Path :')
  ImGui.PushItemWidth(ctx, 400)
  --_, subproject_path = ImGui.InputText(ctx, '##txtin_subprojFn', subproject_path)
  ImGui.InputText(ctx, '##txtin_subprojFn', subproject_path, ImGui.InputTextFlags_ReadOnly | ImGui.InputTextFlags_AutoSelectAll)
  if ImGui.IsItemHovered(ctx) then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_NotAllowed) end
  ImGui.SameLine(ctx, nil, 2)
  if ImGui.Button(ctx, '...##btn_pathselect') then
    local ok, temp_path = reaper.JS_Dialog_BrowseForFolder('Select Location', subproject_path)
    if ok == 1 then subproject_path = temp_path end
  end
end

local function DrawTemplateFileSelector()
  ImGui.Text(ctx, 'Template File :')
  ImGui.PushItemWidth(ctx, 400)
  --_, template_path = ImGui.InputText(ctx, '##txtin_templateFn', template_path)
  ImGui.InputText(ctx, '##txtin_templateFn', template_path, ImGui.InputTextFlags_ReadOnly | ImGui.InputTextFlags_AutoSelectAll)
  if ImGui.IsItemHovered(ctx) then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_NotAllowed) end
  ImGui.SameLine(ctx, nil, 2)
  if ImGui.Button(ctx, '...##btn_templatepathselect') then
    local ok, temp_path = reaper.JS_Dialog_BrowseForOpenFiles('Select Template', template_folder, '', '.rpp', false)
    if ok then template_path = temp_path end
  end
end

local function DrawParentProjectNameShit()
  _, append_parent_name = ImGui.Checkbox(ctx, '##append_parentname', append_parent_name)
  ImGui.SameLine(ctx, nil, 2)
  ImGui.PushItemWidth(ctx, 65)
  _, parent_name_position = ImGui.Combo(ctx, '##prepostfix_combo', parent_name_position, 'Prefix\0Postfix\0')
  ImGui.SameLine(ctx)
  --ImGui.AlignTextToFramePadding(ctx)
  ImGui.Text(ctx, 'parent project name')
end

local function DrawWindow()
  DrawSubprojNameInput()
  DrawParentProjectNameShit()

  ImGui.Dummy(ctx, 0, 5)
  DrawPathSelector()

  ImGui.Dummy(ctx, 0, 10)
  _, use_template = ImGui.Checkbox(ctx, 'Create from Project Template', use_template)

  if use_template then DrawTemplateFileSelector() end

  DrawOkCancelButtons()
end

local function guiloop()
  ImGui.SetNextWindowSize(ctx, 300, 400, ImGui.Cond_FirstUseEver)
  ImGui.PushFont(ctx, font)
  visible, open = ImGui.Begin(ctx, script_name, true, window_flags)

  if visible then
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameRounding, 5)
    DrawWindow()
    ImGui.PopStyleVar(ctx)
    ImGui.End(ctx)
  end
  ImGui.PopFont(ctx)

  if open then
    reaper.defer(guiloop)
  end

  first_frame = false
end

reaper.defer(guiloop)
