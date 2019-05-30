local PUG = PUG
local timer = timer

local addHook = PUG.util.addHook
local hooks = {}

local function applyPlayerHack( ply )
	timer.Simple(0, function()
		local phys = ply:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableMotion(false)
			phys:Sleep()
		end
	end)
end

--FIXME: Check if "PlayerInitialSpawn" is also needed.
addHook("PlayerInitialSpawn", "PUG_PlayerSpawn", applyPlayerHack, hooks)
addHook("PlayerSpawn", "PUG_PlayerSpawn", applyPlayerHack, hooks)

for _, ply in next, player.GetAll() do
	if IsValid( ply ) then
		applyPlayerHack( ply )
	end
end

addHook("EntityTakeDamage", "PUG_DamageControl", function(target, dmg)
	if type(target) ~= "Player" then
		return
	end

	local ent = dmg:GetInflictor()
	local damageType = dmg:GetDamageType()

	if ent.PUGBadEnt then
		return true
	else
		if IsValid( ent ) then
			if PUG:isGoodEnt( ent ) or ent:IsWeapon() then
				return
			end
		end
	end

	if damageType == DMG_CRUSH or damageType == DMG_VEHICLE then
		return true
	end
end, hooks)

return {
	hooks = hooks
}