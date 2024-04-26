-- @description DESC
-- @author smandrap
-- @version 1.0
-- @donation https://paypal.me/smandrap
-- @about
--   ABOUT

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
local rec_path = reaper.GetProjectPath()

local subproject_path = rec_path

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
  if reaper.ImGui_Button(ctx, "OK", btn_w) then
    main()
    open = false
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
    local ok, temp_path = reaper.JS_Dialog_BrowseForOpenFiles('Select Template', template_folder, '','.rpp', false)
    if ok then template_path = temp_path end
  end
end

local function DrawWindow()
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
end

reaper.defer(guiloop)
