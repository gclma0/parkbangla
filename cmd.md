Fix role-based access and implement the booking notification workflow.

Before making changes, inspect the current authentication/mock-user implementation, routing/navigation, role handling, booking state, and any existing notification components or services. Reuse existing architecture where possible rather than creating parallel systems.

1. Enforce proper Host/Renter role separation

Currently, when I log in using the built-in mock Renter account, I can still access Host features. This is incorrect.

The active role must determine what functionality the user can access.

Renter mode

When logged in as a Renter, the user should only be able to access Renter functionality, including applicable features such as:

Browse/search parking spots
Swipe/browse parking cards
View the map
View parking-space details
Add/manage their vehicles
Make bookings
View their bookings
Cancel/reschedule bookings where allowed
Check in/check out
View booking-related notifications
Review Hosts/spots after completed bookings

The Renter must not be able to access Host functionality such as:

Create a parking-space listing
Edit Host parking spaces
Set Host availability
Set parking prices
Approve/reject booking requests
View Host booking-management screens
View Host earnings/payout functionality
Access Host-only dashboard/navigation items
Host mode

When logged in as a Host, the user should only have access to Host functionality, including applicable features such as:

Create/manage parking-space listings
Manage availability
Manage pricing
View booking requests
Accept/reject bookings
Monitor active/upcoming bookings
View Host-specific notifications
View Host earnings/payout information where implemented

Host mode should not expose Renter-specific booking actions unless the account explicitly switches into Renter mode.

Important role rule

The SRS allows a single account to potentially support Host, Renter, or both roles. Preserve that capability if it already exists.

However:

Account roles and active role are not the same thing.

For example, if an account has:

roles = [RENTER, HOST]

but:

activeRole = RENTER

then Host functionality must not be accessible until the user explicitly switches to Host mode.

For the current built-in mock accounts:

Mock Renter → Renter access only
Mock Host → Host access only

Do not simply hide buttons in the UI. Enforce role authorization at all relevant layers:

Navigation/UI + protected routes/screens + API/backend authorization.

A Renter manually attempting to access a Host route/API must receive an appropriate unauthorized/forbidden response.

2. Implement a proper persistent notification system

The SRS requires booking-related push notifications, including booking confirmations and related booking events. Implement the notification workflow properly rather than relying only on temporary toast messages.

Notifications should be persisted so users can view them from a Notifications screen/list.

Each notification should support at minimum:

Notification ID
Recipient user ID
Recipient role where relevant
Notification type
Title
Message/summary
Related booking ID
Related parking-space ID where applicable
Created timestamp
Read/unread status
Deep-link/navigation target

Show an unread indicator/count in the appropriate notification icon/navigation element.

Opening a notification should mark it as read.

3. Renter creates booking → notify Host

When a Renter successfully submits a booking request, the Host who owns that parking space must receive a notification.

Example:

New booking request

You received a booking request for [Parking Space Name].

The notification should contain enough information to identify the booking, but clicking/tapping it must open the actual Host Booking Details screen.

The Host should then be able to see relevant booking information such as:

Parking-space name/location
Renter information permitted by the application
Vehicle information
Booking start date
Booking end date
Start time
End time
Number of hours/days booked
Booking type, e.g. instant/recurring where applicable
Booking amount
Booking status
Any other booking information already supported by the system

The Host must be able to clearly see how long the space is being requested for, not merely receive a generic notification.

If Host approval is required for that listing, the details screen should provide:

Accept Booking

and

Reject Booking

actions.

4. Host accepts booking → notify Renter

When the Host accepts a booking request:

Update the booking status appropriately.
Persist the status change.
Generate a notification for the Renter.

Example:

Booking accepted

Your booking for [Parking Space Name] has been accepted.

Clicking the notification should open the Renter's Booking Details screen showing information such as:

Parking-space information
Booking date(s)
Start/end time
Duration
Booking status: Accepted/Confirmed
Amount/payment information where applicable
Check-in/access information when appropriate
5. Host rejects booking → notify Renter

When the Host rejects a booking:

Update the booking status appropriately.
Persist the rejection.
Release any temporary reservation/availability hold if one exists.
Perform the appropriate payment/refund handling if applicable.
Generate a notification for the Renter.

Example:

Booking declined

Your booking request for [Parking Space Name] was not accepted.

Clicking the notification should open the appropriate booking-details/status screen containing:

Parking-space name
Requested date/time
Requested duration
Booking status: Rejected
Refund/payment status where relevant
Rejection reason if the application supports Host rejection reasons

Do not expose unnecessary private information in notification preview text.

6. Notification events must come from booking state changes

Do not implement notifications as disconnected frontend demo data.

They should be generated as a consequence of actual booking events:

Renter creates booking
→ BOOKING_REQUESTED
→ Host notification

Host accepts
→ BOOKING_ACCEPTED / CONFIRMED
→ Renter notification

Host rejects
→ BOOKING_REJECTED
→ Renter notification

The notification should reference the actual bookingId so clicking it always opens the correct booking.

Avoid duplicate notifications if the same operation/API request is accidentally submitted more than once.

7. Notification UX

Implement proper notification states:

Unread
Read
Empty notifications state
Loading state
Error/retry state

Sort notifications newest-first.

Clicking a notification should navigate directly to its relevant entity rather than simply opening the notification list.

Example:

BOOKING_REQUESTED
→ Host Booking Details

BOOKING_ACCEPTED
→ Renter Booking Details

BOOKING_REJECTED
→ Renter Booking Details

Test the complete role + booking workflow

After implementation, verify at minimum:

Scenario A

Login as Mock Renter
→ Host controls are unavailable
→ attempt direct Host route/API access
→ access denied

Scenario B

Login as Mock Host
→ Host functionality available
→ Renter-only functionality unavailable unless explicitly switching roles is supported

Scenario C

Renter books Spot A for Sep 5, 9 AM–5 PM
→ Host receives New Booking Request notification
→ Host clicks it
→ correct booking details open
→ Host can clearly see Sep 5, 9 AM–5 PM and calculated duration

Scenario D

Host accepts booking
→ booking status changes
→ Renter receives Booking Accepted notification
→ clicking it opens the correct booking

Scenario E

Host rejects booking
→ booking status changes
→ Renter receives Booking Rejected notification
→ clicking it opens the rejected booking details

Do not change unrelated functionality. Inspect the existing implementation first, make the smallest clean architectural changes necessary, and ensure authorization is enforced server-side rather than being purely cosmetic frontend hiding.