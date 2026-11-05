--[[
    LucidUI - Roblox UI Library (Tabs, Groupboxen, Toggles, Buttons, Slider, Dropdown, Input, Lucide-Icons)
    Ladbar per: loadstring(game:HttpGet("https://raw.githubusercontent.com/DEIN_USER/DEIN_REPO/main/Library.lua"))()
]]

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")

local Library = {
    Toggles = {},
    Options = {},
    Connections = {},
    -- Quelle fuer Lucide-Icons (Spritesheet-Modul). Anpassbar, siehe Library:SetIconSource()
    IconSource = "https://raw.githubusercontent.com/Footagesus/Icons/main/Main.lua",
    Theme = {
        Background = Color3.fromRGB(18, 18, 22),
        Sidebar    = Color3.fromRGB(24, 24, 30),
        Group      = Color3.fromRGB(28, 28, 35),
        Element    = Color3.fromRGB(38, 38, 48),
        Outline    = Color3.fromRGB(52, 52, 66),
        Accent     = Color3.fromRGB(110, 120, 255),
        Text       = Color3.fromRGB(235, 235, 245),
        SubText    = Color3.fromRGB(150, 150, 170),
    },
}

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function New(class, props, children)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do obj[k] = v end
    for _, c in ipairs(children or {}) do c.Parent = obj end
    return obj
end

local function Corner(r) return New("UICorner", { CornerRadius = UDim.new(0, r or 6) }) end
local function Stroke(color, t) return New("UIStroke", { Color = color, Thickness = t or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
local function Pad(l, t, r, b)
    return New("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0), PaddingTop = UDim.new(0, t or 0),
        PaddingRight = UDim.new(0, r or 0), PaddingBottom = UDim.new(0, b or 0),
    })
end
local function Tween(obj, props, t)
    TweenService:Create(obj, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad), props):Play()
end
local function Connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(Library.Connections, c)
    return c
end
local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if not ok then warn("[LucidUI] Callback-Fehler: " .. tostring(err)) end
end

----------------------------------------------------------------
-- Lucide Icons
-- Unterstuetzt: Lucide-Name ("swords"), "rbxassetid://123", Zahl (Asset-ID)
----------------------------------------------------------------
local IconModule, IconLoadTried = nil, false

local function LoadIconModule()
    if IconLoadTried then return IconModule end
    IconLoadTried = true
    local ok, mod = pcall(function()
        return loadstring(game:HttpGet(Library.IconSource))()
    end)
    if ok and mod then
        IconModule = mod
        pcall(function() if mod.SetIconsType then mod.SetIconsType("lucide") end end)
    else
        warn("[LucidUI] Lucide-Icons konnten nicht geladen werden: " .. tostring(mod))
    end
    return IconModule
end

-- Eigene Quelle setzen (URL des Icon-Moduls)
function Library:SetIconSource(url)
    self.IconSource = url
    IconModule, IconLoadTried = nil, false
end

-- Eigene Aufloese-Funktion setzen: fn(name) -> { Image=..., ImageRectSize=..., ImageRectOffset=... }
function Library:SetIconResolver(fn)
    self.CustomIconResolver = fn
end

local function ResolveLucide(name)
    if Library.CustomIconResolver then
        local ok, r = pcall(Library.CustomIconResolver, name)
        if ok and r then return r end
    end
    local mod = LoadIconModule()
    if not mod then return nil end

    local fn = mod.Icon or mod.GetIcon or mod.Get
    if not fn then return nil end
    local ok, r1, r2 = pcall(fn, name)
    if not ok or not r1 then return nil end

    local image, size, offset
    if type(r1) == "table" then
        image  = r1.Image or r1.ImageId or r1[1]
        local rect = r1.ImageRect or r1[2]
        size   = r1.ImageRectSize   or (type(rect) == "table" and (rect.ImageRectSize or rect.Size))
        offset = r1.ImageRectOffset or r1.ImageRectPosition
              or (type(rect) == "table" and (rect.ImageRectPosition or rect.ImageRectOffset or rect.Position))
    else
        image = r1
        if type(r2) == "table" then
            size   = r2.ImageRectSize or r2.Size
            offset = r2.ImageRectPosition or r2.ImageRectOffset or r2.Position
        end
    end
    if type(image) == "number" then image = "rbxassetid://" .. image end
    if not image then return nil end
    return { Image = image, ImageRectSize = size or Vector2.zero, ImageRectOffset = offset or Vector2.zero }
end

function Library:ApplyIcon(img, icon)
    if not icon or icon == "" then img.Visible = false return false end
    if typeof(icon) == "number" then
        img.Image = "rbxassetid://" .. icon
    elseif type(icon) == "string" and (icon:find("rbxassetid://") or icon:find("rbxasset://") or icon:find("^http")) then
        img.Image = icon
    else
        local data = ResolveLucide(tostring(icon))
        if not data then img.Visible = false return false end
        img.Image = data.Image
        img.ImageRectSize = data.ImageRectSize
        img.ImageRectOffset = data.ImageRectOffset
    end
    img.Visible = true
    return true
end

local function MakeIcon(parent, icon, size, color)
    local img = New("ImageLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(size or 16, size or 16),
        ImageColor3 = color or Library.Theme.Text,
        Parent = parent,
    })
    Library:ApplyIcon(img, icon)
    return img
end

----------------------------------------------------------------
-- Parent-GUI
----------------------------------------------------------------
local function GetGuiParent()
    local ok, hui = pcall(function() return gethui and gethui() end)
    if ok and hui then return hui end
    local ok2, core = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and core then
        local test = pcall(function() Instance.new("Folder", core):Destroy() end)
        if test then return core end
    end
    return Players.LocalPlayer:WaitForChild("PlayerGui")
end

----------------------------------------------------------------
-- Groupbox (Elemente)
----------------------------------------------------------------
local Groupbox = {}
Groupbox.__index = Groupbox

local function BaseRow(self, height)
    return New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, height or 24),
        Parent = self.Container,
    })
end

function Groupbox:AddLabel(text, wrap)
    local T = Library.Theme
    local lbl = New("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18),
        Text = text or "", TextColor3 = T.SubText, Font = Enum.Font.Gotham, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = wrap or false,
        AutomaticSize = wrap and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
        Parent = self.Container,
    })
    local obj = {}
    function obj:SetText(t) lbl.Text = t end
    return obj
end

function Groupbox:AddDivider()
    New("Frame", { BackgroundColor3 = Library.Theme.Outline, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 1), Parent = self.Container })
end

function Groupbox:AddToggle(idx, cfg)
    cfg = cfg or {}
    local T = Library.Theme
    local toggle = { Value = cfg.Default == true, Type = "Toggle", Changed = {} }

    local row = New("TextButton", {
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, 24), Parent = self.Container,
    })
    local box = New("Frame", {
        BackgroundColor3 = T.Element, Size = UDim2.fromOffset(18, 18),
        Position = UDim2.new(0, 0, 0.5, -9), Parent = row,
    }, { Corner(5), Stroke(T.Outline) })
    local check = MakeIcon(box, "check", 12, Color3.new(1, 1, 1))
    check.AnchorPoint = Vector2.new(0.5, 0.5); check.Position = UDim2.fromScale(0.5, 0.5)
    check.ImageTransparency = 1
    local fallback = New("Frame", { -- Fallback falls Icons nicht laden
        BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(8, 8),
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        BackgroundTransparency = 1, Visible = not check.Visible, Parent = box,
    }, { Corner(2) })

    New("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(26, 0), Size = UDim2.new(1, -26, 1, 0),
        Text = cfg.Text or idx, TextColor3 = T.Text, Font = Enum.Font.Gotham, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })

    local function render()
        Tween(box, { BackgroundColor3 = toggle.Value and T.Accent or T.Element })
        Tween(check, { ImageTransparency = toggle.Value and 0 or 1 })
        Tween(fallback, { BackgroundTransparency = toggle.Value and 0 or 1 })
    end

    function toggle:SetValue(v, silent)
        self.Value = v and true or false
        render()
        if not silent then
            SafeCall(cfg.Callback, self.Value)
            for _, fn in ipairs(self.Changed) do SafeCall(fn, self.Value) end
        end
    end
    function toggle:OnChanged(fn) table.insert(self.Changed, fn) end

    Connect(row.MouseButton1Click, function() toggle:SetValue(not toggle.Value) end)
    render()
    if toggle.Value then SafeCall(cfg.Callback, true) end

    Library.Toggles[idx] = toggle
    return toggle
end

function Groupbox:AddButton(cfg, func)
    if type(cfg) == "string" then cfg = { Text = cfg, Callback = func } end
    local T = Library.Theme
    local btn = New("TextButton", {
        BackgroundColor3 = T.Element, AutoButtonColor = false, Text = "",
        Size = UDim2.new(1, 0, 0, 28), Parent = self.Container,
    }, { Corner(6), Stroke(T.Outline) })

    local holder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = btn }, {
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6),
        }),
    })
    if cfg.Icon then MakeIcon(holder, cfg.Icon, 14, T.Text) end
    local lbl = New("TextLabel", {
        BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
        Text = cfg.Text or "Button", TextColor3 = T.Text, Font = Enum.Font.GothamMedium, TextSize = 14, Parent = holder,
    })

    Connect(btn.MouseEnter, function() Tween(btn, { BackgroundColor3 = T.Outline }) end)
    Connect(btn.MouseLeave, function() Tween(btn, { BackgroundColor3 = T.Element }) end)
    Connect(btn.MouseButton1Click, function()
        Tween(btn, { BackgroundColor3 = T.Accent }, 0.08)
        task.delay(0.12, function() Tween(btn, { BackgroundColor3 = T.Element }) end)
        SafeCall(cfg.Callback)
    end)

    local obj = {}
    function obj:SetText(t) lbl.Text = t end
    return obj
end

function Groupbox:AddSlider(idx, cfg)
    cfg = cfg or {}
    local T = Library.Theme
    local min, max = cfg.Min or 0, cfg.Max or 100
    local rounding = cfg.Rounding or 0
    local slider = { Value = cfg.Default or min, Type = "Slider", Changed = {} }

    local row = BaseRow(self, 38)
    New("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -60, 0, 18), Text = cfg.Text or idx,
        TextColor3 = T.Text, Font = Enum.Font.Gotham, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })
    local valueLbl = New("TextLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.fromOffset(60, 18), TextColor3 = T.SubText, Font = Enum.Font.Gotham, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Right, Parent = row,
    })
    local bar = New("Frame", {
        BackgroundColor3 = T.Element, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 8), Parent = row,
    }, { Corner(4), Stroke(T.Outline) })
    local fill = New("Frame", { BackgroundColor3 = T.Accent, Size = UDim2.fromScale(0, 1), Parent = bar }, { Corner(4) })

    local function round(v)
        local m = 10 ^ rounding
        return math.floor(v * m + 0.5) / m
    end
    function slider:SetValue(v, silent)
        v = round(math.clamp(tonumber(v) or min, min, max))
        self.Value = v
        fill.Size = UDim2.fromScale((v - min) / math.max(max - min, 1e-9), 1)
        valueLbl.Text = tostring(v) .. (cfg.Suffix or "")
        if not silent then
            SafeCall(cfg.Callback, v)
            for _, fn in ipairs(self.Changed) do SafeCall(fn, v) end
        end
    end
    function slider:OnChanged(fn) table.insert(self.Changed, fn) end

    local dragging = false
    local function update(x)
        local a = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        slider:SetValue(min + (max - min) * a)
    end
    Connect(bar.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; update(i.Position.X)
        end
    end)
    Connect(UserInputService.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            update(i.Position.X)
        end
    end)
    Connect(UserInputService.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    slider:SetValue(slider.Value, true)
    Library.Options[idx] = slider
    return slider
end

function Groupbox:AddInput(idx, cfg)
    cfg = cfg or {}
    local T = Library.Theme
    local input = { Value = cfg.Default or "", Type = "Input", Changed = {} }

    local row = BaseRow(self, 50)
    New("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), Text = cfg.Text or idx,
        TextColor3 = T.Text, Font = Enum.Font.Gotham, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })
    local box = New("TextBox", {
        BackgroundColor3 = T.Element, Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 26),
        Text = input.Value, PlaceholderText = cfg.Placeholder or "", PlaceholderColor3 = T.SubText,
        TextColor3 = T.Text, Font = Enum.Font.Gotham, TextSize = 13, ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    }, { Corner(6), Stroke(T.Outline), Pad(8, 0, 8, 0) })

    function input:SetValue(v, silent)
        self.Value = tostring(v); box.Text = self.Value
        if not silent then
            SafeCall(cfg.Callback, self.Value)
            for _, fn in ipairs(self.Changed) do SafeCall(fn, self.Value) end
        end
    end
    function input:OnChanged(fn) table.insert(self.Changed, fn) end

    Connect(box.FocusLost, function() input:SetValue(box.Text) end)
    Library.Options[idx] = input
    return input
end

function Groupbox:AddDropdown(idx, cfg)
    cfg = cfg or {}
    local T = Library.Theme
    local dd = { Values = cfg.Values or {}, Multi = cfg.Multi == true, Type = "Dropdown", Changed = {} }
    dd.Value = dd.Multi and {} or cfg.Default
    if dd.Multi and type(cfg.Default) == "table" then
        for _, v in ipairs(cfg.Default) do dd.Value[v] = true end
    end

    local row = New("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = self.Container,
    }, { New("UIListLayout", { Padding = UDim.new(0, 4) }) })

    New("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), Text = cfg.Text or idx,
        TextColor3 = T.Text, Font = Enum.Font.Gotham, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = row,
    })
    local head = New("TextButton", {
        BackgroundColor3 = T.Element, AutoButtonColor = false, Text = "", Size = UDim2.new(1, 0, 0, 26),
        LayoutOrder = 2, Parent = row,
    }, { Corner(6), Stroke(T.Outline) })
    local headText = New("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -30, 1, 0),
        TextColor3 = T.Text, Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, Parent = head,
    })
    local arrow = MakeIcon(head, "chevron-down", 14, T.SubText)
    arrow.AnchorPoint = Vector2.new(1, 0.5); arrow.Position = UDim2.new(1, -6, 0.5, 0)

    local list = New("Frame", {
        BackgroundColor3 = T.Element, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        Visible = false, LayoutOrder = 3, Parent = row,
    }, { Corner(6), Stroke(T.Outline), Pad(4, 4, 4, 4), New("UIListLayout", { Padding = UDim.new(0, 2) }) })

    local function display()
        if dd.Multi then
            local t = {}
            for _, v in ipairs(dd.Values) do if dd.Value[v] then table.insert(t, v) end end
            headText.Text = #t > 0 and table.concat(t, ", ") or "-"
        else
            headText.Text = dd.Value ~= nil and tostring(dd.Value) or "-"
        end
    end

    local buttons = {}
    local function fire()
        display()
        SafeCall(cfg.Callback, dd.Value)
        for _, fn in ipairs(dd.Changed) do SafeCall(fn, dd.Value) end
    end
    local function refresh()
        for v, b in pairs(buttons) do
            local selected = dd.Multi and dd.Value[v] or dd.Value == v
            b.TextColor3 = selected and T.Accent or T.Text
        end
    end
    local function build()
        for _, b in pairs(buttons) do b:Destroy() end
        buttons = {}
        for _, v in ipairs(dd.Values) do
            local b = New("TextButton", {
                BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Text = tostring(v),
                TextColor3 = T.Text, Font = Enum.Font.Gotham, TextSize = 13, Parent = list,
            })
            buttons[v] = b
            Connect(b.MouseButton1Click, function()
                if dd.Multi then dd.Value[v] = not dd.Value[v] or nil
                else dd.Value = v; list.Visible = false end
                refresh(); fire()
            end)
        end
        refresh(); display()
    end

    function dd:SetValue(v, silent)
        if self.Multi then
            self.Value = {}
            for _, k in ipairs(v or {}) do self.Value[k] = true end
        else self.Value = v end
        refresh(); display()
        if not silent then fire() end
    end
    function dd:SetValues(values) self.Values = values; build() end
    function dd:OnChanged(fn) table.insert(self.Changed, fn) end

    Connect(head.MouseButton1Click, function() list.Visible = not list.Visible end)
    build()
    Library.Options[idx] = dd
    return dd
end

----------------------------------------------------------------
-- Tab
----------------------------------------------------------------
local Tab = {}
Tab.__index = Tab

local function NewGroupbox(column, name, icon)
    local T = Library.Theme
    local frame = New("Frame", {
        BackgroundColor3 = T.Group, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = column,
    }, { Corner(8), Stroke(T.Outline), New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }) })

    local header = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 1, Parent = frame }, {
        Pad(10, 0, 10, 0),
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 6),
        }),
    })
    if icon then MakeIcon(header, icon, 15, T.Accent) end
    New("TextLabel", {
        BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
        Text = name, TextColor3 = T.Text, Font = Enum.Font.GothamBold, TextSize = 14, Parent = header,
    })
    New("Frame", { BackgroundColor3 = T.Outline, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), LayoutOrder = 2, Parent = frame })

    local container = New("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 3, Parent = frame,
    }, { Pad(10, 8, 10, 10), New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

    return setmetatable({ Frame = frame, Container = container }, Groupbox)
end

function Tab:AddLeftGroupbox(name, icon)  return NewGroupbox(self.Left, name, icon) end
function Tab:AddRightGroupbox(name, icon) return NewGroupbox(self.Right, name, icon) end

----------------------------------------------------------------
-- Window
----------------------------------------------------------------
function Library:CreateWindow(cfg)
    cfg = cfg or {}
    local T = self.Theme
    local Window = { Tabs = {}, Active = nil }

    local gui = New("ScreenGui", {
        Name = "LucidUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 999, Parent = GetGuiParent(),
    })
    self.Gui = gui

    local size = cfg.Size or UDim2.fromOffset(680, 440)
    local main = New("Frame", {
        BackgroundColor3 = T.Background, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = size, ClipsDescendants = true, Parent = gui,
    }, { Corner(10), Stroke(T.Outline) })

    -- Topbar
    local top = New("Frame", { BackgroundColor3 = T.Sidebar, Size = UDim2.new(1, 0, 0, 38), Parent = main }, {
        Pad(12, 0, 8, 0),
        New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8) }),
    })
    if cfg.Icon then MakeIcon(top, cfg.Icon, 18, T.Accent) end
    New("TextLabel", {
        BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
        Text = cfg.Title or "LucidUI", TextColor3 = T.Text, Font = Enum.Font.GothamBold, TextSize = 15, Parent = top,
    })
    if cfg.Footer then
        New("TextLabel", {
            BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
            Text = cfg.Footer, TextColor3 = T.SubText, Font = Enum.Font.Gotham, TextSize = 12, Parent = top,
        })
    end

    -- Dragging
    local dragging, dragStart, startPos
    Connect(top.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, i.Position, main.Position
        end
    end)
    Connect(UserInputService.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    Connect(UserInputService.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)

    -- Sidebar
    local sidebar = New("ScrollingFrame", {
        BackgroundColor3 = T.Sidebar, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 38),
        Size = UDim2.new(0, 150, 1, -38), ScrollBarThickness = 0, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = main,
    }, { Pad(8, 8, 8, 8), New("UIListLayout", { Padding = UDim.new(0, 4) }) })

    local pages = New("Frame", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(150, 38), Size = UDim2.new(1, -150, 1, -38), Parent = main,
    }, { Pad(10, 10, 10, 10) })

    function Window:AddTab(name, icon)
        local tab = setmetatable({ Name = name }, Tab)

        local btn = New("TextButton", {
            BackgroundColor3 = T.Element, BackgroundTransparency = 1, AutoButtonColor = false, Text = "",
            Size = UDim2.new(1, 0, 0, 32), Parent = sidebar,
        }, { Corner(6), Pad(10, 0, 10, 0),
            New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8) }) })
        local ico = icon and MakeIcon(btn, icon, 16, T.SubText)
        local lbl = New("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.new(1, -26, 1, 0), Text = name, TextColor3 = T.SubText,
            Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = btn,
        })

        local page = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = pages })
        local function column(pos, sz)
            return New("ScrollingFrame", {
                BackgroundTransparency = 1, BorderSizePixel = 0, Position = pos, Size = sz, ScrollBarThickness = 2,
                ScrollBarImageColor3 = T.Outline, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = page,
            }, { New("UIListLayout", { Padding = UDim.new(0, 10) }), Pad(0, 0, 4, 0) })
        end
        tab.Left  = column(UDim2.fromScale(0, 0), UDim2.new(0.5, -5, 1, 0))
        tab.Right = column(UDim2.new(0.5, 5, 0, 0), UDim2.new(0.5, -5, 1, 0))
        tab.Page = page

        function tab:Select()
            for _, t in ipairs(Window.Tabs) do
                t.Page.Visible = false
                Tween(t.Button, { BackgroundTransparency = 1 })
                t.Label.TextColor3 = T.SubText
                if t.IconImg then t.IconImg.ImageColor3 = T.SubText end
            end
            page.Visible = true
            Tween(btn, { BackgroundTransparency = 0 })
            lbl.TextColor3 = T.Text
            if ico then ico.ImageColor3 = T.Accent end
            Window.Active = tab
        end
        tab.Button, tab.Label, tab.IconImg = btn, lbl, ico

        Connect(btn.MouseButton1Click, function() tab:Select() end)
        table.insert(Window.Tabs, tab)
        if #Window.Tabs == 1 then tab:Select() end
        return tab
    end

    function Window:Toggle(state)
        if state == nil then state = not main.Visible end
        main.Visible = state
    end

    -- UI ein-/ausblenden
    local toggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift
    Connect(UserInputService.InputBegan, function(i, gpe)
        if not gpe and i.KeyCode == toggleKey then Window:Toggle() end
    end)

    function Window:Unload() Library:Unload() end
    self.Window = Window
    return Window
end

----------------------------------------------------------------
-- Notify & Unload
----------------------------------------------------------------
function Library:Notify(text, duration, icon)
    if not self.Gui then return end
    local T = self.Theme
    if not self.NotifyHolder then
        self.NotifyHolder = New("Frame", {
            BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16),
            Size = UDim2.fromOffset(260, 300), Parent = self.Gui,
        }, { New("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 6) }) })
    end
    local n = New("Frame", {
        BackgroundColor3 = T.Group, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = self.NotifyHolder,
    }, { Corner(8), Stroke(T.Accent), Pad(10, 8, 10, 8),
        New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8) }) })
    if icon then MakeIcon(n, icon, 16, T.Accent) end
    New("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, icon and -24 or 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        Text = text, TextWrapped = true, TextColor3 = T.Text, Font = Enum.Font.Gotham, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = n,
    })
    task.delay(duration or 4, function() if n then n:Destroy() end end)
end

function Library:Unload()
    for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
    self.Connections = {}
    if self.Gui then self.Gui:Destroy() end
    self.Gui, self.NotifyHolder = nil, nil
end

return Library
