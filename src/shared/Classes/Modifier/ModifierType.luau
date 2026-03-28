--!strict

export type ModifierKind =
	"BaseFlat"
	| "BaseAdditive"
	| "FinalAdditive"
	| "Multiplicative"
	| "FinalFlat"

export type Modifier = {
	Id: string,
	Type: ModifierKind,
	Value: number,
	Source: string?,
}

return {}
