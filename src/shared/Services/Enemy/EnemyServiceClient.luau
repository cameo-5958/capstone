--!strict
-- Mostly an utility module

-- Grab API endpoints
local API: RemoteEvent = script.Parent:WaitForChild("EnemyEndpoint")
local Handler: RemoteEvent = script.Parent:WaitForChild("EnemyHandler")

-- Require
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Entity = require(ReplicatedStorage.Classes.Entity.Entity)
local EntityTypes = require(ReplicatedStorage.Classes.Entity.EntityTypes)
local CombatNumbers = require(ReplicatedStorage.Modules.Combat.CombatNumbers)
type Entity = EntityTypes.Entity

local __Enemies: {
	[string]: Entity,
} = {}
local __EnemyTags: {
	[string]: BillboardGui,
} = {}
local __DamageIndicators: {
	[string]: {
		Gui: BillboardGui,
		Label: TextLabel,
		StartedAt: number,
		Duration: number,
		Direction: number,
		BaseOffset: Vector3,
		BaseTextSize: number,
		RotationAmplitude: number,
	},
} = {}
local __AttackPredictors: {
	[string]: {
		Part: Part,
		ChargeStartedAt: number,
		ChargeEndsAt: number,
		ClearAt: number,
	},
} = {}
local __LookTargets: {
	[string]: Vector3?,
} = {}
local __VelocityCancelTasks: {
	[string]: thread?,
} = {}
local __AttackHitboxes: {
	[string]: {
		Part: Part,
		ActiveFrom: number,
		ActiveUntil: number,
		ClearAt: number,
		HitboxSize: Vector3,
		HitboxOffset: CFrame,
	},
} = {}
local LOCAL_LINEAR_VELOCITY_NAME = "ClientLinearVelocity"
local DAMAGE_INDICATOR_DURATION = 0.7
local ClearAttackHitbox: (uuid: string) -> ()
local ClearAttackPredictor: (uuid: string) -> ()
local DestroyDamageIndicator: (indicatorId: string) -> ()

local function FormatStatValue(value: number?): string
	return CombatNumbers.FormatTenth(value)
end

local function GetEnemyDisplayLevel(ent: Entity): number
	if ent.Character then
		local attributeLevel = ent.Character:GetAttribute("EnemyLevel")
		if type(attributeLevel) == "number" then
			return attributeLevel
		end
	end

	local scaledLevel = ent.__ScaledLevel
	if type(scaledLevel) == "number" then
		return scaledLevel
	end

	return ent.Level or 1
end

local function GetTagAdornee(ent: Entity): Instance?
	if not ent.Character then
		return nil
	end

	local head = ent.Character:FindFirstChild("Head")
	if head then
		return head
	end

	return ent.RootPart
end

local function DestroyEnemyTag(uuid: string)
	local tag = __EnemyTags[uuid]
	if not tag then
		return
	end

	tag:Destroy()
	__EnemyTags[uuid] = nil
end

local function DestroyEnemyArtifacts(uuid: string)
	DestroyEnemyTag(uuid)
	ClearAttackHitbox(uuid)
	ClearAttackPredictor(uuid)
end

local function DestroyEnemyDamageIndicators(uuid: string)
	for indicatorId in pairs(__DamageIndicators) do
		if string.sub(indicatorId, 1, #uuid) == uuid then
			DestroyDamageIndicator(indicatorId)
		end
	end
end

function DestroyDamageIndicator(indicatorId: string)
	local indicator = __DamageIndicators[indicatorId]
	if not indicator then
		return
	end

	indicator.Gui:Destroy()
	__DamageIndicators[indicatorId] = nil
end

local function CreateTextLabel(name: string, size: UDim2, position: UDim2, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Size = size
	label.Position = position
	label.Font = Enum.Font.Code
	label.TextColor3 = Color3.fromRGB(0, 0, 0)
	label.TextSize = textSize
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	return label
end

local function CreateSeparator(name: string, y: number): Frame
	local separator = Instance.new("Frame")
	separator.Name = name
	separator.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	separator.BorderSizePixel = 0
	separator.Position = UDim2.fromOffset(0, y)
	separator.Size = UDim2.new(1, 0, 0, 2)
	return separator
end

local function EnsureEnemyTag(uuid: string, ent: Entity): BillboardGui?
	if not ent.Character or ent.Character.Parent == nil then
		DestroyEnemyTag(uuid)
		return nil
	end

	local adornee = GetTagAdornee(ent)
	if not adornee then
		DestroyEnemyTag(uuid)
		return nil
	end

	local existing = __EnemyTags[uuid]
	if existing and existing.Parent and existing.Adornee == adornee then
		return existing
	end

	if existing then
		existing:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EnemyTag"
	billboard.Size = UDim2.fromOffset(128, 18)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120
	billboard.Adornee = adornee
	billboard.Parent = adornee

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.BackgroundTransparency = 1
	container.Size = UDim2.fromScale(1, 1)
	container.Parent = billboard

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.fromScale(0.5, 0)
	panel.Size = UDim2.fromOffset(124, 18)
	panel.BackgroundTransparency = 1
	panel.BorderSizePixel = 0
	panel.Parent = container

	local title = CreateTextLabel("Title", UDim2.new(1, -2, 0, 7), UDim2.fromOffset(1, 0), 8)
	title.Parent = panel

	local titleSeparator = CreateSeparator("TitleSeparator", 7)
	titleSeparator.Size = UDim2.new(1, -2, 0, 1)
	titleSeparator.Position = UDim2.fromOffset(1, 7)
	titleSeparator.Parent = panel

	local healthText = CreateTextLabel("HealthText", UDim2.fromOffset(1, 1), UDim2.fromOffset(0, 0), 1)
	healthText.Visible = false
	healthText.Parent = panel

	local barBackground = Instance.new("Frame")
	barBackground.Name = "HealthBarBackground"
	barBackground.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	barBackground.BorderSizePixel = 0
	barBackground.Position = UDim2.fromOffset(2, 10)
	barBackground.Size = UDim2.fromOffset(120, 4)
	barBackground.Parent = panel

	local barFill = Instance.new("Frame")
	barFill.Name = "HealthBarFill"
	barFill.BackgroundColor3 = Color3.fromRGB(198, 58, 58)
	barFill.BorderSizePixel = 0
	barFill.Position = UDim2.fromOffset(1, 1)
	barFill.Size = UDim2.new(1, -2, 1, -2)
	barFill.Parent = barBackground

	__EnemyTags[uuid] = billboard
	return billboard
end

local function ShowDamageIndicator(uuid: string, ent: Entity, damage: number, isCrit: boolean?)
	local adornee = GetTagAdornee(ent)
	if not adornee then
		return
	end

	local indicatorId = ("%s:%0.6f"):format(uuid, workspace:GetServerTimeNow())
	local baseOffset = Vector3.new(math.random(-24, 24) / 20, 2.25 + (math.random(0, 10) / 20), math.random(-8, 8) / 20)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DamageIndicator"
	billboard.Adornee = adornee
	billboard.Size = UDim2.fromOffset(104, 40)
	billboard.StudsOffsetWorldSpace = baseOffset
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120
	billboard.Parent = adornee

	local label = Instance.new("TextLabel")
	label.Name = "Value"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Code
	label.Text = FormatStatValue(damage)
	label.TextColor3 = if isCrit then Color3.fromRGB(150, 84, 255) else Color3.fromRGB(185, 22, 22)
	label.TextStrokeTransparency = 0.4
	label.TextStrokeColor3 = Color3.fromRGB(255, 245, 245)
	label.TextSize = 24
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = billboard

	__DamageIndicators[indicatorId] = {
		Gui = billboard,
		Label = label,
		StartedAt = workspace:GetServerTimeNow(),
		Duration = DAMAGE_INDICATOR_DURATION,
		Direction = math.random(0, 1) == 0 and -1 or 1,
		BaseOffset = baseOffset,
		BaseTextSize = 24,
		RotationAmplitude = if isCrit then 11 else 4,
	}
end

local function UpdateEnemyTag(uuid: string, ent: Entity)
	local tag = EnsureEnemyTag(uuid, ent)
	if not tag then
		return
	end

	local container = tag:FindFirstChild("Container")
	if not container then
		return
	end

	local panel = container:FindFirstChild("Panel") :: Frame?
	if not panel then
		return
	end

	local title = panel:FindFirstChild("Title") :: TextLabel?
	local healthText = panel:FindFirstChild("HealthText") :: TextLabel?
	local healthBarBackground = panel:FindFirstChild("HealthBarBackground") :: Frame?
	local healthBarFill = healthBarBackground and healthBarBackground:FindFirstChild("HealthBarFill") :: Frame?
	if not title or not healthText or not healthBarBackground or not healthBarFill then
		return
	end

	local currentHealth = ent.__Stats.Health
	local maxHealth = ent.__Stats.MaxHealth
	local healthRatio = if maxHealth > 0 then math.clamp(currentHealth / maxHealth, 0, 1) else 0

	title.Text = ("[%s] %s"):format(FormatStatValue(GetEnemyDisplayLevel(ent)), ent.Name)
	healthBarFill.Visible = healthRatio > 0
	if healthRatio > 0 then
		healthBarFill.Size = UDim2.new(healthRatio, -2, 1, -2)
	end
end

local function IsEnemyAlive(ent: Entity?): boolean
	if not ent or not ent.Character or ent.Character.Parent == nil or not ent.RootPart then
		return false
	end

	local humanoid = ent.Character:FindFirstChild("Humanoid")
	if humanoid and humanoid:IsA("Humanoid") and humanoid.Health <= 0 then
		return false
	end

	return ent:IsAlive()
end

function ClearAttackHitbox(uuid: string)
	local state = __AttackHitboxes[uuid]
	if not state then
		return
	end

	state.Part:Destroy()
	__AttackHitboxes[uuid] = nil
end

function ClearAttackPredictor(uuid: string)
	local state = __AttackPredictors[uuid]
	if not state then
		return
	end

	state.Part:Destroy()
	__AttackPredictors[uuid] = nil
end

local function EnsureAttackHitbox(uuid: string): Part
	local existing = __AttackHitboxes[uuid]
	if existing and existing.Part.Parent then
		return existing.Part
	end

	local part = Instance.new("Part")
	part.Name = "EnemyAttackHitboxVisualizer"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.ForceField
	part.Color = Color3.fromRGB(255, 90, 90)
	part.Transparency = 0.82
	part.Parent = workspace

	return part
end

local function EnsureAttackPredictor(uuid: string): Part
	local existing = __AttackPredictors[uuid]
	if existing and existing.Part.Parent then
		return existing.Part
	end

	local part = Instance.new("Part")
	part.Name = "EnemyAttackPredictor"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromHSV(0, 0.2, 0.95)
	part.Transparency = 0.35
	part.Parent = workspace

	return part
end

local function CancelLinearVelocityVisual(uuid: string)
	local pending = __VelocityCancelTasks[uuid]
	if pending then
		task.cancel(pending)
		__VelocityCancelTasks[uuid] = nil
	end

	local ent = __Enemies[uuid]
	if not ent or not ent.Character or not ent.Character.PrimaryPart then
		return
	end

	local lv = ent.Character:FindFirstChild("LinearVelocity")
		or ent.Character:FindFirstChild(LOCAL_LINEAR_VELOCITY_NAME)
	if lv then
		lv:Destroy()
	end

	(ent.Character.PrimaryPart :: BasePart).AssemblyLinearVelocity = Vector3.zero
end

local function ApplyLinearVelocityVisual(uuid: string, velocity: Vector3, duration: number)
	local ent = __Enemies[uuid]
	if not ent or not ent.Character or not ent.Character.PrimaryPart then
		return
	end

	CancelLinearVelocityVisual(uuid)

	local rootPart = ent.Character.PrimaryPart :: BasePart
	local attachment = rootPart:FindFirstChild("RootAttachment") :: Attachment?
	if not attachment then
		return
	end

	local lv = Instance.new("LinearVelocity")
	lv.Name = LOCAL_LINEAR_VELOCITY_NAME
	lv.Attachment0 = attachment
	lv.VectorVelocity = velocity
	lv.MaxForce = 999999
	lv.Parent = ent.Character
	rootPart.AssemblyLinearVelocity = Vector3.zero

	__VelocityCancelTasks[uuid] = task.delay(duration, function()
		__VelocityCancelTasks[uuid] = nil
		CancelLinearVelocityVisual(uuid)
	end)
end

-- Public API
local Enemies = {}

-- API Handshakes
API.OnClientEvent:Connect(function(ds: { [string]: { [string]: Entity } })
	-- Delay the task to ensure that the models are all
	-- loaded in
	task.delay(0.5, function()
		if ds["Remove"] then
			for uuid in pairs(ds["Remove"]) do
				__Enemies[uuid] = nil
				DestroyEnemyArtifacts(uuid)
			end
		end

		-- Create
		for uuid, ent in pairs(ds["Create"] or {}) do
			-- Cast to Entity to give functionality back
			local inflated = Entity.Inflate(ent)
			__Enemies[uuid] = inflated
			UpdateEnemyTag(uuid, inflated)
		end
	end)
end)

-- Find closest
function Enemies.GetClosest(pos: Vector3, sight: number?)
	local closest = ""
	local closestDistance = sight or 64

	for uuid, ent in pairs(__Enemies) do
		if not IsEnemyAlive(ent) then
			continue
		end

		-- Find the distance between pos and
		-- ent location
		local dist = (ent.RootPart.Position - pos).Magnitude

		if dist < closestDistance then
			closestDistance = dist
			closest = uuid
		end
	end

	return __Enemies[closest]
end

function Enemies.GetAll()
	return __Enemies
end

function Enemies.RequestSpawnEnemy(enemyPath: string?)
	API:FireServer("RequestSpawnEnemy", {
		EnemyPath = enemyPath or "Skeletal.Korblox",
	})
end

-- Handle movement etc.
Handler.OnClientEvent:Connect(function(action: string, data: { [string]: any })
	if action == "Move" then
		local ent = __Enemies[data.UUID]
		if ent and ent.Character and ent.Character:FindFirstChild("Humanoid") then
			(ent.Character:FindFirstChild("Humanoid") :: Humanoid):MoveTo(data.Position)
		end
		CancelLinearVelocityVisual(data.UUID)

		__LookTargets[data.UUID] = data.LookAt
	elseif action == "Pivot" then
		local ent = __Enemies[data.UUID]
		if ent and ent.Character and ent.Character.PrimaryPart then
			ent.Character.PrimaryPart:PivotTo(data.CFrame)
		end
		CancelLinearVelocityVisual(data.UUID)
		__LookTargets[data.UUID] = nil
	elseif action == "Face" then
		__LookTargets[data.UUID] = data.LookAt
	elseif action == "LinearVelocity" then
		ApplyLinearVelocityVisual(data.UUID, data.Velocity, data.Duration)
	elseif action == "CancelLinearVelocity" then
		CancelLinearVelocityVisual(data.UUID)
	elseif action == "AttackHitbox" then
		local hitbox = EnsureAttackHitbox(data.UUID)
		__AttackHitboxes[data.UUID] = {
			Part = hitbox,
			ActiveFrom = data.ActiveFrom,
			ActiveUntil = data.ActiveUntil,
			ClearAt = data.ClearAt,
			HitboxSize = data.HitboxSize,
			HitboxOffset = data.HitboxOffset,
		}
	elseif action == "AttackPredictor" then
		local predictor = EnsureAttackPredictor(data.UUID)
		predictor.Size = data.PredictorSize
		predictor.CFrame = data.PredictorCFrame
		__AttackPredictors[data.UUID] = {
			Part = predictor,
			ChargeStartedAt = data.ChargeStartedAt,
			ChargeEndsAt = data.ChargeEndsAt,
			ClearAt = data.ClearAt,
		}
	elseif action == "DamageIndicator" then
		local ent = __Enemies[data.UUID]
		if ent then
			if data.CurrentHealth ~= nil then
				ent.__Stats.Health = data.CurrentHealth
			end
			if data.MaxHealth ~= nil then
				ent.__Stats.MaxHealth = data.MaxHealth
			end
			ShowDamageIndicator(data.UUID, ent, data.Damage, data.IsCrit)
			UpdateEnemyTag(data.UUID, ent)
		end
	end
end)

RunService.Heartbeat:Connect(function()
	for uuid, target in pairs(__LookTargets) do
		local ent = __Enemies[uuid]
		if not target or not ent or not ent.Character or not ent.Character.PrimaryPart then
			continue
		end

		local rootPart = ent.Character.PrimaryPart
		local rootPosition = rootPart.Position
		local flatTarget = Vector3.new(target.X, rootPosition.Y, target.Z)
		if (flatTarget - rootPosition).Magnitude > 0.001 then
			rootPart.CFrame = CFrame.lookAt(rootPosition, flatTarget)
		end
	end

	for uuid, ent in pairs(__Enemies) do
		if IsEnemyAlive(ent) then
			UpdateEnemyTag(uuid, ent)
		else
			DestroyEnemyArtifacts(uuid)
		end
	end

	local now = workspace:GetServerTimeNow()
	for indicatorId, indicator in pairs(__DamageIndicators) do
		local elapsed = now - indicator.StartedAt
		local alpha = math.clamp(elapsed / indicator.Duration, 0, 1)
		if alpha >= 1 then
			DestroyDamageIndicator(indicatorId)
			continue
		end

		indicator.Gui.StudsOffsetWorldSpace = Vector3.new(
			indicator.BaseOffset.X,
			indicator.BaseOffset.Y + (elapsed * 0.45),
			indicator.BaseOffset.Z
		)
		indicator.Label.Rotation = math.sin(elapsed * 12) * indicator.RotationAmplitude * indicator.Direction
		indicator.Label.TextTransparency = alpha
		indicator.Label.TextStrokeTransparency = math.min(1, 0.4 + alpha)
		indicator.Label.TextSize = indicator.BaseTextSize - (6 * alpha)
	end

	for uuid, state in pairs(__AttackPredictors) do
		if now > state.ClearAt then
			ClearAttackPredictor(uuid)
			continue
		end

		local duration = math.max(state.ChargeEndsAt - state.ChargeStartedAt, 0.001)
		local alpha = math.clamp((now - state.ChargeStartedAt) / duration, 0, 1)
		state.Part.Color = Color3.fromHSV(0, 0.2 + (0.8 * alpha), 0.95)
		state.Part.Transparency = 0.55 - (0.25 * alpha)
	end

	for uuid, state in pairs(__AttackHitboxes) do
		local ent = __Enemies[uuid]
		if now > state.ClearAt or not ent or not ent.Character or not ent.Character.PrimaryPart then
			ClearAttackHitbox(uuid)
			continue
		end

		if now < state.ActiveFrom or now > state.ActiveUntil then
			state.Part.Transparency = 1
			continue
		end

		state.Part.Transparency = 0.82
		state.Part.Size = state.HitboxSize
		state.Part.CFrame = ent.Character.PrimaryPart.CFrame * state.HitboxOffset
	end
end)

return table.freeze(Enemies)
