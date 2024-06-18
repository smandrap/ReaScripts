-- @description Trim items left of cursor
-- @author smandrap
-- @version 1.1
-- @noindex
-- @donation https://paypal.me/smandrap
-- @about
--   Same as native action, but does not operate on locked actions and does not delete items if edit cursor is in a position that would delete them
-- @readme_skip


local r <const> = reaper

local CURRENT_PROJECT <const> = 0

local UNSELECT_ITM_CMDID <const> = 40289
local TRIM_LEFT_CMDID <const> = 40511
local CUR_POS <const> = r.GetCursorPosition()

---Returns a 1-based table with selected items and the table length.<br>
---If no items are selected return <code>nil</code>
---@return table|nil
---@return integer|nil
local function GetSelItems()
  local sel_itm_cnt = r.CountSelectedMediaItems(CURRENT_PROJECT)
  if sel_itm_cnt == 0 then return end

  local itm_t = {}
  local GetSelectedMediaItem = r.GetSelectedMediaItem
  for i = 1, sel_itm_cnt do itm_t[#itm_t + 1] = GetSelectedMediaItem(CURRENT_PROJECT, i - 1) end
  return itm_t, #itm_t
end

---Returns true if item can be trimmed (not locked and length would not be 0)
---@param item MediaItem
---@return boolean
local function CanTrim(item)
  if not reaper.ValidatePtr(item, 'MediaItem*') then return false end
  if r.GetMediaItemInfo_Value(item, 'D_POSITION') + r.GetMediaItemInfo_Value(item, 'D_LENGTH') == CUR_POS then return false end
  if r.GetMediaItemInfo_Value(item, 'C_LOCK') == 1 then return false end

  return true
end

---Temporarily select the item and trim it
---@param item MediaItem
---@return MediaItem new_item #The media item created after the trim
local function TrimItem(item)
  r.SetMediaItemSelected(item, true)
  r.Main_OnCommand(TRIM_LEFT_CMDID, 0)
  local new_item = r.GetSelectedMediaItem(CURRENT_PROJECT, 0)
  r.SetMediaItemSelected(new_item, false)

  return new_item
end

---Set all items in table (1-based) passed as argument as selected<br>
---Optionally pass <code>cnt</code> to avoid table calculation
---@param item_t table
local function SetItemsSelected(item_t, cnt)
  cnt = cnt or #item_t
  local SetMediaItemSelected = r.SetMediaItemSelected

  for i = 1, cnt do
    if reaper.ValidatePtr(item_t[i], 'MediaItem*') then
      SetMediaItemSelected(item_t[i], true) 
    end
  end
end

local function main()
  local sel_itm, cnt = GetSelItems()
  if not sel_itm then return end

  r.Main_OnCommand(UNSELECT_ITM_CMDID, 0)

  for i = 1, cnt do
    if CanTrim(sel_itm[i]) then
      sel_itm[i] = TrimItem(sel_itm[i])
    end
  end

  SetItemsSelected(sel_itm, cnt)
end

r.Undo_BeginBlock()
main()
r.Undo_EndBlock("Trim items left of cursor", 0)