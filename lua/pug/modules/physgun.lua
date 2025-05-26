local u = PUG.util

local hooks = {}
local _s = u.settings.set({
	alwaysFrozen = false,
	noThrowing = false,
	noPhysgunReload = false,
	noVehiclePickup = false
})

u.addHook("PhysgunDrop", "physgun", function( _, ent )
	if _s.noThrowing then
		u.sleepEntity( ent, true )
	end
	if _s.alwaysFrozen then
		u.freezeEntity( ent )
	end
end, hooks)

u.addHook("CanPlayerUnfreeze", "physgun", function( _, _, phys )
	if _s.alwaysFrozen then
		return false
	end
end, hooks)

u.addHook("PhysgunPickup", "physgun", function( _, ent )
	if _s.noVehiclePickup and ( IsValid( ent ) and u.isVehicle( ent ) ) then
		return false
	end
end, hooks)

u.addHook("OnEntityCreated", "physgun", function( ent )
	if not _s.alwaysFrozen then return end

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
	end, 0, 0)
end, hooks)

u.addHook("OnPhysgunReload", "physgun", function()
	if _s.alwaysFrozen or _s.noPhysgunReload then
		return false
	end
end, hooks)

return u.settings.release(hooks, _s)
