-- =============================================================================
-- MODULE 2: Hidden Place Discovery
--
-- Every table this module owns, in dependency order (there are none - all three
-- stand alone). Run after schema/CreateUser.sql has created the database.
--
--     mysql -u root -p < database/schema/CreateHiddenPlace.sql
--
-- The three are deliberately separate rather than one table with more columns,
-- because they have three different lifetimes:
--
--   hidden_place_cache        disposable. Refilled from Google every 30 days,
--                             safe to TRUNCATE at any time.
--   place_photo               permanent. Each row is a photo already paid for;
--                             losing one means buying it from Google again.
--   hidden_place_suppression  permanent. Each row is a place the community
--                             voted out and must never see again.
--
-- That is why neither of the permanent tables has a foreign key to the cache:
-- an FK would tie their lifetime to the disposable one, and the 30-day refresh
-- would erase exactly the rows that exist to survive it.
-- =============================================================================

USE exploremy_dev;

-- Hidden place cache table (no dependencies)
--
-- A disposable cache of Google Places results, bucketed by cache_grid_key -
-- a "<place type>:<grid x>:<grid y>" key such as 'restaurant:118:5761'. Every row
-- fetched under the same bucket shares one fetched_at_utc, and a bucket is
-- replaced as a whole (old rows deleted, new rows inserted) when it goes stale.
-- Not a source of truth: safe to TRUNCATE at any time, it refills on the next
-- search. See backend/Application/HiddenPlace/Facade/SearchGridPlanner.cs.
--
-- fetched_at_utc is DATETIME(6) rather than TIMESTAMP because cache freshness is
-- compared against UTC "now" in code, and TIMESTAMP would apply session
-- timezone conversion on the way in and out.
CREATE TABLE IF NOT EXISTS hidden_place_cache (
    hidden_place_cache_id INT AUTO_INCREMENT PRIMARY KEY,
    cache_grid_key VARCHAR(255) NOT NULL,
    fetched_at_utc DATETIME(6) NOT NULL,
    place_id VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    primary_type VARCHAR(100) NOT NULL,
    latitude DOUBLE NOT NULL,
    longitude DOUBLE NOT NULL,
    rating DOUBLE DEFAULT NULL,
    user_rating_count INT NOT NULL DEFAULT 0,
    price_level INT DEFAULT NULL,
    business_status VARCHAR(50) NOT NULL DEFAULT 'OPERATIONAL',

    -- Presentation detail, cached so the app can show a place without a second
    -- round-trip to Google. None of it feeds the discovery algorithm.
    formatted_address VARCHAR(500) DEFAULT NULL,
    google_maps_uri VARCHAR(500) DEFAULT NULL,
    website_uri VARCHAR(500) DEFAULT NULL,
    national_phone_number VARCHAR(50) DEFAULT NULL,
    -- Google's `photos` array verbatim: photo resource names plus the
    -- authorAttributions that must be shown with the image. Fetching an actual
    -- image is a separate, separately billed Place Photos call.
    photos_json JSON DEFAULT NULL,
    -- Google's `regularOpeningHours` verbatim: weekdayDescriptions to display,
    -- periods to compute "open now". The standard weekly pattern only - not
    -- currentOpeningHours, which is per-request and would go stale in a day.
    regular_opening_hours_json JSON DEFAULT NULL,

    -- Added on top of the original set. All Pro tier or lower in the Places API
    -- SKU, so free given the mask is already Enterprise (see the FieldMask
    -- comment on GooglePlacesApiClient). Presentation detail, except
    -- pure_service_area_business, which is a candidate signal for the
    -- discovery quality gate but is not wired into it yet.
    address_components_json JSON DEFAULT NULL,
    viewport_json JSON DEFAULT NULL,
    google_maps_links_json JSON DEFAULT NULL,
    accessibility_options_json JSON DEFAULT NULL,
    containing_places_json JSON DEFAULT NULL,
    -- True when the business has no storefront customers visit (delivery-only,
    -- mobile, home-based, ...). Data only for now - not yet checked by the
    -- discovery quality gate (backend/.../DiscoverHiddenPlaceService.cs).
    pure_service_area_business BOOLEAN DEFAULT NULL,
    -- Date the place opened, when Google has a complete year/month/day for it.
    opening_date DATE DEFAULT NULL,
    primary_type_display_name VARCHAR(100) DEFAULT NULL,
    short_formatted_address VARCHAR(500) DEFAULT NULL,

    -- Whether the row passed the stage-1 quality gate (business status, rating,
    -- review count, chain-brand name check) at the time it was fetched. This is
    -- the ABSOLUTE part of the algorithm only - the relative HiddenScore is
    -- recomputed on every request and never stored.
    passed_quality_gate BOOLEAN NOT NULL DEFAULT FALSE,

    -- A bucket is replaced wholesale on refetch, and within one bucket a given
    -- real-world place must appear at most once.
    UNIQUE KEY ix_hidden_place_cache_cache_grid_key_place_id (cache_grid_key, place_id)
);

-- Place photo table (no dependencies)
--
-- One row per place: our own copy of that place's first Google photo, living in Supabase
-- Storage. Exists purely to stop us paying Google twice for the same picture - Place Photos
-- bills per image fetched and the URI it returns expires, so an app that linked straight to
-- Google would be charged on every render.
--
-- Deliberately SEPARATE from hidden_place_cache, and deliberately NOT a foreign key to it.
-- That table is disposable: buckets are deleted and re-inserted wholesale on refresh, and the
-- whole thing is safe to TRUNCATE. A photo URL stored there would be destroyed on every cache
-- refresh and re-bought from Google. Rows here have no expiry and survive anything done to the
-- cache - which is the entire point.
--
-- attribution is the photographer credit Google returned. It is not optional decoration:
-- Google's terms require it to be shown wherever the image is, and since we serve the bytes
-- ourselves, Google is no longer there to attach it.
CREATE TABLE IF NOT EXISTS place_photo (
    place_photo_id INT AUTO_INCREMENT PRIMARY KEY,
    place_id VARCHAR(255) NOT NULL,
    photo_url VARCHAR(500) NOT NULL,
    photo_reference VARCHAR(500) DEFAULT NULL,
    attribution VARCHAR(255) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- One photo per place, and the index the lookup-by-place-id read uses.
    UNIQUE KEY ix_place_photo_place_id (place_id)
);

-- Hidden place suppression table (no dependencies)
--
-- Google-sourced places the community has reported out of the app: closed down, wrong location,
-- inappropriate. One row = one place that must never be shown again.
--
-- Why a table and not a DELETE: hidden_place_cache is refilled from Google on a 30-day cycle, so
-- deleting the cached row hides the place until the next refresh and then hands it straight back,
-- with every report against it silently undone. The exclusion has to live somewhere the refresh
-- cannot reach, and be applied when results are read.
--
-- Note this is only for GOOGLE places. A community submission is our own data, so hiding one is
-- just a status change on its recommended_places row - see RecommendedPlaceStatus.REPORTED_CLOSED.
CREATE TABLE IF NOT EXISTS hidden_place_suppression (
    hidden_place_suppression_id INT AUTO_INCREMENT PRIMARY KEY,
    place_id VARCHAR(255) NOT NULL,
    name VARCHAR(255) DEFAULT NULL,
    reason VARCHAR(100) DEFAULT NULL,
    report_count INT NOT NULL DEFAULT 0,
    suppressed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- One row per place, and the index the read-time exclusion uses.
    UNIQUE KEY ix_hidden_place_suppression_place_id (place_id)
);
