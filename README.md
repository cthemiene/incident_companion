# Incident Companion

A Flutter app for incident triage and update workflows with offline-first local persistence.

The app includes:
- Mock authentication
- Incident list with global search, status tabs, and top-down filters
- Incident detail with assignment-aware update queueing
- My Items view scoped to the current signed-in user
- Search-based assignee selection in update flow
- Legacy queue/sync simulation support (Outbox provider + sync simulation)
- Hive-backed persistence for incidents, auth token, and queued updates

---

## Tech Stack

- Flutter (Material 3)
- `provider` for state management
- `go_router` for navigation and auth guards
- `hive` + `hive_flutter` for local persistence
- `uuid` for update IDs
- `intl` for date/time formatting

---

## Architecture Overview

This project uses a layered architecture with clear responsibilities.

```text
UI (Screens + Widgets)
  -> Providers (AuthProvider, IncidentsProvider, MyItemsProvider, OutboxProvider)
    -> Repository (IncidentRepository / MockIncidentRepository)
      -> Local Storage (HiveService + Hive boxes)
```

### Layers

1. UI Layer
- Located in `lib/features/**` and `lib/shared/widgets/**`
- Renders state from providers
- Sends user actions to providers

2. State Layer (Providers)
- `AuthProvider`: authentication state + token persistence
- `IncidentsProvider`: incident list state, global search, tabs, filters
- `MyItemsProvider`: current-user assigned incidents, search, and filters
- `OutboxProvider`: queued update state and sync simulation behavior

3. Data Layer (Repository)
- `IncidentRepository` defines contracts
- `MockIncidentRepository` implements contracts and seeds sample data
- Handles filtering, pagination, queue writes, and reads

4. Persistence Layer (Hive)
- `HiveService.initialize()` runs before `runApp`
- Opens and manages:
  - `incidents_box`
  - `outbox_box`
  - `auth_box`

---

## Routing & Auth Guard

Defined in `lib/app/router.dart`.

Routes:
- `/login`
- `/incidents`
- `/incidents/:id`
- `/my-items`
- `/outbox` (legacy redirect to `/my-items`)

Redirect rules:
- If unauthenticated and not on `/login` -> redirect to `/login`
- If authenticated and on `/login` -> redirect to `/incidents`

---

## Data Models

Located in `lib/data/models/`.

### `Incident`
- `id`
- `title`
- `description`
- `status` (`open`, `inProgress`, `resolved`)
- `severity` (`s1`, `s2`, `s3`, `s4`, `s5`) where `s5` is the lowest default
- `service`
- `environment` (`prod`, `nonProd`)
- `createdAt`
- `updatedAt`
- `assignedTo` (optional)

### `IncidentUpdate`
- `id`
- `incidentId`
- `newStatus` (optional)
- `assignedTo` (optional)
- `comment`
- `visibility` (`workNotes`, `customerVisible`)
- `createdAt`
- `syncState` (`pending`, `failed`, `synced`)
- `lastError` (optional)

Manual Hive adapters are implemented and registered at startup.

---

## Feature Flow

### Sign in
- `LoginScreen` calls `AuthProvider.signIn()`
- Provider stores mock token in Hive `auth_box`
- Router redirects to `/incidents`

### Browse incidents
- `IncidentsListScreen` triggers `loadIncidents()` in `initState`
- Search is global across status tabs when search text is present
- Provider requests repository data with active tabs/search/filters
- UI renders loading, empty, error, or list states

### Review my assigned work
- `MyItemsScreen` is scoped to `AuthProvider.currentUserEmail`
- Includes My Items-only search and filters (status, severity, environment)
- Never shows incidents assigned to other users

### Queue an update
- `IncidentDetailScreen` opens `UpdateIncidentSheet`
- On save:
  - Creates `IncidentUpdate` (`pending`)
  - Stores status change and optional `assignedTo`
  - Writes to Hive outbox through repository
  - Applies local optimistic update to incident details
  - Refreshes outbox provider
  - Shows snackbar (`Update queued`)

### Assignment UX
- Update sheet supports searching assignees instead of static dropdown selection
- Signed-in user is prioritized and available as quick action (`Assign to me`)
- Supports clearing assignment (`Unassigned`)

### Queue and sync simulation
- `OutboxProvider` keeps queue state for retry/delete/simulate sync workflows
- `simulateSync()` randomly transitions pending items to `synced` or `failed`

---

## Folder Structure

```text
lib/
  app/
    router.dart
    theme.dart
  data/
    local/
      hive_service.dart
    models/
      incident.dart
      incident_update.dart
    repositories/
      incident_repository.dart
      mock_incident_repository.dart
  features/
    auth/
      auth_provider.dart
      login_screen.dart
    incidents/
      incident_detail_screen.dart
      incidents_list_screen.dart
      incidents_provider.dart
      widgets/
        update_incident_sheet.dart
    my_items/
      my_items_provider.dart
      my_items_screen.dart
    outbox/
      outbox_provider.dart
      outbox_screen.dart
  shared/
    widgets/
      empty_state.dart
      loading_skeleton.dart
      severity_badge.dart
      status_chip.dart
  main.dart
```

---

## Getting Started

### Prerequisites
- Flutter SDK installed
- Android emulator or physical device

### Install dependencies

```bash
flutter pub get
```

### Run

```bash
flutter run
```

### Analyze

```bash
flutter analyze lib
```

---

## Current Scope

This project is intentionally mock-first:
- No real backend integration yet
- No secure auth flow yet
- No real directory service for assignee lookup yet (mock user list)
- No real telemetry provider yet

It is structured so these can be added without major rewrites.

---

## Next Improvements

1. Replace mock repository with real API + DTO mapping
2. Add real sync engine and retry policy
3. Add tests:
- provider unit tests
- repository tests
- widget tests for list/detail/outbox states
4. Add pagination controls and infinite scroll
5. Add role/permission behavior for update visibility

---

## License

Add your preferred license in this repository (for example, MIT).
