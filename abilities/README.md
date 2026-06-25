# Ability data layout

```text
abilities/
├── AbilityData.gd
├── AbilityDatabase.gd
├── AbilityResolver.gd
├── definitions/
│   ├── assault/
│   ├── attrition/
│   ├── control/
│   ├── economy/
│   ├── insight/
│   ├── mobility/
│   └── protection/
└── icons/                 # optional per-ability art
```

Create one `AbilityData` `.tres` per canonical ability. `ability_id` is the stable gameplay key; names and rules text may be edited without breaking resolver code. Card resources assign these resources through their `abilities` field. Both databases scan and cache their definition trees automatically.

Legacy `ability_text` and `ability_types` remain temporarily so existing cards keep working during migration. New cards should use only `abilities`.
