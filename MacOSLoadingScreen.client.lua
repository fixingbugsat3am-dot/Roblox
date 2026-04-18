--!strict
-- MacOS-inspired mobile-friendly loading screen + floating button panel
-- Place this LocalScript inside StarterPlayerScripts (or StarterGui) in Roblox Studio.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Cleanup existing copy if re-running in Studio.
local existing = playerGui:FindFirstChild("MacOSUi")
if existing then
	existing:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "MacOSUi"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function applyCorner(parent: Instance, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = parent
	return corner
end

local function applyStroke(parent: Instance, transparency: number)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Transparency = transparency
	stroke.Color = Color3.fromRGB(245, 245, 247)
	stroke.Parent = parent
	return stroke
end

local palette = {
	background = Color3.fromRGB(15, 16, 22),
	surface = Color3.fromRGB(30, 32, 42),
	surfaceSoft = Color3.fromRGB(38, 41, 53),
	text = Color3.fromRGB(244, 244, 248),
	subtext = Color3.fromRGB(190, 193, 204),
	accent = Color3.fromRGB(10, 132, 255), -- macOS-like system blue
	accentSoft = Color3.fromRGB(100, 190, 255),
	shadow = Color3.fromRGB(5, 5, 7),
}

-- Background layer
local bg = Instance.new("Frame")
bg.Name = "Background"
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = palette.background
bg.BorderSizePixel = 0
bg.Parent = gui

local bgGradient = Instance.new("UIGradient")
bgGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 24, 33)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 9, 14)),
})
bgGradient.Rotation = 130
bgGradient.Parent = bg

-- Floating subtle noise-like overlay (soft visual depth)
local overlay = Instance.new("Frame")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
overlay.BackgroundTransparency = 0.96
overlay.BorderSizePixel = 0
overlay.Parent = bg

-- Central loading card
local card = Instance.new("Frame")
card.Name = "LoadingCard"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.fromScale(0.74, 0.36)
card.BackgroundColor3 = palette.surface
card.BackgroundTransparency = 0.15
card.BorderSizePixel = 0
card.Parent = bg
applyCorner(card, UDim.new(0, 24))
applyStroke(card, 0.6)

local cardMax = Instance.new("UISizeConstraint")
cardMax.MaxSize = Vector2.new(720, 320)
cardMax.MinSize = Vector2.new(280, 190)
cardMax.Parent = card

local shadow = Instance.new("ImageLabel")
shadow.Name = "Shadow"
shadow.AnchorPoint = Vector2.new(0.5, 0.5)
shadow.Position = UDim2.fromScale(0.5, 0.52)
shadow.Size = UDim2.fromScale(1.03, 1.03)
shadow.BackgroundTransparency = 1
shadow.Image = "rbxassetid://1316045217"
shadow.ImageColor3 = palette.shadow
shadow.ImageTransparency = 0.55
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(10, 10, 118, 118)
shadow.ZIndex = card.ZIndex - 1
shadow.Parent = card

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, -24, 0, 26)
topBar.Position = UDim2.new(0, 12, 0, 12)
topBar.BackgroundTransparency = 1
topBar.Parent = card

local dots = {Color3.fromRGB(255, 95, 87), Color3.fromRGB(255, 189, 46), Color3.fromRGB(40, 201, 64)}
for i, color in ipairs(dots) do
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(11, 11)
	dot.Position = UDim2.new(0, (i - 1) * 18, 0.5, -6)
	dot.BackgroundColor3 = color
	dot.BorderSizePixel = 0
	dot.Parent = topBar
	applyCorner(dot, UDim.new(1, 0))
end

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -16, 0, 34)
title.Position = UDim2.new(0, 8, 0.2, 10)
title.BackgroundTransparency = 1
title.Text = "Launching Experience"
title.TextColor3 = palette.text
title.TextScaled = true
title.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
title.Parent = card

local titleConstraint = Instance.new("UITextSizeConstraint")
titleConstraint.MaxTextSize = 34
titleConstraint.MinTextSize = 16
titleConstraint.Parent = title

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -32, 0, 24)
subtitle.Position = UDim2.new(0, 16, 0.45, -4)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Optimizing assets for your device..."
subtitle.TextColor3 = palette.subtext
subtitle.TextScaled = true
subtitle.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular)
subtitle.Parent = card

local subtitleConstraint = Instance.new("UITextSizeConstraint")
subtitleConstraint.MaxTextSize = 20
subtitleConstraint.MinTextSize = 12
subtitleConstraint.Parent = subtitle

local progressTrack = Instance.new("Frame")
progressTrack.Size = UDim2.new(1, -40, 0, 14)
progressTrack.Position = UDim2.new(0, 20, 1, -50)
progressTrack.BackgroundColor3 = palette.surfaceSoft
progressTrack.BorderSizePixel = 0
progressTrack.Parent = card
applyCorner(progressTrack, UDim.new(1, 0))

local progressFill = Instance.new("Frame")
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = palette.accent
progressFill.BorderSizePixel = 0
progressFill.Parent = progressTrack
applyCorner(progressFill, UDim.new(1, 0))

local fillGradient = Instance.new("UIGradient")
fillGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, palette.accentSoft),
	ColorSequenceKeypoint.new(1, palette.accent),
})
fillGradient.Parent = progressFill

local percentLabel = Instance.new("TextLabel")
percentLabel.Size = UDim2.new(1, -40, 0, 18)
percentLabel.Position = UDim2.new(0, 20, 1, -72)
percentLabel.BackgroundTransparency = 1
percentLabel.Text = "0%"
percentLabel.TextXAlignment = Enum.TextXAlignment.Right
percentLabel.TextColor3 = palette.subtext
percentLabel.TextScaled = true
percentLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
percentLabel.Parent = card

local percentConstraint = Instance.new("UITextSizeConstraint")
percentConstraint.MaxTextSize = 16
percentConstraint.MinTextSize = 10
percentConstraint.Parent = percentLabel

-- Floating button + collapsible frame (mobile-safe hit area)
local dockButton = Instance.new("TextButton")
dockButton.Name = "DockButton"
dockButton.AnchorPoint = Vector2.new(1, 1)
dockButton.Position = UDim2.new(1, -18, 1, -18)
dockButton.Size = UDim2.fromOffset(58, 58)
dockButton.AutoButtonColor = false
dockButton.Text = "≡"
dockButton.TextColor3 = palette.text
dockButton.TextScaled = true
dockButton.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
dockButton.BackgroundColor3 = palette.surface
dockButton.BackgroundTransparency = 0.2
dockButton.BorderSizePixel = 0
dockButton.Parent = bg
applyCorner(dockButton, UDim.new(1, 0))
applyStroke(dockButton, 0.55)

local btnConstraint = Instance.new("UISizeConstraint")
btnConstraint.MinSize = Vector2.new(52, 52)
btnConstraint.MaxSize = Vector2.new(64, 64)
btnConstraint.Parent = dockButton

local panel = Instance.new("Frame")
panel.Name = "QuickPanel"
panel.AnchorPoint = Vector2.new(1, 1)
panel.Position = UDim2.new(1, -18, 1, -86)
panel.Size = UDim2.fromOffset(260, 0)
panel.BackgroundColor3 = palette.surface
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Parent = bg
applyCorner(panel, UDim.new(0, 18))
applyStroke(panel, 0.6)

local panelConstraint = Instance.new("UISizeConstraint")
panelConstraint.MaxSize = Vector2.new(300, 210)
panelConstraint.MinSize = Vector2.new(220, 0)
panelConstraint.Parent = panel

local panelPadding = Instance.new("UIPadding")
panelPadding.PaddingLeft = UDim.new(0, 14)
panelPadding.PaddingRight = UDim.new(0, 14)
panelPadding.PaddingTop = UDim.new(0, 12)
panelPadding.PaddingBottom = UDim.new(0, 12)
panelPadding.Parent = panel

local panelList = Instance.new("UIListLayout")
panelList.Padding = UDim.new(0, 8)
panelList.FillDirection = Enum.FillDirection.Vertical
panelList.HorizontalAlignment = Enum.HorizontalAlignment.Left
panelList.VerticalAlignment = Enum.VerticalAlignment.Top
panelList.Parent = panel

local function buildPanelRow(text: string)
	local row = Instance.new("TextLabel")
	row.Size = UDim2.new(1, 0, 0, 28)
	row.BackgroundTransparency = 0.75
	row.BackgroundColor3 = palette.surfaceSoft
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.Text = "   " .. text
	row.TextColor3 = palette.text
	row.TextScaled = true
	row.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
	row.BorderSizePixel = 0
	row.Parent = panel
	applyCorner(row, UDim.new(0, 10))

	local rowConstraint = Instance.new("UITextSizeConstraint")
	rowConstraint.MaxTextSize = 16
	rowConstraint.MinTextSize = 11
	rowConstraint.Parent = row
end

buildPanelRow("System Status: Ready")
buildPanelRow("Graphics: Auto")
buildPanelRow("Touch Controls: Enabled")
buildPanelRow("Audio: Spatial")

local panelOpen = false
local panelOpenTween = TweenService:Create(panel, TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
	Size = UDim2.fromOffset(260, 176),
})
local panelCloseTween = TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
	Size = UDim2.fromOffset(260, 0),
})

local buttonDownTween = TweenService:Create(dockButton, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
	Size = UDim2.fromOffset(54, 54),
})
local buttonUpTween = TweenService:Create(dockButton, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
	Size = UDim2.fromOffset(58, 58),
})

dockButton.Activated:Connect(function()
	buttonDownTween:Play()
	task.delay(0.08, function()
		buttonUpTween:Play()
	end)

	panelOpen = not panelOpen
	if panelOpen then
		panelOpenTween:Play()
	else
		panelCloseTween:Play()
	end
end)

-- Loading simulation (replace with your own game-loading logic if needed)
local progress = 0
local totalDuration = 3.8
local elapsed = 0

local heartbeatConnection: RBXScriptConnection?
heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	progress = math.clamp(elapsed / totalDuration, 0, 1)

	local easedProgress = 1 - (1 - progress) ^ 2
	progressFill.Size = UDim2.new(easedProgress, 0, 1, 0)
	percentLabel.Text = string.format("%d%%", math.floor(easedProgress * 100 + 0.5))

	if progress >= 1 then
		if heartbeatConnection then
			heartbeatConnection:Disconnect()
			heartbeatConnection = nil
		end

		subtitle.Text = "Loading complete"
		task.wait(0.4)

		local fade = TweenService:Create(bg, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		})
		fade:Play()

		local descendants = gui:GetDescendants()
		for _, item in ipairs(descendants) do
			if item:IsA("GuiObject") then
				TweenService:Create(item, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play()
			end
			if item:IsA("TextLabel") or item:IsA("TextButton") then
				TweenService:Create(item, TweenInfo.new(0.35), {TextTransparency = 1}):Play()
			end
			if item:IsA("UIStroke") then
				TweenService:Create(item, TweenInfo.new(0.35), {Transparency = 1}):Play()
			end
			if item:IsA("ImageLabel") then
				TweenService:Create(item, TweenInfo.new(0.35), {ImageTransparency = 1}):Play()
			end
		end

		task.wait(0.45)
		gui:Destroy()
	end
end)
