local u = PUG.util

local hooks = {}
local settings = {
	["AddFadingDoorHooks"] = true,
	["BlockToolUseOnWorld"] = true,
	["BlockToolSpam"] = true,
	["ToolFreezes"] = false,
	["SpamToolDelay"] = 1,
	["SpamToolRate"] = 7,
}

settings = u.getSettings( settings )

local addFadingDoorHooks 	= settings[ "AddFadingDoorHooks" ]
local blockToolWorld 		= settings[ "BlockToolUseOnWorld" ]
local blockToolSpam 		= settings[ "BlockToolSpam" ]
local toolFreezes 			= settings[ "ToolFreezes" ]
local toolDelay 			= settings[ "SpamToolDelay" ]
local toolRate 				= settings[ "SpamToolRate" ]

u.addHook("PUG.PostCanTool", "ToolSpamControl", function( ply, _, _, canTool )
	if not canTool then return end
	if not blockToolSpam then return end

	ply.PUG_toolCTRL = ply.PUG_toolCTRL or {}

	local data = ply.PUG_toolCTRL
	local delay = 0
	local diff = 0

	data.curTime = CurTime()
	data.toolDelay = data.toolDelay or 0
	data.toolUseTimes = data.toolUseTimes or 0

	diff = data.curTime - data.toolDelay
	delay = toolDelay

	if data.toolUseTimes <= 0 or diff > delay then
		data.toolUseTimes = 0
		data.toolDelay = 0
		data.wasNotified = false
	end

	if diff > 0 then
		data.toolUseTimes = data.toolUseTimes - 1
		if data.toolUseTimes < 0 then
			data.toolUseTimes = 0
		end
	else
		data.toolUseTimes = data.toolUseTimes + 1

		if data.toolUseTimes > toolRate then
			data.toolUseTimes = toolRate
		end

		if data.toolUseTimes >= toolRate then
			data.toolDelay = data.curTime + delay
			if not data.wasNotified then
				data.wasNotified = true
				PUG:Notify( "pug_tool2fast", 1, 5, ply )
			end

			return false
		end
	end

	if data.toolDelay == 0 then
		data.toolDelay = data.curTime + delay
	end
end, hooks)

u.addHook("CanTool", "ToolWorldControl", function(ply, tr)
	if blockToolWorld then
		if tr.HitWorld then
			PUG:Notify( "pug_toolworld", 1, 5, ply )
			return false
		end
	end
end, hooks)

u.addHook("PUG.PostCanTool", "ToolUnfreezeControl", function(ply, tr, _, canTool)
	if not canTool then return end
	if not toolFreezes then return end

	timer.Simple(0.003, function()
		local ent = tr.Entity
		local phys = NULL

		if IsValid(ent) then
			phys = ent:GetPhysicsObject()
			if IsValid(phys) and phys:IsMotionEnabled() then
				phys:EnableMotion( false )
				PUG:Notify( "pug_entfrozen", 1, 1, ply )
			end
		end
	end)
end, hooks)

u.addHook("PUG.PostCanTool", "FadingDoors", function(ply, tr)
	if not addFadingDoorHooks then return end
	u.addJob(function()
		local ent = tr.Entity

		if IsValid(ent) then
			if not ent.isFadingDoor then return end
			local state = ent.fadeActive

			if state then
				ent:fadeDeactivate()
			end

			ent.oldFadeActivate = ent.oldFadeActivate or ent.fadeActivate
			ent.oldFadeDeactivate = ent.oldFadeDeactivate or ent.fadeDeactivate

			function ent:fadeActivate()
				if hook.Run("PUG.FadingDoorToggle", self, true, ply) then
					return
				end

				ent:oldFadeActivate()
			end

			function ent:fadeDeactivate()
				if hook.Run("PUG.FadingDoorToggle", self, false, ply) then
					return
				end

				ent:oldFadeDeactivate()
				ent:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE)
			end

			if state then
				ent:fadeActivate()
			end
		end
	end)
end, hooks)

return {
	hooks = hooks,
	settings = settings,
}