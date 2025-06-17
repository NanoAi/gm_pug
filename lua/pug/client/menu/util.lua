local type = type
local istable = istable
local tostring = tostring
local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local langGetPhrase = language.GetPhrase
local string = string
local emptyFunc = function() end
local emptyStr = ""

local u = {}

function u.declare(key, value)
  u.internal = u.internal or {}
  u.internal[key] = value
end

function u.l( str, describe )
	local key = describe and "vd" or "v"
	local re = langGetPhrase( string.format("pug_%s.%s", key, str) )
	if string.sub(re, 1, 4) == "pug_" then
		return (key == "vd" and "No description available.") or str
	end
	return re
end

local l = u.l

function u.netSendSettings( data )
  local sendData = util.TableToJSON( data )
	if sendData and sendData ~= "" then
		sendData = util.Compress( sendData )
		net.Start("pug.take")
		net.WriteData( sendData, #sendData )
		net.SendToServer()
		sendData = nil
	end
end

function u.type( object )
	if object == nil then 
		return "nil"
	end
	local guess = type(object)
	if guess == "table" then
		return object[0] or guess
	end
	return guess
end

function u.setupMenu( menu )
	function menu:GetFrame()
		return self.frames.parent
	end

	function menu:SetFrame( frame )
		self.frames.parent = frame
		return frame
	end

	function menu:GetChildren()
		return self.frames.children
	end

	function menu:AddChild(panel)
		local children = self.frames.children
		local key = #children + 1

		children[key] = panel
		self.frames.children = children -- Update.
		
		return children[key]
	end

	function menu:CreateChild(type, parent)
		local children = self.frames.children
		local key = #children + 1

		children[key] = vgui.Create(type, parent)
		self.frames.children = children -- Update.

		return children[key]
	end

	return menu
end

function u.newToggleLine(parent, v)
	local b = vgui.Create("DButton", parent)
	b:SetText(emptyStr)
	b:SetIsToggle(true)
	b:Dock(TOP)
	b:SetTooltip("Click to Toggle")
	b:SetTall(10)
	function b:DoClick()
		self:Toggle()
		v.enabled = self:GetToggle()
	end
	function b:Paint(w, h)
		local ww = w * 0.95
		local mid = w/2 - ww/2
		if self:GetToggle() then
			surface.SetDrawColor(Color(0, 255, 0, 100))
			surface.DrawRect(mid, 4, ww, 2)
		else
			surface.SetDrawColor(Color(255, 0, 0, 100))
			surface.DrawRect(mid, 4, ww, 2)
		end
	end
	b:SetToggle(v.enabled)
end

function u.newToggleButton( parent, value )
	local RNDX = u.internal.RNDX
	local PUGMenu = u.internal.PUGMenu
	local b = vgui.Create("DButton", parent)
	b:SetText(emptyStr)
	b:SetIsToggle(true)
	b:Dock(TOP)
	b:DockMargin(0, 5, 0, 5)
	b:SetTooltip("Click to Toggle")
	b:SetTall(20)
	function b:DoClick()
	end
	function b:Paint(w, h)
		local ww = w * 0.90
		local hh = h * 0.55
		local wm = (w/2) - (ww/2)
		local hm = (h/2) - (hh/2)

		if self:GetToggle() then
			local onColour = Color(85, 100, 85, 150)
			RNDX.DrawOutlined(8, wm, hm, ww, hh, onColour, 3, RNDX.SHAPE_FIGMA)
			RNDX.Draw(8, wm, hm, ww, hh, Color(0, 255, 0, 100), RNDX.SHAPE_FIGMA)
		else
			local onColour = Color(100, 100, 100, 100)
			RNDX.DrawOutlined(8, wm, hm, ww, hh, onColour, 3, RNDX.SHAPE_FIGMA)
			RNDX.Draw(8, wm, hm, ww, hh, Color(140, 10, 10, 90), RNDX.SHAPE_FIGMA)
		end
	end
	b:SetToggle(value)
	return b
end

function u.dColumnSheet( sheet, width, height )
	local RNDX = u.internal.RNDX
	local rFlags = RNDX.NO_TR + RNDX.NO_BR + RNDX.SHAPE_FIGMA
	sheet.Navigation:DockMargin( 0, 10, 0, 10 )

	local old = sheet.AddSheet
	function sheet:AddSheet(label, panel, material)
		local v = old(sheet, label, panel, material)
		v.Panel.Paint = function( self, w, h )
			RNDX.Draw(8, 0, 0, w, h, Color(50, 50, 50, 150), RNDX.SHAPE_FIGMA)
		end
		v.Button:DockMargin( 0, 0, 0, 5 )
		v.Button:SetSize(width, height)
		v.Button.Paint = function( self, w, h )
			if self:GetToggle() then
				RNDX.Draw(8, 0, 0, w, h, Color(50, 50, 50, 150), rFlags)
			else
				RNDX.Draw(8, 0, 0, w, h, Color(0, 0, 0, 200), rFlags)
			end
		end
		return v
	end

	function sheet:ClearSheets()
		for _, v in next, self.Items do
			v.Button:Remove()
			v.Panel:Remove()
		end
		self.Items = {}
	end
	
	return sheet
end

function u.setupButton(x, y, width, height, button, src, colours, flags, noBackground, setOffset)
	colours = colours or {
		base = Color(60, 60, 60, 255),
		click = Color(80, 80, 80, 255),
		image = Color(255, 255, 255, 255),
		imageClick = Color(125, 125, 125, 255),
	}

	noBackground = noBackground or false
	setOffset = setOffset or 3

  local RNDX = u.internal.RNDX
  button.colours = colours

  function button:Paint(w, h)
		local offset = 0
		local colours = {
			base = self.colours.base,
			image = self.colours.image,
		}

		if self.clicked then
			colours.base = self.colours.click
			colours.image = self.colours.imageClick
			offset = setOffset
		end

		if not noBackground then
			RNDX.Draw(8, 0, 4, w - 5, h - 4, colours.base, flags)
		end
		-- w/2 = 37.5, h * 0.75 = 37.5 | Rounding to 38.
		RNDX.DrawMaterial(0, x, y + offset, width, height, colours.image, src, RNDX.SHAPE_FIGMA)
	end

	function button:Clicked()
		self.clicked = true
		timer.Simple(0.3, function()
			self.clicked = false
		end)
	end
end

function u.dCornerButton(parent, x, y, w, h)
	local RNDX = u.internal.RNDX
	local PUGMenu = u.internal.PUGMenu
	local btn = vgui.Create("DButton", parent)
	btn:SetPos(x, y)
	btn:SetSize(w, h)

	function btn:Paint(w, h)
		surface.SetFont("Default")
		surface.SetTextColor(255, 255, 255, 200)
		surface.SetTextPos(w/2, h/2 - 9) 
		surface.DrawText("?")
	end

	function btn:SetRelative(opts, fit, puntX, puntY)
		function btn:PerformLayout(w, h)
			opts = opts or {}

			local sw, sh = self:GetSize()
			local pw, pt = parent:GetSize()
			local x = (pw + (opts.x or 0)) * (opts.xm or 1)
			local y = (pt + (opts.y or 0)) * (opts.ym or 1)
			local w = (pw + (opts.w or 0)) * (opts.wm or 1)
			local h = (pt + (opts.h or 0)) * (opts.hm or 1)

			sw = puntX and sw or 0
			sh = puntY and sh or 0

			self:SetPos(x - sw, y - sh)
			if fit then
				self:SetSize(w, h)
			end
		end
		self:InvalidateLayout()
	end
	return btn
end

function u.hookTooltip(btn, text, offset)
	offset = offset or 0
	btn.ToolTip = nil
	function btn:PopPanel()
		local RNDX = u.internal.RNDX
		local x, y = input.GetCursorPos()
		local w, h = ScrW() / 4, 40

		local frame = vgui.Create("DPanel")
		frame:SetPos(x - w/2, (y - h) - offset)
		frame:SetSize(w, h)
		local scroller = vgui.Create("DScrollPanel", frame)
		scroller:Dock(FILL)
		scroller:DockMargin(10, 10, 10, 10)
		scroller:GetVBar().btnGrip.Paint = emptyFunc
		local option = vgui.Create("DLabel", scroller)
		option:SetText(text)
		option:SetAutoStretchVertical(true)
		option:SetWrap(true)
		option:Dock(FILL)

		function frame:Paint(w, h)
			RNDX.Draw(8, 0, 0, w, h, nil, RNDX.SHAPE_FIGMA + RNDX.BLUR)
			RNDX.Draw(8, 0, 0, w, h, Color(0, 0, 0, 150), RNDX.SHAPE_FIGMA)
		end

		frame:SetDrawOnTop(true)
		self.ToolTip = frame
	end

	local mem = btn.Paint
	function btn:Paint(w, h)
		mem(self, w, h)
		if btn.Hovered then
			if not self.ToolTip then
				btn:PopPanel()
			end
		elseif self.ToolTip and not self.ProxyHover then
			self.ToolTip:Remove()
			self.ToolTip = nil
		end
	end
end

-- # Type defined panels.
local typedPanels = {}

local function setInMemoryTable(key, keyPath, value)
	local data = PUGMenu.data[keyPath[0]].data.settings
	for _, k in ipairs(keyPath) do
		if istable(data[k]) and data[k].v ~= nil then
			data = data[k].v
		else
			data = data[k]
		end
	end
	if istable(data[key]) and data[key].v ~= nil then
		data[key].v = value
	else
		data[key] = value
	end
end

function typedPanels:number(v, container, key)
	local panel = vgui.Create("DPanel")
	local option = vgui.Create("DNumberWang", panel)
	option:SetMinMax(0, 100)
	option:SetDecimals(3)
	option:SetValue(v)
	function option:PerformLayout(w, h)
		w = container:GetWide() - 40
		self:SetSize(w, h)
		self:CenterHorizontal()
		self.Up:SetPos(w - 20, 0)
		self.Down:SetPos(w - 20, h - 10)
		self.Up:SetSize(20, h/2)
		self.Down:SetSize(20, h/2)
	end
	function option:OnValueChanged()
		v = self:GetValue()
	end
	
	container:SetContents(panel)
	panel:SetPaintBackground(false)
	panel:InvalidateChildren()
end

function typedPanels:boolean(v, container, key, keyPath)
	local panel = vgui.Create("DPanel")
	local btn = u.newToggleButton(panel, v)
	function btn:DoClick()
		self:Toggle()
		setInMemoryTable(key, keyPath, self:GetToggle())
	end
	container:SetContents(panel)
	panel:SetPaintBackground(false)
	panel:InvalidateChildren()
end

function typedPanels:colour(v, container, key)
	local panel = vgui.Create("DPanel")
	panel:Dock(FILL)
	local option = vgui.Create( "DColorCombo", panel )
	option:SetSize(300, 200)
	option:SetColor(v)
	option.Mixer:SetAlphaBar(true)
	option.Mixer:SetWangs(true)
	local layout = option.PerformLayout
	function option:PerformLayout(w, h)
		layout(self, w, h)
		self:SetSize(container:GetWide(), 200)
	end
	function option:OnValueChanged( newColour )
		local colour = {
			[0] = v,
			r = newColour.r,
			g = newColour.g,
			b = newColour.b,
			a = newColour.a,
		}
		setInMemoryTable(key, keyPath, colour)
	end
	container:SetContents(panel)
	panel:SetPaintBackground(false)
	panel:InvalidateChildren()
end

function typedPanels:string(v, container, key)
	local panel = vgui.Create("DPanel")
	local dEntry = vgui.Create("DTextEntry", panel)
	dEntry:Dock(TOP)
	function dEntry:OnEnter()
		local value = self:GetValue()
		chat.AddText("Value Set To: " .. value)
		setInMemoryTable(key, keyPath, value)
	end
	container:SetContents(panel)
	panel:SetPaintBackground(false)
	panel:InvalidateChildren()
end
-- # Panel Caller.
function u.newPanelByType(panelType, v, container, key, keyPath)
	local panel = typedPanels[panelType]
	if panel ~= nil then
		return panel(typedPanels, v, container, key, keyPath)
	end
end

return u
