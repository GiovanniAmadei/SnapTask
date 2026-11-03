# SnapTask Android: porting status

Native Kotlin/Compose rewrite of the iOS app (reference: `SnapTask/`, branch feat/android from feat/mac-app).
All files use `package com.snaptask.app`, in folders named like the iOS ones.

Rules: stored icon names are SF Symbol names (drawn through kit/SFIcons.kt); strings use the iOS keys
(assets/i18n is a copy of Localizable.strings); JSON matches iOS Codable so an iOS backup imports;
completed tasks never struck through or dimmed; text never cut with an ellipsis; animations gradual.

Left out on purpose: iCloud sync, Spazi (needs sync), Watch, Mac, Live Activity (ongoing notification
instead), Mandala and AI Brain Dump (hidden on iOS too).

## Status
All iOS screens are ported. Tests: `./gradlew :app:testDebugUnitTest`. Debug builds only:
`adb shell am broadcast -n com.snaptask.app/.DebugSeedReceiver` fills the app and turns Pro on
(`--es lang de` switches language).

- [x] Foundation, models, managers, notifications, calendar, attachments, billing
- [x] Home, task form and detail, Focus, Rewards, Finance, Statistics, Journal
- [x] Settings, themes, app icons, categories, priorities, language, paywall, legal, welcome
- [x] Feedback, What's new (Firestore through REST, services/Firestore.kt)
- [x] Widgets (Glance): tasks, performance, large performance, finance, budgets, with their setup screen
- [x] Quick settings tile and launcher shortcuts instead of Control Center and App Shortcuts

Testers: `./gradlew :app:assembleBeta` makes `app/build/outputs/apk/beta/app-beta.apk`, like release
but with Pro unlocked and signed with the debug key. Never upload it to the store.

Automatic checks: `GalleryActivity` (debug) opens any screen by name; `androidTest/ExploreTest` uses every control of a screen,
one screen per process (`am instrument -e screen <name> -e seconds 25 ... com.snaptask.app.test/androidx.test.runner.AndroidJUnitRunner`).
It logs under the tag `EXPLORE`. Its DEAD lines are candidates, not bugs: in a gallery screen Save and Cancel have nowhere to go.

## Differences from iOS
- Calendar: "Device Calendar" and "Google Calendar" both read the phone's calendars (no Google sign-in).
- Feedback replies: no push (iOS only, APNs). A background check about once an hour posts the notification.
- Offer codes open the Play redeem page. Siri, Action Button and spoken "today's tasks" have no equivalent.

## Feedback
Separate from iOS: `feedback_android`, `votes_android`, `likes_android`. The Firestore rules allow them (copy of the rules in use:
`tools/firebase-admin/firestore.rules`). The reply scripts in `tools/firebase-admin` still write to `feedback` only.

## Before release
- Create the three products in Play Console; prices show "---" until then. Purchases are untested.
- Legal texts in assets/legal still describe Apple, iCloud and the App Store.
- Release signing is not configured.
