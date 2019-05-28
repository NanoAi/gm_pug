local u = PUG.util

local hooks = {}
local settings = {
	["AlwaysFrozen"] = 0,
	["NoThrowing"] = 0,
	["NoPhysgunReload"] = 0,
	["NoVehiclePickup"] = 0,
}

settings = u.getSettings( settings )

local alwaysFrozen = ( settings[ "AlwaysFrozen" ] == 1 )
local noThrowing = ( settings[ "NoThrowing" ] == 1 )
local noPhysgunReload = ( settings[ "NoPhysgunReload" ] == 1 )
local noVehiclePickup = ( settings[ "NoVehiclePickup" ] == 1 )

u.addHook("PhysgunDrop", "PUG.physgun", function( _, ent )
	if noThrowing then
		if IsValid( ent ) and ent.GetPhysicsObject then
			u.sleepEntity( ent )
		end
	end
end, hooks)

u.addHook("CanPlayerUnfreeze", "PUG.physgun", function( _, _, phys )
	if alwaysFrozen then
		if IsValid( phys ) then
			phys:EnableMotion( false )
		end
		return false
	end
end, hooks)

u.addHook("PhysgunPickup", "PUG.physgun", function( _, ent )
	if noVehiclePickup then
		if IsValid( ent ) and u.isVehicle( ent ) then
			return false
		end
	end
end, hooks)

u.addHook("OnEntityCreated", "PUG.physgun", function( ent )
	if not alwaysFrozen then return end

	u.addJob(function()
		if not ent.PUGBadEnt then return end
		if not IsValid( ent ) then return end
		if not ent:IsSolid() then return end

		if type( ent.GetPhysicsObject ) ~= "function" then
			return
		end

		local phys = ent:GetPhysicsObject()
		if IsValid( phys ) then
			phys:EnableMotion( false )
		end
	end)
end, hooks)

u.addHook("OnPhysgunReload", "PUG.physgun", function()
	if alwaysFrozen or noPhysgunReload then
		return false
	end
end)

return {
	hooks = hooks,
	settings = settings,
}