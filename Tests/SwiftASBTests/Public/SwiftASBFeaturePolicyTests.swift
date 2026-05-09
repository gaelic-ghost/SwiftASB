import Foundation
import Testing
@testable import SwiftASB

@Suite("SwiftASB feature policy")
struct SwiftASBFeaturePolicyTests {
    @Test("built-in feature categories have stable ids and defaults")
    func builtInFeatureCategoriesHaveStableIDsAndDefaults() {
        let categories = SwiftASBFeatureCategory.builtIn
        let ids = categories.map(\.id)

        #expect(ids == [
            .gitObservability,
            .extensionInventory,
            .extensionMaintenance,
            .swiftRepoGuidanceSync,
            .gitActions,
            .configMutation,
            .extensionMutation,
            .worktreeAutomation,
        ])

        #expect(SwiftASBFeatureCategory.builtInCategory(id: .gitObservability)?.defaultMode == .enabled)
        #expect(SwiftASBFeatureCategory.builtInCategory(id: .extensionInventory)?.defaultMode == .enabled)
        #expect(SwiftASBFeatureCategory.builtInCategory(id: .extensionMaintenance)?.defaultMode == .enabled)
        #expect(SwiftASBFeatureCategory.builtInCategory(id: .swiftRepoGuidanceSync)?.defaultMode == .disabled)
        #expect(SwiftASBFeatureCategory.builtInCategory(id: .gitActions)?.defaultMode == .disabled)
        #expect(SwiftASBFeatureCategory.builtInCategory(id: .configMutation)?.defaultMode == .disabled)
        #expect(SwiftASBFeatureCategory.builtInCategory(id: .extensionMutation)?.defaultMode == .disabled)
        #expect(SwiftASBFeatureCategory.builtInCategory(id: .worktreeAutomation)?.defaultMode == .disabled)
    }

    @Test("policy defaults allow quiet reads and disable repo mutations")
    func policyDefaultsAllowQuietReadsAndDisableRepoMutations() {
        let policy = SwiftASBFeaturePolicy.defaults

        #expect(policy.mode(for: .gitObservability) == .enabled)
        #expect(policy.mode(for: .extensionInventory) == .enabled)
        #expect(policy.mode(for: .extensionMaintenance) == .enabled)
        #expect(policy.mode(for: .swiftRepoGuidanceSync) == .disabled)
        #expect(policy.mode(for: .gitActions) == .disabled)
        #expect(policy.mode(for: .configMutation) == .disabled)
        #expect(policy.mode(for: .extensionMutation) == .disabled)
        #expect(policy.mode(for: .worktreeAutomation) == .disabled)
        #expect(policy.hostAccess == .unknown)
    }

    @Test("policy can override one category without losing built-in fallback")
    func policyCanOverrideOneCategoryWithoutLosingBuiltInFallback() {
        var policy = SwiftASBFeaturePolicy()

        #expect(policy.mode(for: .gitObservability) == .enabled)
        #expect(policy.mode(for: .swiftRepoGuidanceSync) == .disabled)

        policy.setMode(.enabled, for: .swiftRepoGuidanceSync)

        #expect(policy.mode(for: .gitObservability) == .enabled)
        #expect(policy.mode(for: .swiftRepoGuidanceSync) == .enabled)
        #expect(policy.mode(for: "futureCustomCategory") == .disabled)
    }

    @Test("host access can declare sandbox-friendly home directory access")
    func hostAccessCanDeclareSandboxFriendlyHomeDirectoryAccess() {
        let home = URL(fileURLWithPath: "/Users/example")
        let access = SwiftASBHostAccess.homeDirectoryReadWrite(
            url: home,
            source: .securityScopedBookmark
        )

        #expect(access.homeDirectoryReadWriteGranted)
        #expect(access.homeDirectoryURL == home)
        #expect(access.accessSource == .securityScopedBookmark)
    }
}
