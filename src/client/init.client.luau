--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlayerUIServiceClient = require(ReplicatedStorage.Services.PlayerUI.PlayerUIServiceClient)
local _ProjectileServiceClient = require(ReplicatedStorage.Services.Projectile.ProjectileServiceClient)
local WorldServiceClient = require(ReplicatedStorage.Services.World.WorldServiceClient)
local WardrobeViewport = require(ReplicatedStorage.Viewports.WardrobeViewport)

local LOCAL_PLAYER = Players.LocalPlayer
local PLAYER_LIGHT_NAME = "PlayerVisionLight"
local LoadingScreenGui: ScreenGui?
local LoadingStatusLabel: TextLabel?
local LoadingProgressFill: Frame?
local LoadingPulseA: Frame?
local LoadingPulseB: Frame?
local LoadingSpin: Frame?
local LoadingConnection: RBXScriptConnection?
local HasCompletedInitialLoad = false
local LastLoadingStatusText = ""

local function bindLoadingScreenReferences(gui: ScreenGui): ()
	LoadingScreenGui = gui

	local panel = gui:FindFirstChild("Background")
		and gui.Background:FindFirstChild("Panel")
	if panel and panel:IsA("Frame") then
		local status = panel:FindFirstChild("Status")
		local pulseA = panel:FindFirstChild("PulseA")
		local pulseB = panel:FindFirstChild("PulseB")
		local ring = panel:FindFirstChild("SpinnerRing")
		local progressRail = panel:FindFirstChild("ProgressRail")
		local progressFill = if progressRail and progressRail:IsA("Frame")
			then progressRail:FindFirstChild("ProgressFill")
			else nil

		LoadingStatusLabel = if status and status:IsA("TextLabel") then status else nil
		LoadingPulseA = if pulseA and pulseA:IsA("Frame") then pulseA else nil
		LoadingPulseB = if pulseB and pulseB:IsA("Frame") then pulseB else nil
		LoadingSpin = if ring and ring:IsA("Frame") then ring else nil
		LoadingProgressFill = if progressFill and progressFill:IsA("Frame") then progressFill else nil
	end
end

local function createCorner(parent: Instance, radius: number): ()
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function createStroke(parent: Instance, color: Color3, transparency: number, thickness: number): ()
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency
	stroke.Thickness = thickness
	stroke.Parent = parent
end

local function createLoadingScreen(): ScreenGui
	local playerGui = LOCAL_PLAYER:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild("WorldLoadingScreen")
	if existing and existing:IsA("ScreenGui") then
		existing.ResetOnSpawn = false
		existing.IgnoreGuiInset = true
		existing.DisplayOrder = 1000
		bindLoadingScreenReferences(existing)
		return existing
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "WorldLoadingScreen"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 1000
	gui.Parent = playerGui

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.BackgroundColor3 = Color3.fromRGB(9, 12, 18)
	background.BorderSizePixel = 0
	background.Size = UDim2.fromScale(1, 1)
	background.Parent = gui

	local backgroundGradient = Instance.new("UIGradient")
	backgroundGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(7, 11, 18)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(17, 25, 39)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 26, 18)),
	})
	backgroundGradient.Rotation = 25
	backgroundGradient.Parent = background

	local glowTop = Instance.new("Frame")
	glowTop.Name = "GlowTop"
	glowTop.AnchorPoint = Vector2.new(0.5, 0.5)
	glowTop.BackgroundColor3 = Color3.fromRGB(85, 154, 255)
	glowTop.BackgroundTransparency = 0.78
	glowTop.BorderSizePixel = 0
	glowTop.Position = UDim2.fromScale(0.2, 0.18)
	glowTop.Size = UDim2.fromOffset(360, 360)
	glowTop.Parent = background
	createCorner(glowTop, 180)

	local glowBottom = Instance.new("Frame")
	glowBottom.Name = "GlowBottom"
	glowBottom.AnchorPoint = Vector2.new(0.5, 0.5)
	glowBottom.BackgroundColor3 = Color3.fromRGB(255, 170, 84)
	glowBottom.BackgroundTransparency = 0.82
	glowBottom.BorderSizePixel = 0
	glowBottom.Position = UDim2.fromScale(0.82, 0.78)
	glowBottom.Size = UDim2.fromOffset(420, 420)
	glowBottom.Parent = background
	createCorner(glowBottom, 210)

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = Color3.fromRGB(18, 24, 34)
	panel.BackgroundTransparency = 0.16
	panel.BorderSizePixel = 0
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0, 520, 0, 280)
	panel.Parent = background
	createCorner(panel, 24)
	createStroke(panel, Color3.fromRGB(198, 157, 94), 0.28, 1.2)

	local panelGradient = Instance.new("UIGradient")
	panelGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(21, 28, 39)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(16, 22, 31)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(33, 24, 20)),
	})
	panelGradient.Rotation = 90
	panelGradient.Parent = panel

	local ring = Instance.new("Frame")
	ring.Name = "SpinnerRing"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.BackgroundTransparency = 1
	ring.Position = UDim2.new(0.5, 0, 0, 70)
	ring.Size = UDim2.fromOffset(88, 88)
	ring.Parent = panel

	local ringStroke = Instance.new("UIStroke")
	ringStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ringStroke.Color = Color3.fromRGB(243, 208, 144)
	ringStroke.Transparency = 0.08
	ringStroke.Thickness = 3
	ringStroke.Parent = ring

	local ringCorner = Instance.new("UICorner")
	ringCorner.CornerRadius = UDim.new(1, 0)
	ringCorner.Parent = ring

	local ringFade = Instance.new("UIGradient")
	ringFade.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(245, 222, 172)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(245, 222, 172)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(66, 82, 110)),
	})
	ringFade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.02),
		NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(1, 0.74),
	})
	ringFade.Parent = ring
	LoadingSpin = ring

	local pulseA = Instance.new("Frame")
	pulseA.Name = "PulseA"
	pulseA.AnchorPoint = Vector2.new(0.5, 0.5)
	pulseA.BackgroundColor3 = Color3.fromRGB(116, 179, 255)
	pulseA.BackgroundTransparency = 0.84
	pulseA.BorderSizePixel = 0
	pulseA.Position = UDim2.new(0.5, 0, 0, 70)
	pulseA.Size = UDim2.fromOffset(110, 110)
	pulseA.Parent = panel
	createCorner(pulseA, 55)

	local pulseB = Instance.new("Frame")
	pulseB.Name = "PulseB"
	pulseB.AnchorPoint = Vector2.new(0.5, 0.5)
	pulseB.BackgroundColor3 = Color3.fromRGB(255, 179, 90)
	pulseB.BackgroundTransparency = 0.88
	pulseB.BorderSizePixel = 0
	pulseB.Position = UDim2.new(0.5, 0, 0, 70)
	pulseB.Size = UDim2.fromOffset(136, 136)
	pulseB.Parent = panel
	createCorner(pulseB, 68)

	local overline = Instance.new("TextLabel")
	overline.Name = "Overline"
	overline.BackgroundTransparency = 1
	overline.Position = UDim2.new(0, 36, 0, 124)
	overline.Size = UDim2.new(1, -72, 0, 18)
	overline.Font = Enum.Font.GothamBold
	overline.Text = "WARDROBE TRANSFER"
	overline.TextColor3 = Color3.fromRGB(241, 194, 121)
	overline.TextSize = 13
	overline.TextXAlignment = Enum.TextXAlignment.Center
	overline.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 36, 0, 144)
	title.Size = UDim2.new(1, -72, 0, 42)
	title.Font = Enum.Font.GothamBlack
	title.Text = "Preparing Camp"
	title.TextColor3 = Color3.fromRGB(247, 239, 221)
	title.TextSize = 32
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Parent = panel

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.new(0, 48, 0, 188)
	subtitle.Size = UDim2.new(1, -96, 0, 38)
	subtitle.Font = Enum.Font.Gotham
	subtitle.Text = "Streaming terrain, dressing the camp, and staging your loadout."
	subtitle.TextColor3 = Color3.fromRGB(183, 195, 212)
	subtitle.TextSize = 15
	subtitle.TextWrapped = true
	subtitle.TextXAlignment = Enum.TextXAlignment.Center
	subtitle.Parent = panel

	local progressRail = Instance.new("Frame")
	progressRail.Name = "ProgressRail"
	progressRail.AnchorPoint = Vector2.new(0.5, 0)
	progressRail.BackgroundColor3 = Color3.fromRGB(28, 35, 47)
	progressRail.BorderSizePixel = 0
	progressRail.Position = UDim2.new(0.5, 0, 0, 232)
	progressRail.Size = UDim2.new(0, 380, 0, 12)
	progressRail.Parent = panel
	createCorner(progressRail, 999)

	local progressFill = Instance.new("Frame")
	progressFill.Name = "ProgressFill"
	progressFill.BackgroundColor3 = Color3.fromRGB(240, 200, 120)
	progressFill.BorderSizePixel = 0
	progressFill.Size = UDim2.fromScale(0.08, 1)
	progressFill.Parent = progressRail
	createCorner(progressFill, 999)

	local fillGradient = Instance.new("UIGradient")
	fillGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(98, 172, 255)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(242, 212, 138)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 168, 88)),
	})
	fillGradient.Parent = progressFill

	local progressSheen = Instance.new("Frame")
	progressSheen.Name = "Sheen"
	progressSheen.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	progressSheen.BackgroundTransparency = 0.7
	progressSheen.BorderSizePixel = 0
	progressSheen.Position = UDim2.fromScale(0.72, 0)
	progressSheen.Size = UDim2.fromOffset(36, 12)
	progressSheen.Rotation = 18
	progressSheen.Parent = progressFill
	createCorner(progressSheen, 999)

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Position = UDim2.new(0, 36, 0, 248)
	status.Size = UDim2.new(1, -72, 0, 18)
	status.Font = Enum.Font.Code
	status.Text = "Establishing landing point"
	status.TextColor3 = Color3.fromRGB(213, 220, 229)
	status.TextSize = 14
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.Parent = panel

	LoadingStatusLabel = status
	LoadingProgressFill = progressFill
	LoadingPulseA = pulseA
	LoadingPulseB = pulseB
	LoadingSpin = ring
	bindLoadingScreenReferences(gui)

	return gui
end

local function setLoadingStatus(text: string): ()
	LastLoadingStatusText = text
	if LoadingStatusLabel then
		LoadingStatusLabel.Text = text
	end
end

local function getLoadingSnapshot(): (boolean, { [string]: any }, boolean)
	local startState = WorldServiceClient.GetStartState()
	local wardrobeReady = WardrobeViewport.IsInterfaceReady()
	local shouldHide = startState.WorldReady and (startState.MatchStarted == true or wardrobeReady)
	return shouldHide, startState, wardrobeReady
end

local function getTargetProgress(startState: { [string]: any }, wardrobeReady: boolean): number
	if not startState.WorldReady then
		if startState.WorldGenerating then
			return 0.56
		end
		return 0.28
	end

	if startState.MatchStarted == true then
		return 1
	end

	if wardrobeReady then
		return 1
	end

	return 0.82
end

local function getLoadingMessage(startState: { [string]: any }, wardrobeReady: boolean): string
	if not startState.WorldReady then
		if startState.WorldGenerating then
			return "Carving the island and streaming the camp"
		end
		return "Establishing landing point"
	end

	if startState.MatchStarted == true then
		return "Finalizing world handoff"
	end

	if not wardrobeReady then
		return "Dressing the camp wardrobe"
	end

	return "Opening camp"
end

local function ensureLoadingAnimationLoop(): ()
	if LoadingConnection then
		return
	end

	local progress = 0.08
	local shownAt = os.clock()

	LoadingConnection = RunService.RenderStepped:Connect(function(deltaTime: number)
		if not LoadingScreenGui or not LoadingScreenGui.Enabled then
			return
		end

		local _, startState, wardrobeReady = getLoadingSnapshot()
		local targetProgress = getTargetProgress(startState, wardrobeReady)
		progress += (targetProgress - progress) * math.clamp(deltaTime * 2.6, 0, 1)

		if LoadingProgressFill then
			LoadingProgressFill.Size = UDim2.fromScale(math.clamp(progress, 0.04, 1), 1)
		end

		local now = os.clock()
		local pulse = (math.sin((now - shownAt) * 2.1) + 1) * 0.5
		local pulseOffsetA = 112 + pulse * 24
		local pulseOffsetB = 136 + (1 - pulse) * 22

		if LoadingPulseA then
			LoadingPulseA.Size = UDim2.fromOffset(pulseOffsetA, pulseOffsetA)
			LoadingPulseA.BackgroundTransparency = 0.88 - pulse * 0.08
		end

		if LoadingPulseB then
			LoadingPulseB.Size = UDim2.fromOffset(pulseOffsetB, pulseOffsetB)
			LoadingPulseB.BackgroundTransparency = 0.91 - (1 - pulse) * 0.07
		end

		if LoadingSpin then
			LoadingSpin.Rotation = (LoadingSpin.Rotation + deltaTime * 110) % 360
		end

		local dotCount = math.floor((now * 1.8) % 4)
		local baseText = getLoadingMessage(startState, wardrobeReady)
		setLoadingStatus(baseText .. string.rep(".", dotCount))
	end)
end

local function setLoadingScreenVisible(visible: boolean): ()
	if not LoadingScreenGui then
		LoadingScreenGui = createLoadingScreen()
	end

	LoadingScreenGui.Enabled = visible
	if visible then
		ensureLoadingAnimationLoop()
	end
end

local function refreshLoadingScreen(): ()
	if HasCompletedInitialLoad then
		setLoadingScreenVisible(false)
		return
	end

	local shouldHide, startState, wardrobeReady = getLoadingSnapshot()
	setLoadingStatus(getLoadingMessage(startState, wardrobeReady))

	if shouldHide then
		HasCompletedInitialLoad = true
		setLoadingScreenVisible(false)
	else
		setLoadingScreenVisible(true)
	end
end

local function attachPlayerLight(character: Model)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	local existing = rootPart:FindFirstChild(PLAYER_LIGHT_NAME)
	if existing and existing:IsA("PointLight") then
		existing.Enabled = true
		return
	end

	local light = Instance.new("PointLight")
	light.Name = PLAYER_LIGHT_NAME
	light.Brightness = 1.6
	light.Range = 20
	light.Shadows = false
	light.Color = Color3.fromRGB(255, 244, 220)
	light.Parent = rootPart
end

LOCAL_PLAYER.CharacterAdded:Connect(function(character)
	task.defer(attachPlayerLight, character)
end)
if LOCAL_PLAYER.Character then
	task.defer(attachPlayerLight, LOCAL_PLAYER.Character)
end

setLoadingScreenVisible(true)
PlayerUIServiceClient.init()
WorldServiceClient.init()

WorldServiceClient.GetStartStateChangedSignal():Connect(refreshLoadingScreen)
WardrobeViewport.GetInterfaceReadyChangedSignal():Connect(refreshLoadingScreen)

task.defer(refreshLoadingScreen)
