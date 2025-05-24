local hook = hook
local istable = istable
local isfunction = isfunction
local pcall = pcall
local cppiOwner = false
local IsValid = IsValid
local IsValidModel = util.IsValidModel
local setmetatable = setmetatable
local type = type
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

	function _s.set(defaults)
		local cm = u.returnIfValid(_s.isModuleValid, PUG.currentModule)
		local module = (cm and cm.data.settings) or {}
		assert(defaults ~= nil, "Default data values must be passed.")

		-- Cleanup unused keys.
		for k, _ in next, module do
			if defaults[ k ] == nil then
				module[ k ] = nil
			end
		end

		if not cm.data then
			module = defaults
		else
			module = table.Merge(defaults, module)
		end

		local hasFolders = false
		local binding = {}
		for k, v in next, module do
			if v and istable(v) and v[0] == "folder" then
				hasFolders = true
				for kk, vv in next, v do
					if kk ~= 0 then
						binding[k] = {}
						binding[k][kk] = vv.v
					end
				end
			end
		end

		if hasFolders then
			module = _s.bind(binding, module)
		end

		return module
	end

	function _s.bind(bindTo, bindFrom)
		bindTo[0] = bindFrom
		return setmetatable(bindTo, {__index = bindTo[0]})
	end

	function _s.release(hooks, settings)
		if settings[0] then
			settings = settings[0]
			settings[0] = nil
		end
		return {
			hooks = hooks,
			settings = settings,
		}
	end

	function _s.merge(settings, hooks, path)
		local cm = u.returnIfValid(_s.isModuleValid, PUG.currentModule)
		settings = settings or {}

		local path = string.format("%s/%s/%s", dirs.modules, cm.key, path)
		local data = include(path)
		table.Merge(settings, data.settings)
		table.Merge(hooks, data.hooks)
		path = nil
		data = nil

		return settings
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

function u.remHook(callID, id, store)
	assert(istable(store) == true, "A storage table must be passed!")
	id = "PUG." .. id

	print("[PUG][HOOKS] Removing " .. id .. " @ " .. callID)
	hook.Remove(callID, id)

	-- Cleanup data store.
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

function u.addHook(callID, id, callback, store, removeCondition)
	assert(istable(store) == true, "A storage table must be passed!")

	local halt = false
	local index = #store + 1
	local hid = "PUG." .. id

	if (removeCondition) then
		if isbool(removeCondition) and removeCondition then
			halt = true
		end
		if isfunction(removeCondition) and removeCondition() then
			halt = true
		end
	end

	if halt then
		index = index - 1
		u.remHook(callID, id, store)
		return store, index
	end

	hook.Add(callID, hid, callback)
	store[index] = store[index] or {}
	store[index][callID] = {
		id = hid,
		cond = removeCondition,
	}

	return store, index
end

function u.addTimer(timerID, delay, reps, callback, store, cond)
	assert(istable(store) == true, "A storage table must be passed!")

	local index = #store + 1
	timerID = "PUG." .. timerID

	timer.Create(timerID, delay, reps, callback)
	store[index] = store[index] or {}
	store[index][timerID] = {
		id = timerID,
		delay = delay,
		cond = cond,
	}

	return store
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
	local _t = {
		size = 0,
		rn = {}, -- List of functions added.
		i = 25, -- The number of iterations.
	}

	do -- Prepare Tables
		_t.rn.__index = _t.rn
		_t.rn = setmetatable( { [ 0 ] = 0 }, _t.rn )
	end

	u.tasks = {} -- Prepare Function Container.
	
	function u.tasks.print()
		PrintTable(_t)
	end

	function u.tasks.add(fn, skips, rerun)
		assert(isfunction(fn), "Argument #1 must be a function.")
		_t.size = _t.rn[0]
		_t.size = _t.size + 1
		_t.rn[_t.size] = {
			fn = fn,
			skips = skips or 0,
			rerun = rerun or 0,
		}
		_t.rn[0] = _t.size
	end

	function u.tasks.next(entry)
		_t.rn[0] = _t.rn[0] + 1
		_t.rn[_t.rn[0]] = entry
	end

	function u.tasks:run(key)
		local count = 0
		local task = _t.rn[key]
		if task and not isnumber(task) then
			if task.skips == 0 then
				local ok, out = pcall(_t.rn[key].fn)
				if not ok then
					ErrorNoHaltWithStack(out)
					out = true
				end
				if task.rerun > 0 and out ~= true then 
					_t.rn[key].rerun = task.rerun - 1
				else
					_t.rn[key] = nil
					count = count + 1
				end
			else
				_t.rn[key].skips = task.skips - 1
			end
		end
		_t.rn[0] = _t.rn[0] - count
		_t.rn[0] = (_t.rn[0] < 0) and 0 or _t.rn[0]
	end

	function u.tasks:process(iters)
		for key, _ in next, _t.rn do
			if iters < 0 then break end
			if key ~= 0 then
				self:run(key)
				iters = iters - 1
			end
		end
	end

	function u.tasks.unhook()
		hook.Remove("Tick", "PUG_TaskProcessor")
	end

	function u.tasks.hook()
		hook.Remove("Tick", "PUG_TaskProcessor")
		hook.Add("Tick", "PUG_TaskProcessor", function()
			u.tasks:process(_t.i)
		end)
	end

	u.tasks.hook()
end

return u
