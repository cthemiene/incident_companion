# Incident Companion

A Flutter app for incident triage and update workflows with offline-first local persistence.

The app includes:
- Mock authentication with role-based behavior (`admin`, `manager`, `member`)
- Incident list with global search, status tabs, and top-down filters
- Incident creation flow with auto-generated ticket numbers (`INC-######`)
- Incident detail with assignment-aware update queueing
- My Items view scoped to the current signed-in user
- Shared search-based assignee selector in create/update flows
- My Profile dialog with org chart and role-gated editing
- Teams page in the 3-dot menu with role-based view/edit rules
- Hive-backed persistence for incidents, auth state, queued updates, and metadata counters

---

## Tech Stack

- Flutter (Material 3)
- `provider` for state management
- `go_router` for navigation and auth guards
- `hive` + `hive_flutter` for local persistence
- `uuid` for immutable IDs
- `intl` for date/time formatting

---

## Architecture Overview

```text
UI (Screens + Shared Widgets)
  -> Providers (Auth, Incidents, MyItems, Outbox)
    -> Repository (IncidentRepository / MockIncidentRepository)
      -> Local Storage (HiveService + Hive boxes)

Mock Directory Layer (Users + Orgs + Teams)
  -> mock_users.dart
  -> mock_org_teams.dart
  -> mock_scope_data.dart
```

### Layers

1. UI Layer
- `lib/features/**` and `lib/shared/widgets/**`
- Renders provider state and dispatches user actions

2. State Layer (Providers)
- `AuthProvider`: token/session state + role/scope identity
- `IncidentsProvider`: incident tabs, global search, filters, scoped loading
- `MyItemsProvider`: current-user assigned items, search, and filters
- `OutboxProvider`: queued update list + retry/delete/simulated sync

3. Data Layer
- `IncidentRepository` defines contracts
- `MockIncidentRepository` implements data access, filtering, paging, migrations, and queue writes

4. Persistence Layer
- `HiveService.initialize()` runs before `runApp`
- Boxes:
  - `incidents_box`
  - `outbox_box`
  - `auth_box`
  - `metadata_box` (`next_incident_number`)

---

## Role Model

- `Admin`
  - Can view and edit all teams
  - Can edit full profile and org-chart members
- `Manager`
  - Can edit current team on Teams page
  - Can view other teams
  - Profile and org chart are read-only
- `Member`
  - Can view current team only
  - Profile and org chart are read-only

---

## Routing & Auth Guard

Defined in `lib/app/router.dart`.

Routes:
- `/login`
- `/incidents`
- `/incidents/new`
- `/incidents/:id`
- `/my-items`
- `/teams`
- `/outbox` (legacy redirect to `/my-items`)

Redirect rules:
- If unauthenticated and not on `/login` -> `/login`
- If authenticated and on `/login` -> `/incidents`

---

## Data Models

Located in `lib/data/models/`.

### `Incident`
- `id` (internal immutable ID, UUID for new records)
- `incidentNumber` (monotonic numeric sequence)
- `displayId` (`INC-######` helper)
- `title`
- `description`
- `status` (`open`, `inProgress`, `resolved`)
- `severity` (`s1`, `s2`, `s3`, `s4`, `s5`) where `s5` is lowest/default
- `service`
- `organizationId`
- `teamId`
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

## Mock Directory (Centralized)

All mock org/team/user directory data is segmented in dedicated files:

- `lib/data/mock/mock_org_teams.dart`
  - Canonical org IDs
  - Canonical team IDs
  - Team definitions and update helpers
- `lib/data/mock/mock_users.dart`
  - Mock users and role/scope profiles
  - Org member lookup and profile update helpers
- `lib/data/mock/mock_scope_data.dart`
  - Shared org/team scope helpers for incident backfill/seed inference

Legacy `org-globo` references are normalized to `org-global` by repository/auth migrations.

---

## Feature Flow

### Sign in
- `LoginScreen` calls `AuthProvider.signIn()`
- Session token + role/scope are persisted to `auth_box`
- Router redirects to `/incidents`

### Browse incidents
- `IncidentsListScreen` loads incidents via provider
- Search is global across status tabs when search text is present
- Loading/empty/error/list states are fully handled

### Create an incident
- Open `/incidents/new`
- Display ID preview is auto-generated and read-only
- Save reserves next incident number from `metadata_box`
- Incident persists with UUID internal `id` + numeric `incidentNumber`

### Update an incident
- `IncidentDetailScreen` opens `UpdateIncidentSheet`
- Save queues `IncidentUpdate` to outbox and applies optimistic incident updates locally

### My Items
- Scoped to `AuthProvider.currentUserEmail`
- My Items-specific search and filters

### My Profile
- Open from 3-dot menu on incidents page
- Displays current user profile + org chart members
- Admin can edit profile and org chart entries
- Manager/member read-only

### Teams
- Open from 3-dot menu on incidents page
- View/edit behavior is role-gated:
  - Member: current team only (view)
  - Manager: edit current team + view all
  - Admin: edit all

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
    mock/
      mock_incident_seed.dart
      mock_org_teams.dart
      mock_scope_data.dart
      mock_users.dart
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
      profile_dialog.dart
    incidents/
      create_incident_screen.dart
      incident_detail_screen.dart
      incidents_list_screen.dart
      incidents_provider.dart
      widgets/
        assignee_selector_field.dart
        update_incident_sheet.dart
    my_items/
      my_items_provider.dart
      my_items_screen.dart
    outbox/
      outbox_provider.dart
      outbox_screen.dart
    teams/
      teams_screen.dart
  shared/
    utils/
      permissions.dart
      user_role.dart
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
- No secure auth provider yet
- No external directory/identity integration yet
- No real telemetry backend yet

Structure is in place to replace mocks with service integrations incrementally.

---

## Next Improvements

1. Replace mock repository with real API + DTO mapping
2. Add unit/widget tests for providers and role-gated flows
3. Add persistent team directory storage (Hive-backed team definitions)
4. Add server-driven org chart and directory search
5. Add stronger policy enforcement at repository boundary for team/profile writes

---

## License

Add your preferred license in this repository (for example, MIT).
