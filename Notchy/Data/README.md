# Data

Camada de persistência e sincronização.

- **Hoje**: preferências e texto do teleprompter em `UserDefaults` (chaves em `Core/NotchyKeys.swift`).
- **Next iterations**: local script repository (e.g. SQLite/Core Data or files), then sync service with backend for web and mobile.

Domain (Script model) lives in Core or in Features/Scripts; Data only implements *where* and *how* to persist and sync.
