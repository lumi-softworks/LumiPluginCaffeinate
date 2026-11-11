import Foundation
import LumiLoggingKit
import OSLog
import ProviderStorage

/// 防休眠插件的本地存储。
///
/// 负责持久化插件的用户配置（默认启动模式等）。
/// 存储位置：`storage.pluginDataDirectory(for:)/settings/settings.plist`
///
/// 共享远程包：宿主通过 `StorageProviding` 注入自己的数据根目录，
/// 插件本身不写死任何宿主品牌信息。
@MainActor
public final class CaffeinateLocalStore: SuperLog, @unchecked Sendable {
    private static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.caffeinate",
        category: "plugin.caffeinate.local-store"
    )

    // MARK: - Singleton

    public static let shared = CaffeinateLocalStore()

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "CaffeinateLocalStore.queue", qos: .userInitiated)

    /// 按插件 ID 缓存的存储位置。
    ///
    /// 单例被多个插件实例共享时（例如同一进程内既有 Lumi 又有 Wakey 的插件实例，
    /// 或者测试里为不同插件 ID 注入不同目录），如果只保留「最后配置的那一份」，
    /// 后一次 `configure` 会把前一次的目录顶掉——前一个插件的读写会落到别人的
    /// 目录里，测试也会因为临时目录已被删除而莫名失败。
    ///
    /// 因此这里按插件 ID 分开寻址：调用方始终带着自己的 pluginID 来读写，
    /// 不存在「当前是哪个插件」这种隐式状态。
    private var locationsByPluginID: [String: StoreLocation] = [:]

    // MARK: - Initialization

    public convenience init() {
        self.init(settingsDirectory: nil)
    }

    /// 仅用于测试：直接绑定到一个固定的设置目录。
    init(settingsDirectory root: URL?) {
        if let root {
            let location = StoreLocation(root: root)
            self.locationsByPluginID[Self.testPluginID] = location
            do {
                try fileManager.createDirectory(at: location.settingsDirectory, withIntermediateDirectories: true)
            } catch {
                Self.logger.error("\(self.t)Create caffeinate settings directory failed: \(error.localizedDescription)")
            }
        }
    }

    /// 测试用的虚拟插件 ID：把固定目录绑定到这个键上。
    private static let testPluginID = "__caffeinate_test__"

    // MARK: - Configuration

    /// 使用宿主提供的存储目录完成懒加载。
    ///
    /// 必须在第一次写入 / 读取前调用一次。可以重复调用以更换目录（仅用于测试）。
    func configure(storage: (any StorageProviding)?, pluginID: String) {
        guard let storage else {
            Self.logger.error("\(self.t)storage is nil; caffeinate local store stays unconfigured")
            // 清掉这个插件 ID 的残留位置：否则它会继续写到上一个实例留下的
            // 目录里，读到的却是别人的数据。
            self.locationsByPluginID.removeValue(forKey: pluginID)
            return
        }

        let root = storage.pluginDataDirectory(for: pluginID)
        migrateLegacyStorageIfNeeded(storage: storage, newRoot: root)

        let settingsRoot = root
            .appendingPathComponent("settings", isDirectory: true)
        do {
            try fileManager.createDirectory(at: settingsRoot, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("\(self.t)Create caffeinate settings directory failed: \(error.localizedDescription)")
        }
        self.locationsByPluginID[pluginID] = StoreLocation(root: settingsRoot)
    }

    /// 将旧版使用短 ID 的目录内容迁移到规范插件 ID 目录。
    ///
    /// 只移动目标目录中尚不存在的项目，避免覆盖新目录中的数据；如果发生冲突，
    /// 保留旧目录并记录日志，交给后续版本继续处理。
    private func migrateLegacyStorageIfNeeded(storage: any StorageProviding, newRoot: URL) {
        let legacyRoot = storage.dataRootDirectory
            .appendingPathComponent("Caffeinate", isDirectory: true)
        guard legacyRoot.standardizedFileURL != newRoot.standardizedFileURL,
              fileManager.fileExists(atPath: legacyRoot.path) else {
            return
        }

        do {
            let legacyItems = try fileManager.contentsOfDirectory(
                at: legacyRoot,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            for item in legacyItems {
                let destination = newRoot.appendingPathComponent(item.lastPathComponent, isDirectory: item.hasDirectoryPath)
                guard !fileManager.fileExists(atPath: destination.path) else {
                    Self.logger.warning("\(self.t)Skipped legacy storage item because destination exists: \(destination.path, privacy: .public)")
                    continue
                }
                try fileManager.moveItem(at: item, to: destination)
            }

            if (try? fileManager.contentsOfDirectory(atPath: legacyRoot.path))?.isEmpty == true {
                try? fileManager.removeItem(at: legacyRoot)
            }
        } catch {
            Self.logger.error("\(self.t)Migrate legacy caffeinate storage failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Public API

    /// 默认启动模式（`SleepMode` 字符串）。未配置时返回 `nil`。
    func defaultModeRaw(pluginID: String) -> String? {
        string(forKey: Keys.defaultMode, pluginID: pluginID)
    }

    /// 设置默认启动模式（持久化）。传 `nil` 表示清除。
    @discardableResult
    func setDefaultModeRaw(_ value: String?, pluginID: String) -> Bool {
        set(value, forKey: Keys.defaultMode, pluginID: pluginID)
    }

    @discardableResult
    func set(_ value: Any?, forKey key: String, pluginID: String) -> Bool {
        queue.sync {
            var dict = readDict(pluginID: pluginID)
            if let value {
                dict[key] = value
            } else {
                dict.removeValue(forKey: key)
            }
            return writeDict(dict, pluginID: pluginID)
        }
    }

    func object(forKey key: String, pluginID: String) -> Any? {
        queue.sync { readDict(pluginID: pluginID)[key] }
    }

    func string(forKey key: String, pluginID: String) -> String? {
        object(forKey: key, pluginID: pluginID) as? String
    }

    // MARK: - Private Helpers

    private func readDict(pluginID: String) -> [String: Any] {
        guard let settingsFileURL = locationsByPluginID[pluginID]?.settingsFileURL else { return [:] }
        guard fileManager.fileExists(atPath: settingsFileURL.path) else { return [:] }
        do {
            let data = try Data(contentsOf: settingsFileURL)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let dict = plist as? [String: Any] else {
                Self.logger.error("\(self.t)Read caffeinate settings failed: root plist is not a dictionary")
                quarantineCorruptSettings(pluginID: pluginID)
                return [:]
            }
            return dict
        } catch {
            Self.logger.error("\(self.t)Read caffeinate settings failed: \(error.localizedDescription)")
            quarantineCorruptSettings(pluginID: pluginID)
            return [:]
        }
    }

    @discardableResult
    private func writeDict(_ dict: [String: Any], pluginID: String) -> Bool {
        guard let location = locationsByPluginID[pluginID] else {
            // 未配置：写入操作静默失败并记录日志。
            Self.logger.error("\(self.t)Persist caffeinate settings skipped: store not configured")
            return false
        }
        let data: Data
        do {
            data = try PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0)
        } catch {
            Self.logger.error("\(self.t)Encode caffeinate settings failed: \(error.localizedDescription)")
            return false
        }

        let tmp = location.settingsDirectory.appendingPathComponent("settings.tmp")
        do {
            try fileManager.createDirectory(at: location.settingsDirectory, withIntermediateDirectories: true)
            try data.write(to: tmp, options: .atomic)
            if fileManager.fileExists(atPath: location.settingsFileURL.path) {
                _ = try fileManager.replaceItemAt(location.settingsFileURL, withItemAt: tmp)
            } else {
                try fileManager.moveItem(at: tmp, to: location.settingsFileURL)
            }
            return true
        } catch {
            Self.logger.error("\(self.t)Persist caffeinate settings failed: \(error.localizedDescription)")
            try? fileManager.removeItem(at: tmp)
            return false
        }
    }

    private func quarantineCorruptSettings(pluginID: String) {
        guard let location = locationsByPluginID[pluginID],
              fileManager.fileExists(atPath: location.settingsFileURL.path) else {
            return
        }
        do {
            if fileManager.fileExists(atPath: location.corruptSettingsFileURL.path) {
                try fileManager.removeItem(at: location.corruptSettingsFileURL)
            }
            try fileManager.moveItem(at: location.settingsFileURL, to: location.corruptSettingsFileURL)
        } catch {
            Self.logger.error("\(self.t)Quarantine corrupt caffeinate settings failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Store Location

/// 一个插件 ID 对应的设置文件位置。
private struct StoreLocation {
    let settingsDirectory: URL
    let settingsFileURL: URL
    let corruptSettingsFileURL: URL

    init(root: URL) {
        self.settingsDirectory = root
        self.settingsFileURL = root.appendingPathComponent("settings.plist")
        self.corruptSettingsFileURL = root.appendingPathComponent("settings.corrupt.plist")
    }
}

// MARK: - Storage Keys

extension CaffeinateLocalStore {
    enum Keys {
        static let defaultMode = "defaultMode"
    }
}
