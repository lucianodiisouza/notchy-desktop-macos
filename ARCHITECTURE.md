# Arquitetura do Notchy

Estrutura pensada para um **app de scripts**: teleprompter no notch hoje, editor de scripts (estilo Notas) e sync com backend nas próximas iterações (web + mobile).

## Estrutura de pastas

```
Notchy/
├── App/                    # Entrada da aplicação
│   ├── NotchyApp.swift
│   └── AppDelegate.swift
├── Core/                   # Compartilhado e domínio
│   ├── NotchyState.swift
│   ├── NotchyKeys.swift    # Chaves UserDefaults (futuro: o que syncar)
│   ├── Color+Hex.swift
│   ├── ScreenLayout.swift
│   └── NotchShapes.swift
├── Data/                   # Persistência e sync (placeholder)
│   └── README.md
├── Features/
│   ├── Teleprompter/       # Janela no notch, scroll, voz
│   │   ├── ContentView.swift
│   │   ├── ControlBar.swift
│   │   ├── FloatingWindowController.swift
│   │   ├── NotchWindow.swift
│   │   ├── ScrollController.swift
│   │   ├── TeleprompterTextView.swift
│   │   ├── WindowAccessor.swift
│   │   └── WindowBackgroundView.swift
│   ├── Settings/           # Configurações
│   │   └── SettingsView.swift
│   └── Scripts/            # Next iteration: list + editor
│       └── README.md
├── Infrastructure/          # Serviços (áudio, etc.)
│   └── AudioMonitor.swift
└── Resources/
    ├── Assets.xcassets
    └── Info.plist
```

## Ideia geral

- **Core**: tipos e helpers usados em todo o app; sem UI; `NotchyKeys` centraliza o que é persistido (útil para definir depois o que vai para o backend).
- **Data**: onde ficarão repositórios e sync; hoje a persistência está em UserDefaults; no futuro, um repositório de scripts (local + remoto).
- **Features**: uma pasta por funcionalidade (Teleprompter, Settings, Scripts). Cada uma pode ter Views, ViewModels/Controllers e, no caso de Scripts, modelo de domínio se fizer sentido manter ali.
- **Infrastructure**: serviços transversais (ex.: áudio). Quando houver sync, pode ganhar um “Services” ou “Networking” aqui ou em Data.

## Próximos passos (scripts + sync)

1. **Scripts**: implementar em `Features/Scripts` (modelo, lista, editor); o teleprompter passa a exibir “script selecionado”.
2. **Data**: criar repositório local de scripts; migrar texto atual do prompter para um script.
3. **Sync**: em Data (ou Infrastructure), adicionar cliente de API e regras de sincronização; web e mobile consumirão o mesmo backend.

Assim a organização já prepara o app para crescer sem misturar teleprompter, configurações e scripts no mesmo monte de arquivos.
