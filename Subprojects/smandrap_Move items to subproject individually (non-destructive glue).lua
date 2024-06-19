-- @description Move items to subproject individually (non-destructive glue)
-- @author smandrap
-- @version 1.0
-- @changelog
--  Testing this
-- @noindex
-- @donation https://paypal.me/smandrap
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

local function CreateSubProjectLabel(item)
  local take = r.GetActiveTake(item)
  if not take then return 'SubProject' end -- Guard against something not returning correctly

  local _, item_name = r.GetSetMediaItemTakeInfo_String(take, 'P_NAME', '', false)
  item_name = item_name:gsub('%..*$', '') -- Strip file extension from take name

  return item_name == '' and 'SubProject' or item_name
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

local function CreateSubProject(project_instance)
  
  r.SelectProjectInstance(project_instance)
  r.Main_OnCommandEx(41996, 0, project_instance)
  
end

---Wrapper for native reaper action 48289, for readability
local function UnselectAllItems() r.Main_OnCommand(40289, 0) end

local function main()
  -- local ok, label = GetSubProjectLabelFromInput()
  -- if not ok then return end

  local project_instance = r.EnumProjects(-1)

  local sel_items = {}

  for i = 0, r.CountSelectedMediaItems(0) - 1 do
    sel_items[#sel_items + 1] = r.GetSelectedMediaItem(0, i)
  end

  r.Undo_BeginBlock()

  for i = 1, #sel_items do
    if not r.ValidatePtr(sel_items[i], 'MediaItem*') then goto continue end

    UnselectAllItems()
    r.SetMediaItemSelected(sel_items[i], true)

    local label = CreateSubProjectLabel(sel_items[i])

    SetRecFileName(label)
    SetRecPath(label)

    CreateSubProject(project_instance)
    ::continue::
  end

  r.Undo_EndBlock('Move items to subproject', -1)
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

local function noundo() r.defer(function() end) end

if r.CountSelectedMediaItems(0) == 0 then
  noundo()
  return
end

r.atexit(Exit)
xpcall(main, err)
