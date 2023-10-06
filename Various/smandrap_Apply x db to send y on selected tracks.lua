-- @description Apply x db to send y on selected tracks
-- @author smandrap
-- @version 1.1
-- @changelog
--    fixed undo
-- @donation https://paypal.me/smandrap
-- @about
--   Bassman002 request. https://forum.cockos.com/showthread.php?p=2718351#post2718351 
--    Db to value conversion functions are taken from someone (can't remember who, sorry)


---------------------

-- CHANGE THESE:

local DB_AMOUNT = -1
local SEND_IDX = 1      -- Target send, 1 based


---------------------


local LN10_OVER_TWENTY = 0.11512925464970228420089957273422
local TWENTY_OVER_LN10 = 8.6858896380650365530225783783321
local MINUS_INFINITY_TRESHOLD = 0.0000000298023223876953125

local function DbToValue(db) return math.exp(db * LN10_OVER_TWENTY) end

local function ValueToDb(value) 
  if value < MINUS_INFINITY_TRESHOLD then return -150 end
  return math.max(-150, math.log(value) * TWENTY_OVER_LN10)
end

local function main()
  local sel_tr_cnt = reaper.CountSelectedTracks()
  if sel_tr_cnt == 0 then return end
  
  for i = 0, sel_tr_cnt - 1 do
    local tr = reaper.GetSelectedTrack(0, i)
    local send_vol = reaper.GetTrackSendInfo_Value(tr, 0, SEND_IDX - 1, 'D_VOL')
    local new_vol = DbToValue(ValueToDb(send_vol) + DB_AMOUNT)
    
    reaper.SetTrackSendInfo_Value(tr, 0, SEND_IDX - 1, 'D_VOL', new_vol)
  end
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Apply "..DB_AMOUNT.." db to Send "..SEND_IDX.." on selected tracks", 1)
