local reaper = reaper

--TODO: GUI
--TODO: Restore state of "ignore project tempo" on items 
--TODO: Scale all tempo markers in between the target bars
--TODO: implement stevie insert/delete bars
--TODO: Preserve tempo at end of changes
--TODO: Replace bars


local start_bar = 1
local length_in_bars = 2
local target_timesig_num = 3
local target_timesig_denom = 4

local tempos = {}

for i = start_bar, (start_bar + length_in_bars) - 1 do
  local _, _, _, timesig_nom, timesig_denom, tempo = reaper.TimeMap_GetMeasureInfo(0, i)
  tempos[i] = {
    timesig_num = timesig_num,
    timesig_denom = timesig_denom,
    tempo = tempo
  }
end

local sel_items = {}
local midi_items = {}


for i = 1, reaper.CountMediaItems(0) do
  local item = reaper.GetMediaItem(0, i - 1)
  if reaper.IsMediaItemSelected(item) then sel_items[#sel_items + 1] = item end
  if reaper.TakeIsMIDI(reaper.GetActiveTake(item)) then midi_items[#midi_items + 1] = item end
end

reaper.Main_OnCommand(40289, 0) --unselect all items

for i = 1, #midi_items do
  reaper.SetMediaItemSelected(midi_items[i], true)  
end

reaper.Main_OnCommand(43094, 0) -- Set midi item timebase to time, ignore project tempo


reaper.Undo_BeginBlock()

for i = start_bar, start_bar + length_in_bars - 1 do
  local _, qn_start, qn_end, timesig_num, timesig_denom, tempo = reaper.TimeMap_GetMeasureInfo(0, i)
  
  if timesig_num ~= target_timesig_num then
    local time_start = reaper.TimeMap_QNToTime(qn_start)
    local tgt_tempo = tempos[i].tempo * (target_timesig_num / target_timesig_denom) / (timesig_num / timesig_denom)
    
    reaper.SetTempoTimeSigMarker(0, -1, -1, i, 0, tgt_tempo, i == start_bar and target_timesig_num or 0, i == start_bar and target_timesig_denom or 0, false)
  end
end

reaper.Main_OnCommand(40289, 0) --unselect all items

for i = 1, #sel_items do
  reaper.SetMediaItemSelected(sel_items[i], true)  
end


reaper.Undo_EndBlock("doit", -1)
reaper.UpdateTimeline()