Implement a complete High-Precision Map, Real-Time User Location & Smart Parking Search system in the existing parking application.

This is a CORE / MUST-HAVE feature of the application, not an optional enhancement.

Before implementing anything, inspect the existing frontend/mobile app, backend, database models, APIs, authentication, parking listing model, current map implementation, and booking flow. Reuse the existing architecture and libraries wherever appropriate instead of unnecessarily rebuilding working functionality.

The expected map experience should be comparable in behavior to modern ride-sharing apps such as Uber or Pathao, particularly in terms of location accuracy, map navigation, zooming, current-location detection, and location search.

==================================================
1. HIGH-PRECISION INTERACTIVE MAP
==================================================

The map must support detailed geographic exploration.

A user must be able to start from a broad area such as Dhaka and progressively zoom into:

City
→ Area/Neighborhood
→ Sub-area
→ Road
→ Lane
→ Building/local landmark
→ Exact parking location

For example, Banani contains many roads, lanes and smaller locations. A parking spot may be located on a small road or relatively isolated location within Banani.

The map must therefore NOT treat "Banani" simply as one broad location.

Requirements:

- Support smooth map panning and deep zooming.
- Preserve street/road-level geographic detail.
- Allow users to explore small roads, lanes and isolated locations.
- Every parking listing must be represented by accurate latitude and longitude coordinates.
- Do not rely only on text addresses for positioning parking spots.
- Display parking spots as map markers at their actual coordinates.
- Markers must remain geographically accurate as the user zooms.
- Use appropriate map zoom levels when navigating to a selected location.
- Do not artificially restrict the map to only major neighborhoods.

==================================================
2. REAL-TIME USER LOCATION
==================================================

After a user creates an account/logs in and opens the application, the application should be capable of detecting and displaying the user's current location after obtaining the necessary location permission.

Implement a proper location permission flow.

When permission has been granted:

1. Obtain the user's current device location.
2. Use the most appropriate available GPS/network-assisted positioning.
3. Obtain latitude and longitude.
4. Consider the accuracy value returned by the device.
5. Display the user's position clearly on the map.
6. Center the map around the user's current location when appropriate.
7. Use an appropriate neighborhood/street-level initial zoom.
8. Load nearby parking spots around the user's current visible area.

The application should NOT simply open at a hardcoded location such as central Dhaka when an accurate user location is available.

For example:

User is physically in Banani
→ App detects current coordinates
→ Map opens around the user's position
→ User's location is visibly marked
→ Nearby parking spots are loaded
→ User can immediately explore nearby parking

Add a "Current Location" / recenter control.

If the user manually pans away from their location, pressing this control should:

- obtain/use the latest appropriate location;
- move the map back to the user's position;
- use an appropriate zoom level;
- refresh nearby parking if necessary.

Handle location updates appropriately if the user's position changes while using the map.

Do not continuously request GPS updates at an unnecessarily aggressive rate that would waste battery.

==================================================
3. LOCATION PERMISSION AND FAILURE HANDLING
==================================================

Location permission must be handled properly.

Possible states include:

- Permission not requested
- Permission granted
- Permission denied
- Permission permanently denied
- Device location/GPS disabled
- Location temporarily unavailable
- Location request timeout

Do not leave the user on a broken map if location cannot be obtained.

If permission is denied:

- Explain that location access helps find nearby parking.
- Keep the application usable.
- Allow manual map navigation.
- Allow location search.

If permission is permanently denied:

- Provide an appropriate option/instruction to enable it through application settings where supported.

If device location services are disabled:

- Tell the user that location services need to be enabled.
- Do not display a misleading current-location marker.

While detecting location, display a proper loading state rather than showing an incorrect location as though it were the user's position.

==================================================
4. ADVANCED LOCATION SEARCH
==================================================

Implement a smart location search/autocomplete system.

Search suggestions should appear while the user is typing.

Example:

User types:

"Ba"

Possible suggestions might include relevant locations such as:

Banani
Badda
Baridhara
Bashundhara
Banglamotor

Do NOT require the user to type the complete location name before suggestions appear.

Support searches for:

- Major areas
- Neighborhoods
- Sub-areas
- Roads
- Streets
- Lanes where supported by the map/geocoding provider
- Landmarks
- Addresses
- Parking spot/listing names
- Other useful geographic entities

Examples should include searches such as:

Banani
Banani DOHS
Road 11 Banani
Kemal Ataturk Avenue
Chairman Bari

Selecting a location suggestion must:

1. Resolve the selected geographic location.
2. Move/animate the map to it.
3. Set an appropriate zoom level based on the geographic result.
4. Query parking spots around/in the selected location.
5. Display relevant parking markers.

==================================================
5. PARKING-AWARE SEARCH
==================================================

Generic map autocomplete alone is not sufficient.

Integrate geographic search with the application's parking data.

Where practical, locations containing available parking listings should be identifiable and/or prioritized.

For example, a search for "Ba" could conceptually produce:

Banani — 18 parking spots
Baridhara — 7 parking spots
Bashundhara — 5 parking spots
Badda — 2 parking spots

Do NOT hardcode these numbers or locations.

Counts/results must come from actual parking data.

The system should combine:

External/geographic place search
+
Internal parking database search

Search should also be capable of finding parking listings directly by their relevant searchable information.

Implement sensible result ranking using factors such as:

- Text relevance
- Geographic relevance
- Parking availability
- Distance where appropriate
- Location popularity where reliable data exists

Do not fabricate popularity information if the selected provider does not supply it.

==================================================
6. MAP BOUNDS-BASED PARKING QUERY
==================================================

Do NOT load every parking listing in the database every time the map opens.

Parking retrieval must support geographic bounds.

Conceptually:

User opens/moves/zooms map
        ↓
Determine visible map boundaries
        ↓
Send geographic bounds to backend
        ↓
Backend queries parking locations within bounds
        ↓
Return matching parking spots
        ↓
Update markers

The backend should be capable of receiving an appropriate bounding box such as:

north latitude
south latitude
east longitude
west longitude

and returning parking locations inside the visible region.

Reuse existing geographic/database capabilities where possible.

The implementation must remain scalable as the number of parking listings grows.

Avoid sending requests continuously for every tiny map movement.

Use appropriate map-idle/debounce behavior so parking is fetched after meaningful map movement rather than generating excessive API traffic.

==================================================
7. "SEARCH THIS AREA"
==================================================

When a user manually pans or zooms away from the previously searched/current location, support a "Search this area" interaction where appropriate.

Example:

User searches Banani
→ Parking appears
→ User pans toward Gulshan
→ Map does not unexpectedly snap back to Banani
→ User can search the newly visible area
→ Backend queries the new map bounds
→ Parking markers update

Design this interaction cleanly for mobile use.

==================================================
8. PARKING MARKER CLUSTERING
==================================================

When many parking locations exist close together, do not create an unreadable pile of overlapping markers.

Implement marker clustering where supported.

Example:

Zoomed out:

[23 Parking Spots]

User zooms in:

[8]      [7]      [8]

Further zoom:

P   P   P   P   P

Clusters should progressively separate into smaller clusters/individual parking markers as the map is zoomed in.

==================================================
9. PARKING MARKER INTERACTION
==================================================

Tapping an individual parking marker should display a compact parking preview.

Use information already available in the existing parking model, such as where applicable:

- Parking name/title
- Location/address
- Price
- Availability
- Distance
- Parking type
- Relevant image

Do not invent fields that do not exist in the application without first determining whether they are necessary.

The preview must allow the user to proceed to the existing Parking Details screen.

Expected flow:

Map marker
→ Parking preview
→ View Details
→ Existing parking details screen
→ Existing booking flow

Do NOT make swiping or interacting with a map marker automatically create a booking.

Booking should continue through the application's existing explicit booking flow.

==================================================
10. MAP + LIST SYNCHRONIZATION
==================================================

If the existing discovery interface contains both map results and parking cards/list results, synchronize them.

When the visible map area changes:

→ Relevant parking results should update.

When the user selects a parking result:

→ Highlight/focus the corresponding map marker where appropriate.

When a map marker is selected:

→ Display/focus the corresponding parking information.

Do not create confusing independent map and list states.

==================================================
11. NEARBY PARKING
==================================================

When the user's current location is available, support nearby parking discovery.

Nearby results should use geographic coordinates rather than string matching against addresses.

Distance calculations should be based on latitude/longitude.

Do not treat two listings as "nearby" merely because both addresses contain something such as "Banani".

==================================================
12. HOST PARKING LOCATION CREATION
==================================================

Inspect the existing host parking creation/editing flow.

Because renters depend on accurate coordinates, hosts must be able to define the exact parking location.

Where appropriate, allow the host to:

- Search for an address/location
- Position the map
- Place/move a marker
- Use current location if appropriate
- Fine-tune the marker to the exact parking entrance/location

Persist:

latitude
longitude
human-readable address/location information

Do not silently save an approximate neighborhood center as the exact parking location.

Validate coordinates before saving.

Existing parking listings without coordinates must be handled gracefully.

==================================================
13. DATA MODEL & BACKEND
==================================================

Inspect the existing parking/location database schema before modifying it.

Determine whether parking listings already store:

latitude
longitude
address
area
city
or equivalent fields.

Reuse existing fields wherever possible.

If latitude/longitude are missing and schema changes are genuinely required, clearly identify the required migration before applying destructive changes.

Implement appropriate backend APIs/query parameters for:

- Visible map bounds
- Nearby parking
- Parking search
- Location-based filtering

Avoid inefficient approaches that retrieve all parking listings and filter them only on the client.

==================================================
14. MAP/GEOCODING PROVIDER
==================================================

Inspect the map technology already used by the project.

Do NOT replace an existing suitable provider unnecessarily.

Determine whether the existing provider supports:

- Detailed Bangladesh/Dhaka maps
- Deep street-level zoom
- Device location
- Geocoding
- Reverse geocoding
- Place autocomplete
- Latitude/longitude navigation
- Marker clustering

Reuse the current provider if it adequately supports the requirements.

If an additional API/service is genuinely required, explain:

- What is missing from the current implementation
- Which service is required
- Whether an API key is required
- Free-tier limitations
- Expected cost implications
- Android/iOS configuration requirements

before making a major provider change.

==================================================
15. PERFORMANCE
==================================================

The map must remain responsive.

Implement appropriate:

- Search debouncing
- Map movement debouncing
- Bounds-based loading
- Marker clustering
- Request cancellation/stale request protection where necessary
- Loading indicators
- Result caching where appropriate

Do not make a backend/API request for every character/map pixel movement without appropriate controls.

==================================================
16. PRIVACY & SECURITY
==================================================

Treat precise location as sensitive application data.

Do not unnecessarily persist a renter's continuous location history.

Only store location information when required by an existing legitimate application feature.

Do not expose private coordinates through logs unnecessarily.

Location permission should be requested because it is needed for nearby parking functionality, not simply because the user has logged in.

==================================================
17. UX EXPECTATIONS
==================================================

The overall experience should feel polished and familiar to users of modern ride-sharing/map applications.

Expected renter flow:

User logs in
      ↓
App requests location permission when needed
      ↓
Current location detected
      ↓
Map centers around user
      ↓
Nearby parking appears
      ↓
User can zoom to individual streets/lanes
      ↓
User can tap parking markers
      ↓
Preview parking
      ↓
View Details
      ↓
Book through existing booking flow

Alternative search flow:

User opens search
      ↓
Types "Ba..."
      ↓
Autocomplete suggestions appear
      ↓
Selects "Banani"
      ↓
Map moves/zooms to Banani
      ↓
Parking within relevant area appears
      ↓
User zooms into smaller roads
      ↓
Individual parking locations become visible
      ↓
Select parking
      ↓
View Details
      ↓
Book

Manual exploration flow:

User pans/zooms map
      ↓
"Search this area"
      ↓
Query visible geographic bounds
      ↓
Update parking markers/results

==================================================
18. IMPORTANT IMPLEMENTATION CONSTRAINTS
==================================================

This is an EXISTING application.

Do not unnecessarily rebuild existing working screens or architecture.

Before modifying anything:

1. Inspect the existing map implementation.
2. Inspect location-related dependencies.
3. Inspect parking database models.
4. Inspect parking APIs.
5. Inspect renter discovery flow.
6. Inspect host parking creation/editing.
7. Inspect authentication.
8. Inspect booking flow.
9. Determine what parts of these requirements already exist.
10. Only implement what is missing or incomplete.

Preserve existing:

- Authentication
- User roles
- Booking logic
- Parking details flow
- Backend conventions
- UI theme/design system
- Navigation architecture

Do not introduce mock parking data into production application logic.

Do not hardcode Dhaka neighborhoods.

Do not hardcode parking availability counts.

Do not hardcode user coordinates.

Do not automatically book parking from map interactions.

==================================================
19. FIRST REPORT BEFORE MAJOR CHANGES
==================================================

Before making any major architectural or provider changes, report:

A. Current map/location implementation
B. Existing map provider and packages
C. Existing location permission implementation
D. Existing parking coordinate fields
E. Existing map/search APIs
F. What already satisfies these requirements
G. What is missing
H. Backend changes required
I. Database changes required, if any
J. External API/provider requirements, if any
K. Files that will need modification

Then implement the feature using the smallest reasonable set of changes consistent with the existing architecture.

==================================================
20. ACCEPTANCE CRITERIA
==================================================

The implementation should not be considered complete until:

- User location can be detected after permission is granted.
- Current location is accurately represented on the map.
- Map can be zoomed into detailed roads/smaller locations.
- Parking spots use actual coordinates.
- Nearby parking can be discovered geographically.
- Typing partial location names produces autocomplete suggestions.
- Selecting a suggestion navigates the map correctly.
- Parking-aware search works with actual application data.
- Map bounds determine which parking spots are retrieved/displayed.
- Moving/zooming the map allows searching the new area.
- Dense parking markers are handled cleanly through clustering or equivalent behavior.
- Parking markers open useful previews.
- Parking previews lead to the existing details/booking flow.
- Current-location recenter works.
- Permission denial/GPS-disabled states are handled gracefully.
- Hosts can specify sufficiently precise parking locations.
- Map/list states remain synchronized where both are present.
- No existing booking/authentication functionality is broken.
- No hardcoded fake location/parking data is introduced.

After implementation, provide a concise report containing:

1. Files changed
2. Database/schema changes
3. New dependencies
4. New environment variables/API keys
5. Backend endpoints added/changed
6. Location permission changes
7. Map/search behavior implemented
8. Any remaining limitations
9. Exact commands I need to run
10. A manual QA checklist specifically for this feature