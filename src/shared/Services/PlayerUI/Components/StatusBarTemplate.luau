--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)

export type StatusBarProps = {
	Size: UDim2?,
	FillColor: Color3,
	BackgroundTransparency: number?,
}

local BAR_HEIGHT = 20

local function createBarLayer(
	name: string,
	color: Color3,
	transparency: number,
	zIndex: number,
	inset: number
)
	local bodyHeight = BAR_HEIGHT - (inset * 2)

	return React.createElement("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, BAR_HEIGHT),
		ZIndex = zIndex,
	}, {
		Body = React.createElement("Frame", {
			BackgroundColor3 = color,
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(inset, inset),
			Size = UDim2.new(1, -(inset * 2), 0, bodyHeight),
			ZIndex = zIndex,
		}),
	})
end

local function StatusBarTemplate(props: StatusBarProps)
	local fillColor = props.FillColor
	local size = props.Size or UDim2.fromOffset(620, BAR_HEIGHT)

	return React.createElement("Frame", {
		Size = size,
		BackgroundTransparency = 1,
	}, {
		BackgroundLayer = createBarLayer("BackgroundLayer", Color3.fromRGB(0, 0, 0), 0, 1, 0),
		FillLayer = createBarLayer("FillLayer", fillColor, props.BackgroundTransparency or 0.02, 2, 2),
	})
end

return StatusBarTemplate
