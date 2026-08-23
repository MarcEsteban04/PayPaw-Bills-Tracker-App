# 🐾 PayPaw

> **Know what you owe. Know when it's due. Stay ahead of your payments.**

PayPaw is a personal financial obligations tracker built with **Flutter/Dart and Supabase**. It helps users organize, monitor, and manage bills, subscriptions, debts, recurring payments, and other financial obligations in one place.

Instead of focusing only on spending, PayPaw focuses on the money you **need to pay** — giving users a clear picture of upcoming obligations and how much money they should prepare.

---

## 🎯 Core Concept

PayPaw answers three simple questions:

* **What do I owe?**
* **When do I need to pay it?**
* **Can I afford my upcoming obligations?**

Users can add bills such as:

* 💡 Electricity
* 💧 Water
* 📶 WiFi / Internet
* 📱 Mobile plans
* 🏠 Rent
* 💳 Credit cards
* 🎬 Subscriptions
* 🎓 School payments
* 🤝 Personal debts
* 🛡️ Insurance
* 📦 Installments
* 💰 Loans
* 🧾 Other recurring payments

---

# ✨ Features

## 🏠 Dashboard

The dashboard provides an immediate overview of the user's financial obligations.

### Overview

* Total upcoming bills
* Amount already paid
* Remaining obligations
* Overdue payments
* Bills due today
* Bills due this week
* Monthly obligations
* Upcoming debt payments

### Example

```text
August 2026

Upcoming Obligations
₱12,450

Paid
₱8,200

Overdue
₱1,500

Safe to Spend
₱12,550
```

---

# 💸 Bill Management

Users can create and manage individual financial obligations.

Each bill can contain:

* Bill name
* Provider/company
* Amount
* Due date
* Category
* Payment status
* Recurrence
* Notes
* Account/reference number
* Attachments
* Payment history

### Supported Statuses

* Upcoming
* Due Today
* Paid
* Overdue
* Partially Paid
* Cancelled

---

# 🔁 Recurring Bills

PayPaw automatically handles recurring financial obligations.

Supported schedules:

* Weekly
* Bi-weekly
* Monthly
* Quarterly
* Semi-annually
* Yearly
* Custom recurrence

Example:

```text
PLDT
₱1,699
Every 15th
Monthly
```

After marking the current bill as paid, PayPaw automatically generates the next occurrence.

---

# 🔔 Smart Reminders

Users can configure reminders for individual bills.

Possible reminder schedules:

* 7 days before
* 3 days before
* 1 day before
* On the due date
* After becoming overdue

Example:

> 🔴 Electricity is due tomorrow
> ₱3,284 • Due August 25

Users can customize reminder settings per bill.

---

# 📅 Payment Calendar

A dedicated calendar displays all financial obligations.

### Indicators

🟢 Paid
🟡 Upcoming
🔴 Overdue
🔵 Partially Paid

Selecting a date displays all payments scheduled for that day.

---

# 🚨 Upcoming Payments

PayPaw provides a dedicated view for upcoming obligations.

## Next 7 Days

```text
Tomorrow
Electricity     ₱3,240

August 27
WiFi            ₱1,699

August 29
Spotify           ₱149

----------------------
Total            ₱5,088
```

This gives users a quick answer to:

> **"How much money do I need to prepare?"**

---

# 💳 Subscription Manager

Users can separately manage recurring subscriptions.

Examples:

* Netflix
* Spotify
* YouTube Premium
* ChatGPT
* iCloud
* Google One
* GitHub
* Adobe
* Gaming subscriptions

PayPaw calculates:

```text
Monthly subscriptions
₱2,847

Estimated yearly cost
₱34,164
```

Users can identify subscriptions they rarely use and decide whether to cancel them.

---

# 🤝 Debt / Utang Tracker

PayPaw includes a dedicated debt management system.

## Money You Owe

Track:

* Person/company
* Original amount
* Remaining balance
* Due date
* Interest
* Installments
* Payment history
* Notes

Example:

```text
You owe John

Original
₱10,000

Paid
₱2,500

Remaining
₱7,500
```

## Money Owed to You

Users can also track money that other people owe them.

Example:

```text
Maria owes you

₱3,000
Due September 1
```

Partial payments are supported.

---

# 📊 Analytics

PayPaw provides financial obligation analytics.

Users can view:

* Monthly obligations
* Yearly obligations
* Subscription spending
* Debt payments
* Most expensive bills
* Payment history
* Average monthly obligations
* Category breakdown
* Month-to-month changes

Example insight:

> **Your monthly obligations increased by 14% compared to last month.**

---

# 🧠 AI Financial Assistant

PayPaw can use AI to analyze the user's financial obligations.

Users can ask questions such as:

> "How much do I need to pay this week?"

> "What bills are due tomorrow?"

> "How much do my subscriptions cost per year?"

> "Which bills increased this month?"

> "Can I afford my upcoming payments?"

> "What are my biggest recurring expenses?"

The AI can generate a simple financial summary based on the user's PayPaw data.

---

# 📸 AI Bill Scanner

Users can photograph a physical bill or upload a digital bill.

PayPaw uses OCR/AI to extract information such as:

* Provider
* Amount
* Due date
* Billing period
* Account/reference number

The user can review the extracted information before saving it.

Example:

```text
Bill detected

Provider: Meralco
Amount: ₱3,284
Due Date: August 25, 2026

[ Add Bill ]
```

For recurring bills, PayPaw can ask:

> **"Make this a recurring bill?"**

---

# 💰 Safe-to-Spend

One of PayPaw's core financial insights is the **Safe-to-Spend** calculation.

Users can enter their current available money.

PayPaw subtracts upcoming financial obligations.

```text
Available Money
₱25,000

Upcoming Obligations
- ₱12,450

----------------
Safe to Spend
₱12,550
```

This gives users a practical number they can use when deciding whether they can afford additional purchases.

---

# 👥 Shared Bills

Users can share selected bills with:

* Partners
* Family members
* Roommates
* Friends

Example:

```text
Internet
₱1,699

Your share
₱850

Roommate
₱849
```

Shared bills can track who has already paid their portion.

Users should only share the specific financial information they choose.

---

# 📎 Attachments

Users can attach documents to bills.

Supported attachments can include:

* Receipts
* Screenshots
* PDF bills
* Payment confirmations
* Invoices

This gives each bill a complete payment history.

---

# 🔐 Privacy & Security

Financial information is sensitive, so PayPaw is designed with privacy and security in mind.

### Security Features

* Supabase Authentication
* Row Level Security
* Secure user-specific data access
* Biometric app lock
* PIN protection
* Hidden financial amounts
* Secure file storage
* Session management

Users can hide sensitive amounts:

```text
Total Upcoming
••••••

Safe to Spend
••••••
```

---

# 📱 Home Screen Widget

The PayPaw widget provides quick access to upcoming obligations without opening the application.

Example:

```text
PAYPAW

Upcoming

🔴 Electricity
₱3,240 — Tomorrow

🟡 WiFi
₱1,699 — Aug 27

🟡 Spotify
₱149 — Aug 29
```

---

# 🔥 Payment Streaks

PayPaw can optionally gamify financial responsibility.

Examples:

```text
🔥 6 months
Zero overdue bills

🏆 97%
Bills paid on time

💰 23
Bills successfully paid
```

This encourages users to consistently pay obligations on time.

---

# 🗂️ Categories

Bills can be organized into categories such as:

* Utilities
* Housing
* Internet
* Mobile
* Subscriptions
* Transportation
* Education
* Healthcare
* Insurance
* Loans
* Credit
* Personal Debt
* Government
* Other

Users can create custom categories.

---

# 🔎 Search & Filters

Users can quickly find financial obligations using:

### Search

Search by:

* Bill name
* Provider
* Person
* Reference number

### Filters

* Upcoming
* Paid
* Overdue
* Recurring
* Subscription
* Debt
* Category
* Date range
* Amount

---

# 📈 Financial History

PayPaw maintains a history of completed payments.

Users can review:

* Previous bills
* Payment dates
* Amounts paid
* Partial payments
* Payment methods
* Receipts
* Historical changes

This allows users to understand their payment patterns over time.

---

# ⚙️ User Settings

Users can configure:

* Currency
* Notification preferences
* Reminder defaults
* App lock
* Biometric authentication
* Theme
* Start of financial month
* Default categories
* AI preferences
* Data export
* Account settings

---

# 🌙 UI / UX

PayPaw should have a clean, modern, financial-focused interface.

### Design Principles

* Simple
* Minimal
* Fast
* Mobile-first
* Easy to scan
* Clear financial hierarchy
* Strong visual distinction between paid, upcoming, and overdue payments

The most important information should always be visible without requiring multiple screens.

---

# 🐾 Why PayPaw?

Traditional budgeting applications focus heavily on:

> **"Where did my money go?"**

PayPaw focuses on:

> **"Where does my money need to go next?"**

The application is designed around **financial obligations**, making it easier for users to prepare for upcoming payments and avoid missed due dates.

---

# 🛠️ Technology Stack

## Frontend

* Flutter
* Dart
* Material 3
* Responsive mobile UI
* Local caching/state management

## Backend

* Supabase
* PostgreSQL
* Supabase Authentication
* Supabase Storage
* Row Level Security
* Supabase Edge Functions

## AI

Potential AI capabilities:

* Bill analysis
* Financial summaries
* Natural-language queries
* Bill classification
* OCR extraction
* Payment predictions
* Spending insights

---

# 🚀 Development Roadmap

## Phase 1 — Foundation

* Project setup
* Flutter architecture
* Supabase configuration
* Authentication
* Database schema
* User profiles

## Phase 2 — Core Bills

* Bill CRUD
* Categories
* Due dates
* Payment statuses
* Recurring bills
* Payment history

## Phase 3 — Dashboard

* Financial overview
* Upcoming payments
* Overdue payments
* Monthly summaries
* Safe-to-Spend

## Phase 4 — Notifications

* Local notifications
* Reminder system
* Custom reminder schedules
* Overdue notifications

## Phase 5 — Advanced Tracking

* Subscriptions
* Debt/utang tracking
* Shared bills
* Attachments
* Payment calendar

## Phase 6 — Analytics

* Charts
* Monthly comparisons
* Category analytics
* Subscription analytics
* Financial trends

## Phase 7 — AI

* AI financial assistant
* Bill analysis
* AI summaries
* Natural-language financial queries
* Smart insights

## Phase 8 — AI Scanner

* OCR
* Bill image recognition
* Automatic bill extraction
* Recurring bill detection

## Phase 9 — Polish

* Biometric security
* Dark mode
* Animations
* Widgets
* Performance optimization
* Accessibility
* Offline support

## Phase 10 — Production

* Testing
* Security audit
* Error monitoring
* Database optimization
* App Store preparation
* Google Play preparation
* Production deployment

---

# 🎯 Target Users

PayPaw is designed for:

* Students
* Young professionals
* Employees
* Freelancers
* Families
* Couples
* Roommates
* People managing multiple subscriptions
* Anyone who regularly manages recurring payments

---

# 🏁 Final Goal

PayPaw should become a personal **financial obligations command center**.

When users open the app, they should immediately understand:

**What have I paid?**

**What do I owe?**

**What's due next?**

**How much should I prepare?**

**How much can I safely spend?**

> **PayPaw — Stay ahead of what you owe. 🐾**
    