local ffi = require("ffi")
local C = ffi.C
ffi.cdef[[
	typedef uint64_t UniverseID;
	typedef struct {
		const char* factionName;
		const char* factionIcon;
	} FactionDetails;
	typedef struct {
		UniverseID softtargetID;
		const char* softtargetName;
		const char* softtargetConnectionName;
	} SofttargetDetails;
	typedef struct {
		float x;
		float y;
		float z;
		float yaw;
		float pitch;
		float roll;
	} UIPosRot;
	void AbortPlayerPrimaryShipJump(void);
	UniverseID AddHoloMap(const char* texturename, float x0, float x1, float y0, float y1);
	void ClearHighlightMapComponent(UniverseID holomapid);
	const char* GetBuildSourceSequence(UniverseID componentid);
	const char* GetComponentClass(UniverseID componentid);
	const char* GetComponentName(UniverseID componentid);
	UniverseID GetContextByClass(UniverseID componentid, const char* classname, bool includeself);
	FactionDetails GetFactionDetails(const char* factionid);
	UniverseID GetMapComponentBelowCamera(UniverseID holomapid);
	bool GetMapPositionOnEcliptic(UniverseID holomapid, UIPosRot* position, bool showposition);
	const char* GetMapShortName(UniverseID componentid);
	FactionDetails GetOwnerDetails(UniverseID componentid);
	UniverseID GetParentComponent(UniverseID componentid);
	UniverseID GetPickedMapComponent(UniverseID holomapid);
	SofttargetDetails GetSofttarget(void);
	UniverseID GetZoneAt(UniverseID sectorid, UIPosRot* uioffset);
	bool HasPlayerJumpKickstarter(void);
	bool InitPlayerPrimaryShipJump(UniverseID objectid);
	bool IsComponentOperational(UniverseID componentid);
	bool IsInfoUnlockedForPlayer(UniverseID componentid, const char* infostring);
	bool IsSellOffer(UniverseID tradeofferdockid);
	void RemoveHoloMap2(void);
	void SetHighlightMapComponent(UniverseID holomapid, UniverseID componentid, bool resetplayerpan);
	bool SetSofttarget(UniverseID componentid);
	void ShowUniverseMap(UniverseID holomapid, UniverseID componentid, bool resetplayerzoom, int overridezoom);
	void StartPanMap(UniverseID holomapid);
	void StartRotateMap(UniverseID holomapid);
	void StopPanMap(UniverseID holomapid);
	void StopRotateMap(UniverseID holomapid);
	void ZoomMap(UniverseID holomapid, float zoomstep);
    bool IsShip(const UniverseID componentid);
]]

local menu = {
    name = "MeJ_TacticalMapMenu",
    white = { r = 255, g = 255, b = 255, a = 100 },
    red = { r = 255, g = 0, b = 0, a = 100 },
    transparent = { r = 0, g = 0, b = 0, a = 0 },
    grey = { r = 128, g = 128, b = 128, a = 100 },
    lightGrey = { r = 170, g = 170, b = 170, a = 100 },
    
    issuableOrders = {},
    gridOrders = {},
    commandAcceptSound = "ui_speedbar_fullforward",
    commandRejectSound = "ui_interaction_not_possible",
    
    text = {
        zoomOut = ReadText(1005, 77),
        zoomIn = ReadText(1005, 76),
        details = ReadText(1001, 2961),
        comm = ReadText(1001, 3216),
        back = ReadText(1001, 2669),
        selectionNone = "-- " .. ReadText(1001, 34) .. " --",
        commandAccepted = ReadText(10002, 132),
        commandRejected = ReadText(10002, 133),
        unknown = ReadText(20214, 100),
        show = ReadText(1001, 1133),
        unknownSystem = ReadText(20006, 101),
        plotCourse = ReadText(1001, 1109),
        abortCourse = ReadText(1001, 1110),
        jump = ReadText(1001, 3218),
        abortJump = ReadText(1001, 3219),
        abortJump = ReadText(1001, 6),
        successOfTotal = ReadText(30533601, 1001)
    }
}

--shallow clone
local function clone(t)
    local new = {}
    for k, v in pairs(t) do
        new[k] = v
    end
    return new
end

local colorChar = string.char(27)

local function loadOrdersFromExtensions()
    --DebugError("TACTICAL MAP: LOADING ORDERS DEFINED IN EXTENSIONS")
    local extensions = GetExtensionList()
    
    for k, extension in ipairs(extensions) do
        local path = "extensions/" .. string.gsub(extension.location, "\\", "/") .. "mej_tacmap_orders.txt"
        local loadedChunk = loadfile(path)
        
        local retVal
        if loadedChunk then
            retVal = loadedChunk()
        end
        
        if retVal then
            --DebugError("Tactical map order definitions found in " .. extension.name)
            if retVal.issuableOrders then
                for k, rightClickOrder in ipairs(retVal.issuableOrders) do
                    table.insert(menu.issuableOrders, rightClickOrder)
                end
            end
            if retVal.gridOrders then
                for k, gridOrder in ipairs(retVal.gridOrders) do
                    table.insert(menu.gridOrders, gridOrder)
                end
            end
        end
    end
    
    --DebugError("Tactical map: finished loading from extensions. "..#menu.issuableOrders.." right-click orders and "..#menu.gridOrders.." grid orders")
end

local function init()
    Menus = Menus or { }
    table.insert(Menus, menu)
    if Helper then
        Helper.registerMenu(menu)
    end
    menu.holomap = 0
    
    loadOrdersFromExtensions()
    
    --fill gridOrders a bit
    while #menu.gridOrders < 12 do
        local num = #menu.gridOrders
        table.insert(menu.gridOrders,
            {
                buttonText = "--",
                
                requiresTarget = false,
                
                buttonFilter = function(order) return false end,
                
                issue = function(order) end
            }
        )
    end
end

function menu.concatHistory(sep)
    local hist = {}
    for k, entry in pairs(menu.history) do
        table.insert(hist, ffi.string(C.GetComponentName(entry.space)))
    end
    
    return table.concat(hist, sep)
end

function menu.onShowMenu()
    Helper.standardFontSize = 9
    Helper.standardTextHeight = 14

    menu.renderTargetWidth = Helper.standardSizeY - 30
    menu.renderTargetHeight = Helper.standardSizeY
    menu.selectTableOffsetX = menu.renderTargetWidth
    menu.selectTableHeight = Helper.standardSizeY - 20 - 110
    menu.commandTableOffsetY = menu.selectTableHeight
    menu.statusBarWidth = 25
    menu.extendButtonWidth = 30
    
    menu.numCommandButtonCols = 3
    local numCommandButtonRows = 10
    local usableWidth = GetUsableTableWidth(Helper.standardSizeX, menu.selectTableOffsetX, 3, true)
    local totalCommandButtonWidth = Helper.standardSizeX - menu.selectTableOffsetX
    local commandButtonWidth = usableWidth / menu.numCommandButtonCols
    
    menu.selectColumnWidths = {menu.extendButtonWidth, Helper.standardTextHeight, 0, 24, 24}
    menu.gridColWidths = {menu.selectColumnWidths[1], menu.selectColumnWidths[2], 0, commandButtonWidth, commandButtonWidth}
    menu.gridEffectiveColumns = {1, 4, 5}
    menu.gridColSpans = {3, 1, 1}
    
    --calculate row widths:
    --there are 9 elements: 4 buttons and 5 spaces
    --a button is about 3 times the width of a space
    --total 'weight' is 12 for buttons and 5 for spaces
    local buttonUsableWidth = GetUsableTableWidth(menu.renderTargetWidth, 0, 9, false)
    local buttonTableButtonShare = 14
    local buttonTableSpacerShare = 4
    local buttonTableTotalShare = buttonTableButtonShare + buttonTableSpacerShare
    menu.buttonTableButtonWidth = (buttonTableButtonShare/buttonTableTotalShare) * buttonUsableWidth / 4
    menu.buttonTableSpacerWidth = (buttonTableSpacerShare/buttonTableTotalShare) * buttonUsableWidth / 5
    
    local productionColor, buildColor, storageColor, radarColor, dronedockColor, efficiencyColor, defenceColor, playerColor, friendColor, enemyColor, missionColor = GetHoloMapColors()
    menu.holomapColor = { productionColor = productionColor, buildColor = buildColor, storageColor = storageColor, radarColor = radarColor, dronedockColor = dronedockColor, efficiencyColor = efficiencyColor, defenceColor = defenceColor, playerColor = playerColor, friendColor = friendColor, enemyColor = enemyColor, missionColor = missionColor }
    
    --used to detect whether a select was made with left or right click
    menu.timeLastMouseDown = 0
    menu.timeLastRightMouseDown = 0
    
    --selected component (ship, space, whatever)
    menu.currentSelection = 0
    
    --player ship to perform a command, and the target
    menu.setCommandSelection(0)
    menu.commandTarget = 0
    menu.commandTargetType = "none"
    --commandTargetType is one of "none", "object", "point"
    menu.commandSelectionRow = 0
    
    --used to control holomap updates
    menu.lastHolomapUpdate = GetCurRealTime() + menu.holomapUpdateInterval
    
    --mapClicked uses this to tell displayMenu what should be selected in the menu
    menu.nextSelection = 0
    
    --the next n row changes on selectTable will have no effect
    menu.ignoreSelectRowChange = 0
    
    menu.nextSelectedRow = 0
    
    menu.extendedObjects = {}
    menu.extend(GetPlayerPrimaryShipID())
    
    --when you don't want to wait for updateHolomap to be called naturally
    --eg an order was issued and you want to update quickly, but not so quickly the command doesn't update on the UI
    menu.nextUpdateQuickly = false
    
    --if a component has its tostring as a key, it's checked, the value doesn't matter
    menu.checkedComponents = {}
    menu.numChecked = 0
    menu.multiSelectMode = false
    
    --a text message you can put above the 4 buttons if you like
    menu.statusMessage = "Ready"
    
    --some grid orders can be specify that they still need a target. if you click on one, its table goes here and will intercept the next right click
    menu.activeGridOrder = nil
    
    menu.displayMenuRunning = false
    
    --set some button scripts we don't have to mess with
    for k, order in ipairs(menu.gridOrders) do
        order.buttonScript = function()
            if menu.activeGridOrder == order then
                menu.setActiveGridOrder(nil)
                return
            end
            if order.requiresTarget then
                menu.setActiveGridOrder(order)
                return
            end
            
            if menu.hasCommandRecipient() then
                menu.broadcastOrder(order, true)
            end
        end
    end
    
    --parse params
    if menu.param then
        local paramSource = menu.param
        if menu.param2 and not menu.param2[1] then
            paramSource = menu.param2
        end
        
        menu.currentSpace = ConvertIDTo64Bit(paramSource[4])
        menu.currentSpaceType = paramSource[3]
        menu.nextSelection = paramSource[6] or 0
        menu.mode = paramSource[7]
        menu.modeParams = paramSource[8] or {}
        
        prevHistory = paramSource[5] or {}
        menu.history = {}
        for k, entry in ipairs(prevHistory) do
            table.insert(menu.history, {
                space = ConvertIDTo64Bit(entry[1]),
                spaceType = entry[2]
            })
        end
        
        if paramSource == menu.param and menu.param2 and menu.nextSelection == 0 then
			menu.nextSelection = menu.param2[2] or 0
		end
    else
        menu.history = {}
        menu.currentSpace = C.GetContextByClass(ConvertIDTo64Bit(GetPlayerPrimaryShipID()), "zone", false)
        menu.currentSpaceType = "zone"
    end
    if #menu.history == 0 then
        menu.pushHistory()
    else
        menu.currentSpace = menu.history[#menu.history].space
        menu.currentSpaceType = menu.history[#menu.history].spaceType
    end
    
    --create child list (this actually sets up the menu)
    menu.displayMenuReason = "open menu"
    menu.displayMenu(true)
    
    --set the activatemap flag
    menu.activateMap = true
    
    RegisterEvent("updateHolomap", menu.updateHolomap)
    
    menu.shouldBeClosed = false
    
    RegisterAddonBindings("ego_detailmonitor")
end

function menu.toggleMultiSelectMode()
    menu.setCommandSelection(0)
    menu.clearChecked()
    menu.multiSelectMode = not menu.multiSelectMode
    if not menu.displayMenuRunning then
        menu.displayMenu()
    end
end

function menu.setCommandSelection(comp)
    menu.commandSelection = comp
    
    if comp == 0 then
        menu.commandSelectionTable = {}
    else
        menu.commandSelectionTable = {comp}
    end
end

function menu.hasCommandRecipient()
    if menu.multiSelectMode then
        return menu.numChecked > 0
    else
        return menu.commandSelection ~= 0
    end
end

function menu.getCommandRecipients()
    if menu.multiSelectMode then
        return menu.checkedComponents
    else
        return menu.commandSelectionTable
    end
end

local function findRowForObject(object)
    for row, data in pairs(menu.rowDataMap) do
        if data and IsSameComponent(data.obj, object) then
            return row
        end
    end
end

--Convert history into the form the rest of the game will expect it to be in
function menu.getMarshaledHistory()
    local marshaled = {}
    for k, entry in ipairs(menu.history) do
        table.insert(marshaled, {ConvertStringToLuaID(tostring(entry.space)), entry.spaceType})
    end
    return marshaled
end

function menu.pushHistory()
    table.insert(menu.history, {
        space = menu.currentSpace,
        spaceType = menu.currentSpaceType
    })
end

function menu.popHistory()
    table.remove(menu.history)
end

function menu.issueOrder(order, orderObj)
    local commandName = order.buttonText or order.name
    PlaySound(menu.commandAcceptSound)
            
    menu.setStatusMessage(GetComponentData(menu.commandSelection, "name") .. textColor("X") .. " -> " .. commandName .. " " .. menu.text.commandAccepted)
    order.issue(orderObj)
end

--applies stuff like soft target and autopilot arrows
local function applyTargetArrows(setup, component, name)
    --softtarget arrows
    if IsSameComponent(component, GetPlayerTarget()) then
        name = "> "..name.." <"
    end
    
    --autopilot arrows
    if IsSameComponent(component, GetAutoPilotTarget()) then
        name = ">> "..name
    end
    
    return name
end

local function getCommandString(pilot, includeAction)
    if not pilot then
        return "--"
    end
    
    local commandString = "--"
    local commandActionString = "--"
    local commandParamString = "--"
    local commandActionParamString = "--"
    
    local commandStack, command, commandParam, commandAction, commandActionParam = GetComponentData(pilot, "aicommandstack", "aicommand", "aicommandparam", "aicommandaction", "aicommandactionparam")
    
    local numCommands = #commandStack
    if numCommands > 0 then
        command = commandStack[1].command
        commandParam = commandStack[1].param
    end
    if numCommands > 1 then
        commandAction = commandStack[numCommands].command
        commandActionParam = commandStack[numCommands].param
    end
    commandParamString = IsComponentClass(commandParam, "component") and GetComponentData(commandParam, "name") or ""
    commandActionParamString = IsComponentClass(commandActionParam, "component") and GetComponentData(commandActionParam, "name") or ""
    
    commandString = string.format(command, commandParamString)
    commandActionString = string.format(commandAction, commandActionParamString)
    if includeAction then
        return commandString, commandActionString
    else
        return commandString
    end
end

--for display on the top-right of buttonTable
local function getComponentInfo(component)
    if component == 0 or not IsComponentOperational(component) then
        return ""
    elseif IsComponentClass(component, "space") then
        local ownerName = GetComponentData(component, "ownername")
        if ownerName then
            return "Policed by " .. ownerName
        else
            return ""
        end
    elseif not menu.canViewDetails(component) then
        return ""
    else
        local infoItems = {}
        local separator = "\27Z" .. " - " .. "\27X"
        
        if IsComponentClass(component, "container") then
            if IsComponentClass(component, "ship") and IsInfoUnlockedForPlayer(component, "operator_commands") then
                local command, action = getCommandString(GetComponentData(component, "pilot"), true)
                table.insert(infoItems, action)
            end
            
            local hullPct, shieldPct, shieldMax = GetComponentData(component, "hullpercent", "shieldpercent", "shieldmax")
            if shieldMax ~= 0 then
                table.insert(infoItems, "\27C" .. shieldPct)
            end
            table.insert(infoItems, hullPct)
            
            local storage = GetStorageData(component)
            if storage.capacity > 0 then
                local tildeMaybe = storage.estimated and "~ " or ""
                table.insert(infoItems, tildeMaybe .. ConvertIntegerString(storage.stored, true, 3, true) .. "/" .. ConvertIntegerString(storage.capacity, true, 3, true))
            end
        else
            return ""
        end
        
        return #infoItems > 0 and table.concat(infoItems, separator) or ""
    end
end

--return true iff the ship is suitable to display on the TOP LEVEL of the right-hand list
local function shouldDisplayShip(ship, sameSpaceType)
    if IsComponentClass(ship, "ship_xs") then return false end
    
    local commander = GetCommander(ship)
    if not commander or IsComponentClass(commander, "station") then
        return true
    else
        return not IsSameComponent(GetContextByClass(commander, sameSpaceType, false), GetContextByClass(ship, sameSpaceType, false))
    end
end

local function filterByDisplayable(shipList, sameSpaceType)
    for i = #shipList, 1, -1 do
        if not shouldDisplayShip(shipList[i], sameSpaceType) then
            table.remove(shipList, i)
        end
    end
    return shipList
end


--helper function to get the highest commander in the chain that isn't the skunk
--(because orderable ships are either subordinate to the skunk or subordinate to nobody)
local function getCommandRecipient(component)
    if IsSameComponent(component, GetPlayerPrimaryShipID()) then
        return nil
    end
    if not IsComponentClass(component, "ship") then
        return nil
    end
    if GetBuildAnchor(component) then
        return nil
    end
    if not GetCommander(component) then
        if GetComponentData(component, "pilot") then
            return component
        else
            return nil
        end
    end
    
    local commandChain = GetAllCommanders(component)
    local comm
    
    --find the top of the command chain - might still be not a valid command receiver!
    if #commandChain == 1 then
        if IsSameComponent(commandChain[1], GetPlayerPrimaryShipID()) then
            --direct subordinate to skunk, i can receive orders
            comm = component
        else
            --direct subordinate to someone who can receive orders
            comm = commandChain[1]
        end
    else
        if IsSameComponent(commandChain[#commandChain], GetPlayerPrimaryShipID()) then
            --skunk is at the top, next one down can receive orders
            comm = commandChain[#commandChain-1]
        else
            --someone who can receive orders is at the top
            comm = commandChain[#commandChain]
        end
    end
    if IsComponentClass(comm, "station") then
        --no way to give orders to a ship assigned to a station
        return nil
    end
    if not GetComponentData(comm, "pilot") then
        return nil
    end
    
    return comm
end

function menu.isExtended(ship)
    for k, v in ipairs(menu.extendedObjects) do
        if IsSameComponent(v, ship) then
            return true
        end
    end
    return false
end
function menu.extend(ship)
    --menu.extendedObjects[ship] = true
    if not menu.isExtended(ship) then
        table.insert(menu.extendedObjects, ship)
    end
end
function menu.collapse(ship)
    --menu.extendedObjects[ship] = nil
    for k, v in ipairs(menu.extendedObjects) do
        if IsSameComponent(v, ship) then
            table.remove(menu.extendedObjects, k)
        end
    end
end

local function getIconName(ship)
    local purpose = GetComponentData(ship, "primarypurpose")
    if IsComponentClass(ship, "ship_xs") then
        if purpose == "fight" then
            return "shipicon_drone_combat"
        else
            return "shipicon_drone_transport"
        end
        
    elseif IsComponentClass(ship, "ship_s") then
        return "shipicon_fighter_s"
        
    elseif IsComponentClass(ship, "ship_m") then
        if purpose == "fight" then
            return "shipicon_fighter_m"
        elseif purpose == "trade" then
            return "shipicon_freighter_m"
        elseif purpose == "mine" then
            return "shipicon_miner_ore_m"
            --return "mej_miner"
        end
        
    elseif IsComponentClass(ship, "ship_l") then
        if purpose == "fight" then
            return "shipicon_destroyer_l"
        elseif purpose == "build" then
            return "shipicon_builder_l"
        elseif purpose == "mine" then
            return "shipicon_miner_ore_l"
            --return "mej_miner"
        else
            return "shipicon_freighter_l"
        end
        
    elseif IsComponentClass(ship, "ship_xl") then
        if purpose == "fight" then
            return "shipicon_destroyer_xl"
        elseif purpose == "mine" then
            return "shipicon_miner_ore_xl"
            --return "mej_miner"
        else
            return "shipicon_freighter_xl"
        end
        
    end
    
    return "solid"
end

local shipClassSizes = {
    ship_xl = 5,
    ship_l = 4,
    ship_m = 3,
    ship_s = 2,
    ship_xs = 1
}
local function shipSortFunc(a, b)
    local ffiA = ConvertIDTo64Bit(a)
    local ffiB = ConvertIDTo64Bit(b)
    local classA = ffi.string(C.GetComponentClass(ffiA))
    local classB = ffi.string(C.GetComponentClass(ffiB))
    
    if classA == classB then
        return ffi.string(C.GetComponentName(ffiA)) < ffi.string(C.GetComponentName(ffiB))
    end
    
    return (shipClassSizes[classA] or 0) > (shipClassSizes[classB] or 0)
end

local function setShipRowScripts(row, data)
    if data.checkBox then
        Helper.setCheckBoxScript(menu, nil, menu.selectTable, row, 2, function() menu.checkBoxSwitched(data.obj, row) end)
    end
    if data.extendButton then
        Helper.setButtonScript(menu, nil, menu.selectTable, row, 1, function() menu.extendObjectButton(data.obj) end)
    end
end

local function setSpaceRowScripts(row, data)
    Helper.setButtonScript(menu, nil, menu.selectTable, row, 1, function() menu.tryZoomIn(data.obj) end)
end

local function getRevealString(percent)
    return " \27A(" .. tostring(percent) .. "%)"
end

local spaceAndGrey2 = " \27Z"
local commandShipPrefix = "\27Y> \27X"
local commandSelPrefix = "\27Y>>>> \27X"
local function displayShip(setup, ship, isCommandSelection, isPlayer, isEnemy, updateTable, updateRow, depth)
    local fontSize = Helper.standardFontSize
    local textHeight = Helper.standardTextHeight
    
    local updateMode = not menu.displayMenuRunning
    
    local rowData
    
    if updateMode and not isCommandSelection then
        rowData = menu.rowDataMap[updateRow]
    end
    
    depth = depth or 0
    
    --so you can omit them if you like
    if isCommandSelection == nil then
        isCommandSelection = false
    end
    if isCommandSelection then
        isPlayer = true
        isEnemy = false
    end
    
    if isPlayer == nil then
        isPlayer = isCommandSelection or GetComponentData(ship, "isplayerowned")
    end
    if isEnemy == nil then
        isEnemy = GetComponentData(ship, "isenemy")
    end
    
    local isCommandRecipient = getCommandRecipient(ship) == ship
    
    local textColor
    if GetComponentData(ship, "ismissiontarget") then
        textColor = menu.holomapColor.missionColor
    elseif isPlayer then
        textColor = menu.holomapColor.playerColor
    elseif isEnemy then
        textColor = menu.holomapColor.enemyColor
    else
        textColor = menu.holomapColor.friendColor
    end
    
    --attach a bunch of stuff to the name as needed
    local name = GetComponentData(ship, "name") or menu.text.unknown
    
    --a yellow something for things that can receive orders
    if isPlayer and not isCommandSelection and isCommandRecipient then
        if (menu.multiSelectMode and menu.checkedComponents[tostring(ship)]) or (not menu.multiSelectMode and IsSameComponent(menu.commandSelection, ship)) then
            name = commandSelPrefix .. name
        else
            name = commandShipPrefix .. name
        end
    end
    
    name = applyTargetArrows(setup, ship, name)
    
    --pseudo-tree output with prefix
    if depth > 0 then
        name = string.rep("     ", depth) .. name
    end
    
    local warningIcon = " / ! \\"
    local warningString = ""
    
    if isPlayer then
        local hullPct, shieldPct, shieldMax = GetComponentData(ship, "hullpercent", "shieldpercent", "shieldmax")
        
        if hullPct < 40 then
            warningString = "\27R" .. warningIcon
        elseif hullPct < 70 then
            warningString = "\27Y" .. warningIcon
        end
        
        if shieldMax > 0 and shieldPct < 50 then
            warningString = warningString .. "\27C" .. warningIcon
        end
    end
    
    local commandString = IsInfoUnlockedForPlayer(ship, "operator_commands") and getCommandString(GetComponentData(ship, "pilot")) or "???"
    
    local childSpaceType = "zone"
    if menu.currentSpaceType == "galaxy" then
        childSpaceType = "cluster"
    elseif menu.currentSpaceType == "cluster" then
        childSpaceType = "sector"
    end
    local subordinates = GetSubordinates(ship)
    
    --different filtering needed here than shouldDisplayShip
    for i = #subordinates, 1, -1 do
        if IsComponentClass(subordinates[i], "ship_xs") or C.GetContextByClass(ConvertIDTo64Bit(subordinates[i]), childSpaceType, false) ~= C.GetContextByClass(ConvertIDTo64Bit(ship), childSpaceType, false) then
            table.remove(subordinates, i)
        end
    end
    local extended = #subordinates ~= 0 and menu.isExtended(ship)
    
    local iconName = getIconName(ship)
    
    --cell for button to extend subordinates (or if command selection, just the number)
    local extendButtonCell
    local hasExtendButton = false
    
    if isCommandSelection then
        extendButtonCell = Helper.createFontString(tostring(#subordinates), false, "center", 255, 255, 255, 100, nil, fontSize, nil, nil, nil, textHeight)
    elseif #subordinates ~= 0 then
        local text = tostring(#subordinates)
        if extended then
            text = "-"..text.."-"
        end
        extendButtonCell = Helper.createButton(Helper.createButtonText(text, "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 0, Helper.standardTextHeight)
        hasExtendButton = true
    else
        extendButtonCell = ""
    end
    
    local classIconCell
    local hasCheckBox = false
    
    if isPlayer and not isCommandSelection and not updateMode and menu.multiSelectMode and isCommandRecipient then
        classIconCell = Helper.createCheckBox(menu.checkedComponents[tostring(ship)] ~= nil, false, textColor, true, nil, nil, textHeight)
        hasCheckBox = true
    else
        classIconCell = Helper.createIcon(iconName, false, textColor.r, textColor.g, textColor.b, 100, 0, 0, textHeight, textHeight)
    end
    
    local textCellString = name .. warningString .. spaceAndGrey2 .. commandString
    
    if not updateMode and not isCommandSelection then
        rowData = {
            obj = ship,
            extendButton = hasExtendButton,
            checkBox = hasCheckBox,
            applyScriptFunction = setShipRowScripts
        }
    end
    
    if updateMode then
        if isCommandSelection then
            Helper.updateCellText(updateTable, updateRow, 1, tostring(#subordinates), menu.white)
        end
        if isCommandSelection or (rowData and not rowData.checkBox) then
            SetCellContent(updateTable, classIconCell, updateRow, 2)
        end
        Helper.updateCellText(updateTable, updateRow, 3, textCellString, textColor)
    else
        setup:addRow(true, {
            --expand/collapse subordinates, if available
            extendButtonCell,
            --small icon like in X3 map
            classIconCell,
            --name
            Helper.createFontString(textCellString, false, "left", textColor.r, textColor.g, textColor.b, 100, nil, fontSize, nil, nil, nil, textHeight),
        }, rowData, {1, 1, 3})
    end
    
    if not isCommandSelection and not updateMode and IsSameComponent(ship, menu.nextSelection) then
        menu.nextSelectedRow = #setup.rows
    end
    
    --if we are extended, display all our subordinates as well
    if extended and not updateMode and not isCommandSelection then
        if #subordinates > 0 then table.sort(subordinates, shipSortFunc) end
        for k, sub in pairs(subordinates) do
            displayShip(setup, sub, nil, nil, nil, nil, nil, depth+1)
        end
    end
end

local function displayStation(setup, station)
    local fontSize = 10
    local textHeight = 16
    
    local nameUnlocked = IsInfoUnlockedForPlayer(station, "name")
    
    local isPlayer, revealPercent, isMissionTarget, isEnemy, hasTradeAgent = GetComponentData(station, "isplayerowned", "revealpercent", "ismissiontarget", "isenemy", "tradesubscription")
    
    local textColor
    if not nameUnlocked then
        textColor = menu.grey
    elseif isMissionTarget then
        textColor = menu.holomapColor.missionColor
    elseif isPlayer then
        textColor = menu.holomapColor.playerColor
    elseif isEnemy then
        textColor = menu.holomapColor.enemyColor
    else
        textColor = menu.holomapColor.friendColor
    end
    
    local rowData = {
        obj = station,
        extendButton = false,
        checkBox = false
    }
    
    local numIcons = 0
    local warningLevel = isPlayer and Helper.hasObjectWarning(station) or 0
    if hasTradeAgent then
        numIcons = numIcons + 1
    end
    if warningLevel > 0 then
        numIcons = numIcons + 1
    end
    
    local extendButtonCell = ""
    
    local classIcon = Helper.createIcon("mej_station", false, textColor.r, textColor.g, textColor.b, 100, 0, 0, Helper.standardTextHeight, Helper.standardTextHeight)
    
    local name
    if nameUnlocked then
        name = GetComponentData(station, "name") .. getRevealString(revealPercent)
    else
        name = "???"
    end
    
    local nameCell = Helper.createFontString(name, false, "left", textColor.r, textColor.g, textColor.b, 100, nil, fontSize, nil, nil, nil, textHeight)
    
    local cellContents = {
        --expand/collapse subordinates, if available
        extendButtonCell,
        --small icon like in X3 map
        classIcon,
        --name
        nameCell
    }
    
    if warningLevel > 0 then
        local warningColor = warningLevel > 1 and menu.red or menu.holomapColor.missionColor
        table.insert(cellContents, Helper.createIcon("workshop_error", false, warningColor.r, warningColor.g, warningColor.b, 100, 0, 0, Helper.standardTextHeight, 24))
    end
    if hasTradeAgent then
        table.insert(cellContents, Helper.createIcon("menu_eye", false, 255, 255, 255, 100, 0, 0, Helper.standardTextHeight, 24))
    end
    
    local colSpans
    if numIcons == 2 then
        colSpans = {1, 1, 1, 1, 1}
    elseif numIcons == 1 then
        colSpans = {1, 1, 2, 1}
    else
        colSpans = {1, 1, 3}
    end
    
    setup:addRow(true, cellContents, rowData, colSpans)
    
    
    if IsSameComponent(station, menu.nextSelection) then
        menu.nextSelectedRow = #setup.rows
    end
end

local function displayGate(setup, gate)
    local name, destination = GetComponentData(gate, "name", "destination")
    local destinationText
    
    local textColor
    if GetComponentData(gate, "ismissiontarget") then
        textColor = menu.holomapColor.missionColor
    else
        textColor = menu.lightGrey
    end
   
    if destination then
        destinationText = GetComponentData(GetContextByClass(destination, "cluster"), "name")
    else
        destinationText = menu.text.unknownSystem
    end
    
    name = name .. ": " .. destinationText
    
    name = applyTargetArrows(setup, gate, name)
    
    local rowData = {
        obj = gate,
        extendButton = false,
        checkBox = false
    }
    
    setup:addRow(true, {
        "",
        Helper.createIcon("mej_jumpgate", false, textColor.r, textColor.g, textColor.b, 100, 0, 0, Helper.standardTextHeight, Helper.standardTextHeight),
        Helper.createFontString(name, false, "left", textColor.r, textColor.g, textColor.b, 100, nil, Helper.standardFontSize, nil, nil, nil, Helper.standardTextHeight),
    }, rowData, {1, 1, 3})
    
    if IsSameComponent(gate, menu.nextSelection) then
        menu.nextSelectedRow = #setup.rows
    end
end

local function displayBeacon(setup, beacon)
    local name = GetComponentData(beacon, "name")
    
    local textColor
    if GetComponentData(beacon, "ismissiontarget") then
        textColor = menu.holomapColor.missionColor
    else
        textColor = menu.lightGrey
    end
    
    local rowData = {
        obj = beacon,
        extendButton = false,
        checkBox = false
    }
    
    setup:addRow(true, {
        "",
        Helper.createIcon("mej_jumpbeacon", false, textColor.r, textColor.g, textColor.b, 100, 0, 0, Helper.standardTextHeight, Helper.standardTextHeight),
        Helper.createFontString(name, false, "left", textColor.r, textColor.g, textColor.b, 100, nil, Helper.standardFontSize, nil, nil, nil, Helper.standardTextHeight),
    }, rowData, {1, 1, 3})
    
    if IsSameComponent(beacon, menu.nextSelection) then
        menu.nextSelectedRow = #setup.rows
    end
end

function menu.clearSelectionClicked()
    menu.clearChecked()
    if not menu.displayMenuRunning then
        menu.displayMenu()
    end
end

menu.prevCommandSelection = 0
menu.prevNumChecked = 0
local multiSelectSeparator = "\27Z -- "
local function displayCommandSelection(setup)
    createMode = menu.displayMenuRunning
    
    if menu.commandSelectionRow == 0 and not createMode then
        return
    end
    
    local selectionChanged
    if menu.multiSelectMode then
        selectionChanged = menu.prevNumChecked ~= menu.numChecked
    else
        selectionChanged = (menu.prevCommandSelection == 0) and (menu.commandSelection ~= 0) or (not IsSameComponent(menu.prevCommandSelection, menu.commandSelection))
    end
    
    if menu.multiSelectMode then
        local numXL = 0
        local numL = 0
        local numM = 0
        local numS = 0
        for k, ship in pairs(menu.checkedComponents) do
            if IsComponentClass(ship, "ship_xl") then numXL = numXL + 1 end
            if IsComponentClass(ship, "ship_l") then numL = numL + 1 end
            if IsComponentClass(ship, "ship_m") then numM = numM + 1 end
            if IsComponentClass(ship, "ship_s") then numS = numS + 1 end
        end
        
        local shipClassList = {}
        if numXL > 0 then
            table.insert(shipClassList, "\27GXL: \27X" .. numXL)
        end
        if numL > 0 then
            table.insert(shipClassList, "\27GL: \27X" .. numL)
        end
        if numM > 0 then
            table.insert(shipClassList, "\27GM: \27X" .. numM)
        end
        if numS > 0 then
            table.insert(shipClassList, "\27GS: \27X" .. numS)
        end
        
        
        local cell1Content = Helper.createButton(Helper.createButtonText("X", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, menu.numChecked > 0, 0, 0, 0, Helper.standardTextHeight)
        
        
        local iconColor = menu.numChecked > 0 and menu.holomapColor.playerColor or menu.grey
        local cell2Content = Helper.createIcon("mej_multiselect", false, iconColor.r, iconColor.g, iconColor.b, 100, 0, 0, Helper.standardTextHeight, Helper.standardTextHeight)
        
        local cell3Content
        if #shipClassList > 0 then
            cell3Content = table.concat(shipClassList, multiSelectSeparator)
        else
            cell3Content = menu.text.selectionNone
        end
        
        if createMode then
            setup:addSimpleRow({
                cell1Content,
                cell2Content,
                cell3Content
            }, nil, {1, 1, 3})
        else
            if selectionChanged then
                Helper.removeButtonScripts(menu, menu.commandGridTable, menu.commandSelectionRow, 1)
                
                SetCellContent(menu.commandGridTable, cell1Content, menu.commandSelectionRow, 1)
                
                Helper.setButtonScript(menu, nil, menu.commandGridTable, menu.commandSelectionRow, 1, menu.clearSelectionClicked)
            end
            SetCellContent(menu.commandGridTable, cell2Content, menu.commandSelectionRow, 2)
            Helper.updateCellText(menu.commandGridTable, menu.commandSelectionRow, 3, cell3Content, menu.white)
        end
        
    elseif menu.commandSelection ~= 0 then
        displayShip(setup, menu.commandSelection, true, true, false, menu.commandGridTable, menu.commandSelectionRow)
        
        if not createMode then
            local currentRow = findRowForObject(menu.commandSelection)
            local prevRow = findRowForObject(menu.prevCommandSelection)
            local differentRows = currentRow ~= prevRow
            if differentRows then
                --refresh the current and previous command selection, as they will need their yellow arrow adding/removing as necessary
                if currentRow then
                    displayShip(setup, menu.commandSelection, false, true, false, menu.selectTable, currentRow)
                end
                if prevRow then
                    displayShip(setup, menu.prevCommandSelection, false, true, false, menu.selectTable, prevRow)
                end
            end
        end
        
        
    else
        if createMode then
            setup:addSimpleRow({
                Helper.createFontString("", false, "center", 255, 255, 255, 100, nil, fontSize, nil, nil, nil, textHeight),
                "",
                menu.text.selectionNone
            }, nil, {1, 1, 3})
        else
            Helper.updateCellText(menu.commandGridTable, menu.commandSelectionRow, 1, "")
            Helper.updateCellText(menu.commandGridTable, menu.commandSelectionRow, 2, "")
            Helper.updateCellText(menu.commandGridTable, menu.commandSelectionRow, 3, menu.text.selectionNone, menu.white)
        end
    end
    
    if createMode then
        menu.commandSelectionRow = #setup.rows
    end
    
    if not createMode and selectionChanged then
        local orderObj = menu.getOrderObject(true)
        for k, order in ipairs(menu.gridOrders) do
            if order.row ~= nil and order.col ~= nil then
                menu.refreshOrderButton(order, orderObj)
            end
        end
    end
    
    menu.prevCommandSelection = menu.commandSelection
    menu.prevNumChecked = menu.numChecked
end

--check the current selection and target, set either one to null if it points to a nonoperational component
function menu.enforceSelections(noCommandUpdate)
    local commandUpdateNeeded = false
    
    if menu.currentSelection ~= 0 and not IsComponentOperational(menu.currentSelection) then
        menu.currentSelection = 0
    end
    if menu.nextSelection ~= 0 and not IsComponentOperational(menu.nextSelection) then
        menu.nextSelection = 0
    end
    
    if menu.multiSelectMode then
        for k, ship in pairs(menu.checkedComponents) do
            if not IsComponentOperational(ship) then
                menu.uncheck(ship)
                commandUpdateNeeded = true
            end
        end
    elseif menu.commandSelection ~= 0 and not IsComponentOperational(menu.commandSelection) then
        menu.setCommandSelection(0)
        commandUpdateNeeded = true
    end
    if menu.commandTargetType == "object" and menu.commandTarget ~= 0 and not IsComponentOperational(menu.commandTarget) then
        menu.commandTarget = 0
        menu.commandTargetType = "none"
    end
    
    if commandUpdateNeeded and not noCommandUpdate then
        displayCommandSelection()
    end
end

function menu.extendObjectButton(ship)
    if menu.isExtended(ship) then
        menu.collapse(ship)
    else
        menu.extend(ship)
    end
    menu.nextSelection = ship
    if not menu.displayMenuRunning then
        menu.displayMenuReason = "extend object button"
        menu.displayMenu()
    end
end

function menu.canViewDetails(obj)
    return (IsComponentClass(obj, "ship") or IsComponentClass(obj, "station")) and IsInfoUnlockedForPlayer(obj, "name") and (CanViewLiveData(obj) or GetComponentData(obj, "tradesubscription"))
end

function menu.createButton1()
    return Helper.createButton(Helper.createButtonText(menu.text.back, "center", Helper.standardFont, 9, 255, 255, 255, 100), nil, false, true, 0, 0, menu.buttonTableButtonWidth, 23, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_B", true))
end
function menu.createButton2()
    return Helper.createButton(Helper.createButtonText(menu.text.zoomOut, "center", Helper.standardFont, 9, 255, 255, 255, 100), nil, false, menu.currentSpaceType ~= "galaxy", 0, 0, menu.buttonTableButtonWidth, 23, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_BACK", true))
end
function menu.createButton3()
    local text
    local enabled
    
    if menu.currentSelection == 0 then
        text = menu.text.comm
        enabled = false
        
    elseif IsComponentClass(menu.currentSelection, "gate") or IsComponentClass(menu.currentSelection, "jumpbeacon") then
        local hasJumpdrive, charging, nextJumpTime, busy = GetComponentData(GetPlayerPrimaryShipID(), "hasjumpdrive", "isjumpdrivecharging", "nextjumptime", "isjumpdrivebusy")
        local onPlatform = IsComponentClass(GetPlayerRoom(), "dockingbay")
        
        if hasJumpdrive then
            if nextJumpTime > GetCurTime() then
                text = menu.text.jump
                enabled = false
                
            elseif busy then
                text = menu.text.jumping
                enabled = false
                
            elseif charging then
                text = menu.text.abortJump
                enabled = not onPlatform
            
            else
                text = menu.text.jump
                enabled = not onPlatform
            end
        else
            text = menu.text.jump
            enabled = false
        end
    
    elseif IsComponentClass(menu.currentSelection, "zone") then
        if IsSameComponent(menu.currentSelection, GetActiveGuidanceMissionComponent()) then
            text = menu.text.abortCourse
            enabled = true
        else
            text = menu.text.plotCourse
            enabled = not IsSameComponent(GetContextByClass(GetPlayerPrimaryShipID(), "zone"), menu.currentSelection)
        end
    
    elseif IsComponentClass(menu.currentSelection, "container") then
        text = menu.text.comm
        enabled = not IsSameComponent(menu.currentSelection, GetPlayerPrimaryShipID())
    
    else
        text = menu.text.comm
        enabled = false
    end
    
    return Helper.createButton(Helper.createButtonText(text, "center", Helper.standardFont, 9, 255, 255, 255, 100), nil, false, enabled, 0, 0, menu.buttonTableButtonWidth, 23, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_Y", true))
end
function menu.createButton4()
    local enabled
    local text
    
    if menu.currentSelection == 0 then
        text = "--"
        enabled = false
    else
        if IsComponentClass(menu.currentSelection, "space") then
            text = menu.text.zoomIn
            enabled = true
        else
            text = menu.text.details
            enabled = menu.canViewDetails(menu.currentSelection)
        end
    end
    return Helper.createButton(Helper.createButtonText(text, "center", Helper.standardFont, 9, 255, 255, 255, 100), nil, false, enabled, 0, 0, menu.buttonTableButtonWidth, 23, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_X", true))
end

function menu.button1Clicked()
    menu.onCloseElement("back")
end
function menu.button2Clicked()
    menu.tryZoomOut()
end
function menu.button3Clicked()
    menu.enforceSelections(true)
    if menu.currentSelection == 0 then return end
    
    if IsComponentClass(menu.currentSelection, "gate") or IsComponentClass(menu.currentSelection, "jumpbeacon") then
        if GetComponentData(GetPlayerPrimaryShipID(), "isjumpdrivecharging") then
            C.AbortPlayerPrimaryShipJump()
        else
            C.InitPlayerPrimaryShipJump(ConvertIDTo64Bit(menu.currentSelection))
        end
        --would be better just to update button 3
        menu.updateButtonsRow()
    
    elseif IsComponentClass(menu.currentSelection, "zone") then
        if IsSameComponent(menu.currentSelection, GetActiveGuidanceMissionComponent()) then
            Helper.closeMenuForSection(menu, false, "gMainNav_abort_plotcourse")
            menu.cleanup()
        else
            Helper.closeMenuForSection(menu, false, "gMainNav_plotcourse", {ConvertStringToLuaID(tostring(menu.currentSelection)), false})
            menu.cleanup()
        end
    elseif IsComponentClass(menu.currentSelection, "container") and not IsSameComponent(menu.currentSelection, GetPlayerPrimaryShipID()) then
        menu.tryComm(menu.currentSelection)
    end
end
function menu.button4Clicked()
    menu.enforceSelections(true)
    if menu.currentSelection == 0 then return end
    
    if IsComponentClass(menu.currentSelection, "space") then
        menu.tryZoomIn()
    elseif menu.canViewDetails(menu.currentSelection) then
        menu.objectDetails()
    end
end

function menu.objectDetails()
    Helper.closeMenuForSection(menu, false, "gMain_object_closeup", {0, 0, ConvertStringToLuaID(tostring(menu.currentSelection)), menu.getMarshaledHistory()})
    menu.cleanup()
end

function menu.updateButtonsRow()
    Helper.removeButtonScripts(menu, menu.buttonTable, 2, 2)
    Helper.removeButtonScripts(menu, menu.buttonTable, 2, 4)
    Helper.removeButtonScripts(menu, menu.buttonTable, 2, 6)
    Helper.removeButtonScripts(menu, menu.buttonTable, 2, 8)
    
    SetCellContent(menu.buttonTable, menu.createButton1(), 2, 2)
    SetCellContent(menu.buttonTable, menu.createButton2(), 2, 4)
    SetCellContent(menu.buttonTable, menu.createButton3(), 2, 6)
    SetCellContent(menu.buttonTable, menu.createButton4(), 2, 8)
    
    Helper.setButtonScript(menu, nil, menu.buttonTable, 2, 2, menu.button1Clicked)
    Helper.setButtonScript(menu, nil, menu.buttonTable, 2, 4, menu.button2Clicked)
    Helper.setButtonScript(menu, nil, menu.buttonTable, 2, 6, menu.button3Clicked)
    Helper.setButtonScript(menu, nil, menu.buttonTable, 2, 8, menu.button4Clicked)
end

function menu.tryComm(component)
    if not GetComponentData(component, "caninitiatecomm") then return end
    local entities = Helper.getSuitableControlEntities(component, true)
    if #entities == 1 then
        Helper.closeMenuForSubConversation(menu, false, "default", entities[1], component, (not Helper.useFullscreenDetailmonitor()) and "facecopilot" or nil)
    else
        Helper.closeMenuForSubSection(menu, false, "gMain_propertyResult", component)
    end
    menu.cleanup()
end

function menu.setupCommandGrid(setup)
    local orderObj = menu.getOrderObject(true)
    
    setup:addHeaderRow({Helper.createFontString("", nil, nil, nil, nil, nil, nil, nil, 6, nil, nil, nil, 6)}, nil, {5})
    displayCommandSelection(setup)
    
    --just in case...
    for k, order in ipairs(menu.gridOrders) do
        order.row = nil
        order.col = nil
    end
    
    --find "about" the weight of each button
    
    local thisRow = {}
    for k, order in ipairs(menu.gridOrders) do
        --make the new button
        local button = menu.getOrderButton(order, orderObj)
        
        table.insert(thisRow, button)
        order.row = #setup.rows + 1
        order.col = menu.gridEffectiveColumns[#thisRow]
        
        if #thisRow >= menu.numCommandButtonCols then
            setup:addSimpleRow(thisRow, nil, clone(menu.gridColSpans))
            thisRow = {}
        end
    end
    
    --if all the orders are there but thisRow isn't empty, pad it and slap it in there
    if #thisRow ~= 0 then
        while #thisRow < menu.numCommandButtonCols do
            table.insert(thisRow, "")
        end
        setup:addSimpleRow(thisRow, nil, clone(menu.gridColSpans))
        thisRow = {}
    end
    
    return commandButtonColWidths
end

function menu.isGridButtonEnabled(order, obj)
    if menu.multiSelectMode and not order.multicast then return false end
    
    if menu.hasCommandRecipient() then
        
        for k, ship in pairs(menu.getCommandRecipients()) do
            obj.subject = ship
            if not order.buttonFilter(obj) then return false end
        end
        return true
        
    else
        return false
    end
end

function menu.getOrderButton(order, orderObj)
    local enabled = menu.isGridButtonEnabled(order, orderObj)
    local color
    local text = order.buttonText
    if menu.activeGridOrder == order then
        color = menu.holomapColor.missionColor
        text = "> " .. text .. " <"
    else
        color = menu.white
    end
    return Helper.createButton(Helper.createButtonText(text, "center", Helper.standardFont, 9, color.r, color.g, color.b, 100), nil, false, enabled, nil, nil, nil, 23)
end

function menu.refreshOrderButton(order, orderObj)
    Helper.removeButtonScripts(menu, menu.commandGridTable, order.row, order.col)
    SetCellContent(menu.commandGridTable, menu.getOrderButton(order, orderObj), order.row, order.col)
    Helper.setButtonScript(menu, nil, menu.commandGridTable, order.row, order.col, order.buttonScript)
end

function menu.setActiveGridOrder(newOrder)
    local orderObj = menu.getOrderObject(true)

    local oldOrder = menu.activeGridOrder
    menu.activeGridOrder = newOrder
    
    if oldOrder ~= newOrder then
        DebugError("Active order has changed from " .. (oldOrder and oldOrder.buttonText or "none") .. " to " .. (newOrder and newOrder.buttonText or "none"))
        if oldOrder ~= nil then menu.refreshOrderButton(oldOrder, orderObj) end
        if newOrder ~= nil then menu.refreshOrderButton(newOrder, orderObj) end
    end
end

local globalOrderObj = {}
function menu.getOrderObject(noTarget)
    menu.enforceSelections()
    newObj = {}
    if not menu.multiSelectMode then
        newObj.subject = menu.commandSelection
    end
    newObj.space = menu.currentSpace
    newObj.spaceType = menu.currentSpaceType
    newObj.menu = menu
    
    if noTarget then
        newObj.target = 0
        newObj.targetType = "none"
    else
        newObj.target = menu.commandTarget
        newObj.targetType = menu.commandTargetType
    end
    
    return newObj
end

function menu.setStatusMessage(msg, noset)
    menu.statusMessage = msg
    if not noset then Helper.updateCellText(menu.buttonTable, 1, 1, msg, menu.white) end
end

function menu.setCommandGridScripts()
    for k, order in ipairs(menu.gridOrders) do
        if order.row ~= nil and order.col ~= nil then
            Helper.setButtonScript(menu, nil, menu.commandGridTable, order.row, order.col, order.buttonScript)
        end
    end
end

function menu.displayMenu(firstTime)
    menu.displayMenuRunning = true
    
    local gridTopRow = -1
    
    --remove old data
    if not firstTime then
        Helper.removeAllKeyBindings(menu)
        Helper.removeAllButtonScripts(menu)
        Helper.currentTableRow = {}
        Helper.currentTableRowData = nil
        menu.rowDataMap = {}
        
        gridTopRow = GetTopRow(menu.commandGridTable)
    end
    
    Helper.setKeyBinding(menu, menu.onHotkey)
    
    local fixedRows = 0
    
    --make sure they're is still valid
    menu.enforceSelections(true)
    
    --selected object might not have a row because its commanders aren't extended
    if menu.nextSelection ~= 0 and C.IsShip(ConvertIDTo64Bit(menu.nextSelection)) and GetCommander(menu.nextSelection) then
        for k, com in pairs(GetAllCommanders(menu.nextSelection)) do
            menu.extend(com)
        end
    end
    
    --create render target
    --=========================================
    local renderTargetDesc = Helper.createRenderTarget(menu.renderTargetWidth, menu.renderTargetHeight, 0, 0)
    
    --create table for selectable ships
    --=========================================
    local setup = Helper.createTableSetup(menu)
    
    
    local topSelectRow = nil
    if not firstTime then
        topSelectRow = GetTopRow(menu.selectTable)
    end
    
    menu.nextSelectedRow = 0
    --if it's still available, it'll be set by a row change event
    menu.currentSelection = 0
    local spaceType
    local spaceName
    local headerText
    
    if menu.currentSpaceType == "zone" then
        spaceType = ReadText(20001, 301)
    elseif menu.currentSpaceType == "sector" then
        spaceType = ReadText(20001, 201)
    elseif menu.currentSpaceType == "cluster" then
        spaceType = ReadText(20001, 101)
    elseif menu.currentSpaceType == "galaxy" then
        spaceType = ReadText(20001, 901)
    end
    
    if menu.currentSpaceType == "galaxy" then
        headerText = spaceType
    else
        headerText = spaceType .. ": " .. ffi.string(C.GetComponentName(menu.currentSpace))
    end
    
    --name of zone/sector/cluster/galaxy
    setup:addSimpleRow({
        Helper.createButton(nil, Helper.createButtonIcon("menu_stats", nil, 255, 255, 255, 100), false, PlayerPrimaryShipHasContents("economymk1")),
        Helper.createFontString(headerText, false, "left", 255, 255, 255, 100, Helper.headerRow1Font, Helper.headerRow1FontSize, false, Helper.headerRow1Offsetx, Helper.headerRow1Offsety, Helper.headerRow1Height, Helper.headerRow1Width)
    }, nil, {2, #menu.selectColumnWidths - 2}, false, Helper.defaultTitleBackgroundColor)
    local headerRow = #setup.rows
    
    --separator
    setup:addHeaderRow({Helper.createFontString("", nil, nil, nil, nil, nil, nil, nil, 6, nil, nil, nil, 6)}, nil, {#menu.selectColumnWidths})
    
    fixedRows = #setup.rows
    
    if menu.currentSpaceType == "zone" then
        menu.displayZoneList(setup)
    else
        menu.displayChildSpaces(setup)
    end
    
    local selectDesc = setup:createCustomWidthTable({unpack(menu.selectColumnWidths)}, false, false, true, 1, fixedRows, menu.selectTableOffsetX, 0, menu.selectTableHeight, nil, topSelectRow, menu.nextSelectedRow)
    
    --table for ABXY buttons
    --=========================================
    
    setup = Helper.createTableSetup(menu)
    
    local toggleMultiColor
    if menu.multiSelectMode then
        toggleMultiColor = menu.holomapColor.playerColor
    else
        toggleMultiColor = menu.grey
    end
    local toggleMultiEnabled = not menu.mode
    
    setup:addRow(true, {
        menu.statusMessage,
        Helper.createFontString("", false, "right", 255, 255, 255, 100),
        -- Helper.createButton(Helper.createButtonText("M", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 0, Helper.standardTextHeight, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_LB", false))
        Helper.createButton(nil, Helper.createButtonIcon("mej_multiselect", nil, toggleMultiColor.r, toggleMultiColor.g, toggleMultiColor.b, 100), false, toggleMultiEnabled, 0, 0, 0, Helper.standardTextHeight, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_LB", false))
    }, nil, {4,4,1})
    
    setup:addSimpleRow({ 
        Helper.getEmptyCellDescriptor(),
        menu.createButton1(),
        Helper.getEmptyCellDescriptor(),
        menu.createButton2(),
        Helper.getEmptyCellDescriptor(),
        menu.createButton3(),
        Helper.getEmptyCellDescriptor(),
        menu.createButton4(),
        Helper.getEmptyCellDescriptor()
    }, nil, nil, false, menu.transparent)
    
    local buttonTableDesc = setup:createCustomWidthTable(
    {
        menu.buttonTableSpacerWidth,
        menu.buttonTableButtonWidth,
        menu.buttonTableSpacerWidth,
        menu.buttonTableButtonWidth,
        menu.buttonTableSpacerWidth,
        menu.buttonTableButtonWidth,
        menu.buttonTableSpacerWidth,
        menu.buttonTableButtonWidth,
        menu.buttonTableSpacerWidth
    }, false, false, false, 2, 2, 2, Helper.standardSizeY-50, 0, false)
    
    --command button table
    --=========================================
    
    setup = Helper.createTableSetup(menu)
    menu.setupCommandGrid(setup)
    
    local gridDesc = setup:createCustomWidthTable(clone(menu.gridColWidths), false, false, true, 3, 2, menu.selectTableOffsetX, menu.commandTableOffsetY, Helper.standardSizeY - menu.commandTableOffsetY, nil, gridTopRow ~= -1 and gridTopRow or nil)
    
    --create and display the table view
    --=========================================
    menu.selectTable, menu.buttonTable, menu.commandGridTable, menu.renderTarget = Helper.displayThreeTableRenderTargetView(menu, selectDesc, buttonTableDesc, gridDesc, renderTargetDesc)
    
    --there's many different requirements for what scripts a row needs, so we let it 'do it itself', and all the code for that row is in one place
    for i = fixedRows + 1, GetTableNumRows(menu.selectTable) do
        local data = menu.rowDataMap[i]
        if data ~= nil and data.applyScriptFunction then
            data.applyScriptFunction(i, data)
        end
    end
    
    --set button script for economy stats
    Helper.setButtonScript(menu, nil, menu.selectTable, headerRow, 1,
        function()
            Helper.closeMenuForSubSection(menu, false, "gMain_economystats", {0, 0, ConvertStringTo64Bit(tostring(menu.currentSpace)), menu.getMarshaledHistory()})
            menu.cleanup()
        end
    )
    
    --set button script for multi-select toggle
    Helper.setButtonScript(menu, nil, menu.buttonTable, 1, 9, menu.toggleMultiSelectMode)
    
    --set button script to clear selection in multi-select mode
    if menu.multiSelectMode then
        Helper.setButtonScript(menu, nil, menu.commandGridTable, menu.commandSelectionRow, 1, menu.clearSelectionClicked)
    end
    
    --apply ABXY button scripts
    Helper.setButtonScript(menu, nil, menu.buttonTable, 2, 2, menu.button1Clicked)
    Helper.setButtonScript(menu, nil, menu.buttonTable, 2, 4, menu.button2Clicked)
    Helper.setButtonScript(menu, nil, menu.buttonTable, 2, 6, menu.button3Clicked)
    Helper.setButtonScript(menu, nil, menu.buttonTable, 2, 8, menu.button4Clicked)
    
    menu.setCommandGridScripts()
    
    Helper.releaseDescriptors()
    
    menu.displayMenuRunning = false
end

function menu.clearChecked()
    for k, ship in pairs(menu.checkedComponents) do
        menu.uncheck(ship)
    end
end

function menu.check(ship)
    if menu.checkedComponents[tostring(ship)] == nil then
        menu.numChecked = menu.numChecked + 1
        menu.checkedComponents[tostring(ship)] = ship
    end
end

function menu.uncheck(ship)
    if menu.checkedComponents[tostring(ship)] ~= nil then
        menu.numChecked = menu.numChecked - 1
        menu.checkedComponents[tostring(ship)] = nil
    end
end

function menu.checkBoxSwitched(component, row)
    if menu.checkedComponents[tostring(component)] ~= nil then
        menu.uncheck(component)
    else
        menu.check(component)
    end
    displayCommandSelection()
    local rowData = menu.rowDataMap[row]
    if rowData and rowData.obj then
        displayShip(nil, rowData.obj, false, true, false, menu.selectTable, row)
    end
end

function menu.displayZoneList(setup)
    local luaSpace = ConvertStringTo64Bit(tostring(menu.currentSpace))
    
    local separatorNeeded = false
    
    local yields = GetZoneYield(luaSpace)
    for k, yield in ipairs(yields) do
        local yieldText = yield.name .. ": " .. ConvertIntegerString(yield.amount, true, 3, true) .. " / " .. ConvertIntegerString(yield.max, true, 3, true)
        setup:addRow(false, {yieldText}, nil, {5})
        separatorNeeded = true
    end
    
    local allStations = GetContainedStations(luaSpace, true)
    for k, station in ipairs(allStations) do
        displayStation(setup, station)
        separatorNeeded = true
    end
    
    local allGates = GetGates(luaSpace, true)
    for k, gate in ipairs(allGates) do
        displayGate(setup, gate)
        separatorNeeded = true
    end
    
    local allJumpBeacons = GetJumpBeacons(luaSpace, true)
    for k, beacon in ipairs(allJumpBeacons) do
        displayBeacon(setup, beacon)
        separatorNeeded = true
    end
    
    if separatorNeeded then
        setup:addHeaderRow({Helper.createFontString("", nil, nil, nil, nil, nil, nil, nil, 6, nil, nil, nil, 6)}, nil, {5})
    end
    
    local allShips = GetContainedShips(luaSpace, true)
    local playerShips = {}
    local enemyShips = {}
    local neutralShips = {}
    for k, ship in ipairs(allShips) do
        if shouldDisplayShip(ship, "zone") then
            if GetComponentData(ship, "isplayerowned") then
                table.insert(playerShips, ship)
            elseif GetComponentData(ship, "isenemy") then
                table.insert(enemyShips, ship)
            else
                table.insert(neutralShips, ship)
            end
        end
    end
    
    table.sort(playerShips, shipSortFunc)
    table.sort(enemyShips, shipSortFunc)
    table.sort(neutralShips, shipSortFunc)
    
    for k, ship in ipairs(playerShips) do
        displayShip(setup, ship, false, true, false)
    end
    for k, ship in ipairs(enemyShips) do
        displayShip(setup, ship, false, false, true)
    end
    for k, ship in ipairs(neutralShips) do
        displayShip(setup, ship, false, false, false)
    end
end

function menu.displayChildSpaces(setup)
    --determine list of spaces and icon
    local spaces
    local childSpaceType
    local shortNameHere
    local luaCurSpace = ConvertStringTo64Bit(tostring(menu.currentSpace))
    if menu.currentSpaceType == "galaxy" then
        spaces = GetClusters(true)
        spaceIcon = "menu_cluster"
        childSpaceType = "cluster"
        shortNameHere = ""
    elseif menu.currentSpaceType == "cluster" then
        spaces = GetSectors(luaCurSpace)
        spaceIcon = "menu_sector"
        childSpaceType = "sector"
        shortNameHere = GetComponentData(luaCurSpace, "mapshortname") .. "."
    elseif menu.currentSpaceType == "sector" then
        spaces = GetZones(luaCurSpace)
        spaceIcon = "menu_zone"
        childSpaceType = "zone"
        shortNameHere = GetComponentData(GetContextByClass(luaCurSpace, "cluster"), "mapshortname") .. "." .. GetComponentData(luaCurSpace, "mapshortname") .. "."
    else
        return
    end
    
    local topHistory = #menu.history > 1 and ConvertStringTo64Bit(tostring(menu.history[#menu.history - 1].space)) or 0
    
    for k, space in ipairs(spaces) do
        local rowData = {
            obj = space,
            extendButton = true,
            applyScriptFunction = setSpaceRowScripts
        }
        
        local name, shortName, isMissionTarget, revealPercent = GetComponentData(space, "name", "mapshortname", "ismissiontarget", "revealpercent")
        name = shortNameHere .. shortName .. ": " .. name
        
        local nameColor = menu.white
        local playerShipsHere = GetContainedShipsByOwner("player", space)
        --filterByDisplayable(playerShipsHere, childSpaceType)
        local playerStationsHere = GetContainedStationsByOwner("player", space)
        
        if isMissionTarget then
            nameColor = menu.holomapColor.missionColor
        elseif #playerShipsHere > 0 or #playerStationsHere > 0 then
            nameColor = menu.holomapColor.playerColor
        end
        
        local selectZoneButton = Helper.createButton(nil, Helper.createButtonIcon(spaceIcon, nil, 255,255,255,100), false, true, 0, 0, menu.extendButtonWidth, menu.extendButtonWidth)
        
        local infoText = ""
        
        if (childSpaceType == "sector" or childSpaceType == "zone") and HasShipyard(space) then
            infoText = infoText .. " [" .. ReadText(1001, 92) .. "]"
        end
        
        if childSpaceType == "zone" and GetComponentData(space, "hasjumpbeacon") then
            infoText = infoText .. " [" .. ReadText(20109, 2101) .. "]"
        end
        
        if IsSameComponent(space, topHistory) then
            infoText = infoText .. " " .. ReadText(1001, 3209)
        end
        
        if childSpaceType == "zone" then
            local yields = GetZoneYield(space)
            if #yields > 0 then
                infoText = infoText .. "\n"
                for i, yield in ipairs(yields) do
                    if i > 1 then
                        infoText = infoText .. ", "
                    end
                    infoText = infoText .. GetWareData(yield.ware, "shortname")
                end
            end
        end
        
        local textCell = name .. getRevealString(revealPercent)
        if string.len(infoText) > 0 then
            textCell = textCell .. spaceAndGrey2 .. infoText
        end
        textCell = Helper.createFontString(textCell, false, "left", nameColor.r, nameColor.g, nameColor.b, nameColor.a, nil, 9, true, nil, nil, menu.extendButtonWidth)
        
        setup:addRow(true, {
            --button to go into zone
            selectZoneButton,
            --name and details
            textCell,
        }, rowData, {1,4})
        
        if IsSameComponent(space, menu.nextSelection) then
            menu.nextSelectedRow = #setup.rows
        end
        
        if menu.currentSpaceType == "sector" then
            for k, station in ipairs(playerStationsHere) do
                displayStation(setup, station)
            end
            if #playerShipsHere > 0 then table.sort(playerShipsHere, shipSortFunc) end
            for k, ship in ipairs(playerShipsHere) do
                if not IsComponentClass(ship, "ship_xs") and getCommandRecipient(ship) == ship then
                    displayShip(setup, ship, false, true, false)
                end
            end
        end
    end
end

function menu.componentSelected(rowdata, highlight)
    if not rowdata then
        return
    end
    
    local component = rowdata.obj
    
    menu.currentSelection = component
    Helper.updateCellText(menu.buttonTable, 1, 5, getComponentInfo(menu.currentSelection))
    menu.updateButtonsRow()
    
    
    if not menu.mode and not menu.multiSelectMode and component ~= 0 and C.IsShip(ConvertIDTo64Bit(component)) and GetComponentData(component, "isplayerowned") then
        --don't change the command selection if it's a ship who can't receive orders
        local newSelection = getCommandRecipient(component)
        menu.setCommandSelection(newSelection or menu.commandSelection)
        displayCommandSelection()
    end
    
    --ships and stuff really mustn't be highlighted when the holomap isn't in zone mode, it clearly wasn't made for it and looks very screwy, so we prevent it
    if menu.holomap ~= 0 and menu.currentSelection ~= 0 and highlight then
        if (menu.currentSpaceType ~= "zone" and not IsComponentClass(menu.currentSelection, "space")) then
            C.SetHighlightMapComponent(menu.holomap, ConvertIDTo64Bit(GetContextByClass(component, "zone")), false)
        else
            C.SetHighlightMapComponent(menu.holomap, ConvertIDTo64Bit(component), false)
        end
    end
end

function menu.onRowChangedSound()
    if menu.ignoreSelectRowChange == 0 then
        PlaySound("ui_table_row_change")
    end
end
function menu.onRowChanged(row, rowdata, whichTable)
    if whichTable == menu.selectTable then
        menu.componentSelected(rowdata and rowdata or nil, true)
    end
end

function menu.softTarget(obj)
    ffiObj = ConvertIDTo64Bit(obj)
    
    if IsComponentClass(GetPlayerRoom(), "dockingbay") then
        return
    end
    if IsComponentClass(obj, "jumpbeacon") then
        return
    end
    if IsSameComponent(obj, GetPlayerPrimaryShipID()) then
        return
    end
    
    if C.SetSofttarget(ffiObj) then
        menu.nextSelection = obj
        if not menu.displayMenuRunning then
            menu.displayMenuReason = "new soft target"
            menu.displayMenu()
        end
    end
end

menu.updateInterval = 0.5
function menu.onUpdate()
    menu.enforceSelections(true)
    
    --on first update call, set up the holomap
    if menu.activateMap then
        menu.activateMap = false
        
        local renderX0, renderX1, renderY0, renderY1 = Helper.getRelativeRenderTargetSize(menu.renderTarget)
        local rendertargetTexture = GetRenderTargetTexture(menu.renderTarget)
        
        if rendertargetTexture then
            menu.holomap = C.AddHoloMap(rendertargetTexture, renderX0, renderX1, renderY0, renderY1)
            
            if menu.holomap ~= 0 then
                C.ShowUniverseMap(menu.holomap, menu.currentSpace, true, 0)
                if menu.currentSelection ~= 0 then
                    C.SetHighlightMapComponent(menu.holomap, ConvertIDTo64Bit(menu.currentSelection), true)
                end
            end
        end
    end
    
    if menu.nextUpdateQuickly then
        menu.nextUpdateQuickly = false
        menu.updateHolomap(true)
    else
        displayCommandSelection()
        Helper.updateCellText(menu.buttonTable, 1, 5, getComponentInfo(menu.currentSelection))
    end
end

menu.holomapUpdateInterval = 3
function menu.updateHolomap(force)
    local curTime = GetCurRealTime()
    
    if curTime > menu.lastHolomapUpdate + menu.holomapUpdateInterval then
        menu.lastHolomapUpdate = curTime
        
        menu.nextSelection = menu.currentSelection
        
        if not menu.displayMenuRunning then
            menu.displayMenuReason = "holo map update"
            menu.displayMenu()
        end
    end
end

function menu.onRenderTargetMouseDown()
    menu.timeLastMouseDown = GetCurRealTime()
    C.StartPanMap(menu.holomap)
end

function menu.onRenderTargetMouseUp()
    C.StopPanMap(menu.holomap)
    if GetCurRealTime() < menu.timeLastMouseDown + 0.2 then
        menu.mapClicked("left")
    end
end

function menu.onRenderTargetRightMouseDown()
    menu.timeLastRightMouseDown = GetCurRealTime()
    C.StartRotateMap(menu.holomap)
end


function menu.onRenderTargetRightMouseUp()
    C.StopRotateMap(menu.holomap)
    if GetCurRealTime() < menu.timeLastRightMouseDown + 0.2 then
        menu.mapClicked("right")
    end
end

function menu.onRenderTargetScrollDown()
    C.ZoomMap(menu.holomap, 1)
end

function menu.onRenderTargetScrollUp()
    C.ZoomMap(menu.holomap, -1)
end

function menu.onSelectElement(tab)
    local rowData = menu.rowDataMap[Helper.currentTableRow[menu.selectTable]]
    if rowData ~= nil then
        menu.onItemDoubleClick(rowData.obj)
    end
end

function menu.onRenderTargetDoubleClick()
    local ffiPicked = C.GetPickedMapComponent(menu.holomap)
    local luaPicked = ConvertStringTo64Bit(tostring(ffiPicked))
    
    if ffiPicked ~= 0 then
        menu.onItemDoubleClick(luaPicked)
    end
end

--for when something is double clicked by either table or map
function menu.onItemDoubleClick(component)
    if menu.currentSpaceType == "zone" then
        menu.softTarget(component)
    elseif menu.currentSpaceType == "sector" or menu.currentSpaceType == "cluster" or menu.currentSpaceType == "galaxy" then
        menu.tryZoomIn(component)
    end
end

local function getApplicableOrders(orderInfo)
    local ordersWithPrio = {}
    
    for k, order in pairs(menu.issuableOrders) do
        local priority = order.priority or 0
        
        local filterResult = (not menu.multiSelectMode or order.multicast) and order.filter(orderInfo)
        local isNumber = type(filterResult) == "number"
        
        priority = isNumber and filterResult or priority
        
        if isNumber or (type(filterResult) == "boolean" and filterResult == true) then
            table.insert(ordersWithPrio, {
                order = order,
                priority = priority
            })
        end
    end
    if #ordersWithPrio > 1 then
        table.sort(ordersWithPrio, function(a, b) return a.priority > b.priority end)
    end
    
    local result = {}
    for k, v in ipairs(ordersWithPrio) do
        table.insert(result, v.order)
    end
    
    return result
end


--make sure you use hasRecipient before calling this, as it will assume a recipient exists
function menu.broadcastOrder(order, isButtonFilter)
    local auto = order == nil
    
    local filterFunc
    if not auto then
        filterFunc = isButtonFilter and order.buttonFilter or order.filter
    end
    
    local numSuccess = 0
    local recip = {}
    for k, ship in pairs(menu.getCommandRecipients()) do
        table.insert(recip, ship)
    end
    local numRecip = #recip
    
    local orderObj = menu.getOrderObject(isButtonFilter)
    for k, ship in pairs(recip) do
        orderObj.subject = ship
        local success = false
        
        if auto then
            order = getApplicableOrders(orderObj)[1]
            success = order ~= nil
        else
            success = (not menu.multiSelectMode or order.multicast) and filterFunc(orderObj)
        end
        
        if success then
            numSuccess = numSuccess + 1
            order.issue(orderObj)
        end
    end
    
    if not menu.shouldBeClosed then
        if numSuccess > 0 then
            local recipientString
            if numRecip > 1 then
                -- recipientString = colorChar .. "Y" .. tostring(numSuccess) .. colorChar .. "X" .. " of " .. tostring(numRecip) .. ": "
                recipientString = string.format(menu.text.successOfTotal, "\27Y" .. tostring(numSuccess) .. "\27X", tostring(numRecip)) .. ": "
            else
                recipientString = "\27Y" .. GetComponentData(recip[1], "name") .. "\27X" .. ": "
            end
            
            local commandString
            if numRecip > 1 and auto then
                commandString = ""
            else
                commandString = (order.buttonText or order.name) .. " "
            end
            PlaySound(menu.commandAcceptSound)
            menu.setStatusMessage(recipientString .. commandString .. menu.text.commandAccepted)
        else
            PlaySound(menu.commandRejectSound)
            menu.setStatusMessage(menu.text.commandRejected)
        end
    end
end

function menu.mapClicked(button)
    if button == "left" then
    
        --left click: try to select an object or space
        local ffiPicked = C.GetPickedMapComponent(menu.holomap)
        local luaPicked = ConvertStringTo64Bit(tostring(ffiPicked))
        
        if ffiPicked ~= 0 and C.IsComponentOperational(ffiPicked) and not IsComponentClass(luaPicked, "ship_xs") then
            local row = findRowForObject(luaPicked)
            if row then
                SelectRow(menu.selectTable, row)
            else
                --Maybe the ship just entered view, but the list doesn't reflect this yet, or the ship is a subordinate of a collapsed commander
                menu.nextSelection = luaPicked
                menu.displayMenuReason = "left click on map"
                menu.displayMenu()
            end
        end
    
    else
    
        menu.enforceSelections()
        if menu.hasCommandRecipient() then
            --right click: try to select command target and issue order
            local ffiPicked = C.GetPickedMapComponent(menu.holomap)
            local luaPicked = ConvertStringTo64Bit(tostring(ffiPicked))
            
            if ffiPicked == 0 then
                --target a point in space
                local clickOffset = ffi.new("UIPosRot")
                local offsetValid = C.GetMapPositionOnEcliptic(menu.holomap, clickOffset, true)
                if offsetValid then
                    menu.commandTarget = clickOffset
                    menu.commandTargetType = "position"
                end
            elseif C.IsComponentOperational(ffiPicked) then
                menu.commandTarget = luaPicked
                menu.commandTargetType = "object"
            else
                menu.commandTarget = 0
                menu.commandTargetType = "none"
            end
            
            if menu.activeGridOrder ~= nil then
                menu.broadcastOrder(menu.activeGridOrder)
                if not menu.shouldBeClosed then
                    menu.setActiveGridOrder(nil)
                end
            else
                menu.broadcastOrder()
            end
            
        end
    end
end

function menu.zoomToSpace(space, spaceType)

    local prevSpace = menu.currentSpace
    
    menu.currentSpace = space
    menu.currentSpaceType = spaceType
    
    if #menu.history > 1 and menu.history[#menu.history-1].space == menu.currentSpace then
        menu.popHistory()
    else
        menu.pushHistory()
    end
    
    menu.nextSelection = ConvertStringToLuaID(tostring(prevSpace))
    menu.displayMenu(false)
    if menu.holomap ~= 0 then
        C.ClearHighlightMapComponent(menu.holomap)
        C.ShowUniverseMap(menu.holomap, menu.currentSpace, true, true)
    end
end

function menu.tryZoomOut()
    if menu.currentSpaceType == "galaxy" then
        return
    end
    
    local prevSpace = menu.currentSpace
    
    menu.displayMenuReason = "zoom out"
    
    if menu.currentSpaceType == "cluster" then
        menu.zoomToSpace(C.GetContextByClass(menu.currentSpace, "galaxy", true), "galaxy")
        
    elseif menu.currentSpaceType == "sector" then
        menu.zoomToSpace(C.GetContextByClass(menu.currentSpace, "cluster", true), "cluster")
        
    else
        menu.zoomToSpace(C.GetContextByClass(menu.currentSpace, "sector", true), "sector")
        
    end
end

--component argument is optional
function menu.tryZoomIn(component)
    if menu.currentSpaceType == "zone" then
        return
    end
    --if no component specified, see if the select table has something valid selected
    if component == nil then
        rowData = menu.rowDataMap[Helper.currentTableRow[menu.selectTable]]
        if rowData ~= nil then
            component = rowData.obj
        end
    end
    if component == nil or component == 0 or not IsComponentClass(component, "space") then
        return
    end
    
    menu.displayMenuReason = "zoom in"
    
    if menu.currentSpaceType == "galaxy" then
        menu.zoomToSpace(ConvertIDTo64Bit(component), "cluster")
        
    elseif menu.currentSpaceType == "cluster" then
        menu.zoomToSpace(ConvertIDTo64Bit(component), "sector")
        
    else
        menu.zoomToSpace(ConvertIDTo64Bit(component), "zone")
        
    end
end

function menu.onHotkey(action)
    menu.enforceSelections()
    if action == "INPUT_ACTION_ADDON_DETAILMONITOR_C" then
        if menu.currentSelection ~= 0 then
            menu.tryComm(menu.currentSelection)
        end
    end
    if action == "INPUT_ACTION_ADDON_DETAILMONITOR_I" then
        if menu.currentSelection ~= 0 and menu.canViewDetails(menu.currentSelection) then
            menu.objectDetails()
        end
    end
    if action == "INPUT_ACTION_ADDON_DETAILMONITOR_T" then
        if menu.currentSelection ~= 0 then
            menu.softTarget(menu.currentSelection)
        end
    end
end

--little hack, play the sound in onCloseElement, so it doesn't play when the menu is refreshed
function menu.onCloseElementSound()
end
function menu.onCloseElement(dueToClose)
    
    if dueToClose == "close" then
        PlaySound("ui_menu_close")
        Helper.closeMenuAndCancel(menu)
        menu.cleanup()
    else
        if #menu.history <= 1 then
            PlaySound("ui_menu_close")
            Helper.closeMenuAndReturn(menu)
            menu.cleanup()
        else
            local prevHistory = menu.history[#menu.history - 1]
            menu.zoomToSpace(prevHistory.space, prevHistory.spaceType)
        end
    end
end

function menu.cleanup()
    if menu.holomap ~= 0 then
        C.RemoveHoloMap2()
        menu.holomap = 0
    end
    UnregisterEvent("updateHolomap", menu.updateHolomap)
    
    Helper.standardFontSize = 14
    Helper.standardTextHeight = 24
    menu.shouldBeClosed = true
    UnregisterAddonBindings("ego_detailmonitor")
    
    menu.currentSelection = nil
    menu.commandTarget = nil
    menu.nextSelection = nil
    
    menu.currentSpace = nil
    menu.currentSpaceType = nil
    
    menu.nextUpdateQuickly = nil
    
    menu.shouldBeClosed = true
    
    menu.selectTable = nil
    menu.commandGridTable = nil
    menu.buttonTable = nil
    
    menu.renderTargetWidth = nil
    menu.renderTargetHeight = nil
    menu.selectTableOffsetX = nil
    menu.selectTableHeight = nil
    menu.commandTableOffsetY = nil
    menu.statusBarWidth = nil
    menu.extendButtonWidth = nil
    
    menu.numCommandButtonCols = nil
    
    menu.selectColumnWidths = nil
    menu.gridColWidths = nil
    menu.gridEffectiveColumns = nil
    menu.gridColSpans = nil
    
    menu.buttonTableButtonWidth = nil
    menu.buttonTableSpacerWidth = nil
    
    menu.holomapColor = nil
    
    menu.timeLastMouseDown = nil
    menu.timeLastRightMouseDown = nil
    
    menu.currentSelection = nil
    
    menu.commandSelection = nil
    menu.commandSelectionTable = nil
    menu.commandTarget = nil
    menu.commandTargetType = nil
    menu.commandSelectionRow = nil
    
    menu.lastHolomapUpdate = nil
    
    menu.nextSelection = nil
    
    menu.ignoreSelectRowChange = nil
    
    menu.nextSelectedRow = nil
    
    menu.extendedObjects = nil
    
    menu.nextUpdateQuickly = nil
    
    menu.checkedComponents = nil
    menu.numChecked = nil
    menu.multiSelectMode = nil
    
    menu.statusMessage = nil
    
    menu.activeGridOrder = nil
    
    menu.displayMenuRunning = nil
    
    menu.mode = nil
    menu.modeParams = nil
    
    menu.displayMenuReason = nil
    
    menu.activateMap = nil
end

init()