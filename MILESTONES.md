# ParkBangla Milestone Plan

This roadmap assumes real payment gateway integration and production SMS/OTP delivery will be handled in the final stage because they require paid provider accounts or subscriptions. Until then, wallet and OTP can remain in controlled demo/sandbox mode.

## Milestone 1: Security And Access Control

Goal: make the existing API safe enough to build on.

Status: completed for the current prototype backend. Production payment/OTP provider controls remain in the final-stage milestone.

Must do:
- Add strict authorization checks to booking detail, booking messages, reviews, disputes, reports, wallet, and host spot actions.
- Ensure only the renter, spot host, or admin can access a booking.
- Ensure only booking participants can send/read booking messages.
- Prevent users from reviewing arbitrary users outside a completed booking.
- Validate all money amounts, dates, times, weekdays, vehicle IDs, and spot IDs.
- Add rate limiting for OTP request, login verification, search, booking creation, wallet actions, messaging, and uploads.
- Stop returning sensitive host/renter fields unless required by the client.
- Add backend tests for unauthorized access attempts.

Acceptance:
- A renter cannot access another renter's booking.
- A host cannot access bookings for spots they do not own.
- A user cannot message, review, or dispute unrelated bookings.
- Invalid booking/payment/location inputs are rejected consistently.

Completed implementation:
- Booking details are scoped to the renter, the spot host, or admin.
- Booking messages require booking participation.
- Reviews require completed bookings and can only target the other booking participant.
- Disputes require booking participation and non-empty notes.
- Wallet top-up/withdraw demo endpoints reject invalid amounts and empty methods/destinations.
- Booking creation validates date windows, time windows, weekday values, vehicle ownership, self-booking, and amount validity.
- Check-in/check-out now enforces valid booking lifecycle states and duplicate action prevention.
- Spot creation/update validates coordinates and prices.
- Spot patching now whitelists mutable fields so protected fields cannot be updated by crafted requests.
- Spot availability and block inputs are validated.
- Uploads are limited to JPEG, PNG, WebP, or PDF files up to 5 MB.
- OTP requests and core API surfaces have in-memory rate limiting suitable for the prototype stage.
- Backend regression tests cover booking access and wallet validation.

## Milestone 2: Availability And Booking Correctness

Goal: make parking inventory reliable.

Status: completed for the current schema/prototype backend. Public-holiday feeds, advanced calendar UI, and provider-backed payment settlement remain later milestones.

Must do:
- Improve availability rules beyond the current simple weekday/time model.
- Support same-day booking rules, overnight parking, unavailable dates, public holidays, and recurring exceptions.
- Add request expiry for pending host approval.
- Add no-show, late check-in, overstay, early checkout, and late checkout policies.
- Add host cancellation and renter cancellation policy variations.
- Prevent race conditions when two renters try to book the same spot at the same time.
- Add transactional conflict checks during booking creation.
- Add clear booking status transition rules.

Acceptance:
- Double booking is not possible under concurrent requests.
- Pending bookings expire automatically.
- Booking status changes follow a defined lifecycle.
- Host blocks and availability exceptions are respected.

Completed implementation:
- Booking-rule helpers now support midnight-crossing time windows.
- Booking conflicts are calculated from concrete date/time intervals instead of only broad date and string comparisons.
- Host blocks are checked against exact requested parking intervals.
- Parking spot availability is enforced before commuter-pass or instant booking creation.
- Pending booking requests expire after `PENDING_BOOKING_EXPIRY_MINUTES`, defaulting to 30 minutes.
- Expired pending bookings are cancelled and renter wallet holds are refunded through ledger and transaction records.
- Booking creation rechecks conflicts inside serializable transactions to reduce double-booking risk under concurrent requests.
- Booking list/detail/decide/cancel paths clear expired pending requests before acting.
- Check-in/check-out state transitions were tightened in Milestone 1 and now form part of the booking lifecycle rules.
- Backend tests cover overnight overlap, valid clock values, availability coverage, and precise host block conflicts.

Manual QA:
- Create a host spot with weekday availability, then book inside that available window. Expected: booking succeeds.
- Try booking outside the spot availability window. Expected: rejected with spot unavailable for schedule.
- Create a host block overlapping the desired booking time. Expected: booking is rejected.
- Create a host block on the same day but outside the desired booking time. Expected: booking is allowed if availability permits.
- Create an overnight availability window such as `22:00` to `02:00`, then book `23:00` to `01:00`. Expected: booking succeeds.
- Try a zero-length booking where start time equals end time. Expected: rejected.
- Try invalid clock values like `24:00` or `12:99`. Expected: rejected.
- Create two overlapping bookings for the same spot/time. Expected: second booking is rejected.
- Create two non-overlapping bookings for the same spot/day. Expected: both are allowed.
- Create a pending booking on a spot with `autoApprove=false`, wait beyond `PENDING_BOOKING_EXPIRY_MINUTES`, then list bookings. Expected: pending request becomes cancelled and renter balance is refunded.
- Try host approval after pending expiry. Expected: approval is rejected as expired/already decided.
- Check in a confirmed booking. Expected: status becomes active.
- Try checking in the same booking again. Expected: rejected.
- Check out an active booking. Expected: status becomes completed.
- Try checking out before check-in. Expected: rejected.

## Milestone 3: Map, Search, And Geo Scalability

Goal: make discovery behave like a modern map-based marketplace.

Status: completed for the current prototype scale. Full PostGIS/geospatial indexing should still be added before large-volume production launch.

Must do:
- Add database indexes for `ParkingSpot.active`, `lat`, `lng`, `area`, and common search filters.
- Move to PostGIS or equivalent geo indexing before large-scale launch.
- Improve search ranking using distance, text relevance, availability, verification status, and price.
- Add reverse geocoding for host-selected coordinates.
- Add saved recent searches.
- Add "available now" map filtering.
- Add deep links to Google Maps and Apple Maps for real navigation.
- Add entrance-specific location notes and photos.

Acceptance:
- Map search remains fast with thousands of listings.
- Search results prioritize actually bookable nearby spots.
- Hosts can confirm precise entrance location.
- Renters can open external navigation to the parking entrance.

Completed implementation:
- Parking spot, availability, block, and booking tables now have indexes for the common discovery and availability lookup paths.
- Map discovery requests can send visible map bounds so the backend narrows results before returning markers.
- Spot discovery can filter by a concrete availability window, including the mobile "Available now" filter.
- The mobile "Available now" filter sends the phone's local one-hour date/time window instead of relying on the hosted server timezone.
- Search combines app listings and OpenStreetMap place suggestions, and recent searches are saved locally for quick repeat searches.
- The host listing flow supports current location, address search, map tap placement, and reverse geocoding to fill address/area from exact coordinates.
- Renters can open external Google Maps navigation from the selected parking spot preview.
- Host spot listings already carry entrance coordinates, access notes, and photos; the map picker now makes those coordinates easier to confirm.

Manual QA:
- Open Discover with location permission allowed. Expected: map centers near the device location and nearby spots load.
- Deny location permission, then open Discover. Expected: app falls back gracefully to the default city view and still loads searchable spots.
- Search for a known Dhaka area. Expected: internal parking areas/listings and OpenStreetMap suggestions appear.
- Select an OpenStreetMap suggestion. Expected: map moves to that location and results refresh for the visible area.
- Repeat a previous search from the empty search box. Expected: recent-search chips appear and selecting one re-runs suggestions.
- Pan or zoom the map. Expected: the "Search this area" control appears, and tapping it reloads spots inside the current map bounds.
- Toggle "Available now" in filters. Expected: unavailable or already-booked spots for the current one-hour window disappear.
- Create a booking or host block for a spot covering the current time, then enable "Available now". Expected: that spot does not appear as available.
- Select a marker. Expected: the bottom preview matches the selected spot and shows distance, price, verification, and actions.
- Tap "Navigate" in the spot preview. Expected: Google Maps opens with directions to the spot coordinates.
- As a host, tap current location in the spot form. Expected: latitude/longitude are filled and the map marker moves there.
- As a host, tap a precise entrance point on the map. Expected: marker and coordinates update, and reverse geocoding fills address/area when available.
- Save the spot, then open it as a renter. Expected: the spot detail shows photos/access notes and map/navigation target the chosen entrance point.

## Milestone 4: Host Trust And Spot Verification

Goal: make listed spots trustworthy before renters rely on them.

Status: completed for the current prototype trust workflow. Production KYC provider integration and richer admin review screens remain later operational work.

Must do:
- Add host KYC workflow states separate from simple ID verified boolean.
- Add spot verification checklist for admin.
- Require spot entrance photo, parking bay photo, access instructions, and ownership/permission proof.
- Add duplicate spot detection by coordinate/address similarity.
- Add admin map review for submitted coordinates.
- Add spot rejection reasons and resubmission flow.
- Add host quality metrics: acceptance rate, cancellation rate, response time, completed bookings.

Acceptance:
- Admins can approve/reject spots with reasons.
- Renters can see whether a spot is verified.
- Duplicate or misleading listings are flagged.
- Hosts can fix rejected listings and resubmit.

Completed implementation:
- Added host KYC status fields separate from the existing `idVerified` boolean.
- Added host quality metric fields for acceptance rate, cancellation rate, and average response time.
- Added spot proof fields for entrance photo, parking bay photo, and ownership/permission proof.
- Added spot review fields for checklist items, admin notes, rejection reason, verified timestamp, resubmission timestamp, and duplicate candidates.
- New host spot submissions require address, area, access notes, entrance photo, bay photo, ownership/permission proof, valid coordinates, and valid prices.
- Spot updates/resubmissions reset verification back to pending and clear previous rejection/verified state.
- Duplicate candidate detection flags nearby or matching-address listings for admin review.
- Admin ID verification now updates the host KYC status.
- Admin spot approval can store checklist items and notes; rejection requires a reason.
- Renter spot detail now shows a trust notice for verified, pending, rejected, or unverified listings.
- Backend tests cover required listing proof fields, duplicate candidate tagging, and required admin rejection reasons.

Manual QA:
- As a host, try submitting a spot without access notes. Expected: submission is rejected.
- As a host, try submitting a spot without entrance photo, bay photo, or ownership proof. Expected: submission is rejected.
- Submit a complete spot with exact map coordinates and all proof fields. Expected: spot is created with `PENDING` verification.
- Submit another active spot at nearly the same coordinates or same address/area. Expected: the new spot stores duplicate candidate IDs for admin review.
- Open the admin app as admin. Expected: the spot appears in the Spots tab with pending verification.
- Tap Verify for the pending spot. Expected: status becomes `VERIFIED`, checklist/notes are stored, and renter detail shows the verified trust notice.
- Tap Reject for another pending spot. Expected: status becomes `REJECTED` with a rejection reason.
- Open the rejected spot as a renter. Expected: trust notice warns that verification was rejected.
- As the host, update/resubmit a rejected spot. Expected: status returns to `PENDING`, previous rejection reason is cleared, and resubmission time updates.
- Toggle a user's ID verification in admin. Expected: `idVerified` changes and KYC status becomes `VERIFIED` or `REJECTED`.

## Milestone 5: Renter Experience And Conversion

Goal: make finding and booking parking fast and clear.

Status: completed for the current renter booking flow. Production UX research, richer saved-spot screens, and full Bangla copy review can continue later.

Must do:
- Add filter controls for vehicle size, covered/open-air, security, access type, price, distance, availability now, hourly/daily/monthly.
- Add parking cards synchronized with selected map marker.
- Add favorites/saved spots.
- Add booking cost breakdown before confirmation.
- Add clear cancellation/refund policy before booking.
- Add empty states for no nearby parking, denied location, and unavailable selected time.
- Add onboarding that explains renter and host roles without blocking discovery.
- Fix text encoding issues in Bangla/English UI strings.

Acceptance:
- A renter can find a suitable available spot in under a few taps.
- Booking price, rules, and access method are clear before confirmation.
- Map and list never show contradictory selected spots.

Completed implementation:
- Added backend spot filters for vehicle size, access type, verified-only/security, and hourly/daily/monthly price caps.
- Added API-backed saved spots with scoped favorite list, save, and remove endpoints.
- Added a Saved toggle in Discover so renters can return to saved spots.
- Expanded Discover filters with vehicle size, covered/open-air, verified-only, access type, distance, available-now, and hourly/daily/monthly price focus.
- Kept map markers and card deck synchronized by using the same visible spot list after saved/filter state is applied.
- Added nonblocking renter onboarding tips on Discover with persistent dismissal.
- Added richer empty states for no nearby results, denied/unavailable location, and too-restrictive filters.
- Added booking cost breakdowns before commuter-pass and instant booking confirmation.
- Added clear wallet-hold, platform-fee, and cancellation/refund policy text before confirmation.
- Fixed core Bangla/English labels in the shared mobile i18n file.
- Backend tests cover saved-spot scoping.

Manual QA:
- Open Discover for the first time. Expected: renter tips banner appears without blocking search or map use.
- Dismiss the tips banner, close and reopen the app. Expected: the banner stays dismissed.
- Open filters and choose Sedan/SUV/Microbus. Expected: results only include spots whose supported vehicle sizes match.
- Filter by Guard, Gate code, or Remote. Expected: results only include the selected access type.
- Toggle Verified only. Expected: only spots with verified spot status and verified host ID appear.
- Switch price focus between Hourly, Daily, and Monthly, then lower the max price. Expected: results update using the selected price type.
- Toggle Available now with other filters. Expected: only bookable spots for the current one-hour window appear.
- Save a spot from the spot preview. Expected: the bookmark state changes and the spot is persisted for the signed-in user.
- Toggle Saved in Discover. Expected: map markers and cards show only saved spots.
- Remove a saved spot while Saved is active. Expected: it disappears from the saved-only list.
- Apply filters that match no results. Expected: a useful empty state appears with Adjust filters and Reset actions.
- Deny location permission and search manually. Expected: the app still works and explains the location limitation.
- Open commuter-pass checkout. Expected: renter sees monthly fare, renter platform fee, wallet after hold, and refund policy before confirming.
- Open instant checkout and switch hourly/daily. Expected: cost breakdown recalculates before confirming.

## Milestone 6: Host Operations

Goal: make hosting manageable after listing a spot.

Must do:
- Add host calendar view.
- Add edit spot flow for address, coordinates, photos, prices, availability, and access instructions.
- Add temporary block/unblock controls with date/time ranges.
- Add booking request inbox with accept/reject reasons.
- Add payout account setup placeholder for final payment integration.
- Add host earnings summary by day/week/month.
- Add host notifications for new request, cancellation, check-in, checkout, dispute, and payout.

Acceptance:
- A host can maintain accurate availability without contacting support.
- A host can edit/fix a listing after creation.
- A host can understand earnings and upcoming bookings.

## Milestone 7: Admin And Support Console

Goal: give operations enough control to run the marketplace.

Must do:
- Add searchable tables for users, spots, bookings, transactions, disputes, reports, and messages.
- Add admin detail pages for user, spot, booking, and dispute.
- Add manual booking cancellation/refund adjustment tools.
- Add moderation notes and audit logs.
- Add dispute evidence fields and timeline.
- Add support ticket workflow.
- Add fraud/risk flags for suspicious users, repeated cancellations, duplicate spots, failed check-ins, and abnormal wallet activity.
- Add admin role levels instead of single `isAdmin`.

Acceptance:
- Ops can investigate any incident from one dashboard.
- Every admin action is auditable.
- Disputes can be resolved with documented evidence and outcome.

## Milestone 8: Notifications And Communication

Goal: keep renters and hosts informed in real time.

Must do:
- Add notification preference settings.
- Add push notification deep links for booking, chat, dispute, and wallet events.
- Add unread message counts.
- Add chat attachments for photos/evidence.
- Add automated reminders for upcoming booking, check-in, checkout, pending approval, and expiring request.
- Add fallback in-app notifications when FCM delivery fails.

Acceptance:
- Users receive timely updates for booking-critical events.
- Tapping a notification opens the correct screen.
- Missed push notifications are still visible in-app.

## Milestone 9: Reviews, Reputation, And Safety

Goal: build marketplace accountability.

Must do:
- Allow reviews only after completed bookings.
- Add separate ratings for spot, host, and renter.
- Add structured review tags: easy access, accurate location, safe, clean, responsive host.
- Add report categories and evidence upload.
- Add safety center with emergency contacts and support escalation.
- Add block user/report user workflows.
- Add penalties for repeated no-show, cancellation abuse, or misleading listings.

Acceptance:
- Ratings reflect real completed transactions.
- Safety reports are actionable by admin.
- Bad actors can be restricted or removed.

## Milestone 10: Production Readiness

Goal: prepare for public launch.

Must do:
- Add CI for API tests, API build, Flutter analyze, and Flutter tests.
- Add environment-specific configuration for dev/staging/production.
- Add database migrations instead of relying only on `prisma db push`.
- Add backups, restore test process, and seed separation.
- Add structured logging and error tracking.
- Add API health checks and uptime monitoring.
- Add privacy policy, terms, cancellation policy, and host agreement.
- Add data retention rules for precise location and documents.
- Add load testing for search, map bounds, booking creation, and notification flows.

Acceptance:
- The app can be deployed repeatedly without manual database risk.
- Production incidents can be diagnosed from logs/metrics.
- Legal and privacy basics are in place.

## Final Stage: Payment And Production OTP

Goal: replace demo financial/authentication flows with real providers.

Must do:
- Integrate SMS OTP provider.
- Add OTP resend cooldown, attempt limits, fraud detection, and delivery status.
- Integrate bKash/Nagad/Rocket/card payment provider.
- Add payment intents, webhook verification, failed payment handling, refunds, payout settlement, and reconciliation.
- Replace demo wallet top-up with provider-confirmed top-up only.
- Add payout account verification for hosts.
- Add finance/admin reconciliation screens.

Acceptance:
- No wallet balance changes occur without verified provider events.
- Refunds and payouts are traceable.
- OTP cannot be brute-forced or abused.

## Suggested Build Order

1. Security and access control.
2. Availability and booking correctness.
3. Host edit/calendar operations.
4. Admin/support console.
5. Map/search scalability.
6. Renter conversion polish.
7. Reviews/reputation/safety.
8. Notifications and communication.
9. Production readiness.
10. Final payment and OTP integration.

## Definition Of Launch-Ready

ParkBangla should not be considered launch-ready until:
- Listings are verified and accurately located.
- Bookings cannot double-book a spot.
- Users cannot access other users' private booking data.
- Availability is reliable for real-world schedules.
- Admin can investigate and resolve incidents.
- Payments and OTP are provider-backed.
- Refunds, cancellations, no-shows, and overstays have enforceable policies.
- App behavior is tested on Android, iOS, and web where supported.
