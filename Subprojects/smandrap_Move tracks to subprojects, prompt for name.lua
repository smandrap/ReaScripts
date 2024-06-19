-- @description Move tracks to subprojects, prompt for name
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
local is_debug = false


local swsok = false
if not r.CF_GetSWSVersion then
  r.MB("This script requires SWS extensions", "SWS REQUIRED", 0)
end

local function print(s)
  if is_debug then r.ShowConsoleMsg(tostring(s)) end
end

local os_sep = package.config:sub(1, 1)

local rec_path = select(2, r.GetSetProjectInfo_String(0, 'RECORD_PATH', '', false))
local _, rec_filename = r.get_config_var_string('recfile_wildcards')

local function CreateProjectLabel()
  local tr = r.GetSelectedTrack(0, 0)

  local _, trname = r.GetSetMediaTrackInfo_String(tr, 'P_NAME', '', false)
  return trname == '' and 'SubProject' or trname
end

local function main()
  local rv, LABEL = r.GetUserInputs('Move Tracks to subproject', 1, 'extrawidth=100,Name:', CreateProjectLabel())
  if not rv then return end

  local final_label = ('%s - %s'):format(PREFIX_PROJECT_NAME and '$project' or '', LABEL)
  r.SNM_SetStringConfigVar('recfile_wildcards', final_label)

  if USE_SUBFOLDER then
    local proj_name = r.GetProjectName():gsub('%.RPP$', '')
    local new_path = CREATE_SUBDIRECTORY and ("%s%s%s - %s"):format(SUBFOLDER, os_sep, proj_name, LABEL) or SUBFOLDER
    r.GetSetProjectInfo_String(0, 'RECORD_PATH', new_path, true)
  end

  r.Undo_BeginBlock()
  r.Main_OnCommand(41997, 0)
  r.Undo_EndBlock('Move Tracks to subproject', 0)
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

if r.CountSelectedTracks(0) == 0 then
  noundo()
  return
end
r.atexit(Exit)
xpcall(main, err)
