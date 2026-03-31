# Multiplayer Hosted AI Design

## Goal

Turn the current turn-based prototype into a room-based multiplayer flow where the host configures the AI provider on their device, other players join the room, each player prepares and confirms an action for the round, and the host advances the story by sending the consolidated round state to the AI.

## Current State

The app is currently a shared Firestore room with:

- a campaign document
- a `players` subcollection
- a `messages` subcollection
- a `currentTurn` field used for single-player-at-a-time input

AI requests are made locally through `AIService`, which currently has a hard-coded API key and assumes one fixed remote API shape.

## Product Direction

This feature will treat the host player as the room's AI executor:

- The host creates the room and configures the AI provider.
- The host's device is the only client allowed to call the AI API.
- Other players never need the API key.
- Firestore remains the shared source of truth for room state, player state, round actions, and story messages.

The AI provider must not be restricted to OpenAI. A room may use:

- a hosted commercial provider
- another player's preferred provider
- a self-hosted model endpoint

The app should therefore model AI access as a provider-agnostic integration point.

This is "hosted P2P" rather than direct peer-to-peer networking. The app does not need socket-based peer discovery or direct device-to-device transport in this version.

## Privacy Boundary

### Shared in Firestore

Only non-sensitive room AI metadata is shared:

- `provider`
- `model`
- `hostId`
- room phase and round state

### Host-only on Device

These values stay on the host device only:

- `baseURL`
- `apiKey`
- `systemPrompt`
- `apiFormat`
- any provider-specific headers or options

Other players should only see which provider and model are hosting the room.

## Room Lifecycle

### 1. Lobby

- Host creates a room with player name plus AI settings.
- Room starts in `lobby`.
- Players can join and appear in the lobby list.
- Host can review visible players and start the game.

### 2. Game Start

- When the host taps Start, room phase changes to `starting`.
- The host device validates that a local AI configuration exists for the current room.
- The host device sends an opening prompt to the AI.
- The AI opening narration is stored as a story message.
- A new round is created and room phase changes to `collectingActions`.

### 3. Collect Actions

- Each player has a private editable draft for the current round.
- Drafts are not visible to other players.
- When a player taps Confirm, their action becomes public for the room and marks them ready.
- Before the host resolves the round, a player may cancel confirmation and edit again.

### 4. Resolve Round

- Once all players are confirmed, the host can tap Continue.
- Room phase changes to `resolvingTurn`.
- The host device reads:
  - current story context
  - public player stats
  - all confirmed actions for the round
- The host device sends one consolidated AI request.
- The AI response is stored as the next GM message.
- A new round is created and phase returns to `collectingActions`.

### 5. End or Abort

Version one does not need a full campaign ending flow.
- A `finished` phase can be reserved for future use.
- A temporary host disconnect should simply block start/continue until the host returns.

## Recommended Interaction Model

The game should move from "one active player turn" to "one shared round".

### Why this model

- It matches the user's desired tabletop feeling.
- It lets players act simultaneously and then resolve together.
- It reduces AI cost because there is one AI request per round instead of one per player.
- It removes the need for strict player turn ownership in the UI.

## Firestore Data Model

### `campaigns/{campaignId}`

Core room document:

- `name: String`
- `hostId: String`
- `phase: String` with values `lobby`, `starting`, `collectingActions`, `resolvingTurn`, `finished`
- `provider: String`
- `model: String`
- `currentRoundId: String?`
- `createdAt: Timestamp`
- `updatedAt: Timestamp`

No `apiKey`, `baseURL`, or `systemPrompt` is stored here.

### `campaigns/{campaignId}/players/{playerId}`

- `name: String`
- `hp: Int`
- `strength: Int`
- `dexterity: Int`
- `intelligence: Int`
- `isConnected: Bool` for future presence use
- `joinedAt: Timestamp`

### `campaigns/{campaignId}/messages/{messageId}`

Story and log messages:

- `kind: String` such as `system`, `gm`, `playerActionSummary`
- `text: String`
- `roundNumber: Int?`
- `timestamp: Timestamp`

### `campaigns/{campaignId}/rounds/{roundId}`

- `number: Int`
- `status: String` with values `collecting`, `ready`, `resolving`, `resolved`
- `createdAt: Timestamp`
- `resolvedAt: Timestamp?`

### `campaigns/{campaignId}/rounds/{roundId}/actions/{playerId}`

Public confirmed action state:

- `playerId: String`
- `playerName: String`
- `text: String`
- `isConfirmed: Bool`
- `confirmedAt: Timestamp?`
- `updatedAt: Timestamp`

Draft text should remain local to the device until confirmation. If the user closes the app mid-edit, losing an unconfirmed draft is acceptable in version one.

## Local Host Configuration Storage

Host-only AI settings should be stored locally on the device using `UserDefaults` in version one.

Suggested key structure:

- `hostAIConfig.<campaignId>.provider`
- `hostAIConfig.<campaignId>.apiFormat`
- `hostAIConfig.<campaignId>.baseURL`
- `hostAIConfig.<campaignId>.model`
- `hostAIConfig.<campaignId>.apiKey`
- `hostAIConfig.<campaignId>.systemPrompt`

This keeps room settings tied to a specific hosted campaign and allows the host to re-enter the room and continue.

Suggested initial `apiFormat` values:

- `openAICompatible`
- `ollama`

This gives version one a practical path to support both commercial providers and common self-hosted setups without pretending every AI API looks the same.

## Service Layer Changes

### `AIService`

Refactor from a hard-coded OpenAI service into a configurable provider adapter:

- accept `provider`
- accept `apiFormat`
- accept `baseURL`
- accept `apiKey`
- accept `model`
- support at least `openAICompatible` and `ollama`
- isolate request-building differences behind small adapter methods or types
- keep the app-facing result format consistent
- fail clearly when required host config is missing

The app should not assume:

- one fixed authorization header pattern
- one fixed request body shape
- one fixed response payload shape

The app should normalize provider responses into the same internal result model used by the rest of the game flow.

### `CampaignService`

Expand room management responsibilities:

- create room with provider/model metadata
- track room phase
- track current round
- create round documents
- confirm player action
- unconfirm player action
- check if all players are confirmed
- resolve round state transitions

This service should own Firestore synchronization for multiplayer game state.

### `GameEngine`

Change from per-player turn resolution to per-round resolution:

- build opening prompt from room players
- build round prompt from story history plus confirmed actions
- optionally include player stats in prompt context
- return GM narration

Rule parsing and stat checks can remain simple in version one. The first milestone is multiplayer flow plus host-owned, provider-agnostic AI configuration.

## UI Design

### Lobby Screen

Host:

- enters player name
- enters provider
- chooses API format
- enters base URL
- enters model
- enters API key
- optionally enters system prompt
- taps Create Room

Guest:

- enters player name
- enters room ID
- taps Join

After room creation/join:

- show room ID
- show provider and model
- show joined players
- host sees Start Game button

### In-Game Screen

Top section:

- room ID
- provider/model badge
- phase badge
- host indicator

Middle section:

- story message feed
- optional compact player list with HP/stats
- ready status summary like "3/4 confirmed"

Bottom section:

- local action editor
- Confirm button when not confirmed
- Cancel Confirm button when already confirmed and round not resolving
- host-only Continue button when all players are confirmed

### Visibility Rules

- unconfirmed text is only visible to the local player
- confirmed actions are visible to all players
- Continue is only visible to the host
- Start Game is only visible to the host while in lobby

## Prompt Composition

### Opening Prompt

Include:

- role of the AI as TRPG GM
- room player list
- player stats
- optional host system prompt

Expected result:

- one opening narration message

### Round Prompt

Include:

- recent story context
- player list and stats
- all confirmed round actions
- optional instruction to summarize consequences clearly

Expected result:

- one narration describing how the round resolves

Version one should keep output format simple:

```json
{
  "narration": "..."
}
```

Provider adapters are responsible for translating between this internal expectation and the external API's native request/response format.

## Error Handling

- If host AI config is missing, host cannot start or continue and sees a clear local error.
- If the selected provider format is unsupported, room creation should be blocked locally before the room is hosted.
- If AI request fails during `starting` or `resolvingTurn`, phase returns to the previous actionable phase and an error message is shown locally.
- If a guest confirms action while another guest is still editing, that is valid.
- If a new player joins after the game starts, version one should reject or ignore the join attempt rather than dynamically rebalance the room.

## Security Notes

- Sensitive AI secrets must never be written into Firestore documents.
- Guests should not be able to transition room phase to `starting` or `resolvingTurn`.
- Guests should only be able to create or modify their own confirmed action record.

Firestore rules are not part of this first implementation in the app code, but the data model should anticipate those constraints.

## Testing Strategy

### Manual verification for version one

- create room as host with local AI config
- join from a second player
- verify guests can see provider/model but not private host settings
- start game as host and receive opening narration
- enter draft action as each player
- confirm action as each player
- cancel and edit before host continues
- continue as host after all players are confirmed
- verify AI narration appears and next round opens

### Future automated tests

- serialization tests for AI config storage
- prompt builder tests for opening and round prompts
- room phase transition tests
- action confirmation aggregation tests

## Scope Boundaries

Included in version one:

- host-owned AI configuration
- provider/model visible to room
- provider-agnostic AI integration with at least `openAICompatible` and `ollama`
- round-based action confirmation
- host-only start/continue flow
- opening narration plus per-round narration

Not included in version one:

- direct P2P networking
- encrypted secret sync
- reconnect-safe cross-device action drafts
- advanced GM memory management
- dynamic host transfer
- full campaign ending flow

## Open Decisions Resolved In This Spec

- Host device sends all AI requests.
- Host must stay online for the game to progress.
- Firestore only stores `provider` and `model` for room AI identity.
- `baseURL`, `apiKey`, `systemPrompt`, and transport details remain host-local.
- Unconfirmed player drafts are private; only confirmed actions are public.
- Round resolution is performed once per round, not once per player turn.
