-- @description Insert new subproject in Subproject folder (prompt for name)
-- @author smandrap
-- @version 1.0
-- @noindex
-- @donation https://paypal.me/smandrap
-- @about
--   Does what it says. If SWS is installed, prefix label with "Subproject"
-- @readme_skip


local LABEL = 'SubProject'
local SUBFOLDER = 'SubProjects'


local swsok = false
if reaper.CF_GetSWSVersion then swsok = true end

local function main()
  local rec_path = select(2, reaper.GetSetProjectInfo_String(0, 'RECORD_PATH', '', false))
  local _, rec_filename = reaper.get_config_var_string('recfile_wildcards')

  if swsok then reaper.SNM_SetStringConfigVar('recfile_wildcards', '$project - '..LABEL) end
  
  reaper.GetSetProjectInfo_String(0, 'RECORD_PATH', SUBFOLDER, true)
  reaper.Main_OnCommand(41049, 0) -- Insert Subproject
  reaper.GetSetProjectInfo_String(0, 'RECORD_PATH', rec_path, true)
  
  if swsok then reaper.SNM_SetStringConfigVar('recfile_wildcards', rec_filename) end
end


reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock('Insert SubProject', 0)
