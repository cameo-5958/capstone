--!strict

export type StatModifier = {
    -- Individual stat
    Stat: string,
    Additive: number, 
    Multiplicative: number,
}

export type Modifier = {
    -- Modifier ID
    MID: string,

    MinModifier: { StatModifier },
    StepModifier: { StatModifier },

    MaxStack: number,
}

return {}