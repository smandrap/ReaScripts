local r = reaper
local getinfo = debug.getinfo(1, 'S');
local script_path = getinfo.source:match [[^@?(.*[\/])[^\/]-$]];
package.path = script_path .. "?.lua;" .. package.path -- GET DIRECTORY FOR REQUIRE

local radial_file = nil
local radial_found = false

local function GetRadialFile()
    local os_sep = package.config:sub(1, 1)
    local radial_fn = "Lokasenna_Radial Menu - user settings.txt"
    local radial_path = table.concat({ r.GetResourcePath(), 'Scripts', 'ReaTeam Scripts', 'Various' }, os_sep) .. os_sep

    radial_file = radial_path .. radial_fn
    if reaper.file_exists(radial_file) then
        radial_found = true
    else
        if r.JS_ReaScriptAPI_Version then
            local ok = 2
            ok = r.MB(("Can't Find the following file :\n\n%s\n\nDo you want to locate it?"):format(radial_fn), 'Error', 1)
            if ok == 2 then return end
            ok = 0
            ok, radial_file = r.JS_Dialog_BrowseForOpenFiles('Radial Menu file', radial_path, '',
                'Radial Menu File\0*.txt\0\0',
                false)
            if ok == 1 then radial_found = true end
        end
    end
    return radial_file
end

local radial_file = GetRadialFile()

if not radial_found then
    reaper.MB("Can't find the following file:\n\nLokasenna_Radial Menu - user settings.txt", "Aborted", 0)
    return
end

local function StringToTable(str)
    local f, err = load(str)
    return f ~= nil and f() or nil
end

local function SaveToFile(data, fn)
    local file
    file = io.open(fn, "w")
    if file then
        file:write(data)
        file:close()
    end
end

local function ReadFromFile(fn)
    local file = io.open(fn, "r")
    if not file then return end
    local content = file:read("a")
    if content == "" then return end
    return StringToTable(content)
end

local function serializeTable(val, name, skipnewlines, depth)
    skipnewlines = skipnewlines or false
    depth = depth or 0
    local tmp = string.rep(" ", depth)
    if name then
        if type(name) == "number" and math.floor(name) == name then
            name = "[" .. name .. "]"
        elseif not string.match(name, '^[a-zA-z_][a-zA-Z0-9_]*$') then
            name = string.gsub(name, "'", "\\'")
            name = "['" .. name .. "']"
        end
        tmp = tmp .. name .. " = "
    end
    if type(val) == "table" then
        tmp = tmp .. "{" .. (not skipnewlines and "\n" or "")
        for k, v in pairs(val) do
            if k ~= "selected" and k ~= "guid_list" and k ~= "img_obj" then
                tmp = tmp .. serializeTable(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "\n" or "")
            end
        end
        tmp = tmp .. string.rep(" ", depth) .. "}"
    elseif type(val) == "number" then
        tmp = tmp .. tostring(val)
    elseif type(val) == "string" then
        tmp = tmp .. string.format("%q", val)
    elseif type(val) == "boolean" then
        tmp = tmp .. (val and "true" or "false")
    else
        tmp = tmp .. "\"[inserializeable datatype:" .. type(val) .. "]\""
    end
    return tmp
end

local function TableToString(table, new_line)
    local str = serializeTable(table, nil, new_line)
    return str
end

RADIAL_TBL = ReadFromFile(radial_file)
MENUS = {}

-- MENUS[#MENUS + 1] = {
--     guid = r.genGuid(),
--     RADIUS = 150,
--     name = "MENU " .. #MENUS,
--     col = 0xff,
--     menu = true,
--     guid_list = {}
-- }

-- button = { name = new_name, cmd = cmd, cmd_name = name, col = 0xff })
local alias_list = {}
for i = 0, #RADIAL_TBL do
    if RADIAL_TBL[i].alias then
        MENUS[#MENUS + 1] = {
            guid = r.genGuid(),
            RADIUS = 150,
            name = RADIAL_TBL[i].alias,
            col = 0xff,
            menu = true,
        }
        alias_list[RADIAL_TBL[i].alias] = { guid = MENUS[#MENUS].guid, menu = MENUS[#MENUS] }
    end
end

local SECTION_FILTER = {
    [0] = 0,
    [32060] = 32060,
    [32062] = 32062,
    [32061] = 32061,
    [32063] = 32063,
}

function IterateActions(sectionID)
    local i = 0
    return function()
        local retval, name = r.kbd_enumerateActions(sectionID, i)
        if #name ~= 0 then
            i = i + 1
            return retval, name
        end
    end
end

function GetActions(s)
    local actions = {}
    local pairs_actions = {}
    for cmd, name in IterateActions(s) do
        if name ~= "Script: Sexan_Pie3000.lua" then
            table.insert(actions, { cmd = cmd, name = name, type = SECTION_FILTER[s] })
            pairs_actions[name] = { cmd = cmd, name = name, type = SECTION_FILTER[s] }
        end
    end
    table.sort(actions, function(a, b) return a.name < b.name end)
    return actions, pairs_actions
end

local ACTIONS_TBL, ACTIONS_TBL_PAIRS = GetActions(0)
local MIDI_ACTIONS_TBL, MIDI_ACTIONS_TBL_PAIRS = GetActions(32060)
local EXPLORER_ACTIONS_TBL, EXPLORER_ACTIONS_TBL_PAIRS = GetActions(32063)

function GetActionName(cmd)
    cmd = reaper.NamedCommandLookup(cmd)
    for i = 1, #ACTIONS_TBL do
        if cmd == ACTIONS_TBL[i].cmd then
            return ACTIONS_TBL[i].name
        end
    end
end

for i = 0, #RADIAL_TBL do
    if RADIAL_TBL[i].alias then
        local rad = RADIAL_TBL[i]
        local menu = alias_list[rad.alias].menu
        local menu_guid = alias_list[rad.alias].guid
        for j = 0, #rad do
            if alias_list[rad[j].act] then
                --table.insert(menu, { name = rad[j].lbl, col = 0xff, menu = true, guid = alias_list[rad[j].act].guid, RADIUS = 150 })
            elseif rad[j].act:match('^midi%s') or rad[j].act:match('^menu%s+') then
                -- continue
            else
                local cmd_name = GetActionName(rad[j].act)
                table.insert(menu,
                    { name = rad[j].lbl:gsub("|", " "), cmd = rad[j].act, cmd_name = cmd_name, col = 0xff })
            end
        end
    end
end
local menus = TableToString(MENUS)
SaveToFile(menus, script_path .. "menu_file.txt")
