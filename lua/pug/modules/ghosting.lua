local PUG = PUG
local hook, timer = hook, timer
local u = PUG.util

hook.Add("PUG_SetCollisionGroup", "PUGCollision", function( ent, group )
	local isGroupNone = ( group == COLLISION_GROUP_NONE )
	local checkEnt = ( ent.PUGBadEnt and not PUG:isGoodEnt( ent ) )
	if isGroupNone and checkEnt and ( not ent.PUGFrozen ) then
		return COLLISION_GROUP_INTERACTIVE
	end
end)

hook.Add("PUG_EnableMotion", "PUGCollision", function( ent, _, bool )
	if bool and ent.PUGBadEnt then
		ent:SetCollisionGroup( COLLISION_GROUP_INTERACTIVE )
	end
end)

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
				end
			end
		else
			if isLivingPlayer then
				local pos = v:GetPos()
				local trace = { start = pos, endpos = pos, filter = v }
				local tr = util.TraceEntity( trace, v )

				if tr.Entity == ent then
					check = v
				end
			end
		end

		if check then break end
	end

	return check and true or false
end

function PUG:Ghost( ent, ghost )
	if not ghost then
		self:UnGhost( ent )
		return
	end

	if ent.jailWall then return end
	if not ent.PUGBadEnt then return end

	ent.FPPAntiSpamIsGhosted = nil -- Override FPP Ghosting.
	ent.PUGGhost = ent.PUGGhost or {}
	ent.PUGGhost.collision = ent:GetCollisionGroup()

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

		ent:SetColor( Color(4, 20, 36, 250) )
	end)

	ent.PUGGhost.render = ent:GetRenderMode()
	ent:SetRenderMode( RENDERMODE_TRANSALPHA )
	ent:DrawShadow( false )

	if noCollide then
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
	local moving = u.entityIsMoving(ent)

	if not ( trap or moving ) then
		u.entityForceDrop( ent )

		ent.APG_Ghosted = false
		ent:DrawShadow( true )

		ent:SetRenderMode( ent.APG_oldRenderMode or RENDERMODE_NORMAL )
		ent:SetColor( ent.APG_oldColor or Color( 255, 255, 255, 255) )
		ent.APG_oldColor = false

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
		return true
	else
		--FIXME: Add notification here!
		print("A prop has tried to unghost, but couldn't!")
		return false
	end
end

hook.Add("PUG_PostPhysgunPickup", "PUGGhosting", function(_, ent, canPickup)
	u.addJob(function()
		if not canPickup then return end
		if IsValid( ent ) then
			PUG:Ghost( ent, true )
		end
	end)
end)

hook.Add("PhysgunDrop", "PUGGhosting", function(_, ent)
	timer.Simple(0.5, function()
		u.addJob(function()
			if u.isEntityHeld(ent) then return end
			if IsValid( ent ) then
				PUG:Ghost( ent, false )
			end
		end)
	end)
end)

return {
	hooks = {
		["PUG_SetCollisionGroup"] = "PUGCollision",
		["PUG_EnableMotion"] = "PUGCollision",
		["PUG_PostPhysgunPickup"] = "PUGGhosting",
		["PhysgunDrop"] = "PUGGhosting",
	},
	settings = {
		["GhostColour"] = "4 20 36 250",
		["GhostsNoCollide"] = "0",
	}
}