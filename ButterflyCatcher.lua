--[[
# Script Name:   <ButterflyCatcher.lua>
# Description:  <Catches Butterflies.>
# Autor:        <Dead (dea.d - Discord)>
# Version:      <1.0>
# Datum:        <2023.11.07>

#Changelog
- 2023.11.07 [1.0]
    Release

#Instructions:
> Set the name of the entity you want to catch on line 26

#Features:
> The tile your character was standing on when you started the script is considered as Home Tile
> If it detects that you're losing health, it runs back to the Home Tile.
> If you wander too far from the Home Tile, it goes back to the Home Tile.

--]]

print("Dead's Butterfly Catcher.")
local API = require("api")
local UTILS = require("utils")

local entityToCatch = "Charming moth"
local startTime, afk = os.time(), os.time()
local MAX_IDLE_TIME_MINUTES = 5
local skillName = "HUNTER"
local startXp = API.GetSkillXP(skillName);
local stateXp = startXp
local failureCount = 0
local startTile = API.PlayerCoord()
local health = API.GetHP_()
local IGP = API.CreateIG_answer()
IGP.box_start = FFPOINT.new(5, 5, 0)
IGP.box_name = "PROGRESSBAR"
IGP.colour = ImColor.new(112, 53, 1);
IGP.string_value = "Dead's Butterfly Catcher"

local function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random((MAX_IDLE_TIME_MINUTES * 60) * 0.6, (MAX_IDLE_TIME_MINUTES * 60) * 0.9)

    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
        return true
    end
end

local function gameStateChecks()
    local gameState = API.GetGameState()
    if (gameState ~= 3) then
        print('Not ingame with state:', gameState)
        API.Write_LoopyLoop(false)
        return
    end
    if API.InvFull_() then
        print('inventory full, stopping')
        API.Write_LoopyLoop(false)
        return
    end
    if failureCount > 50 then
        print('Couldnt find moths more than 50 times, exiting')
        API.Write_LoopyLoop(false)
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

local function printProgressReport()
    local currentXp = API.GetSkillXP(skillName)
    local elapsedMinutes = (os.time() - startTime) / 60
    local diffXp = math.abs(currentXp - startXp);
    local xpPH = round((diffXp * 60) / elapsedMinutes);
    local time = formatElapsedTime(startTime)
    local currentLevel = API.XPLevelTable(API.GetSkillXP(skillName))
    if diffXp > 0 then
        stateXp = stateXp + diffXp;
    end
    IGP.radius = calcProgressPercentage(skillName, API.GetSkillXP(skillName)) / 100
    IGP.string_value = time ..
        " | " ..
        string.lower(skillName):gsub("^%l", string.upper) ..
        ": " .. currentLevel .. " | XP/H: " .. formatNumber(xpPH) .. " | XP: " .. formatNumber(diffXp)
end


local function drawGUI()
    API.DrawProgressBar(IGP, false)
    printProgressReport()
end

local function walkBack()
    API.DoAction_WalkerW(startTile);
end

local function runBackIfUnderAttack()
    local currentHealth = API.GetHP_()
    if currentHealth < health then
        print('Were under attack, running back to start point')
        if not API.ReadPlayerMovin2() then
            walkBack()
            health = currentHealth
        end
    elseif currentHealth > health then
        health = currentHealth
    end
end

local function CatchAButterfly()
    local interactingWithMoth = API.Local_PlayerInterActingWith_22(20, entityToCatch)
    if not (interactingWithMoth or API.ReadPlayerAnim() ~= 0) and not API.ReadPlayerMovin2() then
        local moth = API.FindNPCbyName(entityToCatch, 30)
        if moth ~= nil and moth.Id ~= 0 then
            if API.Math_DistanceF(moth.Tile_XYZ, API.PlayerCoordfloat()) > 50 then
            print('Too far from target, walking back')
                API.DoAction_WalkerF(moth.Tile_XYZ)
            end
            API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route, {moth.Id}, 50)
        else
            if API.Math_DistanceW(startTile, API.PlayerCoord()) > 50 then
            print('Wandered off, going back')
                walkBack()
            end
            failureCount  = failureCount + 1
        end
        failureCount = 0
        UTILS.randomSleep(300)
    else
        runBackIfUnderAttack()
    end
end
print('Starting to catch:', entityToCatch)
API.Write_LoopyLoop(true)
while API.Read_LoopyLoop() do
    drawGUI()
    gameStateChecks()
    idleCheck()
    runBackIfUnderAttack()
    API.DoRandomEvents()
    CatchAButterfly()
    printProgressReport()
    UTILS.randomSleep(300)
end
