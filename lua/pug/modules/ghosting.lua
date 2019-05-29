local PUG = PUG
local timer = timer
local u = PUG.util

local hooks = {}
local settings = {
	["GhostColour"] = {4, 20, 36, 250},
	["GhostOnSetPos"] = 1,
	["GhostsNoCollide"] = 0,
	["GroupOverride"] = 1,
}

settings = u.getSettings( settings )

local ghostSetPos = ( settings[ "GhostOnSetPos" ] == 1 )

u.addHook("PUG.SetCollisionGroup", "Collision", function( ent, group )
	if not ( settings[ "GroupOverride" ] == 1 ) then
		return
	end

	local isGroupNone = ( group == COLLISION_GROUP_NONE )
	local checkEnt = ( ent.PUGBadEnt and not PUG:isGoodEnt( ent ) )

	if isGroupNone and checkEnt and ( not ent.PUGFrozen ) then
		return COLLISION_GROUP_INTERACTIVE
	end
end, hooks)

u.addHook("PUG.EnableMotion", "Collision", function( ent, _, bool )
	if not ( settings[ "GroupOverride" ] == 1 ) then
		return
	end

	if bool and ent.PUGBadEnt then
		if ent:GetCollisionGroup( ) ~= COLLISION_GROUP_WORLD then
			ent:SetCollisionGroup( COLLISION_GROUP_INTERACTIVE )
		end
	end
end, hooks)

local function isTrap( ent )
	local check = false

	local isVehicle = u.isVehicle( ent )
	local center = ent:LocalToWorld( ent:OBBCenter() )
	local bRadius = ent:BoundingRadius()

	for _,v in next, ents.FindInSphere( center, bRadius ) do
		local isLivingPlayer = ( v:IsPlayer() and v:Alive() )

		if isVehicle then
			if isLivingPlayer then
				-- Check if the distance between the sphere centers is less
				-- than the sum of their radius.
				local vCenter = v:LocalToWorld( v:OBBCenter() )
				if center:Distance( vCenter ) < v:BoundingRadius() then
					check = v
					break
				end
			end
		else
			if isLivingPlayer then
				local pos = v:GetPos()
				local trace = { start = pos, endpos = pos, filter = v }
				local tr = util.TraceEntity( trace, v )

				if tr.Entity == ent then
					check = v
					break
				end
			end
		end
	end

	return check and true or false
end

function PUG:Ghost( ent )
	if ent.PUGGhosted then return end
	if ent.jailWall then return end
	if not ent.PUGBadEnt then return end
	if not ent:IsSolid() then return end
	if type( u.getCPPIOwner( ent ) ) ~= "Player" then return end

	ent.FPPAntiSpamIsGhosted = nil -- Override FPP Ghosting.
	ent.PUGGhost = ent.PUGGhost or {}
	ent.PUGGhost.collision = ent.PUGGhost.collision or ent:GetCollisionGroup()

	-- If and old collision group was set get it.
	if ent.OldCollisionGroup then -- FPP Compatibility
		ent.PUGGhost.collision = ent.OldCollisionGroup
	end

	if ent.DPP_oldCollision then -- DPP Compatibility
		ent.PUGGhost.collision = ent.DPP_oldCollision
	end

	ent.OldCollisionGroup = nil
	ent.DPP_oldCollision = nil
	ent.PUGGhosted = true

	timer.Simple(0, function()
		if not IsValid( ent ) then return end

		if not ent.PUGGhost.colour then
			ent.PUGGhost.colour = ent:GetColor()

			-- Compatibility with other Ghosting
			if ent.OldColor then
				ent.PUGGhost.colour = ent.OldColor
			end

			if ent.__DPPColor then
				ent.PUGGhost.colour = ent.__DPPColor
			end

			ent.OldColor = nil
			ent.__DPPColor = nil
		end

		if not ent.PUGGhost.material then
			ent.PUGGhost.material = ent:GetMaterial()
		end

		ent:SetColor( Color( unpack( settings[ "GhostColour" ] ) ) )
		ent:SetMaterial("models/debug/debugwhite")
	end)

	ent.PUGGhost.render = ent:GetRenderMode()
	ent:SetRenderMode( RENDERMODE_TRANSALPHA )
	ent:DrawShadow( false )

	if settings[ "GhostsNoCollide" ] then
		ent:SetCollisionGroup( COLLISION_GROUP_WORLD )
	else
		ent:SetCollisionGroup( COLLISION_GROUP_DEBRIS_TRIGGER )
	end

	do -- Fix magic surfing
		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableCollisions( false )
			timer.Simple(0, function()
				if IsValid(phys) then
					phys:EnableCollisions( true )
				end
			end)
		end
	end

	ent:CollisionRulesChanged()
end

function PUG:UnGhost( ent )
	if not ent.PUGGhosted then return end

	local trap = isTrap(ent)
	local moving = u.entityIsMoving(ent, 9.3)

	if not ( trap or moving ) then
		u.entityForceDrop( ent )
		u.sleepEntity( ent )
		ent:DrawShadow( true )

		ent:SetRenderMode( ent.PUGGhost.render or RENDERMODE_NORMAL )
		ent:SetColor( ent.PUGGhost.colour or Color( 255, 255, 255, 255) )
		ent:SetMaterial( ent.PUGGhost.material or '' )

		local newCollisionGroup = COLLISION_GROUP_INTERACTIVE

		if PUG:isGoodEnt( ent ) then
			newCollisionGroup = ent.PUGGhost.collision
		else
			if ent.PUGGhost.collision == COLLISION_GROUP_WORLD then
				newCollisionGroup = COLLISION_GROUP_WORLD
			else
				if ent.PUGFrozen then
					newCollisionGroup = COLLISION_GROUP_NONE
				end
			end
		end

		ent:SetCollisionGroup( newCollisionGroup )
		ent:CollisionRulesChanged()

		ent.PUGGhosted = nil
		ent.PUGGhost = nil

		return true
	else
		if trap then
			-- Only notify if something is inside this entity.
			print("Entity Trap Detected!")
		end
		return false
	end
end

u.addHook("PUG.PostSetPos", "Ghosting", function( ent )
	u.addJob(function()
		if IsValid( ent ) and ent.PUGBadEnt then
			PUG:Ghost( ent )
		end
	end)
end, hooks)

u.addHook("PUG.PostPhysgunPickup", "Ghosting", function(_, ent, canPickup)
	u.addJob(function()
		if not canPickup then return end
		if IsValid( ent ) then
			PUG:Ghost( ent )
			if constraint.HasConstraints( ent ) then
				local cw = constraint.Weld
				local denyMovement = cw(ent, Entity(0), 0, 0, 0, false, false)
				ent.PUGWeld = denyMovement
			end
		end
	end)
end, hooks)

u.addHook("PhysgunDrop", "Ghosting", function(_, ent)
	timer.Simple(0.05, function()
		u.addJob(function()
			if u.isEntityHeld(ent) then return end
			if IsValid( ent ) then
				PUG:UnGhost( ent )
				if ent.PUGWeld then
					ent.PUGWeld:Remove()
					ent.PUGWeld = nil
				end
			end
		end)
	end)
end, hooks)

u.addHook("OnEntityCreated", "Ghosting", function( ent )
	timer.Simple(0.1, function()
		if not ent.PUGBadEnt then return end
		if not IsValid( ent ) then return end
		if not ent:IsSolid() then return end
		if ent:GetClass() == "gmod_hands" then return end

		DropEntityIfHeld( ent )
		ent:ForcePlayerDrop()
		u.sleepEntity( ent )

		PUG:Ghost( ent )
	end)
end, hooks)

u.addHook("CanProperty", "Ghosting", function( _, _, ent )
	if ent.PUGGhosted then
		--FIXME: Add Notice here!
		return false
	end
end, hooks)

u.addHook("CanTool", "Ghosting", function(_, tr, tool)
	local ent = tr.Entity
	if ent.PUGGhosted and tool ~= "remover" then
		return false
	end
end, hooks)

u.addHook("PUG.FadingDoorToggle", "FadingDoor", function(ent, isFading)
	if ent.PUGGhosted then
		-- Add notification
		if isFading then
			PUG:UnGhost( ent )
		else
			return true
		end
	end

	if ent.PUGBadEnt then
		local ply = u.getCPPIOwner( ent )
		if type( ply ) ~= "Player" then return end

		if not isFading then
			u.addJob(function()
				if IsValid( ply ) and IsValid( ent ) and isTrap( ent ) then
					--FIXME: Add Notifications
					ent.PUGGhost = ent.PUGGhost or {}
					ent.PUGGhost.collision = COLLISION_GROUP_INTERACTIVE
					ent:oldFadeDeactivate()
					PUG:Ghost( ent )
					return true
				end
			end)
		end
	end
end, hooks)

_G.PUG = PUG -- Pass to global.

return {
	hooks = hooks,
	settings = settings,
}