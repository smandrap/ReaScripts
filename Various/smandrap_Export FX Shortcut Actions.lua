local function GetFXList()
  local rv = true
  local i = 0
  local s = nil
  
  local fx_list = {}
  
  while rv  do
    rv, s = reaper.EnumInstalledFX(i)
    if rv then fx_list[#fx_list + 1] = s end
    i = i + 1
  end
  
  return fx_list
end

