---@meta
local hook = hook
local istable = istable
local isfunction = isfunction
local pcall = pcall
local cppiOwner = false
local IsValid = IsValid
local IsValidModel = util.IsValidModel
local setmetatable = setmetatable
local type = type
local stringFormat = string.format
local physTime = physenv.GetLastSimulationTime
local vecZero = Vector(0, 0, 0)

local u = {}

dirs = {
	modules = "pug/modules",
}

do
	local ENT = FindMetaTable("Entity")
	cppiOwner = ENT.CPPIGetOwner
end

local function isTableLike(tableLike)
	if not tableLike then return false end
	
	local isNot = {
		table = (not istable(tableLike)),
		entity = (not isentity(tableLike)),
		panel = (not ispanel(tableLike)),
	}
	
	if isNot.table or isNot.entity or isNot.panel then
		return false
	end
	return true
end

function u.isGhostState(ent, ghostState, gt)
	if not ent.PUGGhosted then return false end
	if type(ent.PUGGhosted) ~= "number" then return false end
	if gt == true then
		return (ent.PUGGhosted > ghostState)
	end
	return (ent.PUGGhosted == ghostState)
end

function u.pugSetVar(tableLike, key, value)
	if not tableLike then return end
	tableLike.PUGData = tableLike.PUGData or {}
	tableLike.PUGData[key] = value
	return tableLike
end

function u.pugGetVar(tableLike, key, fallback)
	if not isTableLike(tableLike) then
		error("Expected a table-like value as argument #1.")
		return
	end

	tableLike.PUGData = tableLike.PUGData or {}

	local value = tableLike.PUGData[key]
	if value == nil then
		return fallback
	end
	return value
end

function u.safeSetCollisionGroup(ent, group, pObj)
	if ent:IsPlayerHolding() then return end
	if ent.PUGGhosted then return end
	if pObj then pObj:Sleep() end
	ent:SetCollisionGroup(group)
	ent.CollisionGroup = group
	ent:CollisionRulesChanged()
end

function u.setCollisionGroup(ent, group, update)
	if ent.CollisionGroup == group then 
		return
	end

	ent:SetCollisionGroup(group)
	ent.CollisionGroup = group

	if update then
		ent:CollisionRulesChanged()
	end
end

function u.isValidPhys(ent, checkModel)
	local model = nil
	if not ent then return false end
	if not IsValid(ent) then return false end

	if checkModel then
		model = ent.GetModel and ent:GetModel() or nil
		if not model then return false end
		if not IsValidModel(model) then return false end
	end

	local phys = ent.GetPhysicsObject and ent:GetPhysicsObject() or nil
	if not phys then return false end

	return IsValid(phys), phys, model
end

-- Same as isValidPhys but returns a table instead.
function u.getValidPhys(ent, checkModel)
	local valid, phys, model = u.isValidPhys(ent, checkModel)
	return {
		valid = valid,
		phys = phys,
		model = model,
	}
end

function u.isVehicle(ent, basic)
	if not IsValid(ent) then return false end

	if ent:IsVehicle() then return true end
	if string.find(ent:GetClass(), "vehicle") then return true end

	if basic then return false end

	local parent = ent:GetParent()
	return u.isVehicle(parent, true)
end

function u.callOnConstraints(ent, callback)
	local constrained = constraint.GetAllConstrainedEntities(ent)
	for _, child in next, constrained do
		if IsValid(child) and child ~= ent then
			callback(child)
		end
	end
end

function u.getCPPIOwner(ent)
	if type(cppiOwner) ~= "function" then
		print("[PUG][ERROR] We need a prop protection to function!")
		return
	end
	local owner = cppiOwner(ent)
	if type(cppiOwner(ent)) ~= "Player" then
		return false
	else
		return owner
	end
end

function u.notifyOwner(msg, msgType, length, ent)
	local owner = u.getCPPIOwner(ent)
	if owner and IsValid(owner) then
		PUG:Notify(msg, msgType, length, owner)
	end
end

function u.entityForceDrop(ent)
	if istable(ent.PUGHolding) then
		for _, ply in next, ent.PUGHolding do
			if ply and IsValid(ply) then
				ply.PUGBlockAttack = CurTime() + (FrameTime() * 2)
				ply:ConCommand("-attack")
				ply:DropObject()
			end
		end
	end
	ent:ForcePlayerDrop()
end

function u.playerForceDrop(ply)
	ply.PUGBlockAttack = CurTime() + (FrameTime() * 2)
	ply:ConCommand("-attack")
	ply:DropObject()
end

function u.entityIsMoving(ent, speed)
	if type(ent) ~= "Entity" then return end
	if not IsValid(ent) then return end

	local p = u.getValidPhys(ent, false)
	if p.valid then
		local vel = p.phys:GetVelocity():Distance(vecZero)
		return (vel > speed), vel
	else
		return false, nil
	end
end

function u.physIsMoving(phys, speed)
	if type(phys) ~= "PhysObj" then return end
	if not IsValid(phys) then return end

	if IsValid(phys) then
		local vel = phys:GetVelocity():Distance(vecZero)
		return (vel > speed), vel
	else
		return false, nil
	end
end

function u.sleepEntity(ent, dontSleep)
	if type(ent) ~= "Entity" then return end
	if not IsValid(ent) then return end

	local p = u.getValidPhys(ent, false)
	if p.valid then
		p.phys:SetVelocityInstantaneous(vecZero)
		p.phys:AddAngleVelocity(p.phys:GetAngleVelocity() * -1)
		if not dontSleep then
			p.phys:Sleep()
		end
	end
end

function u.freezeEntity(ent)
	if type(ent) ~= "Entity" then return end
	if not IsValid(ent) then return end

	local p = u.getValidPhys(ent, false)
	if p.valid then
		p.phys:EnableMotion(false)
	end
end

function u.isEntityPicked(ent)
	if not istable(ent.PUGHolding) then
		return false
	end
	return (next(ent.PUGHolding) ~= nil)
end

function u.isEntityHeld(ent)
	if ent.PUGPicked then return true end
	if ent:IsPlayerHolding() then return true end
	return u.isEntityPicked(ent)
end

function u.addEntityHolder(ent, ply)
	local steamID = ply:SteamID()
	ent.PUGHolding = ent.PUGHolding or {}
	ent.PUGHolding[steamID] = ply
end

function u.removeEntityHolder(ent, ply)
	local steamID = ply:SteamID()
	ent.PUGHolding = ent.PUGHolding or {}
	ent.PUGHolding[steamID] = nil
end

function u.returnIfValid(validator, input)
	if validator(input) then
		return input
	end
	return nil
end

do
	local _s = {}
	function _s.isModuleValid(module)
		if not module then return false end
		if module.data == nil then return false end
		if module.path == nil then return false end
		if module.key == nil then return false end
		return true
	end

	function _s.set(defaults, inject, noClean)
		local cm = u.returnIfValid(_s.isModuleValid, PUG.currentModule)
		local module = (cm and cm.data.settings) or {}
		local hooks = {}

		assert(defaults ~= nil, "Default data values must be passed.")

		-- Cleanup unused keys.
		if noClean ~= true then
			for k, _ in next, module do
				if defaults[ k ] == nil then
					module[ k ] = nil
				end
			end
		end

		if not cm.data then
			module = defaults
		else
			module = table.Merge(defaults, module)
		end

		if istable(inject) then
			assert(isstring(inject[1]), "Expected string table at variable 2.")
			for k, v in next, inject do
				module, hooks = _s.merge(module, hooks, v)
			end
		end

		local hasFolders = false
		local binding = {}
		for k, v in next, module do
			if v and istable(v) and v[0] == "folder" then
				hasFolders = true
				for kk, vv in next, v do
					if kk ~= 0 then
						binding[k] = { [kk] = vv.v }
					end
				end
			end
		end

		return module, hooks
	end

	function _s.bind(bindTo, bindFrom)
		bindTo[0] = bindFrom
		bindTo = table.Merge(bindTo, bindFrom)

		PrintTable(bindTo)

		return bindTo -- No meta needed, table merged.
	end

	function _s.release(hooks, timers, settings)
		if settings[0] then
			settings = settings[0]
			settings[0] = nil
		end
		return {
			hooks = hooks,
			timers = timers,
			settings = settings,
		}
	end

	function _s.merge(settings, hooks, path)
		local cm = u.returnIfValid(_s.isModuleValid, PUG.currentModule)
		settings = settings or {}

		local path = stringFormat("%s/%s/%s", dirs.modules, cm.key, path)
		local data = include(path)
		
		table.Merge(settings, data.settings)
		table.Merge(hooks, data.hooks)

		path = nil
		data = nil

		return settings, hooks
	end

	function _s.folder(settings, inherit)
		settings[0] = "folder"
		for k, v in next, settings do
			if k ~= 0 then
				settings[k] = { v = v, inherit = (inherit == k) }
			end
		end
		return settings
	end

	u.settings = _s
end

do
	local _module = nil

	local function remCall(callID, id, store, isHook, append)
		local tag = isHook and "HOOK" or "TIMER"
		local hookNotice = callID and stringFormat(" @ \"%s\"", callID) or ""
		assert(istable(store) == true, "A storage table must be passed!")

		if append then
			_module = (_module and _module) or PUG.currentModule.key or "<NIL>"
			id = stringFormat("PUG.%s.%s", _module, id)
		end

		print(stringFormat("[PUG][%s] Removing \"%s\"%s", tag, id, hookNotice))
		if isHook then
			hook.Remove(callID, id)
		else
			timer.Remove(id)
		end

		-- Cleanup data store.
		callID = callID or id
		for index, getTable in next, store do
			for cid, hid in next, getTable do
				if (cid == callID and hid == id) then
					store[index][callID] = nil
					break
				end
			end
		end

		return store, #store
	end

	local function addCall(callID, id, delay, reps, callback, store, remCond, isHook)
		assert(store and istable(store) == true, "A storage table must be passed!")

		local halt = false
		local index = #store + 1

		_module = (_module and _module) or PUG.currentModule.key or "<NIL>"
		id = stringFormat("PUG.%s.%s", _module, id)

		if remCond ~= nil then
			if isbool(remCond) and (not remCond) then
				halt = true
			end
			if isfunction(removeCondition) and removeCondition() then
				halt = true
			end
		end

		if halt then
			index = index - 1
			if isHook then
				-- u.remHook(callID, id, store)
				remCall(callID, id, store, true, false)
			else
				-- u.remTimer(id, store)
				remCall(callID, id, store, false, false)
			end
			return store, index
		end

		if isHook then
			hook.Add(callID, id, callback)
		else
			timer.Create(id, delay, reps, callback)
		end

		callID = callID or id
		store[index] = store[index] or {}
		store[index][callID] = id

		return store, index
	end

	-- Prepare hooks for the current module.
	-- boolean
	function u.declareHooks(hasTimers)
		_module = PUG.currentModule.key
		return {
			h = {}, -- Hooks
			t = hasTimers and {} or nil, -- Timers
		}
	end

	-- Remove a hook from PUG.
	-- string, string, table
	function u.remHook(callID, id, store)
		return remCall(callID, id, store, true, true)
	end

	-- Add a hook to PUG so that it can be removed when the module is unloaded.
	-- string, string, function, table, boolean|function
	function u.addHook(callID, id, callback, store, remCond)
		return addCall(callID, id, nil, nil, callback, store, remCond, true)
	end

	---Remove a Timer added to PUG
	---@param timerID string
	---@param store table
	---@return table
	function u.remTimer(timerID, store)
		return remCall(nil, timerID, store, false)
	end

	-- Adds a timer to PUG.
	-- string, number, number, function, table, boolean|function
	function u.addTimer(timerID, delay, reps, callback, store, cond)
		return addCall(nil, timerID, delay, reps, callback, store, remCond, false)
	end

	function u.getHookID(id)
		_module = (_module and _module) or PUG.currentModule.key or "<NIL>"
		id = stringFormat("PUG.%s.%s", _module, id)
		return id
	end
end

function u.tableReduce(func, tbl)
	local out = 0
	local head = tbl[1]
	local err = "May contain only numbers."

	assert(type(head) == "number", err)

	for _, v in next, tbl do
		assert(type(v) == "number", err)
		out = func(out, v)
	end

	return out
end

function u.physTimer(mult, callback)
	mult = (mult ~= nil) and mult or 1
	timer.Simple(physTime() * mult, callback)
end

do
	local numId = 0
	u.tasks = {} -- Prepare Function Container.
	function u.tasks.add(fn, delay, reruns)
		numId = numId + 1
		delay = FrameTime() * (delay or 0)
		reruns = reruns or 0

		local id = stringFormat("PUG.Task.%d", numId)
		local task = { 
			id = id,
			fn = fn, 
			delay = delay,
			reruns = reruns,
		}

		timer.Create(id, delay, 0, function()
			task.reruns = task.reruns - 1
			local ok, result = pcall(task.fn)
			if not ok then
				ErrorNoHaltWithStack(result)
				timer.Remove(task.id)
				return
			end
			if result == true or task.reruns <= 0 then
				timer.Remove(task.id)
				return
			end
		end)
	end
end

return u
