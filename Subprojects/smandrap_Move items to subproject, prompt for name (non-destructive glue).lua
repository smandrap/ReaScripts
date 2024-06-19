-- @description Move items to subproject, prompt for name (non-destructive glue)
-- @author smandrap
-- @version 1.2
-- @changelog
--  Fix a bunch of things
-- @noindex
-- @donation https://paypal.me/smandrap
-- @about
--   Does what it says. Requires SWS.
-- @readme_skip



PREFIX_PROJECT_NAME = true -- Prefix the subproject with the parent project name
CREATE_SUBDIRECTORY = true -- Self-Contain the subproject in its own folder
USE_SUBFOLDER = true       -- Create the subproject in a subfolder next to parent project location
SUBFOLDER = 'SubProjects'  -- Name of the subfolder

local r = reaper

local swsok = false
if not r.CF_GetSWSVersion then
  r.MB("This script requires SWS extensions", "SWS REQUIRED", 0)
end


local rec_path = select(2, r.GetSetProjectInfo_String(0, 'RECORD_PATH', '', false))
local _, rec_filename = r.get_config_var_string('recfile_wildcards')

local os_sep = package.config:sub(1, 1)

local function CreateProjectLabel()
  local first_sel_take = r.GetActiveTake(r.GetSelectedMediaItem(0, 0))

  local _, itemname = r.GetSetMediaItemTakeInfo_String(first_sel_take, 'P_NAME', '', false)
  itemname = itemname:gsub('%..*$', '')

  return itemname
end

local function main()
  local rv, LABEL = r.GetUserInputs('Move items to subproject', 1, 'extrawidth=100,Name:', CreateProjectLabel())
  if not rv then return end

  local final_label = ('%s - %s'):format(PREFIX_PROJECT_NAME and '$project' or '', LABEL)
  r.SNM_SetStringConfigVar('recfile_wildcards', final_label)

  if USE_SUBFOLDER then
    local proj_name = r.GetProjectName():gsub('%.RPP$', '')
    local new_path = CREATE_SUBDIRECTORY and ("%s%s%s - %s"):format(SUBFOLDER, os_sep, proj_name, LABEL) or SUBFOLDER
    r.GetSetProjectInfo_String(0, 'RECORD_PATH', new_path, true)
  end

  r.Undo_BeginBlock()
  r.Main_OnCommand(41996, 0)
  r.Undo_EndBlock('Move items to subproject', 0)
end

local function RestorePaths()
  r.GetSetProjectInfo_String(0, 'RECORD_PATH', rec_path, true)
  r.SNM_SetStringConfigVar('recfile_wildcards', rec_filename)
end

local function err()
  RestorePaths()
  r.ShowConsoleMsg(debug.traceback())
end

local function Exit()
  RestorePaths()
end

local function noundo() r.defer(function() end) end

if r.CountSelectedMediaItems(0) == 0 then
  noundo()
  return
end
r.atexit(Exit)
xpcall(main, err)
