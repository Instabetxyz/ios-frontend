# Plan: Live Stream iOS App with Dynamic SDK + 0G Storage

## Context

Build an iOS app for EthGlobal Cannes 2026 where users create short live video streams (max 60 seconds) that other users can watch in real-time. Users authenticate via Dynamic's Swift wallet SDK (embedded MPC wallets, no MetaMask needed). Live streams are delivered via HLS through the backend, and completed streams are archived to 0G decentralized storage

**Architecture**: iOS (SwiftUI + Dynamic SDK) → thin Node.js backend (HLS relay + 0G Storage SDK) → 0G chain (Galileo testnet)

---

## Live Streaming Architecture (HLS)

```
  BROADCASTER (iOS)                    BACKEND (Node.js)                  VIEWER (iOS)
  ─────────────────                    ─────────────────                  ────────────
  AVCaptureSession                                                       
  + AVAssetWriter                                                        
       │                                                                 
       │ Records 2-3s .ts segments                                       
       │                                                                 
       ├─── POST /api/streams/:id/segment ──►  Saves .ts to disk        
       │    (uploads each segment)              Updates .m3u8 playlist   
       │                                              │                  
       │                                              │◄── GET /api/streams/:id/live.m3u8
       │                                              │         AVPlayer (native HLS)
       │                                              │◄── GET /api/streams/:id/segments/:n.ts
       │                                              │                  
       ├─── POST /api/streams/:id/end ──────►  Stream marked complete    
                                               │                        
                                               ▼                        
                                         Concatenate all .ts segments   
                                         Upload full video to 0G Storage
                                         Return rootHash               
```

**How it works:**
1. Broadcaster starts a stream → backend creates a stream ID and empty `.m3u8` playlist
2. iOS captures video using `AVCaptureSession` + `AVAssetWriter`, outputting HLS segments (~2-3 seconds each)
3. Each segment is uploaded to the backend immediately via `POST /api/streams/:id/segment`
4. Backend appends the segment to the `.m3u8` playlist on disk
5. Viewers open the HLS URL in `AVPlayer` → iOS natively handles HLS playback, buffering, and segment fetching
6. When the broadcaster stops (or hits 60s), `POST /api/streams/:id/end` is called
7. Backend concatenates all segments into a single video file and uploads to 0G Storage
8. The completed stream remains playable from the archived 0G copy

**Latency**: ~4-6 seconds (2-3s segment duration + network round trip)

---

## Project Structure

```
Ethglobal-cannes-2026/
├── ios/LiveStream/
│   ├── LiveStream.xcodeproj
│   └── LiveStream/
│       ├── App/
│       │   ├── LiveStreamApp.swift             # @main, Dynamic SDK init
│       │   └── AppState.swift                  # ObservableObject, auth + wallet state
│       ├── Config/
│       │   └── Constants.swift                 # Dynamic env ID, backend URL
│       ├── Models/
│       │   └── Stream.swift                    # Stream metadata model
│       ├── Services/
│       │   ├── APIClient.swift                 # Backend HTTP calls
│       │   ├── WalletService.swift             # Dynamic SDK wallet wrapper
│       │   └── HLSBroadcastService.swift       # AVCaptureSession → segment → upload
│       ├── Views/
│       │   ├── RootView.swift                  # Auth gate → HomeView
│       │   ├── Auth/
│       │   │   └── AuthView.swift              # Dynamic showAuth()
│       │   ├── Home/
│       │   │   └── HomeView.swift              # Feed + create stream tab
│       │   ├── Stream/
│       │   │   ├── BroadcastView.swift         # Camera preview + go live + stop
│       │   │   ├── LivePlayerView.swift        # Watch a live stream (HLS)
│       │   │   ├── StreamPlayerView.swift      # Play archived stream from 0G
│       │   │   └── StreamFeedView.swift        # List of live + archived streams
│       │   └── Profile/
│       │       └── ProfileView.swift           # Wallet info, my streams
│       ├── Assets.xcassets
│       └── Info.plist                          # URL scheme + camera/mic permissions
├── backend/
│   ├── src/
│   │   ├── index.ts                            # Express app
│   │   ├── config.ts                           # Env vars, 0G constants
│   │   ├── services/
│   │   │   ├── storage.ts                      # 0G Storage SDK (reuse from 0g-easy-walks)
│   │   │   └── hls.ts                          # HLS playlist management + segment concat
│   │   └── routes/
│   │       └── streams.ts                      # All stream endpoints
│   ├── package.json
│   ├── tsconfig.json
│   └── .env
└── README.md
```

---

## Implementation Phases

### Phase 1: Backend — HLS Relay + 0G Storage (45 min)

**Goal**: Backend that receives HLS segments, serves live playlists, and archives to 0G.

1. Init Node.js/TypeScript project in `backend/`
2. Install deps: `@0gfoundation/0g-ts-sdk`, `ethers@6`, `express`, `multer`, `dotenv`, `typescript`, `ts-node`, `fluent-ffmpeg` (for segment concatenation)
3. Copy and adapt `storage.ts` from `0g-easy-walks/backend/src/services/storage.ts`
4. Write `config.ts` with 0G Galileo testnet config
5. Write `services/hls.ts`:
   - `createStream(id)` — creates a directory for segments + initial `.m3u8` playlist
   - `addSegment(streamId, segmentData, duration)` — saves `.ts` file, updates `.m3u8` with new `#EXTINF` entry
   - `finalizeStream(streamId)` — adds `#EXT-X-ENDLIST` to playlist, concatenates all `.ts` segments into a single `.mp4` using ffmpeg
6. Write `routes/streams.ts`:
   - `POST /api/streams/start` — body: `{ title, creatorAddress }` → creates stream ID, returns `{ streamId }`
   - `POST /api/streams/:id/segment` — multipart: `.ts` segment file + `duration` → appends to playlist
   - `POST /api/streams/:id/end` — finalizes stream, concatenates segments, uploads to 0G, returns `{ rootHash }`
   - `GET /api/streams/:id/live.m3u8` — serves the live HLS playlist
   - `GET /api/streams/:id/segments/:filename` — serves individual `.ts` segment files
   - `GET /api/streams` — returns list of all streams (live + archived) with status
   - `GET /api/streams/:id/archived` — proxies the full video from 0G storage
7. Write `index.ts` — Express app, CORS, static serving for segments
8. Test: simulate a stream by uploading sample `.ts` segments via curl, verify `.m3u8` updates, verify VLC/ffplay can play the HLS URL

**Env vars** (`.env`):
```
OG_PRIVATE_KEY=<funded Galileo wallet>
OG_RPC=https://evmrpc-testnet.0g.ai
OG_INDEXER=https://indexer-storage-testnet-turbo.0g.ai
OG_FLOW_CONTRACT=0x22E03a6A89B950F1c82ec5e74F8eCa321a105296
PORT=3000
```

**Key files to reuse**:
- `storage.ts` from `/Users/alok/Projects/Hackathons/0g-easy-walks/backend/src/services/storage.ts`
- `config.ts` pattern from `/Users/alok/Projects/Hackathons/0g-easy-walks/backend/src/config.ts`

### Phase 2: iOS Project Scaffold + Dynamic Auth (45 min)

**Goal**: App launches, user authenticates via Dynamic SDK, wallet is created.

1. Create Xcode project "LiveStream" with SwiftUI lifecycle, iOS 15+ target
2. Add Dynamic SDK via Swift Package Manager
3. Configure `Info.plist`:
   - URL scheme `livestream` for Dynamic auth callback
   - `NSCameraUsageDescription` and `NSMicrophoneUsageDescription` for AV capture
4. Write `LiveStreamApp.swift`:
   - Initialize `DynamicSDK` with `DynamicSDKConfiguration(environmentId:, appName: "LiveStream", appLogoUrl:, redirectUrl: "livestream://callback", appOrigin:)`
5. Write `AppState.swift`:
   - `@Published var isAuthenticated: Bool` — observe `sdk.auth.authenticatedUserChanges`
   - `@Published var walletAddress: String?` — from `sdk.wallets.userWallets`
6. Write `AuthView.swift` — calls `DynamicSDK.shared.showAuth()` on button tap
7. Write `RootView.swift` — shows `AuthView` when not authenticated, `HomeView` when authenticated
8. Write `Constants.swift` — Dynamic environment ID, backend base URL
9. Test: app launches → auth screen → login via email/social → wallet created → home screen

**Dynamic dashboard setup** (manual, before coding):
- Create project at dynamic.xyz, get environment ID
- Enable email OTP + Apple social login
- Enable embedded wallets
- Add 0G Galileo testnet as custom EVM network (chain ID 16602, RPC https://evmrpc-testnet.0g.ai)

### Phase 3: Live Broadcasting from iOS (75 min)

**Goal**: User taps "Go Live", camera starts, HLS segments are uploaded to backend in real-time.

1. Write `HLSBroadcastService.swift` — the core broadcasting engine:
   - Set up `AVCaptureSession` with video + audio inputs (front camera, mic)
   - Use `AVAssetWriter` to write video to a file
   - Every ~3 seconds, finalize the current segment file, start a new one
   - Segment rotation approach: use a timer to stop the current `AVAssetWriter`, create a new one for the next segment. Each segment is a self-contained `.ts` (or `.mp4` — backend can handle either)
   - After each segment is finalized, upload it to `POST /api/streams/:id/segment` in the background via `URLSession`
   - Track segment count and enforce 60-second max (stop after ~20 segments of 3s each)
   - Expose: `startBroadcast(streamId:)`, `stopBroadcast()`, `@Published var isLive: Bool`, `@Published var elapsedSeconds: Int`
2. Write `BroadcastView.swift`:
   - Camera preview using `AVCaptureVideoPreviewLayer` (wrapped in `UIViewRepresentable`)
   - "Go Live" button → calls `APIClient.startStream()` to get `streamId`, then `HLSBroadcastService.startBroadcast(streamId:)`
   - Live indicator (red dot + timer counting up)
   - "Stop" button → calls `HLSBroadcastService.stopBroadcast()`, then `APIClient.endStream(streamId:)`
   - Auto-stop at 60 seconds
3. Write `APIClient.swift` — stream management calls:
   - `func startStream(title: String, creatorAddress: String) async throws -> String` (returns streamId)
   - `func uploadSegment(streamId: String, segmentData: Data, segmentIndex: Int, duration: Double) async throws`
   - `func endStream(streamId: String) async throws -> StreamEndResponse` (returns rootHash)
   - `func getStreams() async throws -> [Stream]`
   - `func getHLSUrl(streamId: String) -> URL`
   - `func getArchivedUrl(rootHash: String) -> URL`
4. Test: go live → verify segments arriving at backend → verify `.m3u8` updates → verify VLC can play the live URL

### Phase 4: Live Viewing + Feed (45 min)

**Goal**: Users can see who's live and watch streams in real-time.

1. Write `StreamFeedView.swift`:
   - On appear + periodic refresh: call `APIClient.getStreams()`
   - Two sections: "Live Now" (streams with `status: "live"`) and "Recent" (archived streams)
   - Each stream card shows: title, creator address (truncated), status badge (LIVE / archived), timestamp
2. Write `LivePlayerView.swift`:
   - Takes a `streamId`, constructs HLS URL: `{backendURL}/api/streams/{streamId}/live.m3u8`
   - Uses `AVPlayer` + SwiftUI `VideoPlayer` — native HLS playback, no custom buffering logic needed
   - Shows "LIVE" badge, viewer count (stretch goal), stream title
   - When stream ends (playlist gets `#EXT-X-ENDLIST`), AVPlayer handles this gracefully
3. Write `StreamPlayerView.swift`:
   - For archived streams — loads video from `GET /api/streams/:id/archived` (proxied from 0G)
   - Same `AVPlayer` approach but with a regular video URL
4. Write `HomeView.swift`:
   - `TabView` with 3 tabs: Feed, Go Live (→ BroadcastView), Profile
5. Test: start a live stream on one device/simulator → open feed on another → tap live stream → watch in real-time


### Phase 5: Profile + Polish (20 min)

1. Write `ProfileView.swift`:
   - Show wallet address from Dynamic SDK
   - Show balance via `sdk.wallets.getBalance()`
   - List "My Streams" filtered by wallet address
   - Logout button via `sdk.auth.logout()`
2. Add loading states, error alerts, transition animations
3. Test full end-to-end flow

---

## Backend API

| Method | Path | Body | Response |
|--------|------|------|----------|
| `POST` | `/api/streams/start` | `{ title, creatorAddress }` | `{ streamId }` |
| `POST` | `/api/streams/:id/segment` | multipart: `segment` file + `duration` | `{ segmentIndex }` |
| `POST` | `/api/streams/:id/end` | — | `{ rootHash }` |
| `GET` | `/api/streams/:id/live.m3u8` | — | HLS playlist (m3u8) |
| `GET` | `/api/streams/:id/segments/:filename` | — | `.ts` segment file |
| `GET` | `/api/streams` | — | `[{ streamId, title, creatorAddress, status, rootHash?, createdAt }]` |
| `GET` | `/api/streams/:id/archived` | — | full video file (proxied from 0G) |

---

## Key Decisions

- **HLS for live streaming** — broadcaster records 2-3s segments, uploads each to backend, backend serves `.m3u8` playlist. Viewers use native `AVPlayer` HLS support. ~4-6s latency, acceptable for 60s streams.
- **No smart contract for MVP** — core value is live stream → watch → 0G archive. Payments/tipping can be added later.
- **ffmpeg for segment concatenation** — after stream ends, backend uses ffmpeg to merge `.ts` segments into a single `.mp4` before uploading to 0G.
- **JSON file for metadata** — backend stores stream metadata in a `streams.json` file. Sufficient for demo scale.
- **0G Storage SDK on backend only** — iOS never touches 0G directly.
- **60-second max streams** — enforced on both iOS (auto-stop) and backend (reject segments past limit).
- **AVAssetWriter segment rotation** — rather than using Apple's `AVAssetWriter` HLS output (which targets local file playback), we manually rotate writers every ~3 seconds to produce uploadable segments. Each segment is a standalone video file.

---

## Verification

1. **Backend HLS**: Upload sample `.ts` segments via curl → verify `.m3u8` updates → play in VLC with `http://localhost:3000/api/streams/:id/live.m3u8`
2. **Backend → 0G**: End a stream → verify concatenated video uploads to 0G → download via root hash
3. **iOS auth**: Launch app → Dynamic auth → verify wallet address appears
4. **iOS broadcast**: Go live → verify segments arriving at backend → verify `.m3u8` is playable
5. **iOS live viewing**: Start stream on device A → watch on device B via feed → verify ~5s latency
6. **iOS archived playback**: After stream ends → verify playable from 0G storage
7. **Full loop**: Auth → go live → watch on another device → stream ends → archived in feed → play archived → logout → login → streams persist
