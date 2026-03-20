# SoupMap

SoupMap is a Vancouver-first iOS app for live, in-person coordination. People create lightweight activities like coding at a cafe, studying at UBC, or heading to the gym, and the city fills with soft bubbles that grow as others join.

## PART 1: Product framing

### What SoupMap is

SoupMap is a live social layer for Vancouver. It is built around intent, not long-tail planning. Users open the app to see what is happening right now, what is about to happen nearby, and where momentum is forming.

### What SoupMap is not

- It is not a traditional event marketplace.
- It is not optimized for week-ahead RSVPs.
- It is not a card-heavy feed product.

### Core product promise

- A map that feels alive the moment you open it.
- Small real-world gatherings feel meaningful, not empty.
- Joining is one tap, counts update instantly, and activity mass is visible.

### Launch market

- Vancouver only.
- Early density focused on coders, students, and builders.
- Category system keeps the product extensible beyond those initial cohorts.

## PART 2: MVP scope

### In scope

- Apple Sign In, with optional email magic-link fallback
- User profile with username, display name, avatar, bio, and interests
- Vancouver-focused map home screen
- Live activity bubbles with non-linear size scaling
- Create, join, leave, and report activity flows
- Realtime participant count updates via Supabase Realtime
- Blocked-user filtering
- Onboarding, permission prompts, privacy copy, and stable empty states

### Out of scope for V1

- Direct messaging
- Rich venue search
- Payments
- Long-form event pages
- Social graph / following
- Push notifications from a remote backend

### MVP success condition

SoupMap is successful when a user can open the app, understand the city pulse in under 5 seconds, join a live bubble in one tap, and watch the system react immediately.

## PART 3: Stack reasoning

### Frontend

- `SwiftUI`
  Chosen for speed of iteration, modern iOS ergonomics, great animation support, and strong compatibility with MVVM plus async/await.
- `MVVM`
  Keeps the UI declarative, business logic testable, and feature modules separated cleanly.
- `async/await`
  Makes auth, database, storage, and realtime refresh flows readable and resilient.

### Backend

- `Supabase Auth`
  Native fit for Sign in with Apple and passwordless email magic links.
- `Supabase Postgres`
  Clean relational model for users, activities, joins, moderation, and tags.
- `Supabase Realtime`
  Lightweight path to instantly update participant counts and bubble states.
- `Supabase Storage`
  Public avatar bucket keeps profile images simple for MVP.

### Map

- `Mapbox Maps SDK for iOS`
  Preferred over MapKit because the bubble experience depends on a more premium visual layer, better annotation control, strong SwiftUI support, and a darker, more polished default presentation.

## PART 4: System architecture

### App architecture

- `SoupMapApp`
  Bootstraps tokens, services, session state, and root routing.
- `AppEnvironment`
  Shared dependency container for services.
- `SessionStore`
  Owns auth session, current profile, onboarding state, and app-wide gating.
- Feature view models
  Own feature-specific state and orchestration.
- Service layer
  Encapsulates Supabase auth, profile, activities, moderation, storage, location, and notifications.

### Realtime architecture

1. App queries the denormalized `activity_feed` view for Vancouver activities.
2. App subscribes to `activities`, `activity_participants`, `activity_tags`, `reports`, and `blocks` changes as needed.
3. On change, the feed is refreshed and local optimistic state is merged.
4. The bubble engine recalculates radius, clustering, and animation state.

### Trust & moderation

- Users can report an activity with structured reasons plus notes.
- Users can block hosts.
- Blocked users are filtered out of the map feed on refresh.
- Database policies keep write access scoped to the acting user.

## PART 5: Database schema

### Tables

- `users`
  Public profile row keyed to `auth.users`.
- `categories`
  Canonical activity categories and accent colors.
- `tags`
  Reusable tag catalog.
- `activities`
  Core activity record with timing, host, coordinates, and participant count.
- `activity_participants`
  Join table for hosts and participants.
- `activity_tags`
  Join table between activities and tags.
- `reports`
  Moderation intake.
- `blocks`
  User-level blocking.

### Supporting database logic

- Trigger creates `public.users` rows for new auth users.
- Trigger auto-adds the host as an activity participant.
- Trigger recalculates `activities.participant_count` on join/leave.
- View `activity_feed` denormalizes host, category, and tags for fast reads.
- RLS policies scope writes to the current authenticated user.

## PART 6: App structure (folders/files)

```text
SoupMap/
├── App/
├── Core/
│   ├── Design/
│   ├── Extensions/
│   ├── Map/
│   ├── Models/
│   └── Utilities/
├── Features/
│   ├── ActivityDetail/
│   ├── Auth/
│   ├── CreateActivity/
│   ├── Map/
│   ├── Onboarding/
│   ├── Profile/
│   ├── Report/
│   ├── Settings/
│   └── Shared/
├── Resources/
└── Services/
    ├── Auth/
    ├── Backend/
    └── Location/
```

## PART 7: Screens

### Splash

- Branded opening state with subtle liquid motion.
- Holds while config and session bootstrap.

### Onboarding

- Explains live city layer concept.
- Requests location and notifications with product context.
- Ends on guest browsing or sign-in entry.

### Auth

- Sign in with Apple primary CTA.
- Email magic-link fallback.

### Map

- Main product surface.
- Vancouver-focused camera.
- Live bubble annotations, create button, profile entry, filters, and empty-state affordances.

### Create Activity

- Full-screen form with category, timing, tags, capacity, and inline map location picker.

### Activity Detail

- Bottom sheet with metadata, host info, state, tags, participant count, and join/leave/report actions.

### Profile

- Public identity and editable profile data.
- Avatar upload backed by Supabase Storage.

### Settings

- Notification controls, location access shortcuts, privacy policy, sign out.

### Report Flow

- Structured reason selection and optional notes.

## PART 8: Bubble system logic

### Bubble size scaling

- Base radius: `26`
- Formula: `radius = min(88, 26 + sqrt(participantCount) * 16)`
- Result:
  Small groups still feel present, larger groups grow meaningfully, but bubbles do not explode visually downtown.

### Rendering

- Bubble content uses layered circles, gradient fills, translucent halo, and blur-backed labels.
- No hard borders or pin metaphors.
- Each category has a low-saturation accent pair for subtle differentiation.

### Animation

- Idle pulse: slow breathing opacity and halo expansion.
- Data updates: spring-based size interpolation.
- Join feedback: short-lived outer ripple to simulate a droplet merging into the bubble.

### Overlap handling

- Nearby activities are clustered by distance threshold that tightens as zoom increases.
- Single activities render as individual bubbles.
- Cluster bubbles show nearby momentum count and zoom affordance.

### Expiration

- Activities with `end_time <= now()` are hidden from the live map.
- Detail state still resolves correctly if an open sheet crosses the end boundary.

### Performance

- Vancouver-only bounding keeps payload small.
- Feed uses a denormalized SQL view to avoid repeated joins on device.
- Realtime changes trigger light refreshes, not full app reloads.
- Bubble views stay lightweight and rely on SwiftUI animation primitives.

## PART 9: Implementation roadmap

1. Create iOS target, environment config, assets, and dependency wiring.
2. Implement session bootstrap, onboarding, auth, and permission flows.
3. Build live map shell with bubble annotations and empty state.
4. Add create activity, detail sheet, join/leave, report, and block flows.
5. Add Supabase schema, RLS, storage bucket setup, and realtime subscriptions.
6. Polish animation, onboarding, privacy copy, and App Store readiness details.

## PART 10+: Full codebase implementation

This repository includes:

- SwiftUI app source using MVVM and async/await
- Supabase-backed auth, profile, activities, moderation, storage, and realtime services
- Mapbox bubble map implementation
- SQL migration for schema, policies, triggers, and seed categories/tags
- Config files for Supabase and Mapbox secrets
- In-app privacy policy content and permissions handling

## Setup

### 1. Prerequisites

- Xcode 16+
- XcodeGen
- A Supabase project
- A Mapbox access token

### 2. Create local secrets config

Copy `Config/Secrets.example.xcconfig` to `Config/Secrets.xcconfig` and fill in:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `MAPBOX_ACCESS_TOKEN`
- `SOUPMAP_URL_SCHEME`
- `SOUPMAP_BUNDLE_ID`

### 3. Enable Supabase features

- Auth: enable Sign in with Apple and Email OTP / Magic Link
- Realtime: enable replication for `activities`, `activity_participants`, `activity_tags`, `blocks`, `reports`
- Storage: create public bucket named `avatars`
- SQL: run `supabase/migrations/20260320_0001_init_soupmap.sql`

### 4. Configure Apple Sign In

- Add the Sign in with Apple capability in your Apple Developer account
- Register the app bundle identifier and URL scheme
- Configure the Apple provider inside Supabase Auth

### 5. Configure email fallback

- Add `SOUPMAP_URL_SCHEME://auth/callback` as a redirect URL in Supabase
- Keep email magic links enabled in Supabase Auth settings

### 6. Generate the Xcode project

```bash
xcodegen generate
open SoupMap.xcodeproj
```

## Environment variables

Environment values are supplied via xcconfig:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `MAPBOX_ACCESS_TOKEN`
- `SOUPMAP_URL_SCHEME`
- `SOUPMAP_BUNDLE_ID`

They are read from `Info.plist` at runtime.

## App Store readiness notes

- Sign in with Apple is the primary auth path.
- Email magic link is implemented as an optional fallback.
- Location permission is requested contextually.
- Notification permission is requested contextually and powers local reminders.
- Privacy policy content is bundled in-app and mirrored in docs.
- The app ships with meaningful empty-state examples so the map never feels dead.

## Verification notes

This workspace does not include Xcode, so the project structure and source were written for handoff and generation on macOS, but could not be compiled or simulator-tested in this environment.
