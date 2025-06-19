local addNotification = notification.AddLegacy
local langGetPhrase = language.GetPhrase
local istable = istable

-- Include Externals
local lang = include("pug/client/language.lua")
local RNDX = include("pug/client/rndx.lua")
local PUGUtil = include("pug/client/menu/util.lua")
local emptyFunc = function() end
local emptyStr = ""
local l = PUGUtil.l
-- END --

PUGUtil.declare("RNDX", RNDX)

PUGMenu = PUGUtil.setupMenu({
  frames = {
		parent = {},
		children = {},
	},
  data = {},
  cache = {
    sound = Sound("pug/breath.mp3"),
		upload = Material( "pug/icons/send_small.png", "smooth" ),
		download = Material( "pug/icons/request_small.png", "smooth" ),
		icon = Material( "materials/pug/x256.png", "smooth" ),
  },
	svPhysFrames = {},
	clFrameTime = {},
	buttonColours = {
		base = Color(60, 60, 60, 255),
		click = Color(80, 80, 80, 255),
		image = Color(255, 255, 255, 255),
		imageClick = Color(125, 125, 125, 255),
	}
})

local function buildOption(module, sheet, settings, scroller, memPath)
	if not istable(settings) then return end -- Ensure that it's a table.
	memPath = memPath or {} -- Default value for keyPath.

	local flip = false
	local flipper = 0
	local parent = sheet.Panel
	local memory = settings[0]

	-- Only main modules have scrollers so it's safe to set other effects there.
	if not scroller then
		flip = true
	end

	settings[0] = nil
	for k, v in next, settings do
		local check = istable(v)
		local inherit = check and v.inherit or false
		if check and v.v ~= nil then
			v = v.v -- If a child `v` exists inherit it as the value.
		end

		local vType = PUGUtil.type(v)

		local curPath = {}
		for i = 1, #memPath do 
			curPath[i] = memPath[i]
		end
		curPath[#curPath + 1] = k

		if flip then
			flipper = flipper < 3 and (flipper + 1) or 0
			scroller = parent.Scroll[(flipper % 2) + 1]
		end

		if inherit and vType == "table" then
			PUGUtil.newToggleLine(scroller, v)
		else
			local container = vgui.Create("DCollapsibleCategory", scroller)
			container:SetLabel(l(k))
			container:SetExpanded(true)
			container:Dock(TOP)
			container:DockMargin(3, 3, 3, 7)
			container:DockPadding(3, 3, 3, 7)
			if vType == "folder" then
				buildOption(module, sheet, v, container, curPath)
			else
				-- Add value controller here.
				local out = {[0] = module, unpack(curPath, 1, #curPath - 1)}
				PUGUtil.newPanelByType(vType, v, container, k, out)
				local btn = PUGUtil.dCornerButton(container.Header, 0, 0, 20, 20)
				btn:SetText(emptyStr)
				btn:SetRelative({x = 1, ym = 0}, false, true, false)
				PUGUtil.hookTooltip(btn, l(k, true))
			end
		end
	end
	settings[0] = memory

	if istable(scroller) then
		for i = 1, 3 do
			scroller[i]:InvalidateLayout()
		end
	else
		scroller:InvalidateLayout()
	end
end

local function showSettings( data )
	local rFlags = RNDX.NO_TR + RNDX.NO_BR + RNDX.SHAPE_FIGMA
  PUGMenu.data = util.JSONToTable( data )
	data = PUGMenu.data
	
	-- DColumnSheet
	local options = PUGMenu:GetChildren().options
	options:ClearSheets()

	-- PrintTable(data)

  for k, v in next, data do
		local p = vgui.Create( "DPanel", options )
		p:Dock( FILL )
		
		PUGUtil.newToggleLine(p, v) -- Main Activation Toggle.
		local sheet = options:AddSheet(k, p)

		local main = vgui.Create("DScrollPanel", sheet.Panel, "Main")
		main:Dock(FILL)

		local panels = {
			[1] = vgui.Create("DPanel", main, "Left"),
			[2] = vgui.Create("DPanel", main, "Right"),
			[3] = main,
		}

		for i = 1, 3 do
			panels[i]:SetPaintBackground(false)
		end

		local o = main.PerformLayout
		function main:PerformLayout(w, h)
			local hw = w / 2 -- Half Width
			for i = 0, 1 do
				local x = i + 1
				local panel = panels[x]
				panel:SetPos(hw * i, 0)
				panel:SetSize(hw - (i * 10), h)
				panel:SizeToChildren(false, true)
				function panel:PerformLayout(w, h)
					self:SizeToChildren(false, true)
				end
			end
			return o(self, w, h)
		end
		sheet.Panel.Scroll = panels

		function sheet.Button:Paint(w, h)
			if self:GetToggle() then
				RNDX.Draw(8, 0, 0, w, h, Color(50, 50, 50, 150), rFlags)
			else
				RNDX.Draw(8, 0, 0, w, h, Color(0, 0, 0, 200), rFlags)
			end
			if v.enabled then
				surface.SetDrawColor(Color(0, 255, 0, 100))
				surface.DrawRect(5, h/4, 2, h/2)
			else
				surface.SetDrawColor(Color(255, 0, 0, 100))
				surface.DrawRect(5, h/4, 2, h/2)
			end
		end
	
		buildOption(k, sheet, v.data.settings, nil)
  end
end

local function buildFrame()
	local frame = PUGMenu.frames.parent
	local s = {w = ScrW() * 0.416, h = ScrH() * 0.463}
	s.w = math.min(s.w, 800)
	s.h = math.min(s.w, 500)

  frame = vgui.Create( "DFrame" )
	frame:SetDeleteOnClose( false )
	frame:SetTitle( "Physics \"UnGriefer\" Settings" )
	frame:SetSize(s.w, s.h)
	frame:Center()
	frame:Hide()

	frame.flags = RNDX.SHAPE_IOS
	frame.width = s.w
	frame.height = s.h

	function frame.btnClose:Paint(w, h)
		RNDX.DrawCircle(w/2, (h/2) + 3, h * 0.75, Color(186, 29, 60, 250))
		RNDX.DrawCircleOutlined(w/2, (h/2) + 3, h * 0.75, Color(148, 31, 54, 250), 2)
	end

	function frame:PerformLayout(w, h)
		self.width = w
		self.height = h
		if self.btnMaxim then
			self.btnMaxim:Remove()
			self.btnMinim:Remove()
		end
	end

	function frame:OnClose()
		net.Start("pug.menu.close")
		net.SendToServer()
	end

	function frame:Paint(w, h)
    RNDX.Draw(8, 0, 0, w, h, nil, self.flags + RNDX.BLUR)
    RNDX.Draw(8, 0, 0, w, h, Color(0, 0, 0, 150), self.flags)
	end
	frame:InvalidateLayout(true)

  local p = PUGMenu:CreateChild("DPanel")
	p:Dock(FILL)
	
	local main = vgui.Create("DColumnSheet", frame)
	main = PUGUtil.dColumnSheet(main, 100, frame:GetTall() / 10.2)
	PUGMenu.frames.children.options = main
	main:Dock(FILL)
	main:DockMargin(0, 0, 0, 0)
	local loader = main:AddSheet("Loading...", p)
	function loader.Panel:PerformLayout()
		-- Request server data when the menu loads.
		net.Start("pug.send")
		net.SendToServer()
	end

	local dock = PUGMenu:CreateChild("DPanel", frame)
	dock.height = s.h * 0.23
	dock.width = s.w

	dock:Dock(BOTTOM)
	dock:SetHeight(dock.height)
	dock:DockMargin(0, 0, 0, 0)

	function dock:Paint(w,h)
    RNDX.Draw(8, 0, 0, w, h, Color(0, 0, 0, 100), frame.flags)
	end

	function dock:PerformLayout(w, h)
		self.width = w
		self.height = h
	end
	dock:InvalidateLayout()

	-- PUG Logo
	p = vgui.Create("DButton", dock)
	p:SetText( emptyStr )
	p:SetPos(0, 0)
	p:SetSize(dock.height, dock.height)
	
	local h = dock.height * 0.99
	PUGUtil.setupButton(0, 0, h, h, p, PUGMenu.cache.icon, nil, nil, true, -3)

	function p:DoClick()
		self:Clicked()
		surface.PlaySound("UI/buttonclick.wav")
		surface.PlaySound(PUGMenu.cache.sound)
	end

	-- Graph
	p = PUGMenu:CreateChild("DPanel", dock)
	p:SetPos(dock.height, 10)
	p:SetSize(dock.width * 0.2, dock.height * 0.80)
	p.key = 0

	function p:Paint(w, h)
		self.key = (self.key % math.ceil(w)) + 1

		local clft = PUGMenu.clFrameTime
		local svpt = PUGMenu.svPhysFrames

		local len = #svpt
		local vh = h - 10 -- Visible Height

		clft[self.key] = math.min(math.floor(engine.ServerFrameTime() * 1000), vh)
		RNDX.Draw(8, 0, 0, w, h, Color(43, 38, 38, 150), frame.flags)

		if svpt and len > 2 then
			for i = 1, len - 1 do
				local n = i + 1
				if clft and clft[n] then
					surface.SetDrawColor(0, 255, 255, 255)
					surface.DrawLine(i - 1, vh - clft[i], i, vh - clft[n])
				end
				surface.SetDrawColor(255, 0, 0, 200)
				surface.DrawLine(i - 1, vh - svpt[i], i, vh - svpt[n])
			end
		end
	end

	p = vgui.Create( "DButton", dock)
	p:SetText( emptyStr )
	p:SetTooltip("Request Data")
	
	p:SetPos(dock.width - 80, 5 + dock.height - 60)
	p:SetSize(80, 50)

	PUGUtil.setupButton(18.75, 9, 38, 38, p, PUGMenu.cache.download, PUGMenu.buttonColours, frame.flags)
	function p:DoClick()
		self:Clicked()
		net.Start("pug.send")
		net.SendToServer()
	end

	p = vgui.Create( "DButton", dock)
	p:SetText( emptyStr )
	p:SetTooltip("Send Data")
	
	p:SetPos(dock.width - 80, dock.height - (50 * 2) - 10)
	p:SetSize(80, 50)

	PUGUtil.setupButton(18.75, 9, 38, 38, p, PUGMenu.cache.upload, PUGMenu.buttonColours, frame.flags)
	function p:DoClick()
		self:Clicked()
		PUGUtil.netSendSettings(PUGMenu.data)
		-- Send Settings Here.
	end

	return PUGMenu:SetFrame(frame)
end

local function openFrame()
	local frame = PUGMenu:GetFrame()
	if not frame.IsVisible then
		frame = buildFrame()
		print('[PUG:Warn] Frame Not Found Recreating.')
	end
	if not frame:IsVisible() then
		frame:Show()
		frame:MakePopup()
	end
end

-- ! Networking Section

net.Receive("pug.menu", openFrame)
net.Receive("pug.send", function( len )
	showSettings( util.Decompress( net.ReadData( len ), len ) )
end)

CreateConVar("pug_cl_enabled", "1", FCVAR_ARCHIVE, lang.notificationToggle, 0, 1)

local notifyDelay = 0
net.Receive("pug.notify", function()
	if not GetConVar( "pug_cl_enabled" ):GetBool() then
		return
	end

	if notifyDelay > CurTime() then
		return
	end

	local str, type, length = net.ReadString(), net.ReadInt(4), net.ReadInt(4)
	str = langGetPhrase( str ) or str

	notification.AddLegacy( str, type, length )
	print( "NOTIFY: ", str )

	notifyDelay = CurTime() + (length * 0.45)
end)

do
	local k = 0
	net.Receive("pug.PhysicsPing", function( len )
		k = (k % 800) + 1
		PUGMenu.svPhysFrames[k] = net.ReadUInt(7)
	end)
end

concommand.Add("pug_cl_menu", openFrame, nil, "Open the menu for PUG.")
concommand.Add("pug_cl_dump", function()
	print(PUGMenu.data)
	if istable(PUGMenu.data) then
		PrintTable(PUGMenu.data)
	end
end, nil, "Dump the currently loaded data set for PUG.")
