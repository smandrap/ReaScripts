-- @description Insert new subproject in Subproject folder (prompt for name)
-- @author smandrap
-- @version 1.1
-- @changelog
--  Refactor, but still doesn't work as desired.. oooof
-- @noindex
-- @donation https://paypal.me/smandrap
-- @about
--   Does What it says. If sws is installed, prefix name with "Subproject"
-- @readme_skip


local LABEL = 'SubProject'
local PREFIX_PROJECT_NAME = true
local SUBFOLDER_NAME = 'SubProjects'

local r = reaper

if not r.CF_GetSWSVersion then
  r.MB("This script requires SWS extensions", "SWS REQUIRED", 0)
  return
end

local orig_recpath = select(2, r.GetSetProjectInfo_String(0, 'RECORD_PATH', '', false))
local _, orig_recfile = r.get_config_var_string('recfile_wildcards')

local function SetRecFileName()
  local full_label = PREFIX_PROJECT_NAME and '$project - ' .. LABEL or LABEL
  r.SNM_SetStringConfigVar('recfile_wildcards', full_label)
end

function SetRecPath()
  r.GetSetProjectInfo_String(0, 'RECORD_PATH', SUBFOLDER_NAME, true)
end

local function CreateSubProject()
  r.Undo_BeginBlock()
  r.Main_OnCommand(41049, 0) -- Insert Subproject
  r.Undo_EndBlock('Insert SubProject in Subprojects folder', 0)
end

local function main()
  SetRecFileName()
  SetRecPath()
  CreateSubProject()
end


local function RestorePaths()
  r.GetSetProjectInfo_String(0, 'RECORD_PATH', orig_recpath, true)
  r.SNM_SetStringConfigVar('recfile_wildcards', orig_recfile)
end


local function err(e)
  RestorePaths()
  r.ShowConsoleMsg(e .. '\n\n')
  r.ShowConsoleMsg(debug.traceback())
end

local function Exit()
  RestorePaths()
end

r.atexit(Exit)
xpcall(main, err)
