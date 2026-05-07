--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)

export type ImageIds = {
	TopLeft: string?,
	TopRight: string?,
	BottomLeft: string?,
	BottomRight: string?,
	Side: string?,
	Center: string?,

	-- Legacy per-side slots are still accepted, but Side is preferred.
	Top: string?,
	Right: string?,
	Bottom: string?,
	Left: string?,
}

export type Props = {
	ImageIds: ImageIds?,
	Thickness: number?,
	ZIndex: number?,
	CenterZIndex: number?,
	ImageTransparency: number?,
	ImageColor3: Color3?,
	UseQuirkyBottomRight: boolean?,
}

local NinePartBorder = {}

-- Source art is expected to be 36x36 for corners and 36px thick for sides.
-- Rendered size is doubled for now.
NinePartBorder.SourcePartSize = 36
NinePartBorder.RenderScale = 2
NinePartBorder.RenderedPartSize = NinePartBorder.SourcePartSize * NinePartBorder.RenderScale
NinePartBorder.SideThicknessScale = 0.5
NinePartBorder.BottomRightScale = 156 / 64
NinePartBorder.BottomRightAnchorPoint = Vector2.new((156 - 41) / 156, (156 - 32) / 156)

-- Side art is authored as the top edge: horizontal, outside edge on the top.
-- These rotations keep that outside edge facing outward on every side.
NinePartBorder.SideRotations = {
	Top = 0,
	Right = 90,
	Bottom = 180,
	Left = 270,
}

NinePartBorder.ImageIds = {
	TopLeft = "rbxassetid://91180302366961",
	TopRight = "rbxassetid://91180302366961",
	BottomLeft = "rbxassetid://91180302366961",
	BottomRight = "rbxassetid://78804921870553",
	Side = "rbxassetid://103384633670763",
	Center = "",
} :: ImageIds

local function resolveImage(imageId: string?): string
	if not imageId or imageId == "" then
		return ""
	end

	if string.find(imageId, "://", 1, true) then
		return imageId
	end

	return "rbxassetid://" .. imageId
end

local function imageTransparency(imageId: string?, configuredTransparency: number?): number
	if not imageId or imageId == "" then
		return 1
	end

	return configuredTransparency or 0
end

local function imagePart(
	name: string,
	imageId: string?,
	position: UDim2,
	size: UDim2,
	zIndex: number,
	props: Props,
	anchorPoint: Vector2?,
	rotation: number?,
	sizeConstraint: Enum.SizeConstraint?
)
	return React.createElement("ImageLabel", {
		Active = false,
		AnchorPoint = anchorPoint or Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = resolveImage(imageId),
		ImageColor3 = props.ImageColor3 or Color3.new(1, 1, 1),
		ImageTransparency = imageTransparency(imageId, props.ImageTransparency),
		Name = name,
		Position = position,
		Rotation = rotation or 0,
		ScaleType = Enum.ScaleType.Stretch,
		Size = size,
		SizeConstraint = sizeConstraint or Enum.SizeConstraint.RelativeXY,
		ZIndex = zIndex,
	})
end

local function getSideImage(imageIds: ImageIds, sideName: string): string?
	if imageIds.Side and imageIds.Side ~= "" then
		return imageIds.Side
	end

	if sideName == "Top" then
		return imageIds.Top
	elseif sideName == "Right" then
		return imageIds.Right
	elseif sideName == "Bottom" then
		return imageIds.Bottom
	else
		return imageIds.Left
	end
end

function NinePartBorder.GetSideThickness(thickness: number?): number
	return (thickness or NinePartBorder.RenderedPartSize) * NinePartBorder.SideThicknessScale
end

function NinePartBorder.GetInnerInset(thickness: number?): number
	return NinePartBorder.GetSideThickness(thickness) * 0.5
end

function NinePartBorder.Component(props: Props)
	local imageIds = props.ImageIds or NinePartBorder.ImageIds
	local thickness = props.Thickness or NinePartBorder.RenderedPartSize
	local zIndex = props.ZIndex or 1
	local centerZIndex = props.CenterZIndex or 0
	local sideZIndex = zIndex
	local cornerZIndex = zIndex + 1
	local sideThickness = NinePartBorder.GetSideThickness(thickness)
	local useQuirkyBottomRight = props.UseQuirkyBottomRight ~= false
	local bottomRightImage = if useQuirkyBottomRight
		then imageIds.BottomRight
		else imageIds.TopRight or imageIds.TopLeft or imageIds.BottomLeft or imageIds.BottomRight
	local bottomRightSize = if useQuirkyBottomRight then thickness * NinePartBorder.BottomRightScale else thickness
	local bottomRightAnchorPoint = if useQuirkyBottomRight then NinePartBorder.BottomRightAnchorPoint else nil

	return React.createElement(React.Fragment, nil, {
		TopLeft = imagePart(
			"TopLeft",
			imageIds.TopLeft,
			UDim2.fromScale(0, 0),
			UDim2.fromOffset(thickness, thickness),
			cornerZIndex,
			props
		),
		Top = imagePart(
			"Top",
			getSideImage(imageIds, "Top"),
			UDim2.fromScale(0.5, 0),
			UDim2.new(1, 0, 0, sideThickness),
			sideZIndex,
			props,
			nil,
			NinePartBorder.SideRotations.Top
		),
		TopRight = imagePart(
			"TopRight",
			imageIds.TopRight,
			UDim2.fromScale(1, 0),
			UDim2.fromOffset(thickness, thickness),
			cornerZIndex,
			props
		),
		Left = imagePart(
			"Left",
			getSideImage(imageIds, "Left"),
			UDim2.fromScale(0, 0.5),
			UDim2.new(1, 0, 0, sideThickness),
			sideZIndex,
			props,
			nil,
			NinePartBorder.SideRotations.Left,
			Enum.SizeConstraint.RelativeYY
		),
		Center = imagePart(
			"Center",
			imageIds.Center,
			UDim2.fromScale(0.5, 0.5),
			UDim2.fromScale(1, 1),
			centerZIndex,
			props
		),
		Right = imagePart(
			"Right",
			getSideImage(imageIds, "Right"),
			UDim2.fromScale(1, 0.5),
			UDim2.new(1, 0, 0, sideThickness),
			sideZIndex,
			props,
			nil,
			NinePartBorder.SideRotations.Right,
			Enum.SizeConstraint.RelativeYY
		),
		BottomLeft = imagePart(
			"BottomLeft",
			imageIds.BottomLeft,
			UDim2.fromScale(0, 1),
			UDim2.fromOffset(thickness, thickness),
			cornerZIndex,
			props
		),
		Bottom = imagePart(
			"Bottom",
			getSideImage(imageIds, "Bottom"),
			UDim2.fromScale(0.5, 1),
			UDim2.new(1, 0, 0, sideThickness),
			sideZIndex,
			props,
			nil,
			NinePartBorder.SideRotations.Bottom
		),
		BottomRight = imagePart(
			"BottomRight",
			bottomRightImage,
			UDim2.fromScale(1, 1),
			UDim2.fromOffset(bottomRightSize, bottomRightSize),
			cornerZIndex,
			props,
			bottomRightAnchorPoint
		),
	})
end

return table.freeze(NinePartBorder)
