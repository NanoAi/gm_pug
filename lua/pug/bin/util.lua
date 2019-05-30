local istable, hook = istable, hook
local cppiOwner = false
local util = {}

do
	local ENT = FindMetaTable("Entity")
	cppiOwner = ENT.CPPIGetOwner
end

function util.safeSetCollisionGroup( ent, group, pObj )
	if ent:IsPlayerHolding() then return end
	if ent.APG_Ghosted then return end
	if pObj then pObj:Sleep() end
	ent:SetCollisionGroup( group )
	ent:CollisionRulesChanged()
end

function util.isVehicle( ent, basic )
	if not IsValid( ent ) then return false end

	if ent:IsVehicle() then return true end
	if string.find( ent:GetClass(), "vehicle" ) then return true end

	if basic then return false end

	local parent = ent:GetParent()
	return util.isVehicle( parent, true )
end

function util.callOnConstraints( ent, callback )
	local constrained = constraint.GetAllConstrainedEntities( ent )
	for _, child in next, constrained do
		if IsValid( child ) and child ~= ent then
			callback( child )
		end
	end
end

function util.getCPPIOwner( ent )
	if type( cppiOwner ) == "function" then
		local owner = cppiOwner( ent )
		if type( cppiOwner( ent ) ) ~= "Player" then
			return false
		else
			return owner
		end
	end
end

function util.notifyOwner( msg, msgType, length, ent )
	local owner = util.getCPPIOwner( ent )
	if owner and IsValid( owner ) then
		PUG:Notify( msg, msgType, length, owner )
	end
end

function util.entityForceDrop( ent )
	if istable(ent.PUGHolding) then
		for _, ply in next, ent.PUGHolding do
			if ply and IsValid(ply) then
				ply:ConCommand("-attack")
			end
		end
	end
	DropEntityIfHeld( ent )
	ent:ForcePlayerDrop()
end

function util.entityIsMoving( ent, speed )
	if type( ent ) ~= "Entity" then return end
	if not IsValid( ent ) then return end

	local zero = Vector(0,0,0)
	local phys = ent:GetPhysicsObject()

	if IsValid(phys) then
		local vel = phys:GetVelocity():Distance(zero)
		return ( vel > speed ), vel
	else
		return false, nil
	end
end

function util.sleepEntity( ent )
	if type( ent ) ~= "Entity" then return end
	if not IsValid( ent ) then return end

	local zero = Vector(0,0,0)
	local phys = ent:GetPhysicsObject()

	if IsValid(phys) then
		phys:SetVelocityInstantaneous( zero )
		phys:AddAngleVelocity( phys:GetAngleVelocity() * -1 )
		phys:Sleep()
	end
end

function util.isEntityHeld( ent )
	if not istable(ent.PUGHolding) then
		return false
	end
	return ( next( ent.PUGHolding ) ~= nil )
end

function util.addEntityHolder( ent, ply )
	local steamID = ply:SteamID()
	ent.PUGHolding = ent.PUGHolding or {}
	ent.PUGHolding[steamID] = ply
end

function util.removeEntityHolder( ent, ply )
	local steamID = ply:SteamID()
	ent.PUGHolding = ent.PUGHolding or {}
	ent.PUGHolding[steamID] = nil
end

function util.getSettings( defaults )
	local module = PUG.currentModule or {}
	-- local path = module.path

	if not module.data then
		module = defaults
	else
		module = table.Merge( defaults, module.data.settings or {} )
	end

	return module
end

function util.addHook( hookID, id, callback, store )
	assert( istable( store ) == true, "A storage table must be passed!" )

	local index = #store + 1
	id = "PUG." .. id

	hook.Add( hookID, id, callback )
	store[ index ] = store[ index ] or {}
	store[ index ][ hookID ] = id

	return store
end

function util.addTimer( timerID, delay, reps, callback, store )
	assert( istable( store ) == true, "A storage table must be passed!" )

	local index = #store + 1
	timerID = "PUG." .. timerID

	timer.Create( timerID, delay, reps, callback )
	store[ index ] = store[ index ] or {}
	store[ index ][ timerID ] = delay

	return store
end

do
	local jobs = {}

	function util.addJob( callback )
		assert(type(callback) == "function", "The callback must be a function!")
		local index = #jobs + 1
		jobs[ index ] = callback
	end

	function util.removeJob( index )
		jobs[ index ] = nil
	end

	hook.Add("Tick", "PUG_JobProcessor", function()
		for _ = 1, 25 do
			local index = #jobs
			local job = jobs[ index ]
			if job then
				job()
				util.removeJob( index )
			end
		end
	end)
end

return util