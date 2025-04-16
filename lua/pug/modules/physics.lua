local PUG = PUG
local timer = timer

local u = PUG.util
local hooks = {}

local settings = {
	["ApplyPlayerHack"] = true,
	["AllowGravityGun"] = false,
	["DamageControl"] = true,
}

settings = u.getSettings( settings )

local _s = {
	allowGravGun = settings[ "AllowGravityGun" ],
	damageControl = settings[ "DamageControl" ],
	setPlayerHack = settings[ "ApplyPlayerHack" ],
}

local function applyPlayerHack( ply )
	if not _s.setPlayerHack then return end
	timer.Simple(0, function()
		local phys = ply:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableMotion(false)
			phys:Sleep()
		end
	end)
end

--FIXME: Check if "PlayerInitialSpawn" is also needed.
u.addHook("PlayerInitialSpawn", "PUG_PlayerSpawn", applyPlayerHack, hooks)
u.addHook("PlayerSpawn", "PUG_PlayerSpawn", applyPlayerHack, hooks)

for _, ply in next, player.GetAll() do
	if IsValid( ply ) then
		applyPlayerHack( ply )
	end
end

u.addHook("EntityTakeDamage", "PUG_DamageControl", function(target, dmg)
	if not _s.damageControl then return end
	if type(target) ~= "Player" then
		return
	end

	local ent = dmg:GetInflictor()
	local valid = IsValid( ent )
	local damageType = dmg:GetDamageType()

	if _s.allowGravGun and valid then
		local phys = ent:GetPhysicsObject()
		if IsValid( phys ) and phys:HasGameFlag( FVPHYSICS_WAS_THROWN ) then
			return
		end
	end

	if ent.PUGBadEnt then
		return true
	else
		if valid and ( PUG:isGoodEnt( ent ) or ent:IsWeapon() ) then
			return
		end
	end

	if damageType == DMG_CRUSH or damageType == DMG_VEHICLE then
		return true
	end
end, hooks)

return {
	hooks = hooks,
	settings = settings,
}
