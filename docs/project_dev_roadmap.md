    # 🐾 PayPaw — Project Development Roadmap

> **Development plan from project initialization to production APK**

PayPaw is a personal financial obligations tracker built with **Flutter/Dart + Supabase**, designed to help users manage bills, subscriptions, debts, recurring payments, reminders, analytics, and upcoming financial obligations.

This roadmap covers the development process from **Sprint 1 through Sprint 85**, ending with a production-ready Android APK.

---

# 📋 Development Overview

| Stage                  | Sprints | Focus                 |
| ---------------------- | ------: | --------------------- |
| Project Foundation     |     1–5 | Setup & architecture  |
| UI/UX Foundation       |    6–10 | Design system         |
| Authentication         |   11–15 | Accounts & security   |
| First-Run Experience   | 11A–11B | Welcome & onboarding  |
| Database               |   16–20 | Supabase backend      |
| Bill Management        |   21–28 | Core bill features    |
| Recurring Bills        |   29–33 | Automation            |
| Dashboard              |   34–38 | Financial overview    |
| Notifications          |   39–43 | Reminders             |
| Calendar               |   44–47 | Payment scheduling    |
| Subscriptions          |   48–51 | Subscription tracking |
| Debt Management        |   52–56 | Utang/debt tracking   |
| Attachments            |   57–59 | Receipts & files      |
| Analytics              |   60–64 | Financial insights    |
| AI Features            |   65–70 | AI assistant          |
| AI Bill Scanner        |   71–74 | OCR & extraction      |
| Shared Bills           |   75–77 | Collaboration         |
| Security & Privacy     |   78–80 | Protection            |
| Testing & Optimization |   81–83 | QA                    |
| Release                |   84–85 | APK deployment        |

---

# 🏗️ Phase 1 — Project Foundation

## Sprint 1 — Project Planning

* Define PayPaw's core purpose
* Define target users
* Define MVP scope
* Define major features
* Define technical requirements
* Establish development milestones
* Create initial project documentation

## Sprint 2 — Flutter Project Initialization

* Create Flutter project
* Configure Dart
* Configure Android project
* Configure package/application ID
* Configure minimum Android SDK
* Initialize Git repository
* Create initial README

## Sprint 3 — Project Architecture

* Establish folder structure
* Define presentation layer
* Define domain layer
* Define data layer
* Define services
* Define models
* Define repositories
* Establish dependency injection strategy

## Sprint 4 — Development Environment

* Configure Android Studio
* Configure VS Code
* Configure Flutter SDK
* Configure Android SDK
* Configure emulator
* Connect physical Android device
* Configure debugging

## Sprint 5 — Dependencies & Infrastructure

* Add Supabase SDK
* Add routing package
* Add state management
* Add local storage
* Add notification dependencies
* Add image/file picker
* Add charting dependencies
* Configure dependency versions

---

# 🎨 Phase 2 — UI/UX Foundation

## Sprint 6 — Design System

* Define colors
* Define typography
* Define spacing
* Define border radius
* Define shadows
* Define button styles
* Define input styles
* Define card styles

## Sprint 7 — App Navigation

* Design bottom navigation
* Define primary screens
* Define navigation hierarchy
* Configure route management
* Add navigation transitions

## Sprint 8 — Reusable Components

Create reusable components for:

* Buttons
* Cards
* Inputs
* Dropdowns
* Chips
* Dialogs
* Bottom sheets
* Empty states
* Loading states
* Error states

## Sprint 9 — Responsive Layout

* Test different Android screen sizes
* Handle small screens
* Handle large screens
* Handle system font scaling
* Improve accessibility
* Prevent overflow issues

## Sprint 10 — Dark Mode

* Create dark theme
* Create light theme
* Theme switching
* Persist theme preference
* Verify all screens in both themes

---

# 🔐 Phase 3 — Authentication

## Sprint 11 — Supabase Project

* Create Supabase project
* Configure database
* Configure authentication
* Configure storage
* Configure environment variables

## Sprint 11A — Welcome Screen

Added after Sprint 21, once the app was run for the first time and dropped
straight onto the dashboard. Numbered 11A rather than inserted as a new Sprint 12
so the remaining seventy-odd sprint numbers keep meaning what they meant when
this roadmap was written and when the commits referencing them were made.

* Register image assets
* Create welcome screen with illustration background
* Value proposition and tagline
* Primary action to sign up
* Secondary action for returning users
* Show once, on first launch only
* Route above the shell, ahead of authentication

## Sprint 11B — Account Onboarding

Deliberately **not** a feature carousel. A three-slide tour of a bills app is the
most-skipped screen in mobile software, and it delays the user without leaving
anything behind. This onboarding does setup work instead, writing to the columns
the schema already has: `profiles.currency`, `profiles.time_zone` and
`reminder_preferences`.

It runs **after** sign-up rather than before, because every one of those writes
needs a session.

* Detect currency and time zone from the device, and confirm rather than assume
* Choose when reminders arrive
* Persist to `profiles` and `reminder_preferences`
* Skippable, with working defaults if skipped
* Run once per account, not once per install
* Progress indication and back navigation

---

## Sprint 12 — Registration

* Create registration screen
* Email validation
* Password validation
* Account creation
* Error handling

## Sprint 13 — Login

* Create login screen
* Email/password authentication
* Session handling
* Login errors
* Loading states

## Sprint 14 — Password Recovery

* Forgot password
* Reset password
* Password validation
* Recovery session handling

## Sprint 15 — Authentication State

* Persist sessions
* Automatic login
* Logout
* Session expiration
* Protected routes
* Authentication guards

---

# 🗄️ Phase 4 — Database Architecture

## Sprint 16 — Database Planning

Design database structure for:

* Users
* Bills
* Categories
* Payments
* Recurring bills
* Subscriptions
* Debts
* Attachments
* Notifications
* Shared bills

## Sprint 17 — User Tables

* Create profiles table
* Configure user relationships
* Add timestamps
* Add profile preferences

## Sprint 18 — Bill Tables

Create bill-related tables:

* Bills
* Bill categories
* Bill statuses
* Recurrence configuration

## Sprint 19 — Payment Tables

* Payment records
* Partial payments
* Payment methods
* Payment timestamps
* Payment references

## Sprint 20 — Supabase Security

* Configure Row Level Security
* Create policies
* Test user isolation
* Secure database queries
* Verify unauthorized access prevention

---

# 💸 Phase 5 — Bill Management

## Sprint 21 — Bill Model

* Create Dart bill model
* Serialization
* Deserialization
* Validation
* Database mapping

## Sprint 22 — Bill Repository

* Create bill repository
* Fetch bills
* Create bills
* Update bills
* Delete bills

## Sprint 23 — Add Bill UI

Create:

* Bill name
* Provider
* Amount
* Due date
* Category
* Notes

## Sprint 24 — Edit Bill

* Edit bill details
* Update amount
* Update due date
* Change category
* Modify notes

## Sprint 25 — Delete Bill — done

* Delete confirmation — an `AppConfirmDialog` that names what else goes with the
  bill, rather than asking "Are you sure?" The payment history is the part the
  user would actually miss.
* Soft delete strategy — archive sets `archived_at`; the list hides those rows by
  default and the app bar's switch brings them back. Without the switch the
  drawer's Restore could not be reached and the undo snackbar was the only route
  back, for four seconds — a soft delete nobody can undo is a hard delete wearing
  a friendlier word.
* Error handling — `BillActionState.errorMessage` reaches the screen. It had been
  recorded and never read, so a refused delete looked exactly like one that
  worked: dialog closed, sheet closed, row still there, no explanation.
* Undo support where appropriate — on archive, which is one reversible column.
  Deliberately not on delete: an Undo button on an operation that cannot be
  undone is a lie, and the confirmation stands in for it.

## Sprint 26 — Bill Details

Create detailed bill page showing:

* Amount
* Due date
* Provider
* Category
* Status
* Payment history
* Notes
* Attachments

## Sprint 27 — Bill Status

Implement:

* Upcoming
* Due today
* Paid
* Overdue
* Partially paid
* Cancelled

## Sprint 28 — Bill Search & Filters

Implement:

* Search
* Category filtering
* Status filtering
* Date filtering
* Amount filtering
* Sorting

---

# 🔁 Phase 6 — Recurring Bills

## Sprint 29 — Recurrence Model

Support:

* Weekly
* Bi-weekly
* Monthly
* Quarterly
* Yearly
* Custom

## Sprint 30 — Recurring Bill UI

* Recurrence selector
* Custom recurrence settings
* Next occurrence preview

## Sprint 31 — Automatic Bill Generation

* Generate future bills
* Calculate next due date
* Handle recurring status
* Prevent duplicates

## Sprint 32 — Recurring Bill Management

* Pause recurrence
* Resume recurrence
* Modify recurrence
* Cancel recurrence

## Sprint 33 — Recurrence Testing

Test:

* Month boundaries
* Leap years
* Different month lengths
* Year transitions
* Time zones
* Duplicate generation

---

# 🏠 Phase 7 — Dashboard

## Sprint 34 — Dashboard Structure

Create:

* Header
* Financial summary
* Upcoming bills
* Overdue section
* Quick actions

## Sprint 35 — Financial Summary

Display:

* Total upcoming
* Total paid
* Total overdue
* Monthly obligations

## Sprint 36 — Upcoming Payments

* Today
* Tomorrow
* This week
* Next week
* Later

## Sprint 37 — Quick Actions

Add:

* Add bill
* Mark paid
* Add debt
* Add subscription
* View calendar

## Sprint 38 — Dashboard Polish

* Animations
* Loading states
* Empty states
* Error states
* Performance optimization

---

# 🔔 Phase 8 — Notifications

## Sprint 39 — Notification Infrastructure

* Configure local notifications
* Android notification channels
* Notification permissions

## Sprint 40 — Bill Reminders

Implement:

* 7-day reminder
* 3-day reminder
* 1-day reminder
* Due-date reminder

## Sprint 41 — Overdue Notifications

* Detect overdue bills
* Notify users
* Prevent notification spam

## Sprint 42 — Notification Settings

* Global reminder settings
* Per-bill settings
* Enable/disable notifications
* Custom reminder times

## Sprint 43 — Notification Testing

Test:

* App closed
* Device restarted
* Time zone changes
* Multiple reminders
* Recurring bills

---

# 📅 Phase 9 — Payment Calendar

## Sprint 44 — Calendar UI

* Monthly calendar
* Weekly view
* Daily view
* Navigation

## Sprint 45 — Payment Indicators

Display:

* Paid
* Upcoming
* Overdue
* Partially paid

## Sprint 46 — Calendar Interaction

* Tap date
* View bills
* Open bill details
* Add bill from date

## Sprint 47 — Calendar Optimization

* Smooth navigation
* Large dataset support
* Performance optimization

---

# 📺 Phase 10 — Subscription Manager

## Sprint 48 — Subscription Model

Add:

* Subscription name
* Provider
* Amount
* Billing frequency
* Next billing date

## Sprint 49 — Subscription UI

* Subscription list
* Subscription details
* Add/edit/delete

## Sprint 50 — Subscription Analytics

Calculate:

* Monthly subscription cost
* Annual subscription cost
* Most expensive subscriptions

## Sprint 51 — Subscription Alerts

* Upcoming renewal
* Price changes
* Cancellation reminders

---

# 🤝 Phase 11 — Debt / Utang Management

## Sprint 52 — Debt Model

Support:

* Person/company
* Amount
* Due date
* Interest
* Notes
* Direction

## Sprint 53 — Money You Owe

* Create debt
* Record payments
* Track balance
* Track installments

## Sprint 54 — Money Owed to You

* Add borrower
* Track amount
* Partial payments
* Remaining balance

## Sprint 55 — Debt Dashboard

Display:

* Total owed
* Total receivable
* Upcoming debt payments
* Overdue debts

## Sprint 56 — Debt Analytics

* Payment history
* Debt progress
* Outstanding balance
* Debt trends

---

# 📎 Phase 12 — Attachments & Receipts

## Sprint 57 — Supabase Storage

* Create storage buckets
* Configure policies
* Secure file access

## Sprint 58 — Receipt Upload

Support:

* Camera
* Gallery
* PDF
* Images

## Sprint 59 — Receipt Management

* View receipts
* Delete receipts
* Download/open files
* Link files to bills

---

# 📊 Phase 13 — Analytics

## Sprint 60 — Analytics Architecture

* Define metrics
* Create analytics queries
* Optimize aggregation

## Sprint 61 — Monthly Analytics

* Monthly obligations
* Paid vs unpaid
* Overdue amounts

## Sprint 62 — Category Analytics

* Category totals
* Category percentages
* Largest categories

## Sprint 63 — Trends

* Month-to-month comparisons
* Increasing bills
* Decreasing bills
* Recurring expense trends

## Sprint 64 — Analytics UI

* Charts
* Graphs
* Summary cards
* Interactive filtering

---

# 🧠 Phase 14 — AI Financial Assistant

## Sprint 65 — AI Architecture

* Select AI provider
* Configure secure API access
* Create AI service
* Define data access boundaries

## Sprint 66 — AI Bill Queries

Support questions like:

* "What do I owe this week?"
* "What's due tomorrow?"
* "How much do I owe this month?"

## Sprint 67 — AI Financial Summary

Generate:

* Weekly summaries
* Monthly summaries
* Upcoming obligation summaries

## Sprint 68 — AI Insights

Generate insights about:

* Increasing bills
* Expensive subscriptions
* Recurring expenses
* Overdue payments

## Sprint 69 — Natural Language Search

Allow users to ask:

> "Show my bills above ₱2,000."

> "What subscriptions renew next week?"

> "Show overdue payments."

## Sprint 70 — AI Safety & Privacy

* Minimize data sent to AI
* Avoid exposing sensitive information unnecessarily
* Secure API keys
* Validate AI responses
* Add AI disclaimers where appropriate

---

# 📸 Phase 15 — AI Bill Scanner

## Sprint 71 — OCR Integration

* Camera integration
* Image processing
* OCR engine
* Text extraction

## Sprint 72 — Bill Information Extraction

Extract:

* Provider
* Amount
* Due date
* Account number
* Billing period

## Sprint 73 — Review & Confirmation

Before saving:

* Show extracted information
* Allow editing
* Validate fields
* Confirm bill creation

## Sprint 74 — Scanner Improvements

* Improve OCR accuracy
* Handle blurry images
* Handle different bill layouts
* Detect missing fields
* Improve error handling

---

# 👥 Phase 16 — Shared Bills

## Sprint 75 — Sharing Architecture

* Shared bill model
* User relationships
* Permissions
* Access rules

## Sprint 76 — Bill Splitting

Support:

* Equal split
* Custom split
* Percentage split

## Sprint 77 — Shared Payment Tracking

Track:

* Who paid
* Who hasn't paid
* Amount remaining
* Shared bill history

---

# 🔐 Phase 17 — Security & Privacy

## Sprint 78 — App Lock

Implement:

* PIN
* Biometric authentication
* Automatic locking

## Sprint 79 — Sensitive Data Protection

* Hide amounts
* Secure local storage
* Secure sessions
* Protect sensitive files

## Sprint 80 — Security Audit

Review:

* Supabase RLS
* Authentication
* Storage policies
* API security
* AI API security
* Database permissions
* Client-side secrets
* Debug logs

---

# 🧪 Phase 18 — Testing & Optimization

## Sprint 81 — Unit Testing

Test:

* Models
* Repositories
* Bill calculations
* Recurrence logic
* Debt calculations
* Safe-to-spend calculations

## Sprint 82 — Integration Testing

Test:

* Authentication
* Supabase
* Database operations
* File uploads
* Notifications
* AI features

## Sprint 83 — UI & Device Testing

Test on:

* Small Android devices
* Large Android devices
* Different Android versions
* Physical devices
* Emulator

Test:

* Light mode
* Dark mode
* Offline scenarios
* Poor network conditions

---

# 🚀 Phase 19 — Release Preparation

## Sprint 84 — Production Build

* Configure production environment
* Configure release signing
* Update application ID
* Configure app icon
* Configure splash screen
* Remove debug logs
* Optimize assets
* Update version number
* Build release APK

Run:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Verify:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Perform final installation testing on a physical Android device.

---

# 🏁 Sprint 85 — Final Release

## Final QA

* Test registration
* Test login
* Test bill creation
* Test bill editing
* Test bill deletion
* Test recurring bills
* Test reminders
* Test calendar
* Test subscriptions
* Test debts
* Test attachments
* Test analytics
* Test AI
* Test OCR
* Test shared bills
* Test app lock
* Test offline behavior

## Production Checklist

* [ ] Production Supabase configured
* [ ] Database migrations complete
* [ ] RLS policies verified
* [ ] Storage policies verified
* [ ] Authentication verified
* [ ] Notifications verified
* [ ] AI API secured
* [ ] Release signing configured
* [ ] App icon finalized
* [ ] Splash screen finalized
* [ ] Version number updated
* [ ] No debug credentials
* [ ] No development URLs
* [ ] No test data
* [ ] No debug logs
* [ ] Flutter analyzer passes
* [ ] Unit tests pass
* [ ] Integration tests pass
* [ ] APK tested on physical device

---

# 📦 Final APK

The final production APK should be generated using:

```bash
flutter build apk --release
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

For multiple architectures:

```bash
flutter build apk --release --split-per-abi
```

For Play Store distribution, generate an Android App Bundle:

```bash
flutter build appbundle --release
```

Output:

```text
build/app/outputs/bundle/release/app-release.aab
```

---

# 🏆 Definition of Done

PayPaw is considered production-ready when:

* Users can securely create accounts
* Users can manage bills
* Recurring bills work automatically
* Payment statuses are accurate
* Reminders work reliably
* Upcoming obligations are clearly displayed
* Subscriptions can be tracked
* Debts can be managed
* Receipts can be attached
* Analytics accurately reflect user data
* AI features work safely
* Bills can be scanned
* Shared bills work correctly
* Sensitive data is protected
* The application performs well
* The application works offline where supported
* The APK installs successfully
* The release build passes final QA

---

# 🐾 PayPaw Release Goal

The final version of PayPaw should feel less like a simple **bill reminder** and more like a personal **financial obligations command center**.

The user should be able to open PayPaw and immediately answer:

> **What have I paid?**
> **What do I owe?**
> **What's due next?**
> **How much should I prepare?**
> **Can I afford to spend this money?**

### Final Product

**PayPaw 🐾**

> **Stay ahead of what you owe.**
