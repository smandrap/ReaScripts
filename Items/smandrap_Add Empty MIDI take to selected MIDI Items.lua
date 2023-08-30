-- @description Add Empty MIDI take to selected MIDI Items
-- @author smandrap
-- @version 1.0
-- @changelog Initial release


local reaper = reaper

local sel_item_cnt = reaper.CountSelectedMediaItems(0)
if sel_item_cnt == 0 then return end

local sel_items = {}

local function AddEmptyMidiTake(item, take)

  reaper.Main_OnCommand(40639, 0) -- Duplicate Active Take
  
  local new_take = reaper.GetActiveTake(item)
  
  local _, midi_string = reaper.MIDI_GetAllEvts(take)
  local note_off_msg = midi_string:sub(-13) -- Magic thing... Shouln't this be -12 ???
  
  reaper.MIDI_SetAllEvts(new_take, note_off_msg)
end

local function main()

  -- SAVE ITEM SELECTION
  for i = 0, sel_item_cnt - 1 do
    sel_items[i] = reaper.GetSelectedMediaItem(0, i)
  end
  
  reaper.Main_OnCommand(40289, 0) -- Deselect all items
  
  
  for i = 0, sel_item_cnt - 1 do
  
    local item = sel_items[i]
    reaper.SetMediaItemSelected(item, true)
    
    local take = reaper.GetActiveTake(item)
    
    if reaper.TakeIsMIDI(take) then 
      AddEmptyMidiTake(item, take)
    end

    reaper.SetMediaItemSelected(item, false)
    
  end
  
  for i = 0, sel_item_cnt - 1 do
    reaper.SetMediaItemSelected(sel_items[i], true)
  end
  
end

reaper.Undo_BeginBlock()
main()
reaper.UpdateArrange()
reaper.Undo_EndBlock("Add Empty MIDI Take to Selected MIDI Items", 0)
