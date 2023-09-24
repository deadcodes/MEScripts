--[[
# Script Name:   <priffTreeChopper.lua>
# Description:  <Chops trees at Crwys Clan.>
# Autor:        <Dead (dea.d - Discord)>
# Version:      <1.0>
# Datum:        <2023.09.24>

#Changelog
- 2023.09.24 [1.0]
    Release

#Requirements:
    Plague's End completed to access Prifddinas
#Instructions:

> Set the name of the tree to chop [treeToChop]
> Set the name of the logs you receive [logsToCount]
> Set the keycode of the bank preset you want to use [bankPresetKeycode] https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes

--]]
print("Run Dead's Priff Tree Chopper.")

--#region INCLUDES
local API = require("api")
local LODESTONES = require("lodestones")
local UTILS = require("utils")
--#endregion

--#region VARIABLES
local MAX_IDLE_TIME_MINUTES = 5
local treeToChop = "Magic tree"
local logsToCount = "Magic logs"
local bankPresetKeycode = 0x72
local logs = 0
local startTime, afk = os.time(), os.time()
local skill = "WOODCUTTING"
local startXp = API.GetSkillXP(skill);

local IGP = API.CreateIG_answer()
IGP.box_start = FFPOINT.new(5, 5, 0)
IGP.box_name = "PROGRESSBAR"
IGP.colour = ImColor.new(65, 52, 28);
IGP.string_value = "Dead's Priff Tree Chopper"

local imguiBackground = API.CreateIG_answer();
imguiBackground.box_name = "imguiBackground";
imguiBackground.box_start = FFPOINT.new(5, 5, 0);
imguiBackground.box_size = FFPOINT.new(190, 90, 0)
imguiBackground.colour = ImColor.new(20, 20, 20);

local imguiLogsChopped = API.CreateIG_answer();
imguiLogsChopped.box_name = "imguiLogsChopped";
imguiLogsChopped.box_start = FFPOINT.new(10, 50, 0);
imguiLogsChopped.colour = ImColor.new(138, 186, 168);
imguiLogsChopped.string_value = "Dead's Priff Tree Chopper\n" .. logsToCount .. " Chopped: 0"
--#endregion


local tickCount = 0
local STATE = 0
local STATES = {
    GOTO_BANK = 0,
    BANK = 1,
    GOTO_TREES = 2,
    CHOP = 3
}

--#region Thanks HigginsHax
local function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random((MAX_IDLE_TIME_MINUTES * 60) * 0.6, (MAX_IDLE_TIME_MINUTES * 60) * 0.9)

    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
        return true
    end
end

-- Rounds a number to the nearest integer or to a specified number of decimal places.
local function round(val, decimal)
    if decimal then
        return math.floor((val * 10 ^ decimal) + 0.5) / (10 ^ decimal)
    else
        return math.floor(val + 0.5)
    end
end

local function formatNumber(num)
    if num >= 1e6 then
        return string.format("%.1fM", num / 1e6)
    elseif num >= 1e3 then
        return string.format("%.1fK", num / 1e3)
    else
        return tostring(num)
    end
end

-- Format script elapsed time to [hh:mm:ss]
local function formatElapsedTime(startTime)
    local currentTime = os.time()
    local elapsedTime = currentTime - startTime
    local hours = math.floor(elapsedTime / 3600)
    local minutes = math.floor((elapsedTime % 3600) / 60)
    local seconds = elapsedTime % 60
    return string.format("[%02d:%02d:%02d]", hours, minutes, seconds)
end

local function calcProgressPercentage(skill, currentExp)
    local currentLevel = API.XPLevelTable(API.GetSkillXP(skill))
    if currentLevel == 120 then return 100 end
    local nextLevelExp = XPForLevel(currentLevel + 1)
    local currentLevelExp = XPForLevel(currentLevel)
    local progressPercentage = (currentExp - currentLevelExp) / (nextLevelExp - currentLevelExp) * 100
    return math.floor(progressPercentage)
end

local function printProgressReport(final)
    local currentXp = API.GetSkillXP(skill)
    local elapsedMinutes = (os.time() - startTime) / 60
    local diffXp = math.abs(currentXp - startXp);
    local xpPH = round((diffXp * 60) / elapsedMinutes);
    local time = formatElapsedTime(startTime)
    local currentLevel = API.XPLevelTable(API.GetSkillXP(skill))
    IGP.radius = calcProgressPercentage(skill, API.GetSkillXP(skill)) / 100
    IGP.string_value = time ..
        " | " ..
        string.lower(skill):gsub("^%l", string.upper) ..
        ": " .. currentLevel .. " | XP/H: " .. formatNumber(xpPH) .. " | XP: " .. formatNumber(diffXp)
end

local function drawGUI()
    API.DrawSquareFilled(imguiBackground)
    API.DrawProgressBar(IGP, false)
    API.DrawTextAt(imguiLogsChopped)
end
--#endregion

local function gameStateChecks()
    local gameState = API.GetGameState()
    if (gameState ~= 3) then
        print('Not ingame with state:', gameState)
        API.Write_LoopyLoop(false)
        return
    end
    if not API.PlayerLoggedIn() then
        print('Not Logged In')
        API.Write_LoopyLoop(false)
        return;
    end
end

local function onStart()
    print('on start')
    local priffLodestone = LODESTONES.LODESTONE.PRIFDDINAS.loc
    local playerXYZ = API.PlayerCoord()
    if (API.Math_DistanceW(priffLodestone, playerXYZ) > 68) then
        print('They are different')
        LODESTONES.Prifddinas()
        UTILS.randomSleep(6000)
    else
        print('Already near PRIFDDINAS lodestone')
    end
    if API.Invfreecount_() < 24 then
        STATE = STATES.BANK
    else
        STATE = STATES.GOTO_TREES
    end
end

local function bank()
    -- open bank
    local atBank = false
    if not API.PInAreaW(WPOINT.new(2240, 3384, 1), 50) then
        API.DoAction_WalkerW(WPOINT.new(2240, 3384, 1))
    else
        API.DoAction_Object1(0x2e, API.OFF_ACT_GeneralObject_route1, { 92692 }, 50)
        UTILS.randomSleep(2000)
        API.WaitUntilMovingEnds();
        -- load preset 3
        if API.BankOpen2() then
            atBank = true
            local invLogsCount = API.InvItemcount_String(logsToCount)
            logs = logs + invLogsCount
            imguiLogsChopped.string_value = "Dead's Priff Tree Chopper\n" .. logsToCount .." Chopped: " .. tostring(logs)
            API.KeyboardPress2(bankPresetKeycode,100,300)
        end
        if atBank then
            STATE = STATES.CHOP
        else
            STATE = STATES.GOTO_TREES
        end
    end
end

local function gotoTrees()
    API.DoAction_WalkerW(WPOINT.new(2246, 3367, 1))
    UTILS.randomSleep(1200);
    API.WaitUntilMovingEnds()
    if not API.PInAreaW(WPOINT.new(2245, 3367, 1), 30) then
        STATE = STATES.GOTO_TREES
    else
        STATE = STATES.CHOP
    end
end

local function CHOP(tableTree)
    if not API.InventoryInterfaceCheckvarbit() then
        API.OpenInventoryInterface2()
        UTILS.randomSleep(600)
    end
    local trees = API.GetAllObjArrayInteract_str(tableTree, 50, 0)
    local validTrees = {}
    tickCount = tickCount + 1
    for i = 1, #trees do
        local tree = trees[i]
        if tree.Bool1 == 0 then
            table.insert(validTrees, tree)
        end
    end
    local tree = validTrees[math.random(1,#validTrees)]
    if not API.CheckAnim(20) or not API.WaitUntilMovingEnds() and trees[1] ~= nil then
        API.DoAction_Object2(0x3b, 0, { tree.Id }, 50, WPOINT.new(tree.TileX / 512, tree.TileY / 512, 1));
        UTILS.randomSleep(1200)
        API.WaitUntilMovingEnds()
        tickCount = 0
    end
end

local function inventoryCheck()
    if API.Invfreecount_() == 0 then
        STATE = STATES.BANK;
    end
end

local function PrifChopper(tableTree)
    gameStateChecks()
    drawGUI()
    idleCheck()
    API.DoRandomEvents()
    inventoryCheck()
    API.DrawTextAt(textdata)
    if STATE == STATES.BANK then
        bank();
    elseif STATE == STATES.GOTO_TREES then
        gotoTrees();
    elseif STATE == STATES.CHOP then
        CHOP(tableTree);
    end
    printProgressReport()
end

if (API.Read_LoopyLoop()) then
    print("Dead Priff Chopper Started!")
    onStart()
    while API.Read_LoopyLoop() do
        PrifChopper({treeToChop})
    end
end
