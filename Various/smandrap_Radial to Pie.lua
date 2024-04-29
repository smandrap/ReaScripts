local radial_path = '/Users/Federico/Library/Application Support/REAPER/Scripts/ReaTeam Scripts/Various/Lokasenna_Radial Menu - user settings.txt'
local f = io.open(radial_path, 'r')
if not f then return end
local buf = f:read('*all')
f:close()

local func, err = load(buf, 'schwa', 'bt')
local t = func()
if not t then return end


for i = 0, #t do
  for j = 0, #t[i] do
    local subt = t[i][j]
    for k, v in pairs(subt) do
      reaper.ShowConsoleMsg(('%s %s\n'):format(k, v))
    end
  end
end