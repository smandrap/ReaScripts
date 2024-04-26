--local fileok, fn = reaper.GetUserFileNameForRead('ciao', 'Test', 'Test')

local sep = package.config:sub(1, 1)

local template_folder = table.concat({reaper.GetResourcePath(), sep, 'ProjectTemplates'})
local ok, template = reaper.JS_Dialog_BrowseForOpenFiles('Template', template_folder, '', '.RPP', false)
if not ok then return end

local f = io.open(template, 'r')
if f == nil then return end

local buf = f:read('*all')
f:close()

local rec_path = reaper.GetProjectPath()
local new_file_path = table.concat({rec_path, sep, 'new_subproject.rpp'})

f = io.open(new_file_path, 'w+')
f:write(buf)
f:close()

reaper.Main_OnCommand(40289, 0) -- Clear item selection
reaper.InsertMedia(new_file_path, 0)
reaper.Main_OnCommand(41816, 0) -- open associated project in tab

