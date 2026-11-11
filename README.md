# LumiPluginCaffeinate

📖 English | [中文版](README_zh.md)

Shared remote package for the "Caffeinate" (anti-sleep) plugin, assembled by CofficLab sibling apps such as Lumi and Wakey.

> This plugin depends on no other plugins. The menu bar, settings, and docs are all accessed through Provider contracts; power assertions are created directly through IOKit.

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
- User manual contribution.

## Dependencies and Integration

```swift
dependencies: [
    .package(url: "https://github.com/lumi-softworks/LumiPluginCaffeinate.git", from: "1.0.0")
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
