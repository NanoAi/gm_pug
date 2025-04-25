local hook = hook
local istable = istable
local cppiOwner = false
local IsValid = IsValid
local IsValidModel = util.IsValidModel
local type = type
local u = {}

do
	local ENT = FindMetaTable("Entity")
	cppiOwner = ENT.CPPIGetOwner
end

function u.isGhostState(ent, ghostState)
	if not ent.PUGGhosted then return false end
	if type(ent.PUGGhosted) ~= "number" then return false end
	return (ent.PUGGhosted == ghostState)
end

function u.safeSetCollisionGroup(ent, group, pObj)
	if ent:IsPlayerHolding() then return end
	if ent.PUGGhosted then return end
	if pObj then pObj:Sleep() end
	ent:SetCollisionGroup(group)
	ent:CollisionRulesChanged()
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
	if type(cppiOwner) == "function" then
		local owner = cppiOwner(ent)
		if type(cppiOwner(ent)) ~= "Player" then
			return false
		else
			return owner
		end
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
				ply:ConCommand("-attack")
			end
		end
	end
	if DropEntityIfHeld then
		DropEntityIfHeld(ent)
	end
	ent:ForcePlayerDrop()
end

function u.entityIsMoving(ent, speed)
	if type(ent) ~= "Entity" then return end
	if not IsValid(ent) then return end

	local zero = Vector(0, 0, 0)
	local phys = ent:GetPhysicsObject()

	if IsValid(phys) then
		local vel = phys:GetVelocity():Distance(zero)
		return (vel > speed), vel
	else
		return false, nil
	end
end

function u.physIsMoving(phys, speed)
	if type(phys) ~= "PhysObj" then return end
	if not IsValid(phys) then return end

	local zero = Vector(0, 0, 0)

	if IsValid(phys) then
		local vel = phys:GetVelocity():Distance(zero)
		return (vel > speed), vel
	else
		return false, nil
	end
end

function u.sleepEntity(ent, dontSleep)
	if type(ent) ~= "Entity" then return end
	if not IsValid(ent) then return end

	local zero = Vector(0, 0, 0)
	local phys = ent:GetPhysicsObject()

	if IsValid(phys) then
		phys:SetVelocityInstantaneous(zero)
		phys:AddAngleVelocity(phys:GetAngleVelocity() * -1)
		if not dontSleep then
			phys:Sleep()
		end
	end
end

function u.freezeEntity(ent)
	if type(ent) ~= "Entity" then return end
	if not IsValid(ent) then return end

	local phys = ent:GetPhysicsObject()

	if IsValid(phys) then
		phys:EnableMotion(false)
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

function u.getSettings(defaults)
	local module = PUG.currentModule or {}

	if not module.data then
		module = defaults
	else
		module = table.Merge(defaults, module.data.settings or {})
	end

	return module, module == defaults
end

function u.addHook(callID, id, callback, store)
	assert(istable(store) == true, "A storage table must be passed!")

	local index = #store + 1
	id = "PUG." .. id

	hook.Add(callID, id, callback)
	store[index] = store[index] or {}
	store[index][callID] = id

	return store, index
end

function u.remHook(callID, id, store)
	assert(istable(store) == true, "A storage table must be passed!")
	id = "PUG." .. id

	for index, getTable in next, store do
		for cid, hid in next, getTable do
			if (cid == callID and hid == id) then
				print("[PUG][HOOKS] Removing " .. hookID .. " @ " .. callID)
				hook.Remove(callID, hookID)
				store[index][callID] = nil
				break
			end
		end
	end
end

function u.addTimer(timerID, delay, reps, callback, store)
	assert(istable(store) == true, "A storage table must be passed!")

	local index = #store + 1
	timerID = "PUG." .. timerID

	timer.Create(timerID, delay, reps, callback)
	store[index] = store[index] or {}
	store[index][timerID] = delay

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

do
	local jobs = {}

	local function jobProcess(index, job, try)
		jobs[index].retry = try
		jobs[index] = job
	end

	function u.addJob(callback, runAfterTicks, retry)
		assert(type(callback) == "function", "The callback must be a function!")
		local index = #jobs + 1
		jobs[index] = {
			call = callback,
			runAfterTicks = runAfterTicks or 0,
			retry = retry or 1,
		}
	end

	hook.Add("Think", "PUG_JobProcessor", function()
		local index = #jobs
		for i = 1, 25 do
			local job = jobs[index]
			if job then
				local try = job.retry - 1

				if job.runAfterTicks <= 0 then
					if job.call() or try <= 0 then
						job = nil
					end
				else
					job.runAfterTicks = job.runAfterTicks - 1
				end

				jobProcess(index, job, try)
				index = index - i
			end
		end
	end)
end

return u
