local dfhack = require("dfhack")
local flua = require("flua")
local utils = require("utils")

local args = {...}
local isInitialized = true

if AutoCager == nil then
	AutoCager = {}
	isInitialized = false
end

function AutoCager:init()
	self.creatureRawIndex = self:buildRawCreatureIdIndex()
	self.rules = {}
	self.enabled = false
end

function AutoCager:buildRawCreatureIdIndex()
	local index = {}
	flua.ieach(df.global.world.raws.creatures.all,
		function(i,unit)
			index[unit.creature_id] = i
		end)
	return index
end


-- A unit is cageable if it's not a pet (owned) and is not assigned to some other labor
function AutoCager:isUnitCageable(unit)
	 return not self:isPet(unit) and not self:isAssigned(unit)
end

function AutoCager:isPet(unit)
	return unit.relations.pet_owner_id ~= -1
end

-- A unit is "young" if it is either a child or baby
function AutoCager:isYoung(unit)
	return unit.profession == df.profession.CHILD or unit.profession == df.profession.BABY
end

-- A unit is "assigned" if it is already caged, chained, or marked for slaughter
function AutoCager:isAssigned(unit)
	return unit.flags1.caged or unit.flags1.chained or unit.flags2.slaughter
end

function AutoCager:isRace(unit, rawId, crIndex)
	return unit.race == crIndex[rawId]
end

--((not onlyYoung) or isYoung(unit)) and isRace(unit, raw_id, crIndex) and isUnitCageable(unit)
function AutoCager:getUnitsToCage(rawId, crIndex, onlyYoung) 
	return flua.filter(df.global.world.units.active,
		function(unit)
			return ((not onlyYoung) or self:isYoung(unit)) and self:isUnitCageable(unit) and self:isRace(unit, rawId, crIndex)
		end)
end

function AutoCager:cageUnits(cage, units)
	return flua.fold_left(units, 0,
		function(unit, result)
			if utils.linear_index(cage.assigned_units, unit.id) == nil then
				cage.assigned_units:insert("#", unit.id)
				return result + 1
			end
			return result
		end)
end

function AutoCager:getSelectedBuilding() 
	local cage = dfhack.gui.getSelectedBuilding()
	if cage == nil then return nil end

	if not df.building_cagest:is_instance(cage) then
		print("Selected building is not a cage.")
		return nil
	end

	return cage
end

function AutoCager:makeRule(rawId, onlyYoung)
	-- Don't know if the not-not is needed, but it forces the value
	-- to a straightup true/false value
	return { rawId=rawId, onlyYoung=(not not onlyYoung) }
end

-- Assigns all active units of type rawId to the currently selected cage.
-- If onlyYoung is true then only active units classified as "young" will be
-- assigned to the cage.
function AutoCager:cage(rawId, onlyYoung)
	local cage = self:getSelectedBuilding()
	if cage == nil then return end

	self:cage(rawId, onlyYoung, cage)
end

function AutoCager:cage(rawId, onlyYoung, cage)
	if self.creatureRawIndex[rawId] == nil then
		print("Invalid raw creature id.")
		return
	end

	local units = self:getUnitsToCage(rawId, self.creatureRawIndex, onlyYoung)
	print("Caging " .. #units .. " creatures in "..cage.id..".")

	local unitsAssigned = self:cageUnits(cage, units)
	print(unitsAssigned .. " creatures assigned to cage "..cage.id..".")
end


-- Adds the provided creature raw idea and "young" setting as a
-- rule for the currently selected cage
function AutoCager:addRule(rawId, onlyYoung)
	local cage = self:getSelectedBuilding()
	if cage == nil then return end

	if self.creatureRawIndex[rawId] == nil then
		print("Invalid raw creature id.")
		return
	end

	local newRule = self:makeRule(rawId, onlyYoung)

	if self.rules[cage.id] == nil then
		self.rules[cage.id] = { newRule }
	else
		table.insert(self.rules[cage.id], newRule)
	end
end

-- Prints the rules that are in place for the currently selected cage
function AutoCager:showRules()
	local cage = self:getSelectedBuilding()
	if cage == nil then return end

	if self.rules[cage.id] ~= nil and #self.rules[cage.id] > 0 then
		flua.ieach(self.rules[cage.id],
			function(i,rule)
				print(i .. ". " .. rule.rawId .. " Only Young? " .. ((rule.onlyYoung and "Yes")  or "No"))
			end)
	else
		print("No rules for selected cage.")
	end
end

-- Clears the rules that are in place for the currently selected cage
function AutoCager:clearRules()
	local cage = self:getSelectedBuilding()
	if cage == nil then return end
	self.rules[cage.id] = nil;
end

-- Runs the rules associated with cages. If the runAllFlag is set to true
-- then the rules for ALL cages are run. Otherwise the rules for the currently
-- selected cage are run
function AutoCager:runRules(runAllFlag)
	if runAllFlag then
		flua.keach(self.rules,
			function(cageId, rules)
				self:runRulesList(rules, cageId)
			end)
	else
		local cage = self:getSelectedBuilding()
		if cage == nil then return end
		if self.rules[cage.id] ~= nil then
			self:runRulesList(self.rules[cage.id], cage.id)
		end
	end
end

function AutoCager:runRulesList(rules,cageId)
	local cage = df.building_cagest.find(cageId)
	if cage == nil then
		print("Cage not found: cage id " .. cageId)
		return
	end
	flua.each(rules,
		function(rule)
			self:cage(rule.rawId, rule.onlyYoung, cage)
		end)
end

function AutoCager:autorun()
	runRules(true)
end

if not isInitialized then
	AutoCager:init()
end

if(args[1] == "cage") then
	local rawId = args[2]
	local onlyYoung = args[3]
	AutoCager:cage(rawId, onlyYoung)

elseif args[1] == "showRules" then
	AutoCager:showRules()

elseif args[1] == "addRule" then
	local rawId = args[2]
	local onlyYoung = args[3]
	AutoCager:addRule(rawId, onlyYoung)

elseif args[1] == "clearRules" then
	AutoCager:clearRules()

elseif args[1] == "runRules" then
	AutoCager:runRules(args[2] == "all")

elseif args[1] == "enableAutorun" then

elseif args[1] == "disableAutorun" then
	
else
	print("Invalid command.")
end