-- @description Quantize all or selected notes
-- @author smandrap
-- @version 1.1
-- @provides midi_editor
-- @donation https://paypal.me/smandrap
-- @about
--   sproost request. https://forum.cockos.com/showthread.php?t=283072
--
--   If no notes are selected, quantize them all. Otherwise quantize selected


local hwnd = reaper.MIDIEditor_GetActive()
if not hwnd then return end
local take = reaper.MIDIEditor_GetTake(hwnd)
if not take then return end

 
local selection = reaper.MIDI_EnumSelNotes(take, 0)

if selection == -1 then
  reaper.MIDIEditor_OnCommand(hwnd, 40003) -- select all
  reaper.MIDIEditor_OnCommand(hwnd, 40469) -- quantize
  reaper.MIDIEditor_OnCommand(hwnd, 40214) -- unselect all
  return
end


reaper.MIDIEditor_OnCommand(hwnd, 40469) -- quantize
