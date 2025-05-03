local u = PUG.util

local hooks = {}
local settings = {
	["AlwaysFrozen"] = false,
	["NoThrowing"] = false,
	["NoPhysgunReload"] = false,
	["NoVehiclePickup"] = false,
}

settings = u.getSettings( settings )

local alwaysFrozen 		= settings[ "AlwaysFrozen" ]
local noThrowing 		= settings[ "NoThrowing" ]
local noPhysgunReload 	= settings[ "NoPhysgunReload" ]
local noVehiclePickup 	= settings[ "NoVehiclePickup" ]

u.addHook("PhysgunDrop", "physgun", function( _, ent )
	if noThrowing then
		u.sleepEntity( ent, true )
	end
	if alwaysFrozen then
		u.freezeEntity( ent )
	end
end, hooks)

u.addHook("CanPlayerUnfreeze", "physgun", function( _, _, phys )
	if alwaysFrozen then
		return false
	end
end, hooks)

u.addHook("PhysgunPickup", "physgun", function( _, ent )
	if noVehiclePickup and ( IsValid( ent ) and u.isVehicle( ent ) ) then
		return false
	end
end, hooks)

u.addHook("OnEntityCreated", "physgun", function( ent )
	if not alwaysFrozen then return end

	u.tasks.add(function()
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

u.addHook("OnPhysgunReload", "physgun", function()
	if alwaysFrozen or noPhysgunReload then
		return false
	end
end, hooks)

return {
	hooks = hooks,
	settings = settings,
}