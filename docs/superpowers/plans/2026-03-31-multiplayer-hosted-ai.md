# Multiplayer Hosted AI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single-turn hard-coded OpenAI flow with a host-driven multiplayer room where the host stores private AI settings locally, guests submit round actions, and the host resolves each round through a provider-agnostic AI adapter.

**Architecture:** Keep Firestore as the shared room state store, move the game from `currentTurn` to room `phase` plus `rounds/actions`, and split AI configuration into public room metadata (`provider`, `model`) and host-local transport settings (`apiFormat`, `baseURL`, `apiKey`, `systemPrompt`). `CampaignService` owns room synchronization, `AIService` normalizes provider differences, and `ContentView` renders lobby plus round-confirmation gameplay.

**Tech Stack:** SwiftUI, Firebase Firestore, async/await, UserDefaults-backed local configuration, Xcode 26 / iOS Simulator build verification

---

## File Structure

### Create

- `AI GM/AIHostConfiguration.swift`  
  Host-local AI config models, validation, and `UserDefaults` persistence helpers.
- `AI GM/CampaignModels.swift`  
  Firestore-facing room, round, action, and message models plus phase/status enums.

### Modify

- `AI GM/AIService.swift`  
  Replace the hard-coded API client with provider adapters for `openAICompatible` and `ollama`.
- `AI GM/RuleEngine/GameEngine.swift`  
  Replace per-player turn prompts with opening and round-resolution prompt builders.
- `AI GM/CampaignService.swift`  
  Replace `currentTurn` logic with room phase, rounds, confirmed actions, host-only transitions, and message publishing.
- `AI GM/ContentView.swift`  
  Replace the single input/send UI with lobby setup, room metadata, round draft/confirm controls, and host start/continue actions.
- `AI GM/Player.swift`  
  Add small helpers needed by round prompts and room display.

### Verification

- Build command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project 'AI GM.xcodeproj' -scheme 'AI GM' -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/ai-gm-derived -clonedSourcePackagesDirPath /tmp/ai-gm-sourcepackages build`
- Manual flow: host creates room, guest joins, host starts, both confirm actions, host resolves round

### Notes

- This iteration intentionally does not add a new Xcode test target. Verification is build-based plus manual multiplayer walkthrough because the current project has no test target and the main risk is integration across SwiftUI, Firestore, and provider-specific network requests.
- Keep files small and focused. Do not reintroduce `currentTurn` ownership once round-based flow exists.

### Task 1: Add Host AI Configuration And Shared Room Models

**Files:**
- Create: `AI GM/AIHostConfiguration.swift`
- Create: `AI GM/CampaignModels.swift`
- Modify: `AI GM/Player.swift`
- Test: Build the target after these files compile cleanly

- [ ] **Step 1: Create the host AI configuration types**

```swift
import Foundation

enum AIAPIFormat: String, CaseIterable, Codable, Identifiable {
    case openAICompatible
    case ollama

    var id: String { rawValue }
}

struct AIHostConfiguration: Codable, Equatable {
    var provider: String
    var apiFormat: AIAPIFormat
    var baseURL: String
    var model: String
    var apiKey: String
    var systemPrompt: String

    var trimmedProvider: String { provider.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedModel: String { model.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedBaseURL: String { baseURL.trimmingCharacters(in: .whitespacesAndNewlines) }
}
```

- [ ] **Step 2: Add local persistence helpers for host configuration**

```swift
enum AIHostConfigurationStore {
    private static let defaults = UserDefaults.standard

    static func save(_ configuration: AIHostConfiguration, campaignId: String) throws {
        let key = "hostAIConfig.\(campaignId)"
        let data = try JSONEncoder().encode(configuration)
        defaults.set(data, forKey: key)
    }

    static func load(campaignId: String) -> AIHostConfiguration? {
        let key = "hostAIConfig.\(campaignId)"
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(AIHostConfiguration.self, from: data)
    }
}
```

- [ ] **Step 3: Create room, round, action, and message models**

```swift
import Foundation

enum CampaignPhase: String, Codable {
    case lobby
    case starting
    case collectingActions
    case resolvingTurn
    case finished
}

enum RoundStatus: String, Codable {
    case collecting
    case ready
    case resolving
    case resolved
}

struct CampaignAction: Identifiable, Equatable {
    let id: String
    let playerId: String
    let playerName: String
    let text: String
    let isConfirmed: Bool
}

struct CampaignMessage: Identifiable, Equatable {
    let id: String
    let kind: String
    let text: String
    let roundNumber: Int?
}
```

- [ ] **Step 4: Extend `Player` with prompt/display helpers**

```swift
extension Player {
    var statSummary: String {
        "\(name) HP \(hp)/\(maxHP), STR \(strength), DEX \(dexterity), INT \(intelligence)"
    }
}
```

- [ ] **Step 5: Run build to verify the new model files integrate**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project 'AI GM.xcodeproj' -scheme 'AI GM' -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/ai-gm-derived -clonedSourcePackagesDirPath /tmp/ai-gm-sourcepackages build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add 'AI GM/AIHostConfiguration.swift' 'AI GM/CampaignModels.swift' 'AI GM/Player.swift'
git commit -m "feat: add host ai configuration models"
```

### Task 2: Refactor AIService And GameEngine For Provider-Adaptive Round Resolution

**Files:**
- Modify: `AI GM/AIService.swift`
- Modify: `AI GM/RuleEngine/GameEngine.swift`
- Test: Build the target and verify unsupported configuration paths fail cleanly

- [ ] **Step 1: Replace the hard-coded API service initializer**

```swift
final class AIService {
    enum AIServiceError: LocalizedError {
        case invalidURL
        case missingAPIKey
        case unsupportedResponse
    }

    private let configuration: AIHostConfiguration

    init(configuration: AIHostConfiguration) {
        self.configuration = configuration
    }
}
```

- [ ] **Step 2: Add adapter methods for OpenAI-compatible and Ollama requests**

```swift
private func buildRequest(prompt: String) throws -> URLRequest {
    switch configuration.apiFormat {
    case .openAICompatible:
        return try buildOpenAICompatibleRequest(prompt: prompt)
    case .ollama:
        return try buildOllamaRequest(prompt: prompt)
    }
}

private func extractContent(from data: Data) throws -> String {
    switch configuration.apiFormat {
    case .openAICompatible:
        return try decodeOpenAICompatibleContent(from: data)
    case .ollama:
        return try decodeOllamaContent(from: data)
    }
}
```

- [ ] **Step 3: Update `sendMessage` and raw JSON handling to use the adapter**

```swift
func sendRawJSON(prompt: String) async throws -> String {
    let request = try buildRequest(prompt: prompt)
    let (data, _) = try await URLSession.shared.data(for: request)
    return try extractContent(from: data)
}
```

- [ ] **Step 4: Replace per-player turn narration with opening and round prompt builders**

```swift
final class GameEngine {
    func makeOpeningPrompt(players: [Player], systemPrompt: String) -> String {
        let roster = players.map(\.statSummary).joined(separator: "\n")
        return """
        \(systemPrompt)

        你是一個 TRPG GM。
        以下是目前房間玩家：
        \(roster)

        請輸出開場白 JSON：
        { "narration": "..." }
        """
    }

    func makeRoundPrompt(messages: [CampaignMessage], players: [Player], actions: [CampaignAction], systemPrompt: String) -> String {
        let recentStory = messages.suffix(6).map(\.text).joined(separator: "\n")
        let actionLines = actions.map { "\($0.playerName)：\($0.text)" }.joined(separator: "\n")
        let roster = players.map(\.statSummary).joined(separator: "\n")
        return """
        \(systemPrompt)

        最近劇情：
        \(recentStory)

        玩家狀態：
        \(roster)

        本回合行動：
        \(actionLines)

        請輸出結算 JSON：
        { "narration": "..." }
        """
    }
}
```

- [ ] **Step 5: Add async helpers that resolve opening and round narration**

```swift
func generateOpeningNarration(players: [Player], configuration: AIHostConfiguration) async throws -> String {
    let prompt = makeOpeningPrompt(players: players, systemPrompt: configuration.systemPrompt)
    let narration = try await AIService(configuration: configuration).sendMessage(prompt: prompt)
    return narration.narration
}

func resolveRound(messages: [CampaignMessage], players: [Player], actions: [CampaignAction], configuration: AIHostConfiguration) async throws -> String {
    let prompt = makeRoundPrompt(messages: messages, players: players, actions: actions, systemPrompt: configuration.systemPrompt)
    let narration = try await AIService(configuration: configuration).sendMessage(prompt: prompt)
    return narration.narration
}
```

- [ ] **Step 6: Run build to verify the service refactor compiles**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project 'AI GM.xcodeproj' -scheme 'AI GM' -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/ai-gm-derived -clonedSourcePackagesDirPath /tmp/ai-gm-sourcepackages build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
git add 'AI GM/AIService.swift' 'AI GM/RuleEngine/GameEngine.swift'
git commit -m "feat: add provider adaptive ai resolution"
```

### Task 3: Rebuild CampaignService Around Phases, Rounds, And Confirmed Actions

**Files:**
- Modify: `AI GM/CampaignService.swift`
- Modify: `AI GM/CampaignModels.swift`
- Test: Build the target and validate room lifecycle methods are reachable from the UI

- [ ] **Step 1: Replace string-only published state with typed room state**

```swift
@Published var campaignId: String?
@Published var campaignName: String = ""
@Published var hostId: String = ""
@Published var phase: CampaignPhase = .lobby
@Published var provider: String = ""
@Published var model: String = ""
@Published var currentRoundId: String?
@Published var currentRoundNumber: Int = 0
@Published var messages: [CampaignMessage] = []
@Published var players: [Player] = []
@Published var confirmedActions: [CampaignAction] = []
@Published var localErrorMessage: String?
```

- [ ] **Step 2: Update room creation to save public metadata and host-local configuration separately**

```swift
func createCampaign(name: String, playerName: String, configuration: AIHostConfiguration) async {
    let doc = db.collection("campaigns").document()
    campaignId = doc.documentID

    try? AIHostConfigurationStore.save(configuration, campaignId: doc.documentID)

    try await doc.setData([
        "name": name,
        "hostId": userId,
        "phase": CampaignPhase.lobby.rawValue,
        "provider": configuration.trimmedProvider,
        "model": configuration.trimmedModel,
        "createdAt": Timestamp(),
        "updatedAt": Timestamp()
    ])
}
```

- [ ] **Step 3: Add listeners for room document, messages, current round, and round actions**

```swift
private func listenCampaign() {
    guard let campaignId else { return }

    let listener = db.collection("campaigns")
        .document(campaignId)
        .addSnapshotListener { snapshot, _ in
            let data = snapshot?.data() ?? [:]
            self.campaignName = data["name"] as? String ?? ""
            self.hostId = data["hostId"] as? String ?? ""
            self.phase = CampaignPhase(rawValue: data["phase"] as? String ?? "") ?? .lobby
            self.provider = data["provider"] as? String ?? ""
            self.model = data["model"] as? String ?? ""
            self.currentRoundId = data["currentRoundId"] as? String
        }

    listeners.append(listener)
}
```

```swift
private func listenMessages() {
    guard let campaignId else { return }

    let listener = db.collection("campaigns")
        .document(campaignId)
        .collection("messages")
        .order(by: "timestamp")
        .addSnapshotListener { snapshot, _ in
            self.messages = snapshot?.documents.map { doc in
                let data = doc.data()
                return CampaignMessage(
                    id: doc.documentID,
                    kind: data["kind"] as? String ?? "gm",
                    text: data["text"] as? String ?? "",
                    roundNumber: data["roundNumber"] as? Int
                )
            } ?? []
        }

    listeners.append(listener)
}
```

Replicate this typed-decoding pattern for `listenPlayers()` and `listenCurrentRoundActions()`.

- [ ] **Step 4: Add action confirmation and cancellation APIs**

```swift
func confirmAction(text: String) async throws {
    guard let campaignId, let currentRoundId else { return }
    let playerName = players.first(where: { $0.id == userId })?.name ?? ""

    try await db.collection("campaigns")
        .document(campaignId)
        .collection("rounds")
        .document(currentRoundId)
        .collection("actions")
        .document(userId)
        .setData([
            "playerId": userId,
            "playerName": playerName,
            "text": text,
            "isConfirmed": true,
            "confirmedAt": Timestamp(),
            "updatedAt": Timestamp()
        ])
}
```

```swift
func cancelConfirmedAction() async throws {
    guard let campaignId, let currentRoundId else { return }
    try await db.collection("campaigns")
        .document(campaignId)
        .collection("rounds")
        .document(currentRoundId)
        .collection("actions")
        .document(userId)
        .delete()
}
```

- [ ] **Step 5: Add host-only start and continue transitions**

```swift
func startGame(using engine: GameEngine) async {
    guard isHost, let campaignId else { return }
    guard let configuration = AIHostConfigurationStore.load(campaignId: campaignId) else {
        localErrorMessage = "找不到房主 AI 設定"
        return
    }

    await updatePhase(.starting)
    let narration = try? await engine.generateOpeningNarration(players: players, configuration: configuration)
    try? await publishMessage(kind: "gm", text: narration ?? "GM 暫時無法產生開場白。", roundNumber: nil)
    try? await createRound(number: 1)
    await updatePhase(.collectingActions)
}
```

```swift
func continueRound(using engine: GameEngine) async {
    guard isHost, areAllPlayersReady, let campaignId else { return }
    guard let configuration = AIHostConfigurationStore.load(campaignId: campaignId) else {
        localErrorMessage = "找不到房主 AI 設定"
        return
    }

    await updatePhase(.resolvingTurn)
    let narration = try? await engine.resolveRound(messages: messages, players: players, actions: confirmedActions, configuration: configuration)
    try? await publishMessage(kind: "gm", text: narration ?? "GM 暫時無法產生本回合結算。", roundNumber: currentRoundNumber)
    try? await createRound(number: currentRoundNumber + 1)
    await updatePhase(.collectingActions)
}
```

- [ ] **Step 6: Add readiness helpers**

```swift
var isHost: Bool { hostId == userId }
var readyPlayerCount: Int { confirmedActions.count }
var areAllPlayersReady: Bool { !players.isEmpty && confirmedActions.count == players.count }
var myConfirmedAction: CampaignAction? { confirmedActions.first { $0.playerId == userId } }
```

- [ ] **Step 7: Run build to verify Firestore and async changes compile**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project 'AI GM.xcodeproj' -scheme 'AI GM' -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/ai-gm-derived -clonedSourcePackagesDirPath /tmp/ai-gm-sourcepackages build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: Commit**

```bash
git add 'AI GM/CampaignService.swift' 'AI GM/CampaignModels.swift'
git commit -m "feat: add multiplayer round state service"
```

### Task 4: Rebuild ContentView For Lobby Setup And Round-Based Multiplayer Play

**Files:**
- Modify: `AI GM/ContentView.swift`
- Modify: `AI GM/CampaignService.swift`
- Test: Build the target and manually walk through host and guest room flow

- [ ] **Step 1: Replace the old lobby form state with host and guest fields**

```swift
@State private var playerName = ""
@State private var campaignInput = ""
@State private var roomName = "Test"
@State private var provider = "OpenAI Compatible"
@State private var apiFormat: AIAPIFormat = .openAICompatible
@State private var baseURL = "https://api.openai.com/v1/chat/completions"
@State private var model = "gpt-4o-mini"
@State private var apiKey = ""
@State private var systemPrompt = "你是一個TRPG GM。"
@State private var actionDraft = ""
@State private var isSubmitting = false
```

- [ ] **Step 2: Replace the host create button so it saves host-local configuration**

```swift
Button {
    let configuration = AIHostConfiguration(
        provider: provider,
        apiFormat: apiFormat,
        baseURL: baseURL,
        model: model,
        apiKey: apiKey,
        systemPrompt: systemPrompt
    )

    Task {
        await campaign.createCampaign(name: roomName, playerName: playerName, configuration: configuration)
    }
} label: {
    Text("建立房間")
}
```

- [ ] **Step 3: Replace the game header and status chips**

```swift
Text(campaign.provider)
Text(campaign.model)
Text(campaign.phase.rawValue)
Text(campaign.isHost ? "房主" : "玩家")
Text("\(campaign.readyPlayerCount)/\(campaign.players.count) 已確認")
```

- [ ] **Step 4: Replace the message feed and action area with round-based controls**

```swift
if let confirmed = campaign.myConfirmedAction {
    Text("已確認：\(confirmed.text)")
    Button("取消確認") {
        Task { try? await campaign.cancelConfirmedAction() }
    }
} else {
    GameTextField(placeholder: "輸入本回合行動", text: $actionDraft)
    Button("確認行動") {
        Task { try? await campaign.confirmAction(text: actionDraft) }
    }
}
```

- [ ] **Step 5: Add host-only start and continue buttons**

```swift
if campaign.phase == .lobby && campaign.isHost {
    Button("開始遊戲") {
        Task { await campaign.startGame(using: engine) }
    }
}

if campaign.phase == .collectingActions && campaign.isHost && campaign.areAllPlayersReady {
    Button("繼續") {
        Task { await campaign.continueRound(using: engine) }
    }
}
```

- [ ] **Step 6: Surface local errors and keep guest editing private until confirmation**

```swift
.alert("錯誤", isPresented: .constant(campaign.localErrorMessage != nil)) {
    Button("好") { campaign.localErrorMessage = nil }
} message: {
    Text(campaign.localErrorMessage ?? "")
}
```

Only bind `actionDraft` to local `@State`. Do not write drafts to Firestore until `confirmAction(text:)` is called.

- [ ] **Step 7: Run build to verify the full UI integration compiles**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project 'AI GM.xcodeproj' -scheme 'AI GM' -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/ai-gm-derived -clonedSourcePackagesDirPath /tmp/ai-gm-sourcepackages build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: Perform manual multiplayer verification**

Manual checklist:

- launch the app on one simulator as host
- create a room with provider, API format, base URL, model, API key, and system prompt
- copy the room ID
- launch the app on a second simulator as guest
- join the room
- verify the guest sees provider and model but not base URL, API key, or system prompt
- start the game as host and verify a GM opening message appears
- type draft actions on both devices and verify unconfirmed text is only local
- confirm both actions and verify the ready count reaches all players
- cancel one action before continue and verify the ready count decreases
- reconfirm and continue as host
- verify a new GM narration appears and the next round begins

- [ ] **Step 9: Commit**

```bash
git add 'AI GM/ContentView.swift' 'AI GM/CampaignService.swift'
git commit -m "feat: add hosted multiplayer room flow"
```

### Task 5: Final Verification And Cleanup

**Files:**
- Modify: any touched files for final fixes only
- Test: final build and `git diff --stat`

- [ ] **Step 1: Run the final simulator build**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project 'AI GM.xcodeproj' -scheme 'AI GM' -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/ai-gm-derived -clonedSourcePackagesDirPath /tmp/ai-gm-sourcepackages build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: Review the final change footprint**

Run: `git diff --stat`
Expected: only the planned multiplayer/AI files show meaningful changes

- [ ] **Step 3: Commit any final polish**

```bash
git add 'AI GM/AIHostConfiguration.swift' 'AI GM/CampaignModels.swift' 'AI GM/AIService.swift' 'AI GM/RuleEngine/GameEngine.swift' 'AI GM/CampaignService.swift' 'AI GM/ContentView.swift' 'AI GM/Player.swift'
git commit -m "feat: finish hosted multiplayer ai flow"
```
