--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local NinePartBorder = require(ReplicatedStorage.Classes.UI.NinePartBorder)

export type Props = {
	Position: UDim2?,
	Size: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	ZIndex: number?,
	Text: string?,
	PlaceholderText: string?,
	ClearTextOnFocus: boolean?,
	TextColor3: Color3?,
	PlaceholderColor3: Color3?,
	BackgroundColor3: Color3?,
	BorderThickness: number?,
	OnTextChanged: ((string) -> ())?,
}

local BorderedTextBox = {}

local DEFAULT_BORDER_THICKNESS = 14
local DEFAULT_SIZE = UDim2.fromOffset(220, 54)
local DEFAULT_BACKGROUND = Color3.fromRGB(45, 29, 18)
local DEFAULT_TEXT = Color3.fromRGB(244, 224, 188)
local DEFAULT_PLACEHOLDER = Color3.fromRGB(167, 128, 84)

function BorderedTextBox.Component(props: Props)
	local thickness = props.BorderThickness or DEFAULT_BORDER_THICKNESS
	local backgroundInset = math.max(2, math.floor(NinePartBorder.GetInnerInset(thickness)))
	local zIndex = props.ZIndex or 1
	local text, setText = React.useState(props.Text or "")

	React.useEffect(function()
		if props.Text ~= nil then
			setText(props.Text)
		end
	end, { props.Text })

	return React.createElement("Frame", {
		AnchorPoint = props.AnchorPoint,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		Size = props.Size or DEFAULT_SIZE,
		ZIndex = zIndex,
	}, {
		Border = React.createElement(NinePartBorder.Component, {
			Thickness = thickness,
			UseQuirkyBottomRight = false,
			ZIndex = zIndex + 2,
		}),
		Field = React.createElement("TextBox", {
			BackgroundColor3 = props.BackgroundColor3 or DEFAULT_BACKGROUND,
			BackgroundTransparency = 0.08,
			BorderSizePixel = 0,
			ClearTextOnFocus = props.ClearTextOnFocus == true,
			Font = Enum.Font.Gotham,
			PlaceholderColor3 = props.PlaceholderColor3 or DEFAULT_PLACEHOLDER,
			PlaceholderText = props.PlaceholderText or "Type here",
			Position = UDim2.fromOffset(backgroundInset, backgroundInset),
			Size = UDim2.new(1, -(backgroundInset * 2), 1, -(backgroundInset * 2)),
			Text = text,
			TextColor3 = props.TextColor3 or DEFAULT_TEXT,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = zIndex + 1,
			[React.Change.Text] = function(rbx: TextBox)
				setText(rbx.Text)
				if props.OnTextChanged then
					props.OnTextChanged(rbx.Text)
				end
			end,
		}, {
			Padding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
		}),
	})
end

return table.freeze(BorderedTextBox)
