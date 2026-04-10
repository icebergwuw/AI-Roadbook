---
title: TravelAI Project Overview
tags: [ios, swiftui, ai, travel, swiftdata, supabase]
date: 2026-04-10
status: active-development
---

# TravelAI — Project Overview

## Summary

TravelAI is an AI-powered travel itinerary iOS application targeting Chinese-speaking users. It allows users to generate personalized multi-day travel plans via AI, then explore those plans through structured tabs covering itinerary, culture, map, chat, and tools.

The project is in **active early development**: core infrastructure and 3 of 8 feature tabs are fully implemented; 5 tabs remain as placeholders pending implementation.

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI Framework | SwiftUI |
| Persistence | SwiftData (iOS 17+) |
| State Management | `@Observable` (Swift 5.9 Observation framework) |
| Networking | `async/await` + `URLSession` |
| Backend (planned) | Supabase Edge Function (TypeScript/Deno) |
| AI Providers | OpenAI / Claude / DeepSeek (via backend proxy) |
| Maps | MapKit (planned, not yet integrated) |
| Minimum Deployment | iOS 17+ |
| Dependencies | None (pure Apple frameworks) |

---

## Architecture

### Navigation Model

```
ContentView (TabView — 5 bottom tabs)
├── HomeView              ✅ Complete
├── ItineraryView         ⚠️ Stub
├── [+] NewTrip sheet     ✅ Complete
├── CultureView           ⚠️ Stub
└── SettingsView          ⚠️ Stub (inline Text)

HomeView → TripDetailView (NavigationStack push)
TripDetailView (manual top tab bar — 5 tabs)
├── ItineraryView         ⚠️ Stub
├── CultureView           ⚠️ Stub
├── TripMapView           ⚠️ Stub
├── ChatView              ⚠️ Stub
└── ToolsView             ⚠️ Stub
```

### Data Flow

```
User Input
  → NewTripViewModel.generate()
  → AIService (POST to Supabase Edge Function)
  → AI Model (OpenAI / Claude / DeepSeek)
  → AIResponseParser.parse(json:)
  → SwiftData models (persisted locally)
  → @Query auto-refreshes HomeView
```

### SwiftData Model Graph

```
Trip (root)
├── [TripDay] → [TripEvent]
├── [ChecklistItem]
├── CultureData? → [CultureNode]
├── [Tip]
├── [SOSContact]
└── [Message]
```

All 9 models are cascade-deleted from their parent.

---

## Feature Status

| Feature | View File | ViewModel | Status |
|---|---|---|---|
| Home | `HomeView.swift` | `HomeViewModel.swift` | Complete |
| New Trip | `NewTripView.swift` | `NewTripViewModel.swift` | Complete |
| Trip Detail | `TripDetailView.swift` | — | Complete |
| Itinerary | `ItineraryView.swift` | — | Stub |
| Culture | `CultureView.swift` | — | Stub |
| Map | `TripMapView.swift` | — | Stub |
| Chat | `ChatView.swift` | — | Stub |
| Tools | `ToolsView.swift` | — | Stub |

---

## Design System

Defined in `Theme/AppTheme.swift` as a caseless `enum` with static properties.

- **Background**: Dark brown `#1E1408`
- **Accent**: Gold `#D4A017`
- **Card radius**: 12pt
- **Base padding**: 16pt
- Uses a `Color(hex:)` extension

---

## Known Issues

1. **ISO8601 date parsing bug** in `AIResponseParser.swift` — `ISO8601DateFormatter` fails on `"yyyy-MM-dd"` date-only strings; dates default to `Date()`. Should use `DateFormatter` with `dateFormat = "yyyy-MM-dd"`.
2. **Backend not created** — `supabase/` directory does not exist; `AIService.swift` contains placeholder credentials. App cannot call AI until Task 13 (Supabase Edge Function) is complete.
3. **5 ViewModels missing** — `ItineraryViewModel`, `TripMapViewModel`, `ChatViewModel` not yet created.
4. **No tests** — `Tests/` directory exists but is empty.
5. **`MockData.swift` missing** — needed for Xcode Previews and offline development.

---

## Planned Implementation Order (from docs/superpowers/plans)

1. Task 7 — Itinerary Tab (DayCalendarView, TimelineView, ChecklistView)
2. Task 8 — Culture Tab (KnowledgeGraphView, NodeDetailView)
3. Task 9 — Map Tab (TripMapViewModel, MapKit integration)
4. Task 10 — Chat Tab (ChatViewModel, message persistence)
5. Task 11 — Tools Tab (checklists, SOS contacts, tips)
6. Task 12 — MockData & Previews
7. Task 13 — Supabase Edge Function backend

---

## Related Docs

- `docs/superpowers/plans/2026-04-07-ios-app.md` — implementation task list
- `docs/superpowers/specs/2026-04-07-ai-travel-app-design.md` — product/design spec
