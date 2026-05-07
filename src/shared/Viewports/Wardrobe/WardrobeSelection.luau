--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Classes.Modifier.Signal)

export type SelectedItem = {
	ItemKind: string,
	Source: string,
	EntryId: string?,
	Slot: number?,
	HotbarSlot: number?,
	IsHotbar: boolean?,
	IsEquipped: boolean?,
	Name: string?,
	Id: string?,
	Class: string?,
	Type: string?,
	Quantity: number?,
	MaxStack: number?,
	Data: { [string]: any },
}

local WardrobeSelection = {}

local selectionChanged = Signal.new()
local selectedItem: SelectedItem? = nil

function WardrobeSelection.SetSelectedItem(item: SelectedItem?): ()
	selectedItem = item
	selectionChanged:Fire(selectedItem)
end

function WardrobeSelection.GetSelectedItem(): SelectedItem?
	return selectedItem
end

function WardrobeSelection.GetSelectionChangedSignal()
	return selectionChanged
end

return table.freeze(WardrobeSelection)
