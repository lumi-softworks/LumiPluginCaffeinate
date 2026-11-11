# LumiPluginCaffeinate

📖 English | [中文版](README_zh.md)

Shared remote package for the "Caffeinate" (anti-sleep) plugin, assembled by CofficLab sibling apps such as Lumi and Wakey.

> This plugin depends on no other plugins. The menu bar, settings, docs, logo highlight, and persistence are all accessed through Provider contracts; power assertions are created directly through IOKit.

## Package

- Manifest package name: `LumiPluginCaffeinate` (matches the repository name)
- Product / Target: `PluginCaffeinate`
- Platform: macOS 14+
- Swift tools: 6.0

## What It Provides

- Menu bar popup with duration presets and quick anti-sleep actions.
- Anti-sleep sessions backed by IOKit power assertions (system, system + display).
- Immediate display-off action that only runs after the system assertion succeeds.
- Custom duration management on the settings page, persisted across launches.
- Four Agent tools (`caffeinate_activate`, `caffeinate_deactivate`, `caffeinate_status`, `caffeinate_turn_off_display`).
- Logo highlight while anti-sleep is active.
- Persisted default mode, applied on the next launch.
- User manual contribution.

## Host Capabilities

The plugin resolves three optional providers from the kernel at boot. Hosts that do not provide one still get a working plugin — only the corresponding effect is missing.

| Provider | Effect when present | Effect when absent |
|---|---|---|
| `StorageProviding` | Persists the default mode and custom durations under the plugin's own data directory | Preferences are not persisted across launches |
| `LogoProviding` | Highlights the status-bar logo while anti-sleep is active | No logo highlight |
| `ToolManagerProviding` | Registers the four Agent tools | The tools are not offered to the Agent |

## Dependencies and Integration

```swift
dependencies: [
    .package(url: "https://github.com/lumi-softworks/LumiPluginCaffeinate.git", from: "1.1.0")
]
```

Add the product to the host Factory target:

```swift
.product(name: "PluginCaffeinate", package: "LumiPluginCaffeinate")
```

And assemble it in the plugin factory:

```swift
import PluginCaffeinate

PluginCaffeinate()
```

The default plugin ID is `com.coffic.lumi.plugin.caffeinate`. Hosts can inject their own brand configuration; Wakey passes the historical ID `CaffeinatePlugin` to preserve its existing enabled state and plugin data directory:

```swift
PluginCaffeinate(
    configuration: CaffeinateConfiguration(
        pluginID: "CaffeinatePlugin",
        loggerSubsystem: "com.coffic.wakey.plugin.caffeinate",
        accessibilityIdentifierPrefix: "wakey.caffeinate"
    )
)
```

The host must provide `MenuBarProviding`, `SettingViewProviding`, and `DocsViewProviding`, and use LumiUI's shared settings and button components.

## Testing

```sh
swift test
```
