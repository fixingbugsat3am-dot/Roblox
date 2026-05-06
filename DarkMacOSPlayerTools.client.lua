--!strict
-- Dark macOS Player Tools UI
-- Place this LocalScript in StarterPlayerScripts inside your own Roblox experience.
-- It uses only normal Roblox APIs; no executor-only functions are required.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local CustomFont = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium)

local FLY_SPEED_MAX = 1000
local MODIFIER_MAX = 250
local DEFAULT_FLY_SPEED = 120
local DEFAULT_WALK_SPEED = 16
local DEFAULT_JUMP_POWER = 50

local state = {
	flyEnabled = false,
	noclipEnabled = false,
	highlightEnabled = false,
	speedModifierEnabled = false,
	jumpModifierEnabled = false,
	flySpeed = DEFAULT_FLY_SPEED,
	walkSpeed = DEFAULT_WALK_SPEED,
	jumpPower = DEFAULT_JUMP_POWER,
}

local character: Model? = nil
local humanoid: Humanoid? = nil
local rootPart: BasePart? = nil
local flyVelocity: LinearVelocity? = nil
local flyAttachment: Attachment? = nil
local flyGyro: AlignOrientation? = nil
local flyGyroAttachment: Attachment? = nil
local renderConnection: RBXScriptConnection? = nil
local noclipConnection: RBXScriptConnection? = nil
local highlightFolder: Folder? = nil

local gui = Instance.new("ScreenGui")
gui.Name = "DarkMacOSPlayerTools"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = PlayerGui

local blur = Instance.new("BlurEffect")
blur.Name = "DarkMacOSToolsBlur"
blur.Size = 0
blur.Parent = Lighting

local function tween(instance: Instance, info: TweenInfo, goals: {[string]: any})
	local created = TweenService:Create(instance, info, goals)
	created:Play()
	return created
end

local function styleText(instance: TextLabel | TextButton, size: number, color: Color3?)
	instance.FontFace = CustomFont
	instance.TextSize = size
	instance.TextColor3 = color or Color3.fromRGB(242, 243, 247)
	instance.TextWrapped = true
end

local function round(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function stroke(parent: Instance, color: Color3, transparency: number, thickness: number?)
	local item = Instance.new("UIStroke")
	item.Color = color
	item.Transparency = transparency
	item.Thickness = thickness or 1
	item.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	item.Parent = parent
	return item
end

local function addGradient(parent: Instance, top: Color3, bottom: Color3)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, top),
		ColorSequenceKeypoint.new(1, bottom),
	})
	gradient.Rotation = 90
	gradient.Parent = parent
	return gradient
end

local function getCharacterParts()
	character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	humanoid = character:FindFirstChildOfClass("Humanoid")
	rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function applyMovementModifiers()
	if not humanoid then
		return
	end

	humanoid.WalkSpeed = if state.speedModifierEnabled then state.walkSpeed else DEFAULT_WALK_SPEED

	if humanoid.UseJumpPower then
		humanoid.JumpPower = if state.jumpModifierEnabled then state.jumpPower else DEFAULT_JUMP_POWER
	else
		humanoid.JumpHeight = if state.jumpModifierEnabled then math.max(1, state.jumpPower / 8) else 7.2
	end
end

local function destroyFlyForces()
	if flyVelocity then
		flyVelocity:Destroy()
		flyVelocity = nil
	end
	if flyAttachment then
		flyAttachment:Destroy()
		flyAttachment = nil
	end
	if flyGyro then
		flyGyro:Destroy()
		flyGyro = nil
	end
	if flyGyroAttachment then
		flyGyroAttachment:Destroy()
		flyGyroAttachment = nil
	end
	if humanoid then
		humanoid.PlatformStand = false
	end
end

local function ensureFlyForces()
	if not rootPart then
		return
	end
	if flyVelocity and flyAttachment and flyGyro and flyGyroAttachment then
		return
	end

	flyAttachment = Instance.new("Attachment")
	flyAttachment.Name = "DarkMacOSFlyAttachment"
	flyAttachment.Parent = rootPart

	flyVelocity = Instance.new("LinearVelocity")
	flyVelocity.Name = "DarkMacOSFlyVelocity"
	flyVelocity.Attachment0 = flyAttachment
	flyVelocity.MaxForce = math.huge
	flyVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	flyVelocity.VectorVelocity = Vector3.zero
	flyVelocity.Parent = rootPart

	flyGyroAttachment = Instance.new("Attachment")
	flyGyroAttachment.Name = "DarkMacOSFlyOrientationAttachment"
	flyGyroAttachment.Parent = rootPart

	flyGyro = Instance.new("AlignOrientation")
	flyGyro.Name = "DarkMacOSFlyOrientation"
	flyGyro.Attachment0 = flyGyroAttachment
	flyGyro.Mode = Enum.OrientationAlignmentMode.OneAttachment
	flyGyro.MaxTorque = math.huge
	flyGyro.Responsiveness = 18
	flyGyro.Parent = rootPart
end

local function getMoveVector(camera: Camera)
	local move = Vector3.zero
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		move += camera.CFrame.LookVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		move -= camera.CFrame.LookVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		move += camera.CFrame.RightVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		move -= camera.CFrame.RightVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.ButtonA) then
		move += Vector3.yAxis
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.ButtonB) then
		move -= Vector3.yAxis
	end

	if humanoid and humanoid.MoveDirection.Magnitude > 0 then
		move += humanoid.MoveDirection
	end

	return if move.Magnitude > 0 then move.Unit else Vector3.zero
end

local function updateFly()
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end

	if not state.flyEnabled then
		destroyFlyForces()
		return
	end

	getCharacterParts()
	ensureFlyForces()
	if humanoid then
		humanoid.PlatformStand = true
	end

	renderConnection = RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not state.flyEnabled or not camera or not rootPart or not flyVelocity or not flyGyro then
			return
		end

		local move = getMoveVector(camera)
		flyVelocity.VectorVelocity = move * state.flySpeed
		flyGyro.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + camera.CFrame.LookVector)
	end)
end

local function setNoclip(enabled: boolean)
	state.noclipEnabled = enabled
	if noclipConnection then
		noclipConnection:Disconnect()
		noclipConnection = nil
	end
	if not enabled then
		return
	end

	noclipConnection = RunService.Stepped:Connect(function()
		if not character then
			getCharacterParts()
		end
		if not character then
			return
		end
		for _, descendant in character:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CanCollide = false
			end
		end
	end)
end

local function clearHighlights()
	if highlightFolder then
		highlightFolder:Destroy()
		highlightFolder = nil
	end
end

local function addHighlightForPlayer(player: Player)
	if not highlightFolder or player == LocalPlayer then
		return
	end
	local targetCharacter = player.Character
	if not targetCharacter then
		return
	end

	local old = highlightFolder:FindFirstChild(player.Name)
	if old then
		old:Destroy()
	end

	local group = Instance.new("Folder")
	group.Name = player.Name
	group.Parent = highlightFolder

	local highlight = Instance.new("Highlight")
	highlight.Name = "PlayerHighlight"
	highlight.Adornee = targetCharacter
	highlight.FillColor = Color3.fromRGB(90, 180, 255)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.6
	highlight.OutlineTransparency = 0.05
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = group

	local head = targetCharacter:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local nameTag = Instance.new("BillboardGui")
		nameTag.Name = "PlayerNameTag"
		nameTag.Adornee = head
		nameTag.AlwaysOnTop = true
		nameTag.Size = UDim2.fromOffset(180, 42)
		nameTag.StudsOffset = Vector3.new(0, 2.8, 0)
		nameTag.Parent = group

		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Text = player.DisplayName .. " (@" .. player.Name .. ")"
		styleText(text, 15, Color3.fromRGB(255, 255, 255))
		text.TextStrokeTransparency = 0.35
		text.Parent = nameTag
	end
end

local function refreshHighlights()
	clearHighlights()
	if not state.highlightEnabled then
		return
	end
	highlightFolder = Instance.new("Folder")
	highlightFolder.Name = "DarkMacOSPlayerHighlights"
	highlightFolder.Parent = gui
	for _, player in Players:GetPlayers() do
		addHighlightForPlayer(player)
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.4)
		if state.highlightEnabled then
			addHighlightForPlayer(player)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	if highlightFolder then
		local item = highlightFolder:FindFirstChild(player.Name)
		if item then
			item:Destroy()
		end
	end
end)

LocalPlayer.CharacterAdded:Connect(function()
	task.wait(0.25)
	getCharacterParts()
	applyMovementModifiers()
	if state.flyEnabled then
		updateFly()
	end
	if state.noclipEnabled then
		setNoclip(true)
	end
end)

for _, player in Players:GetPlayers() do
	if player ~= LocalPlayer then
		player.CharacterAdded:Connect(function()
			task.wait(0.4)
			if state.highlightEnabled then
				addHighlightForPlayer(player)
			end
		end)
	end
end

local loading = Instance.new("Frame")
loading.Name = "LoadingScreen"
loading.BackgroundColor3 = Color3.fromRGB(8, 9, 13)
loading.Size = UDim2.fromScale(1, 1)
loading.Parent = gui
addGradient(loading, Color3.fromRGB(15, 17, 27), Color3.fromRGB(4, 5, 8))

local loadingCard = Instance.new("Frame")
loadingCard.AnchorPoint = Vector2.new(0.5, 0.5)
loadingCard.Position = UDim2.fromScale(0.5, 0.5)
loadingCard.Size = UDim2.fromOffset(360, 190)
loadingCard.BackgroundColor3 = Color3.fromRGB(24, 25, 34)
loadingCard.Parent = loading
round(loadingCard, 24)
stroke(loadingCard, Color3.fromRGB(255, 255, 255), 0.86)

local loadingTitle = Instance.new("TextLabel")
loadingTitle.BackgroundTransparency = 1
loadingTitle.Position = UDim2.fromOffset(24, 24)
loadingTitle.Size = UDim2.new(1, -48, 0, 34)
loadingTitle.Text = "Searching tools..."
styleText(loadingTitle, 24)
loadingTitle.Parent = loadingCard

local loadingSubtitle = Instance.new("TextLabel")
loadingSubtitle.BackgroundTransparency = 1
loadingSubtitle.Position = UDim2.fromOffset(24, 64)
loadingSubtitle.Size = UDim2.new(1, -48, 0, 42)
loadingSubtitle.Text = "Building fly, noclip, ESP, speed, and jump controls"
styleText(loadingSubtitle, 14, Color3.fromRGB(166, 170, 185))
loadingSubtitle.Parent = loadingCard

local searchTrack = Instance.new("Frame")
searchTrack.Position = UDim2.fromOffset(24, 124)
searchTrack.Size = UDim2.new(1, -48, 0, 18)
searchTrack.BackgroundColor3 = Color3.fromRGB(38, 40, 52)
searchTrack.Parent = loadingCard
round(searchTrack, 99)

local searchFill = Instance.new("Frame")
searchFill.Size = UDim2.fromScale(0, 1)
searchFill.BackgroundColor3 = Color3.fromRGB(0, 122, 255)
searchFill.Parent = searchTrack
round(searchFill, 99)
addGradient(searchFill, Color3.fromRGB(77, 171, 255), Color3.fromRGB(155, 108, 255))

tween(blur, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = 14})
tween(loadingCard, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(390, 205)})
tween(searchFill, TweenInfo.new(2.2, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), {Size = UDim2.fromScale(1, 1)})

local window = Instance.new("Frame")
window.Name = "MacOSWindow"
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Position = UDim2.fromScale(0.5, 0.55)
window.Size = UDim2.fromScale(0.88, 0.78)
window.SizeConstraint = Enum.SizeConstraint.RelativeYY
window.BackgroundColor3 = Color3.fromRGB(21, 22, 30)
window.BackgroundTransparency = 0.03
window.Visible = false
window.Parent = gui
round(window, 22)
stroke(window, Color3.fromRGB(255, 255, 255), 0.87)
addGradient(window, Color3.fromRGB(33, 34, 44), Color3.fromRGB(14, 15, 21))

local scale = Instance.new("UIScale")
scale.Parent = window
local function updateScale()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	scale.Scale = math.clamp(math.min(viewport.X / 520, viewport.Y / 700), 0.72, 1)
end
updateScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

local titleBar = Instance.new("Frame")
titleBar.BackgroundTransparency = 1
titleBar.Size = UDim2.new(1, 0, 0, 54)
titleBar.Parent = window

local closeDot = Instance.new("Frame")
closeDot.Position = UDim2.fromOffset(18, 21)
closeDot.Size = UDim2.fromOffset(13, 13)
closeDot.BackgroundColor3 = Color3.fromRGB(255, 95, 86)
closeDot.Parent = titleBar
round(closeDot, 99)

local minDot = closeDot:Clone()
minDot.Position = UDim2.fromOffset(40, 21)
minDot.BackgroundColor3 = Color3.fromRGB(255, 189, 46)
minDot.Parent = titleBar

local zoomDot = closeDot:Clone()
zoomDot.Position = UDim2.fromOffset(62, 21)
zoomDot.BackgroundColor3 = Color3.fromRGB(39, 201, 63)
zoomDot.Parent = titleBar

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(92, 10)
title.Size = UDim2.new(1, -112, 0, 36)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Player Control Center"
styleText(title, 20)
title.Parent = titleBar

local content = Instance.new("ScrollingFrame")
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.Position = UDim2.fromOffset(18, 58)
content.Size = UDim2.new(1, -36, 1, -78)
content.ScrollBarThickness = 4
content.ScrollBarImageColor3 = Color3.fromRGB(80, 85, 110)
content.CanvasSize = UDim2.fromOffset(0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.Parent = window

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 12)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = content

local padding = Instance.new("UIPadding")
padding.PaddingBottom = UDim.new(0, 8)
padding.PaddingLeft = UDim.new(0, 2)
padding.PaddingRight = UDim.new(0, 2)
padding.Parent = content

local function makeCard(titleText: string, description: string)
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Color3.fromRGB(31, 33, 43)
	card.Size = UDim2.new(1, -4, 0, 86)
	card.Parent = content
	round(card, 18)
	stroke(card, Color3.fromRGB(255, 255, 255), 0.91)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(16, 10)
	label.Size = UDim2.new(1, -112, 0, 28)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = titleText
	styleText(label, 17)
	label.Parent = card

	local desc = Instance.new("TextLabel")
	desc.BackgroundTransparency = 1
	desc.Position = UDim2.fromOffset(16, 38)
	desc.Size = UDim2.new(1, -32, 0, 36)
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.Text = description
	styleText(desc, 13, Color3.fromRGB(156, 160, 176))
	desc.Parent = card

	return card
end

local function makeToggle(card: Frame, initial: boolean, callback: (boolean) -> ())
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, -16, 0, 18)
	button.Size = UDim2.fromOffset(58, 30)
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundColor3 = initial and Color3.fromRGB(0, 122, 255) or Color3.fromRGB(63, 66, 78)
	button.Parent = card
	round(button, 99)

	local knob = Instance.new("Frame")
	knob.Position = initial and UDim2.fromOffset(30, 4) or UDim2.fromOffset(4, 4)
	knob.Size = UDim2.fromOffset(22, 22)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.Parent = button
	round(knob, 99)

	local on = initial
	local function set(value: boolean)
		on = value
		tween(button, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			BackgroundColor3 = on and Color3.fromRGB(0, 122, 255) or Color3.fromRGB(63, 66, 78),
		})
		tween(knob, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = on and UDim2.fromOffset(30, 4) or UDim2.fromOffset(4, 4),
		})
		callback(on)
	end

	button.Activated:Connect(function()
		set(not on)
	end)

	return set
end

local function makeButton(card: Frame, label: string, callback: () -> ())
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, -16, 0, 16)
	button.Size = UDim2.fromOffset(94, 34)
	button.AutoButtonColor = false
	button.BackgroundColor3 = Color3.fromRGB(0, 122, 255)
	button.Text = label
	styleText(button, 14)
	button.Parent = card
	round(button, 12)
	addGradient(button, Color3.fromRGB(41, 151, 255), Color3.fromRGB(92, 86, 255))

	button.Activated:Connect(function()
		tween(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(88, 31)})
		task.delay(0.1, function()
			tween(button, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(94, 34)})
		end)
		callback()
	end)

	return button
end

local function makeSlider(card: Frame, minValue: number, maxValue: number, value: number, callback: (number) -> ())
	card.Size = UDim2.new(1, -4, 0, 128)

	local valueLabel = Instance.new("TextLabel")
	valueLabel.AnchorPoint = Vector2.new(1, 0)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Position = UDim2.new(1, -18, 0, 76)
	valueLabel.Size = UDim2.fromOffset(68, 28)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	styleText(valueLabel, 14, Color3.fromRGB(205, 210, 225))
	valueLabel.Parent = card

	local track = Instance.new("Frame")
	track.Position = UDim2.fromOffset(18, 86)
	track.Size = UDim2.new(1, -104, 0, 12)
	track.BackgroundColor3 = Color3.fromRGB(50, 53, 66)
	track.Parent = card
	round(track, 99)

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromRGB(0, 122, 255)
	fill.Parent = track
	round(fill, 99)
	addGradient(fill, Color3.fromRGB(83, 178, 255), Color3.fromRGB(165, 102, 255))

	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(26, 26)
	knob.BackgroundColor3 = Color3.fromRGB(245, 246, 250)
	knob.Parent = track
	round(knob, 99)
	stroke(knob, Color3.fromRGB(0, 0, 0), 0.8)

	local dragging = false
	local currentValue = value

	local function setFromAlpha(alpha: number)
		alpha = math.clamp(alpha, 0, 1)
		currentValue = math.floor(minValue + (maxValue - minValue) * alpha + 0.5)
		valueLabel.Text = tostring(currentValue)
		tween(fill, TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.fromScale(alpha, 1)})
		tween(knob, TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = UDim2.fromScale(alpha, 0.5)})
		callback(currentValue)
	end

	local function inputToAlpha(input: InputObject)
		local left = track.AbsolutePosition.X
		local width = math.max(track.AbsoluteSize.X, 1)
		return (input.Position.X - left) / width
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromAlpha(inputToAlpha(input))
		end
	end)
	knob.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromAlpha(inputToAlpha(input))
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	setFromAlpha((value - minValue) / (maxValue - minValue))
	return function(newValue: number)
		setFromAlpha((newValue - minValue) / (maxValue - minValue))
	end
end

local flyCard = makeCard("Fly", "Toggle flight, then use WASD/mobile thumbstick to move, Space to rise, Ctrl/Button B to descend.")
makeToggle(flyCard, state.flyEnabled, function(value)
	state.flyEnabled = value
	updateFly()
end)

local flySliderCard = makeCard("Fly speed", "Maximum 1000 for very fast flight.")
makeSlider(flySliderCard, 0, FLY_SPEED_MAX, state.flySpeed, function(value)
	state.flySpeed = value
end)

local noclipCard = makeCard("Noclip", "Button toggles collision bypass for your character.")
local noclipButton: TextButton
noclipButton = makeButton(noclipCard, "Noclip OFF", function()
	setNoclip(not state.noclipEnabled)
	noclipButton.Text = state.noclipEnabled and "Noclip ON" or "Noclip OFF"
end)

local espCard = makeCard("Highlight players", "Shows every other player through walls with a name tag above their head.")
makeToggle(espCard, state.highlightEnabled, function(value)
	state.highlightEnabled = value
	refreshHighlights()
end)

local speedCard = makeCard("Speed modifier", "Toggle custom WalkSpeed.")
makeToggle(speedCard, state.speedModifierEnabled, function(value)
	state.speedModifierEnabled = value
	applyMovementModifiers()
end)

local speedSliderCard = makeCard("WalkSpeed value", "Maximum 250.")
makeSlider(speedSliderCard, 0, MODIFIER_MAX, state.walkSpeed, function(value)
	state.walkSpeed = math.max(0, value)
	applyMovementModifiers()
end)

local jumpCard = makeCard("Jump modifier", "Toggle custom JumpPower or JumpHeight, depending on your experience settings.")
makeToggle(jumpCard, state.jumpModifierEnabled, function(value)
	state.jumpModifierEnabled = value
	applyMovementModifiers()
end)

local jumpSliderCard = makeCard("Jump value", "Maximum 250.")
makeSlider(jumpSliderCard, 0, MODIFIER_MAX, state.jumpPower, function(value)
	state.jumpPower = math.max(0, value)
	applyMovementModifiers()
end)

local draggingWindow = false
local dragStart: Vector3? = nil
local startPosition: UDim2? = nil

titleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingWindow = true
		dragStart = input.Position
		startPosition = window.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if draggingWindow and dragStart and startPosition and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		window.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingWindow = false
	end
end)

task.delay(2.45, function()
	tween(loadingCard, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.fromOffset(330, 175)})
	tween(loading, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), {BackgroundTransparency = 1})
	task.wait(0.35)
	window.Visible = true
	window.Position = UDim2.fromScale(0.5, 0.58)
	window.Size = UDim2.fromScale(0.82, 0.72)
	tween(window, TweenInfo.new(0.75, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.88, 0.78),
	})
	tween(blur, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = 0})
	loading:Destroy()
end)

getCharacterParts()
applyMovementModifiers()
