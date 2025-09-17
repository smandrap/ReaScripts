-- @description Auto-set loop points to selected items (background)
-- @author smandrap
-- @version 1.0
-- @donation https://paypal.me/smandrap
-- @about
--   Select items -> loop points are set to those items. Useful for quickly auditioning loops.

reaper.set_action_options(5)

local reaper = reaper
local sel_item_cnt = reaper.CountSelectedMediaItems(0)

local function isProjChange()
  local new_state_cnt =  reaper.GetProjectStateChangeCount(0)
  if new_state_cnt ~= proj_state_cnt then
    proj_state_cnt = new_state_cnt
    return true
  end
  return false
end

local function main()
  if isProjChange() then
    local newcnt = reaper.CountSelectedMediaItems(0)
    if newcnt ~= sel_item_cnt then
      reaper.Main_OnCommand(41039, 0)
      sel_item_cnt = newcnt
    end
  end
  
  reaper.defer(main)
end

local function exit()
  reaper.set_action_options(8)
end

reaper.atexit(exit)
reaper.defer(main)
