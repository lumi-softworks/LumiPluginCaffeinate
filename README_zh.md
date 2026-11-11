# LumiPluginCaffeinate

[English](README.md) | 📖 中文版

「防休眠（Caffeinate）」插件的共享远程包，由 Lumi、Wakey 等 CofficLab 同族应用装配。

> 本插件不依赖任何其它插件：状态栏、设置页与说明书均通过 Provider 契约接入，
> 电源断言直接经由 IOKit 创建。

## 包信息

- Manifest 包名：`LumiPluginCaffeinate`（与仓库名一致）
- Product / Target：`PluginCaffeinate`
- 平台：macOS 14+
- Swift tools：6.0

## 提供的能力

- 状态栏弹窗：时长档位与防休眠快捷操作。
- 基于 IOKit 电源断言的防休眠会话（仅系统 / 系统与显示器）。
- 「立即关闭显示器」操作仅在系统断言创建成功后执行。
- 设置页自定义时长管理，跨启动持久化。
- 说明书条目贡献。

## 依赖与接入

```swift
dependencies: [
    .package(url: "https://github.com/lumi-softworks/LumiPluginCaffeinate.git", from: "1.0.0")
]
```

在宿主的 Factory target 中加入 product：

```swift
.product(name: "PluginCaffeinate", package: "LumiPluginCaffeinate")
```

并在插件装配处创建实例：

```swift
import PluginCaffeinate

PluginCaffeinate()
```

默认插件 id 为 `com.coffic.lumi.plugin.caffeinate`。宿主可注入自己的品牌配置；
Wakey 传入历史 id `CaffeinatePlugin`，以保留既有启用状态与插件数据目录：

```swift
PluginCaffeinate(
    configuration: CaffeinateConfiguration(
        pluginID: "CaffeinatePlugin",
        loggerSubsystem: "com.coffic.wakey.plugin.caffeinate",
        accessibilityIdentifierPrefix: "wakey.caffeinate"
    )
)
```

宿主需提供 `MenuBarProviding`、`SettingViewProviding` 与 `DocsViewProviding`，
并使用 LumiUI 提供的共享设置与按钮组件。

## 测试

```sh
swift test
```
