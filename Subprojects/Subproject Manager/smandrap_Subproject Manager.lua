-- @description Insert Subproject
-- @author smandrap
-- @version 1.0
-- @donation https://paypal.me/smandrap
-- @about
--   Noice interface for subproject insertion

dofile(reaper.GetResourcePath() ..
  '/Scripts/ReaTeam Extensions/API/imgui.lua') '0.9'

local reaper = reaper
local script_name = "Insert Subproject"

if not reaper.ImGui_GetVersion() then
  local ok = reaper.MB('Install now?', 'ReaImGui Missing', 1)
  if ok == 1 then reaper.ReaPack_BrowsePackages("ReaImGui API") end
  return
end

-- APP

local _ = nil
local os_sep = package.config:sub(1, 1)
local rec_path = reaper.GetProjectPath():gsub("(.+)"..os_sep..".+$", "%1"..os_sep)

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

local ctx = reaper.ImGui_CreateContext(script_name)
local visible, open
local window_flags = reaper.ImGui_WindowFlags_None() | reaper.ImGui_WindowFlags_AlwaysAutoResize()
local font = reaper.ImGui_CreateFont('sans-serif', 12)

local first_frame = true
local btn_w = 80

reaper.ImGui_Attach(ctx, font)

local function DrawOkCancelButtons()
  reaper.ImGui_Dummy(ctx, 0, 10)
  reaper.ImGui_Separator(ctx)
  reaper.ImGui_Dummy(ctx, 0, 2)

  reaper.ImGui_SetCursorPosX(ctx, reaper.ImGui_GetWindowWidth(ctx) - btn_w * 2 - 15)


  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x5D5D5DAA)
  if reaper.ImGui_Button(ctx, "Cancel", btn_w) then open = false end
  reaper.ImGui_PopStyleColor(ctx)
  reaper.ImGui_SameLine(ctx)

  reaper.ImGui_SetCursorPosX(ctx, reaper.ImGui_GetWindowWidth(ctx) - btn_w - 10)
  if reaper.ImGui_Button(ctx, "OK", btn_w) and can_perform then
    main()
    open = false
  end
end

-- TODO: Sanitize input and add .RPP extension
local function DrawSubprojNameInput()
  reaper.ImGui_Text(ctx, 'SubProject Name :')
  reaper.ImGui_PushItemWidth(ctx, 200)
  if first_frame then reaper.ImGui_SetKeyboardFocusHere(ctx) end
  local ok = false

  ok, subproject_name = reaper.ImGui_InputText(ctx, '##txtin_subprojName', subproject_name)
  ok = reaper.ImGui_IsItemDeactivatedAfterEdit(ctx)

  reaper.ImGui_SameLine(ctx, nil, 0)
  reaper.ImGui_Text(ctx, '.RPP')
  if subproject_name == '' then
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_TextColored(ctx, 0xFF0000FF, 'Invalid Name')
    can_perform = false
  end

  -- TODO: move this shit somewhere else, but also refactor
  if ok == true then
    subproject_complete_fn = subproject_name:gsub("(.+)%.[rR][pP][pP]", '%1') .. subproject_ext
    file_exists = reaper.file_exists(subproject_path .. os_sep .. subproject_complete_fn)
  end
  if file_exists then   -- TODO: move this shit after path selection
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_TextColored(ctx, 0xFF0000FF, 'File already exists')
    can_perform = false
  else
    can_perform = true
  end
end

local function DrawPathSelector()
  reaper.ImGui_Text(ctx, 'Path :')
  reaper.ImGui_PushItemWidth(ctx, 400)
  _, subproject_path = reaper.ImGui_InputText(ctx, '##txtin_subprojFn', subproject_path)
  reaper.ImGui_SameLine(ctx, nil, 2)
  if reaper.ImGui_Button(ctx, '...##btn_pathselect') then
    local ok, temp_path = reaper.JS_Dialog_BrowseForFolder('Select Location', subproject_path)
    if ok == 1 then subproject_path = temp_path end
  end
end

local function DrawTemplateFileSelector()
  reaper.ImGui_Text(ctx, 'Template File :')
  reaper.ImGui_PushItemWidth(ctx, 400)
  _, template_path = reaper.ImGui_InputText(ctx, '##txtin_templateFn', template_path)
  reaper.ImGui_SameLine(ctx, nil, 2)
  if reaper.ImGui_Button(ctx, '...##btn_templatepathselect') then
    local ok, temp_path = reaper.JS_Dialog_BrowseForOpenFiles('Select Template', template_folder, '', '.rpp', false)
    if ok then template_path = temp_path end
  end
end

local function DrawParentProjectNameShit()
  _, append_parent_name = reaper.ImGui_Checkbox(ctx, '##append_parentname', append_parent_name)
  reaper.ImGui_SameLine(ctx, nil, 2)
  reaper.ImGui_PushItemWidth(ctx, 65)
  _, parent_name_position = reaper.ImGui_Combo(ctx, '##prepostfix_combo', parent_name_position, 'Prefix\0Postfix\0')
  reaper.ImGui_SameLine(ctx)
  --reaper.ImGui_AlignTextToFramePadding(ctx)
  reaper.ImGui_Text(ctx, 'parent project name')
end

local function DrawWindow()
  DrawSubprojNameInput()
  DrawParentProjectNameShit()

  reaper.ImGui_Dummy(ctx, 0, 5)
  DrawPathSelector()

  reaper.ImGui_Dummy(ctx, 0, 10)
  _, use_template = reaper.ImGui_Checkbox(ctx, 'Create from Project Template', use_template)

  if use_template then DrawTemplateFileSelector() end

  DrawOkCancelButtons()
end

local function guiloop()
  reaper.ImGui_SetNextWindowSize(ctx, 300, 400, reaper.ImGui_Cond_FirstUseEver())
  reaper.ImGui_PushFont(ctx, font)
  visible, open = reaper.ImGui_Begin(ctx, script_name, true, window_flags)

  if visible then
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 5)
    DrawWindow()
    reaper.ImGui_PopStyleVar(ctx)
    reaper.ImGui_End(ctx)
  end
  reaper.ImGui_PopFont(ctx)

  if open then
    reaper.defer(guiloop)
  end

  first_frame = false
end

reaper.defer(guiloop)
