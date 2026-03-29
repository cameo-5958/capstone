--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)

export type StatusBarProps = {
	Size: UDim2?,
	FillColor: Color3,
	BackgroundTransparency: number?,
	FillRatio: number?,
	OverlayFillColor: Color3?,
	OverlayFillRatio: number?,
	OverlayTransparency: number?,
}

local BAR_HEIGHT = 20

local function StatusBarTemplate(props: StatusBarProps)
	local fillColor = props.FillColor
	local size = props.Size or UDim2.fromOffset(620, BAR_HEIGHT)
	local fillRatio = math.clamp(props.FillRatio or 1, 0, 1)
	local overlayFillRatio = props.OverlayFillRatio and math.clamp(props.OverlayFillRatio, 0, 1) or nil

	return React.createElement("Frame", {
		Size = size,
		BackgroundTransparency = 1,
	}, {
		BackgroundLayer = React.createElement("Frame", {
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, BAR_HEIGHT),
			ZIndex = 1,
		}),
		FillInset = if fillRatio > 0 then React.createElement("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.new(fillRatio, -4, 0, BAR_HEIGHT - 4),
			ZIndex = 2,
		}, {
			FillLayer = React.createElement("Frame", {
				BackgroundColor3 = fillColor,
				BackgroundTransparency = props.BackgroundTransparency or 0.02,
				BorderSizePixel = 0,
				Size = UDim2.new(1 / math.max(fillRatio, 0.0001), 0, 1, 0),
				ZIndex = 2,
			}),
		}) else nil,
		OverlayInset = if overlayFillRatio and overlayFillRatio > 0 then React.createElement("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.new(overlayFillRatio, -4, 0, BAR_HEIGHT - 4),
			ZIndex = 3,
		}, {
			OverlayLayer = React.createElement("Frame", {
				BackgroundColor3 = props.OverlayFillColor or fillColor,
				BackgroundTransparency = props.OverlayTransparency or 0,
				BorderSizePixel = 0,
				Size = UDim2.new(1 / math.max(overlayFillRatio, 0.0001), 0, 1, 0),
				ZIndex = 3,
			}),
		}) else nil,
	})
end

return StatusBarTemplate
