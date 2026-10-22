local playerEntity = Player.GetEntity()
local primaryKey = 'numberOfBonks'
local dbKey = string.format('%s-%s', primaryKey, playerEntity.displayName)
local cheevocfg = config.Achievement.CHEEVO_SURGE_ONE_TILE
local numberOfBonks = PersistentDB:GetInt(dbKey) or (cheevocfg.progress == -2 and 1) or 0
local coords = {x = playerEntity.coordGrid.x, z = playerEntity.coordGrid.z}
local justSurged = false
local contentView
local countBonks = PersistentDB:GetBool('countBonks') ~= false
local showPopup = PersistentDB:GetBool('showPopup') ~= false
local popupIcon = PersistentDB:GetBool('popupIcon') ~= false
local thisRsnCount = PersistentDB:GetBool('popupIcon') ~= false
local bonkCountText
local totalBonkCountText
local totalBonkCount = 0
local rsnCount = 0

PersistentDB:IterateEntries(function(key, value)
	local tempBonkCount = 0
	if key:match('^'..primaryKey) and type(value) == 'number' then
		tempBonkCount = tempBonkCount + value
		rsnCount = rsnCount + 1
	end

	totalBonkCount = totalBonkCount + tempBonkCount
end)

local function getBonkCountStr()
	return string.format('Bonk count%s: %s',
		rsnCount > 1 and ' (this RSN)' or '',
		numberOfBonks)
end

local function getTotalBonkCountStr()
	return formatStr('Bonk count (total): {}', totalBonkCount)
end

local function displayPopup()
	if not showPopup then return end
	-- Don't show the popup if you've only bonked once (ingame achievement fires)
	if numberOfBonks <= 1 then return end

	local text = formatStr('You\'ve bonked {} times!', numberOfBonks)
	if not countBonks then
		text = 'Bonk!'
	end

	local popup = prettyui.AchievementPopup.show({
		title = 'I Meant To Do That',
		text = text,
		item = popupIcon and config.Obj.RUBBER_CHICKEN or nil, -- config.Obj.AGILITY_JUMP
		parent = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__TASK_COMPLETE_WINDOW),
	})
	if not popupIcon then return end
	popup.itemSlot.item:SetAssociatedObject(-1)
	popup.itemSlot.item.spriteID = cheevocfg.spriteID
end

local function hasMovedOneTile()
	local abs_x = math.abs(playerEntity.coordGrid.x - coords.x)
	local abs_z = math.abs(playerEntity.coordGrid.z - coords.z)
	return (abs_z == 1 and playerEntity.coordGrid.x == coords.x) or
		(abs_x == 1 and playerEntity.coordGrid.z == coords.z) or
		(abs_z == 1 and abs_x == 1)
end

Event.Logic.Subscribe("updatePlayerData", function()
	if playerEntity.coordGrid.x == coords.x and playerEntity.coordGrid.z == coords.z then return end
	if not (playerEntity.coordGrid.x - coords.x ~= 0 or playerEntity.coordGrid.z - coords.z ~= 0) then return end

	if hasMovedOneTile() then
			--print(formatStr('Moved one tile: ({} -> {}, {} -> {})', coords.x, playerEntity.coordGrid.x, coords.z, playerEntity.coordGrid.z))
			if justSurged then
				if countBonks then
					numberOfBonks = numberOfBonks + 1
					totalBonkCount = totalBonkCount + 1
					PersistentDB:SetInt(dbKey, numberOfBonks)
					bonkCountText.content = getBonkCountStr()
					if totalBonkCountText then
						totalBonkCountText.content = getTotalBonkCountStr()
					end
				end
				displayPopup()
			end
	end

	justSurged = false
	coords = {x = playerEntity.coordGrid.x, z = playerEntity.coordGrid.z}
end)

Event.VarTransmit.Subscribe('surge', function(event)
	if event.oldValue == event.newValue then return end
	if event.var.configName ~= 'COMBATV2_COOLDOWN_MAGIC_SURGE_CHARGE2_START'
		and event.var.configName ~= 'COMBATV2_COOLDOWN_MAGIC_SURGE_START' then return end
	--print(formatStr('{} ({}): {}, {}', event.var.configName, event.var.valueType, event.oldValue, event.newValue))
	justSurged = true
end)

Event.ContentLayerReady.Subscribe('plugin-content', function(event)
    if contentView then contentView:Destroy() end

    local parent = event.component
    contentView = prettyui.SimpleView.new(parent, {
        width = parent.width,
        height = parent.height,
    })

		local showPopupCheckbox
		local popupIconCheckbox
		local thisRsnCountCheckbox

		local bonkCountDisabledStr = 'Bonk counter disabled.'

    contentView:AddTitle('I Meant To Do That')
		local bonkTxt = getBonkCountStr()
		if cheevocfg.progress ~= -2 then
			bonkTxt = 'Achievement not unlocked yet!'
		end
		if not countBonks then
			bonkTxt = bonkCountDisabledStr
		end
    bonkCountText = contentView:AddText(bonkTxt)
		if rsnCount > 1 then
			totalBonkCountText = contentView:AddText(getTotalBonkCountStr())
		end
    contentView:AddDivider({
			marginTop = -30,
			marginBottom = -10
		})

		local countBonksTooltip = 'When disabled, stops incrementing bonk count, but continues showing popup.'
    local countBonksCheckbox = contentView:AddCheckboxButton({
			{ text = 'Count bonks', value = 1, selected = countBonks },
		}, {
			tooltip = countBonksTooltip,
			onChange = function(_, _, _, selected)
				countBonks = selected
				PersistentDB:SetBool('countBonks', selected)
				if selected then
					bonkCountText.content = getBonkCountStr()
				else
					bonkCountText.content = bonkCountDisabledStr
				end
			end
		})
		countBonksCheckbox:SetOptionTooltip(1, countBonksTooltip)

		local showPopupTooltip = 'When disabled, continues to tally bonks without showing an achievement popup.'
    showPopupCheckbox = contentView:AddCheckboxButton({
			{ text = 'Show popup', value = 1, selected = showPopup }
		}, {
			tooltip = showPopupTooltip,
			onChange = function(_, _, _, selected)
				showPopup = selected
				PersistentDB:SetBool('showPopup', selected)
				popupIconCheckbox:SetDisabled(not selected)
			end
		})
		showPopupCheckbox:SetOptionTooltip(1, showPopupTooltip)

		local popupIconTooltip = 'Show achievement icon on popup.'
    popupIconCheckbox = contentView:AddCheckboxButton({
			{ text = 'Popup icon', value = 1, selected = popupIcon },
		}, {
			tooltip = popupIconTooltip,
			onChange = function(_, _, _, selected)
				popupIcon = selected
				PersistentDB:SetBool('popupIcon', selected)
			end
		})
		popupIconCheckbox:SetOptionTooltip(1, popupIconTooltip)
		popupIconCheckbox:SetDisabled(not showPopup)

		if rsnCount > 1 then
			local thisRsnCountTooltip = 'Popup shows bonk count for this RSN. When disabled, shows the total bonk count for all your RSNs.'
			thisRsnCountCheckbox = contentView:AddCheckboxButton({
				{ text = 'This RSN count', value = 1, selected = thisRsnCount },
			}, {
				tooltip = thisRsnCountTooltip,
				onChange = function(_, _, _, selected)
					thisRsnCount = selected
					PersistentDB:SetBool('thisRsnCount', selected)
				end
			})
			thisRsnCountCheckbox:SetOptionTooltip(1, thisRsnCountTooltip)
			thisRsnCountCheckbox:SetDisabled(not showPopup)
		end

    contentView:AddSimpleButton('Test popup', displayPopup, { tooltip = 'Show a test popup.' })
end)

function PluginShutdown()
	Event.Logic.Unsubscribe('updatePlayerData')
	Event.VarTransmit.Unsubscribe('surge')
	PersistentDB:SetInt(dbKey, numberOfBonks)

	PersistentDB:SetBool('countBonks', countBonks)
	PersistentDB:SetBool('showPopup', showPopup)
	PersistentDB:SetBool('popupIcon', popupIcon)
	Event.ContentLayerReady.Unsubscribe('plugin-content')
	if contentView then
			contentView:Destroy()
			contentView = nil
	end
end
