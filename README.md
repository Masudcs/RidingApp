# RidingApps

A ride-hailing iOS app (SwiftUI, iOS 17+) with a rider side and a driver side. It currently runs
against in-memory mock services; a real backend is being added.

## Running it

1. Open `RidingApps.xcodeproj` in Xcode.
2. Pick a scheme and run:
   - `RidingApps-Dev` and `RidingApps-Staging` use mock services (no server needed).
   - `RidingApps-Production` uses the real API (`https://api.ridehailing.app`).
3. Sign-in is by phone number plus a one-time code. With mock services any 4–6 digit code works
   except `0000`.

The project file lists source files explicitly. After adding or removing a Swift file, regenerate
it with `python3 Scripts/generate_pbxproj.py` (or add the file in Xcode).

## Sending real SMS codes (optional, for testing)

The app never sends SMS itself; a server does. `Backend/dev_server.py` is a small dev server for
the auth endpoints (no packages to install):

```
python3 Backend/dev_server.py                        # prints codes in the terminal
SMS_PROVIDER=twilio TWILIO_ACCOUNT_SID=... TWILIO_AUTH_TOKEN=... TWILIO_FROM=+1... \
  python3 Backend/dev_server.py                      # sends real SMS
```

Then set `AUTH_API_BASE_URL` in `Config/Dev.xcconfig` (instructions are in that file). Only login
uses the server; everything else stays mocked. The server keeps state in memory and is for
development only. A new driver is auto-approved 20 seconds after submitting documents.
Login returns access/refresh tokens (`POST /auth/refresh` renews them); every endpoint except
`/auth/otp/*` and `/auth/refresh` needs `Authorization: Bearer <accessToken>`. Repositories get an
authenticated client from `APIClientFactory.make()`.

## Project layout

```
RidingApps/
  App/                 App entry point and Info.plist
  Root/Screens/        Top-level flow: RootScreen picks Auth, RiderRoot or DriverRoot
  Features/
    Auth/              Phone + OTP sign-in, role, profile, driver onboarding
    Session/           SessionStore: keeps the login in UserDefaults (uninstall clears it)
    Booking/           Booking flow, fare negotiation, scheduled rides, saved places
    Tracking/          Live trip tracking and chat
    Payments/          Wallet, checkout, promo codes, loyalty, referrals
    Ratings/           Rate a trip
    RideHistory/       Completed-ride history
    Safety/            SOS, emergency contacts, route deviation, trip recording
    Support/           Support chat and requests
    Demand/            Driver demand heatmap
    DriverEarnings/    Earnings, incentives, cash out
    Core/              Shared models, networking, design system, location, notifications
Config/                xcconfig per environment (Dev, Staging, Production)
Backend/               Dev server for auth (see above)
RidingAppsTests/       Unit tests (Swift Testing)
```

## How the code is organised

Each feature follows the same shape:

- `Screens/<Name>/<Name>Screen.swift`: the SwiftUI view.
- `Screens/<Name>/<Name>ViewModel.swift`: `@Observable` state and logic; the screen only displays it.
- `Repositories/`: an `I<Name>Repository` protocol, a real implementation that calls `APIClient`,
  and a `Mock<Name>Repository` used in Dev and Staging.

View models take their repository as an init parameter, defaulting to the mock or real one
depending on `AppEnvironment.current.usesMockServices`. Tests inject mocks directly.

Navigation is state-driven: `RootScreen` shows a flow based on `RootViewModel.currentUser`, and
screens such as `RiderHomeScreen` swap their content as the trip moves between stages.

## Environments

`APP_ENVIRONMENT` in each `Config/*.xcconfig` is read at runtime by `AppEnvironment`. It decides
the API base URL, whether mock services are used, and logging verbosity.

## Before connecting the real API

Things the code already marks as TODO or that need a decision:

- Auth tokens: `verifyOTP` must return tokens; `SessionStore` can already store them. Requests do
  not send an `Authorization` header yet (`URLSessionAPIClient`).
- Charges and cash-outs need an idempotency key so a retry after a timeout cannot pay twice.
- Remote push (APNs) is needed for alerts while the app is closed; current notifications are local.
- Referral credit and loyalty points are stored on the device and must move to the server.
- There is no way yet to resubmit rejected driver documents, or to delete an account.
