local util = {}

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

function util.entityForceDrop( ent )
	if type(ent.PUGHolding) == "table" then
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
		phys:SetVelocityInstantaneous(zero)
		phys:Sleep()
	end
end

function util.isEntityHeld( ent )
	if type(ent.PUGHolding) ~= "table" then
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
		local index = #jobs
		local job = jobs[ index ]
		if job then
			job()
			util.removeJob( index )
		end
	end)
end

return util