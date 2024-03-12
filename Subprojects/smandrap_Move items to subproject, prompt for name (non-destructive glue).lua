-- @description Move items to subproject, prompt for name (non-destructive glue)
-- @author smandrap
-- @version 1.0
-- @noindex
-- @donation https://paypal.me/smandrap
-- @about
--   Does what it says. Requires SWS.
-- @readme_skip


PREFIX_PROJECT_NAME = false
USE_SUBFOLDER = false

local LABEL = 'SubProject'
local SUBFOLDER = 'SubProjects'

if reaper.CountSelectedTracks(0) == 0 then return end

local swsok = false
if not reaper.CF_GetSWSVersion then 
  reaper.MB("This script requires SWS extensions", "SWS REQUIRED", 0)
end

local function main()
  local rec_path = select(2, reaper.GetSetProjectInfo_String(0, 'RECORD_PATH', '', false))
  local _, rec_filename = reaper.get_config_var_string('recfile_wildcards')
  
  local rv, LABEL = reaper.GetUserInputs('Move items to subproject', 1, 'extrawidth=100,Name:', LABEL)
  if rv then 
    reaper.SNM_SetStringConfigVar('recfile_wildcards', PREFIX_PROJECT_NAME and '$project - 'or ''..LABEL)
  
    if USE_SUBFOLDER then reaper.GetSetProjectInfo_String(0, 'RECORD_PATH', SUBFOLDER, true) end
    reaper.Main_OnCommand(41997, 0)
    reaper.GetSetProjectInfo_String(0, 'RECORD_PATH', rec_path, true)
  
    if swsok then reaper.SNM_SetStringConfigVar('recfile_wildcards', rec_filename) end
  end
end


reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock('Move tracks to subproject, prompt for name', 0)
