local PUG = PUG
local isvector = isvector

local u = PUG.util
local hooks = {}

local settings = {
	["ApplyPlayerHack"] = true,
	["AllowGravityGun"] = false,
	["SleepOnDamage"] = false,
	["TurboPhysics"] = false,
	["RemoveOOB"] = false,
	["DamageControl"] = true,
}

settings = u.getSettings( settings )

local memory = {}
local _s = {
	allowGravGun = settings[ "AllowGravityGun" ],
	damageControl = settings[ "DamageControl" ],
	sleepOnDamage = settings[ "SleepOnDamage" ],
	setPlayerHack = settings[ "ApplyPlayerHack" ],
	turboPhysics = settings[ "TurboPhysics" ],
	removeOOB = settings[ "RemoveOOB" ],
}

local function applyPlayerHack( ply )
	if not _s.setPlayerHack then return end
	u.addJob(function()
		local phys = ply:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableMotion(false)
			phys:Sleep()
		end
	end, 1, 1)
end

--FIXME: Check if "PlayerInitialSpawn" is also needed.
u.addHook("PlayerInitialSpawn", "PUG_PlayerSpawn", applyPlayerHack, hooks)
u.addHook("PlayerSpawn", "PUG_PlayerSpawn", applyPlayerHack, hooks)

for _, ply in next, player.GetAll() do
	if IsValid( ply ) then
		applyPlayerHack( ply )
	end
end

if _s.removeOOB then
	u.addHook("Think", "RemoveOOB", function()
		if not _s.removeOOB then return end
		for _, ent in ents.Iterator() do
			if u.isValidPhys(ent) then
				local pos = ent:GetPhysicsObject():GetPos()
				if ( isvector(pos) ) then
					if ( util.IsInWorld(pos) ) then
						ent.PUG_LastInWorld = pos
					else
						local _pos = ent.PUG_LastInWorld
						if ( isvector(_pos) and _pos:DistToSqr(pos) > 25 ) then
							ent:Remove()
							print("[PUG][OOB] Removing Entity[" .. ent:EntIndex() .. "][" .. ent:GetClass() .. "] removed." )
						end
					end
				end
			end
		end
	end, hooks)
end

if _s.turboPhysics then
	memory = physenv.GetPerformanceSettings()
	RunConsoleCommand("sv_turbophysics", "1")
	u.addJob(function()
		local pe = physenv.GetPerformanceSettings()
		pe.LookAheadTimeObjectsVsObject = 0.25
		pe.MaxCollisionChecksPerTimestep = 25000
		pe.MaxVelocity = 2000
		pe.MaxAngularVelocity = 4000
		pe.MaxFrictionMass = 1250
		physenv.SetPerformanceSettings(pe)
		print("[PUG][EXPERIMENTAL] !! Physics Getting Lazy... !!")
	end, 1, 1)
else
	RunConsoleCommand("sv_turbophysics", "0")
	u.addJob(function()
		if (memory and memory.LookAheadTimeObjectsVsObject) then
			physenv.SetPerformanceSettings(memory)
			print("[PUG][EXPERIMENTAL] !! Restored Physics Settings. !!")
		end
	end, 1, 1)
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
		if _s.sleepOnDamage then
			u.sleepEntity(ent)
		end
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
