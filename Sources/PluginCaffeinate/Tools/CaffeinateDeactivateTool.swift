import KitAgentTool
import Foundation

/// 关闭防休眠工具
///
/// 释放 IOKit 电源断言，恢复系统正常的休眠策略。
struct CaffeinateDeactivateTool: SuperAgentTool {
    let name = "caffeinate_deactivate"

    /// 测试注入点；生产路径使用共享 Manager。
    var manager: CaffeinateManager? = nil

    func description(for language: LanguagePreference) -> String {
        "Deactivate caffeinate and restore normal system sleep behavior. Releases all IOKit power assertions."
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": [:]]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String { "恢复系统睡眠" }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }


    @MainActor
    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let manager = self.manager ?? CaffeinateManager.shared

        guard manager.isActive else {
            return """
            ## Caffeinate Status

            Caffeinate is **not active**. No action needed.
            System is already following normal sleep policy.
            """
        }

        guard manager.deactivate() else {
            // 释放失败时断言仍在系统里阻止休眠，不能宣称「已恢复」（#650）。
            return """
            ## Caffeinate Deactivation Failed ❌

            The system refused to release the power assertion, so the Mac
            may still be prevented from sleeping. Check `caffeinate_status`
            and try `caffeinate_deactivate` again.
            """
        }

        return """
        ## Caffeinate Deactivated ✅

        System sleep policy has been **restored to normal**.
        The system will now follow its default power management settings.
        """
    }
}
