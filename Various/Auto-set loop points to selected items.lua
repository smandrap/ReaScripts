-- @description Auto-set loop points to selected items (background)
-- @author smandrap
-- @version 1.2
-- @changelog
--  moar fix
-- @donation https://paypal.me/smandrap
-- @about
--   Select items -> loop points are set to those items. Useful for quickly auditioning loops.

reaper.set_action_options(5)

local reaper = reaper

local sel_items = {}
local sel_item_cnt = reaper.CountSelectedMediaItems(0)
local proj_state_cnt = reaper.GetProjectStateChangeCount(0)

local function get_items(tbl)
  tbl = tbl or {}
  local cnt = reaper.CountSelectedMediaItems(0)

  for i = 1, cnt do
    tbl[i] = reaper.GetSelectedMediaItem(0, i-1)
  end

  -- trim
  for j = cnt+1, #tbl do
    tbl[j] = nil
  end

  return tbl, cnt
end


local function items_equal(a, b, cnt)
  if #a ~= cnt or #b ~= cnt then return false end
  for i = 1, cnt do
    if a[i] ~= b[i] then return false end
  end
  return true
end


local function isProjChange()
  local new_state_cnt = reaper.GetProjectStateChangeCount(0)
  if new_state_cnt ~= proj_state_cnt then
    proj_state_cnt = new_state_cnt
    return true
  end
  return false
end

local function main()
  if isProjChange() then
    local newcnt = reaper.CountSelectedMediaItems(0)
    local new_items = {}
    get_items(new_items)

    if not items_equal(new_items, sel_items, newcnt) then
      reaper.Main_OnCommand(41039, 0) -- "set loop points"
      sel_items, sel_item_cnt = new_items, newcnt
    end
  end

  reaper.defer(main)
end

local function exit()
  reaper.set_action_options(8)
end

reaper.Main_OnCommand(41039, 0) -- "set loop points"
sel_items, sel_item_cnt = get_items(sel_items)

reaper.atexit(exit)
reaper.defer(main)
