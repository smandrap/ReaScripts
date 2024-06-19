-- @description Move tracks to subprojects, prompt for name
-- @author smandrap
-- @version 1.3
-- @changelog
--  Fix a bunch more things
-- @noindex
-- @donation https://paypal.me/smandrap
-- @about
--   Does what it says. Requires SWS.
-- @readme_skip


PREFIX_PROJECT_NAME = true     -- Prefix the subproject with the parent project name
CREATE_SUBDIRECTORY = true     -- Self-Contain the subproject in its own folder
USE_SUBFOLDER = true           -- Create the subproject in a subfolder next to parent project location
SUBFOLDER_NAME = 'SubProjects' -- Name of the subfolder

local r = reaper

if not r.CF_GetSWSVersion then
  r.MB("This script requires SWS extensions", "SWS REQUIRED", 0)
  return
end

local orig_recpath = select(2, r.GetSetProjectInfo_String(0, 'RECORD_PATH', '', false))
local _, orig_recfile = r.get_config_var_string('recfile_wildcards')

local os_sep = package.config:sub(1, 1)

local function CreateSubProjectLabel()
  local first_sel_track = r.GetSelectedTrack(0, 0)
  if not first_sel_track then return end

  local _, track_name = r.GetSetMediaTrackInfo_String(first_sel_track, 'P_NAME', '', false)
  track_name = track_name:gsub("^%s+(.*)%s+$", "%1")

  return track_name == '' and 'SubProject' or track_name
end

local function GetSubProjectLabelFromInput()
  local rv, label = r.GetUserInputs('Move Tracks to subproject', 1, 'extrawidth=100,Name:', CreateSubProjectLabel())
  label = label:gsub("^%s+(.*)%s+$", "%1")
  return rv, label == '' and 'SubProject' or label
end

local function SetRecFileName(name)
  local subproject_name = ('%s - %s'):format(PREFIX_PROJECT_NAME and '$project' or '', name)
  r.SNM_SetStringConfigVar('recfile_wildcards', subproject_name)
end

local function SetRecPath(label)
  local new_path = orig_recpath

  if CREATE_SUBDIRECTORY then
    new_path = label

    if PREFIX_PROJECT_NAME then
      local parent_proj_name = r.GetProjectName():gsub('%.RPP$', '')
      new_path = ("%s - %s"):format(parent_proj_name, new_path)
    end
  end

  if USE_SUBFOLDER then new_path = ("%s%s%s"):format(SUBFOLDER_NAME, os_sep, new_path) end

  r.GetSetProjectInfo_String(0, 'RECORD_PATH', new_path, true)
end

local function CreateSubProject()
  r.Undo_BeginBlock()
  r.Main_OnCommand(41997, 0)
  r.Undo_EndBlock('Move tracks to subproject', 0)
end

local function main()
  local ok, label = GetSubProjectLabelFromInput()
  if not ok then return end

  SetRecFileName(label)
  SetRecPath(label)

  CreateSubProject()
end

local function RestorePaths()
  r.GetSetProjectInfo_String(0, 'RECORD_PATH', orig_recpath, true)
  r.SNM_SetStringConfigVar('recfile_wildcards', orig_recfile)
end

local function err(e)
  RestorePaths()
  r.ShowConsoleMsg(e..'\n\n')
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
