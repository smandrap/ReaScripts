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

local function InsertSubprojecFromTemplate()
  --local fileok, fn = reaper.GetUserFileNameForRead('ciao', 'Test', 'Test')

  local sep = package.config:sub(1, 1)

  local template_folder = table.concat({ reaper.GetResourcePath(), sep, 'ProjectTemplates' })
  local ok, template = reaper.JS_Dialog_BrowseForOpenFiles('Template', template_folder, '', '.RPP', false)
  if not ok then return end

  local f = io.open(template, 'r')
  if f == nil then return end

  local buf = f:read('*all')
  f:close()

  local rec_path = reaper.GetProjectPath()
  local new_file_path = table.concat({ rec_path, sep, 'new_subproject.rpp' })

  f = io.open(new_file_path, 'w+')
  f:write(buf)
  f:close()

  reaper.Main_OnCommand(40289, 0) -- Clear item selection
  reaper.InsertMedia(new_file_path, 0)
  reaper.Main_OnCommand(41816, 0) -- open associated project in tab
end


-- GUI

local ctx = reaper.ImGui_CreateContext(script_name)
local visible, open
local window_flags = reaper.ImGui_WindowFlags_None()
local font = reaper.ImGui_CreateFont('sans-serif', 12)
reaper.ImGui_Attach(ctx, font)


local function DrawWindow()
  if reaper.ImGui_Button(ctx, 'DOIT') then
    InsertSubprojecFromTemplate()
  end
end

local function guiloop()
  reaper.ImGui_SetNextWindowSize(ctx, 300, 400, reaper.ImGui_Cond_FirstUseEver())
  reaper.ImGui_PushFont(ctx, font)
  visible, open = reaper.ImGui_Begin(ctx, script_name, true, window_flags)

  if visible then
    DrawWindow()
    reaper.ImGui_End(ctx)
  end
  reaper.ImGui_PopFont(ctx)

  if open then
    reaper.defer(guiloop)
  end
end

reaper.defer(guiloop)
