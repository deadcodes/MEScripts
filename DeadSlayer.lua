--[[
# Script Name:   <DeadSlayer.lua>
# Description:  <Kills stuff.>
# Autor:        <Dead (dea.d - Discord)>
# Version:      <1.1>
# Datum:        <2023.09.21>

#Changelog
    - 2023-09-21 [1.1]
        Added CheckForAnim to handle channeled abilities
        Added longer delays before clicking next mob
    - 2023-09-21 [1.0]
        Release
#Credits
Alar (test8888) for the cpp script that inspired this

# Requirements
- Eat Food skill on Action bar

# Features
- Uses Augmented Enhanced Excalibur if found in inventory and health below 50%
- Uses Elven Ritual Shard if found in inventory and prayer below 50%
- Uses the Eat Food skill if available and Excalibur is on cooldown and health below 50%
- If unable to heal and health falls below 20%, uses Wars Retreat teleport and exits

# Script Setup
- Set the items that you want to loot in the variable itemIdsToLoot.
- Below is an example on how I store items and use them

#Script Execution

- Click the GET button to populate the dropdown with list of mobs
- Click the SET button to set the target
- Click Slaughter to start, it flips over to Pause to pause
- Click Stop script to exit
ITEMS = {}

ITEMS.COMMON = {
    -- 592, -- ashes
    995, -- gold coins
    32341, -- ghostly essence
}

ITEMS.GEMS = {
    1623, -- uncut sapphire
    1621, -- uncut emerald
    1619, -- uncut ruby
    1617, -- uncut diamond
    1631, -- uncut dragonstone
}

ITEMS.RUNES = {
    554, -- fire
    555, -- water
    556, -- air
    557, -- earth
    564, -- cosmic
    561, -- nature
    563, -- law
    565, -- blood
    560, -- death
    566, -- soul
}

ITEMS.HERBS = {
    21626, -- fellstalk
    48243, -- arbuck
    219, -- torstol
    217, -- dwarf weed
    2485, -- lantadyme
    215, -- cadantine
    3051, -- snapdragon
    37975, -- bloodweed
    213, -- kwuarm
    14836, -- wergali
    12174, -- spirit weed
    3049, -- toadflax
    207, -- ranarr
    201, -- marrentill
}

ITEMS.SEEDS = {
    28265, -- butterfly flower
    6311, -- gout tuber
    48201, -- arbuck
    37952, -- bloodweed
    21621, -- fellstalk
    5295, -- ranarr
    5303, -- dwarf weed
    14870, -- wergali
    5304, -- torstol
    5298, -- avantoe
    5302, -- lantadyme
    28264, -- grapevine
    5316, -- magic
    5315, -- yew
    48769, -- ciku
    48768, -- carambola
    48764, -- golden dragonfruit
    31437, -- elder
    28262, -- snape grass
}

ITEMS.BONES = {
    35010, -- reinforced dragon
    3123, -- shaikahan
    4834, -- ourg
    35008, -- hardened dragon
    18832, -- frost dragon
    30209, -- airut
    6812, -- wyvern
    48075, -- dinosaur
    51858, -- dragonkin
    4832, -- raurg
    6729, -- dagannoth
    4830, -- fayrg
    2859, -- wolf
    536, -- dragon
    4812, -- zogre
    530, -- bat
    534, -- baby dragon
    528, -- burnt
    3125, -- jogre
}

ITEMS.ASHES = {
    34159, -- searing
    33260, -- tortured
    20268, --infernal
    20266, -- accursed
    20264, -- impious
}

ITEMS.ARROWS = {
    892, -- rune arrows
}
return ITEMS

local ITEMS = require("items")

local itemIdsToLoot = UTILS.concatenateTables(ITEMS.COMMON, ITEMS.GEMS, ITEMS.SEEDS, ITEMS.HERBS, ITEMS.RUNES,
    ITEMS.ARROWS)
--]]

print("Run DeadSlayer.")
local API = require("api")
local UTILS = require("utils")

--#region User Inputs
local itemIdsToLoot = { 995 }
--#endregion

--#region Imgui Setup
local imguiBackground = API.CreateIG_answer();
imguiBackground.box_name = "imguiBackground";
imguiBackground.box_start = FFPOINT.new(16, 20, 0);
imguiBackground.box_size = FFPOINT.new(300, 116, 0)

local getTargetBtn = API.CreateIG_answer();
getTargetBtn.box_name = "Get";
getTargetBtn.box_start = FFPOINT.new(16, 20, 0);
getTargetBtn.box_size = FFPOINT.new(50, 30, 0);
getTargetBtn.tooltip_text = "Populate mobs list"

local setTargetBtn = API.CreateIG_answer();
setTargetBtn.box_name = "Set";
setTargetBtn.box_start = FFPOINT.new(60, 20, 0);
setTargetBtn.box_size = FFPOINT.new(50, 30, 0);
setTargetBtn.tooltip_text = "The script will kill this mob"

local imguicombo = API.CreateIG_answer()
imguicombo.box_name = "Mobs     "
imguicombo.box_start = FFPOINT.new(100, 20, 0)
imguicombo.stringsArr = { "a", "b" }
imguicombo.tooltip_text = "Available mobs to target"

local imguiCurrentTarget = API.CreateIG_answer();
imguiCurrentTarget.box_name = "Current Target:";
imguiCurrentTarget.box_start = FFPOINT.new(30, 50, 0);

local imguiSlaughter = API.CreateIG_answer();
imguiSlaughter.box_name = "Slaughter";
imguiSlaughter.box_start = FFPOINT.new(18, 60, 0);
imguiSlaughter.box_size = FFPOINT.new(80, 30, 0);
imguiSlaughter.tooltip_text = "Start/Stop slaying"

local imguiTerminate = API.CreateIG_answer();
imguiTerminate.box_name = "Stop Script";
imguiTerminate.box_start = FFPOINT.new(100, 60, 0);
imguiTerminate.box_size = FFPOINT.new(100, 30, 0);
imguiTerminate.tooltip_text = "Exit the script"

local imguiRuntime = API.CreateIG_answer();
imguiRuntime.box_name = "imguiRuntime";
imguiRuntime.box_start = FFPOINT.new(30, 90, 0);

API.DrawComboBox(imguicombo, false)
--#endregion

--#region Variables init
local startTime = os.time()
local idleTime = os.time()
local targetPlaceholder = "None. Click Set Mob"
local target = targetPlaceholder
local runSlayer = false
local targetNotFoundCount = 0

local IDS = {
    EXCALIBUR = 14632,
    EXCALIBUR_AUGMENTED = 36619,
    ELVEN_SHARD = 43358
}

local COLORS = {
    BACKGROUND = ImColor.new(10, 13, 29),
    TARGET_UNSET = ImColor.new(189, 185, 167),
    TARGET_SET = ImColor.new(70, 143, 126),
    SLAUGHTER = ImColor.new(84, 166, 102),
    PAUSED = ImColor.new(238, 59, 83),
    RUNTIME = ImColor.new(198, 120, 102)
}

imguiBackground.colour = COLORS.BACKGROUND
imguiCurrentTarget.colour = COLORS.TARGET_UNSET
imguiRuntime.colour = COLORS.SLAUGHTER
--#endregion

--#region Util functions
local function log(text)
    print(string.format("%s - %s", os.date("[%H:%M:%S]"), text))
end

local function antiIdleTask()
    local timeDiff = os.difftime(os.time(), idleTime)
    local randomTime = math.random((5 * 60) * 0.6, (5 * 60) * 0.9)

    if timeDiff > randomTime then
        API.PIdle2()
        idleTime = os.time()
    end
end

local function formatElapsedTime(start)
    local currentTime = os.time()
    local elapsedTime = currentTime - start
    local hours = math.floor(elapsedTime / 3600)
    local minutes = math.floor((elapsedTime % 3600) / 60)
    local seconds = elapsedTime % 60
    return string.format("Runtime: %02d:%02d:%02d", hours, minutes, seconds)
end

local function gameStateChecks()
    local gameState = API.GetGameState()
    if (gameState ~= 3) then
        log('Not ingame with state:', gameState)
        API.Write_LoopyLoop(false)
        return
    end
    if targetNotFoundCount > 30 then
        imguiSlaughter.box_name = "Slaughter"
        runSlayer = false;
        API.Write_LoopyLoop(false)
    end
end

local function terminate()
    runSlayer = false
    API.Write_LoopyLoop(false)
end

--#endregion

--#region UI render functions
local function populateDropdown()
    log('populateDropdown')
    local allNPCS = API.ReadAllObjectsArray(false, 1)
    local mobs = {}
    if #allNPCS > 0 then
        for _, a in pairs(allNPCS) do
            local distance = API.Math_DistanceF(a.Tile_XYZ, API.PlayerCoordfloat())
            a.Distance = distance;
            if a.Id ~= 0 and a.Life > 1 and distance < 50 then
                table.insert(mobs, a.Name)
            end
        end
        local distinct = UTILS.getDistinctValues(mobs)
        if #distinct > 0 then
            table.sort(distinct)
            imguicombo.stringsArr = distinct
        end
    end
end

local function setMob()
    log('setMob')
    local currentMob = target;
    local selected = imguicombo.stringsArr[imguicombo.int_value + 1]
    if currentMob ~= selected then
        target = selected;
    end
    imguiCurrentTarget.colour = COLORS.TARGET_SET
    setTargetBtn.return_click = false;
end

local function pauseSlayer()
    runSlayer = false
    log("Slayer paused")
    imguiSlaughter.return_click = false
    imguiCurrentTarget.colour = COLORS.PAUSED
    imguiRuntime.colour = COLORS.PAUSED
    imguiSlaughter.box_name = "Slaughter"
end

local function startSlayer()
    log("Slayer started")
    runSlayer = true;
    imguiCurrentTarget.colour = COLORS.SLAUGHTER
    imguiRuntime.colour = COLORS.SLAUGHTER
    imguiSlaughter.box_name = "Pause"
end

local function drawGUI()
    if imguiTerminate.return_click then
        terminate()
    end
    if imguiSlaughter.return_click then
        if not runSlayer then
            startSlayer()
        end
    else
        if runSlayer then
            pauseSlayer()
        end
    end
    if getTargetBtn.return_click then
        populateDropdown()
        getTargetBtn.return_click = false
    end
    if not runSlayer and setTargetBtn.return_click then
        setMob()
    end
    API.DrawSquareFilled(imguiBackground)
    API.DrawBox(setTargetBtn)
    API.DrawBox(getTargetBtn)
    imguiCurrentTarget.string_value = "Current target:" .. target
    imguiRuntime.string_value = formatElapsedTime(startTime) --os.difftime(os.time(),startTime)
    API.DrawBox(imguiSlaughter)
    API.DrawBox(imguiTerminate)
    API.DrawTextAt(imguiCurrentTarget)
    API.DrawTextAt(imguiRuntime)
end

--#endregion

--#region Script functions
local function loot()
    if not API.InvFull_() then
        -- log('looting')
        API.DoAction_Loot_w(itemIdsToLoot, 5, API.PlayerCoordfloat(), 10)
        UTILS.randomSleep(600)
        API.WaitUntilMovingEnds()
    end
end

local function healthCheck()
    local hp = API.GetHPrecent()
    local prayer = API.GetPrayPrecent()
    local excalCD = API.DeBuffbar_GetIDstatus(IDS.EXCALIBUR, false)
    local excalFound = API.InvItemcount_1(IDS.EXCALIBUR_AUGMENTED)
    local elvenCD = API.DeBuffbar_GetIDstatus(IDS.ELVEN_SHARD, false)
    local elvenFound = API.InvItemcount_1(IDS.ELVEN_SHARD)
    local eatFoodAB = API.GetABs_name1("Eat Food")
    if hp < 50 then
        if not excalCD.found and excalFound > 0 then
            log("Using Excalibur")
            API.DoAction_Inventory1(IDS.EXCALIBUR_AUGMENTED, 0, 2, API.OFF_ACT_GeneralInterface_route)
            UTILS.randomSleep(800)
        else
            if eatFoodAB.id ~= 0 and eatFoodAB.enabled then
                log("Eating")
                API.DoAction_Ability_Direct(eatFoodAB, 1, API.OFF_ACT_GeneralInterface_route)
                UTILS.randomSleep(600)
            elseif hp < 20 then
                log("Health critical, unable to heal, running away")
                API.DoAction_Ability("Retreat Teleport", 1, API.OFF_ACT_GeneralInterface_route)
                terminate()
            end
        end
    end
    if prayer < 50 and not elvenCD.found and elvenFound > 0 then
        log("Using Elven Shard")
        API.DoAction_Inventory1(IDS.ELVEN_SHARD, 43358, 1, API.OFF_ACT_GeneralInterface_route)
        UTILS.randomSleep(600)
    end
end

local function useSkills()
end

local function usePrayers()
end

local function hasTarget()
    local interacting = API.ReadLpInteracting()
    if interacting.Id ~= 0 then return true else return false end
end

local function KillMob(name)
    if name == targetPlaceholder then
        log('No target selected, stopping slayer');
        pauseSlayer()
    end
    if not hasTarget() and not API.CheckAnim(20) then
        loot()
        local attackingMe = API.OthersInteractingWithLpNPC(true, 10)
        if #attackingMe > 0 then
            if attackingMe[1].Name == target then
                API.DoAction_NPC__Direct(0x2a, API.OFF_ACT_AttackNPC_route, attackingMe[1])
                UTILS.randomSleep(600)
            end
        else
            if API.DoAction_NPC_str(0x2a, API.OFF_ACT_AttackNPC_route, { name }, 40, false, 50) then
                UTILS.randomSleep(600)
                API.WaitUntilMovingEnds()
            else
                log('unable to find target')
                targetNotFoundCount = targetNotFoundCount + 1
                UTILS.randomSleep(600)
            end
        end
    else
        healthCheck()
        useSkills()
        usePrayers()
    end
end
--#endregion

--#region Main loop
API.Write_LoopyLoop(true)
populateDropdown()
while (API.Read_LoopyLoop()) do -----------------------------------------------------------------------------------
    API.DoRandomEvents()
    gameStateChecks()
    antiIdleTask()
    drawGUI()
    if runSlayer then
        KillMob(target)
    end
    UTILS.randomSleep(300)
end ----------------------------------------------------------------------------------
--#endregion
