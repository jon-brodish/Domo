# Domo

Domo is a premium Apple-platform prototype for home maintenance and appliance health, designed to feel calm, fast, and trustworthy.

## Product Vision

Think "Things 3 for home systems":
- Track appliances and systems (HVAC, water heater, dishwasher, smoke/CO, exterior, and more)
- Manage recurring maintenance with elegant task workflows
- Surface a health score per system and for the home overall
- Use AI-assisted setup to suggest appliance metadata and recurring tasks from photo/model hints

## Current MVP Scope

- Dashboard with:
  - Overall home health score
  - Due soon tasks
  - Overdue tasks
  - Recently completed maintenance
- Systems list with health and next-service context
- System detail with:
  - Metadata, health ring, service timeline
  - Recurring maintenance list
  - Add task directly from the system view
- Tasks view with smart groupings:
  - Overdue, Today, Upcoming, Planned, Completed
  - Add task from a global task entry point
- Add System flow:
  - Manual setup
  - AI-assisted setup with review-before-save suggestions

## Tech Stack

- SwiftUI (macOS-first structure, adaptable to iOS/iPadOS)
- ObservableObject state container (`HomeStore`)
- Lightweight domain models (`HomeSystem`, `MaintenanceTask`, recurrence and health types)
- Service abstraction for AI setup (`AISetupService`) with a mock implementation

## Architecture

```
Domo/
  App/
  Models/
  Services/
  Store/
  Theme/
  Views/
    Dashboard/
    Systems/
    Tasks/
    AddSystem/
    Components/
```

## AI Integration Notes

`OpenAISetupService` is intentionally scaffolded for secure production integration.

- Do not hardcode API keys in source
- Use Keychain or backend token exchange for secrets
- Parse structured JSON responses from OpenAI and map into system/task suggestions

## Run Locally

1. Open `Domo.xcodeproj` in Xcode
2. Select the `Domo` scheme
3. Build and run on macOS or iOS simulator

## Roadmap Ideas

- Persistent storage with SwiftData
- Calendar timeline and maintenance history charts
- Document uploads (manuals/warranties)
- Notifications and smart reminders
- Rich AI recommendations by appliance category and age profile

## Status

Prototype quality, optimized for product exploration and interaction design iteration.
