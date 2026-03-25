--!strict

export type ModifierKind =
	"BaseFlat"
	| "BaseAdditive"
	| "FinalAdditive"
	| "Multiplicative"
	| "FinalStatFlat"

export type Modifier = {
	Id: string,
	Type: ModifierKind,
	Value: number,
	Source: string?,
}

return {}
