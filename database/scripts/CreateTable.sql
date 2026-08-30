use exploremy_dev;

-- MODULE 1: User Authentication & Profile Management

-- Users table
CREATE TABLE IF NOT EXISTS users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    username VARCHAR(50) NOT NULL,
    profile_picture_url VARCHAR(500) DEFAULT NULL,
    city VARCHAR(100) DEFAULT NULL,
    age INT DEFAULT NULL,
    gender ENUM('Male','Female','Prefer not to say') DEFAULT NULL,
    account_status VARCHAR(30) NOT NULL DEFAULT 'pending_verification',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Email verification token table (depends on users)
CREATE TABLE IF NOT EXISTS email_verification_token (
    token_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    token VARCHAR(255) NOT NULL UNIQUE,
    expires_at DATETIME NOT NULL,
    is_used BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    pending_email VARCHAR(255) DEFAULT NULL,

    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,

    INDEX idx_evt_user_id (user_id)
);

-- Password reset token table (depends on users)
CREATE TABLE IF NOT EXISTS password_reset_token (
    token_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    token VARCHAR(255) NOT NULL UNIQUE,
    expires_at DATETIME NOT NULL,
    is_used BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,

    INDEX idx_prt_user_id (user_id)
);

-- User session table (depends on users)
CREATE TABLE IF NOT EXISTS user_session (
    session_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    session_token VARCHAR(500) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,

    INDEX idx_session_user_id (user_id)
);

-- MODULE 2: Hidden Place Discovery

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

-- MODULE 3: My Recommended Places (UC502)

-- Recommended places table (submitted by users for community voting)
CREATE TABLE recommended_places (
    `recommend_place_id` VARCHAR(255) NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `primary_type` VARCHAR(100) NOT NULL,
    `latitude` DOUBLE NOT NULL,
    `longitude` DOUBLE NOT NULL,
    `rating` DOUBLE NULL,
    `user_rating_count` INT NOT NULL DEFAULT 0,
    `price_level` INT NULL,
    `business_status` VARCHAR(50) NOT NULL,
    `source` VARCHAR(50) NOT NULL DEFAULT 'USER',
    `description` TEXT NULL,
    `photo_json` JSON NULL,
    PRIMARY KEY (`recommend_place_id`)
);

-- CREATE TABLE IF NOT EXISTS recommended_places (
--     submission_id VARCHAR(36) PRIMARY KEY,
--     submitter_id INT NOT NULL,
--     name VARCHAR(150) NOT NULL,
--     location_address VARCHAR(250) NOT NULL,
--     latitude DECIMAL(10,7) DEFAULT NULL,
--     longitude DECIMAL(10,7) DEFAULT NULL,
--     category VARCHAR(50) NOT NULL,
--     description VARCHAR(500) DEFAULT NULL,
--     status VARCHAR(30) NOT NULL DEFAULT 'UNDER_VOTING',
--     created_at DATETIME(6) NOT NULL,
--     updated_at DATETIME(6) NOT NULL,

--     FOREIGN KEY (submitter_id) REFERENCES users(user_id) ON DELETE CASCADE,

--     INDEX idx_recommended_places_submitter_id (submitter_id),
--     INDEX idx_recommended_places_status (status)
-- );

-- Community verifications (voting) on recommended places
-- CREATE TABLE IF NOT EXISTS recommended_place_verifications (
--     verification_id VARCHAR(36) PRIMARY KEY,
--     submission_id VARCHAR(36) NOT NULL,
--     user_id INT NOT NULL,
--     status VARCHAR(20) NOT NULL,
--     created_at DATETIME(6) NOT NULL,

--     FOREIGN KEY (submission_id) REFERENCES recommended_places(submission_id) ON DELETE CASCADE,
--     FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,

--     UNIQUE KEY uq_verification_submission_user (submission_id, user_id),
--     INDEX idx_verification_user_id (user_id)
-- );

-- -- Reports on recommended places
-- CREATE TABLE IF NOT EXISTS recommended_place_reports (
--     report_id VARCHAR(36) PRIMARY KEY,
--     submission_id VARCHAR(36) NOT NULL,
--     reporter_id INT NOT NULL,
--     reason VARCHAR(100) NOT NULL,
--     status VARCHAR(20) NOT NULL,
--     created_at DATETIME(6) NOT NULL,

--     FOREIGN KEY (submission_id) REFERENCES recommended_places(submission_id) ON DELETE CASCADE,
--     FOREIGN KEY (reporter_id) REFERENCES users(user_id) ON DELETE CASCADE,

--     UNIQUE KEY uq_report_submission_reporter (submission_id, reporter_id),
--     INDEX idx_report_reporter_id (reporter_id)
-- );

CREATE TABLE hidden_place_review (
    review_id BIGINT NOT NULL AUTO_INCREMENT,

    google_place_id VARCHAR(255) NULL,
    recommend_place_id VARCHAR(255) NULL,

    user_id INT NOT NULL,

    rating DECIMAL(2,1) NOT NULL,
    comment TEXT NOT NULL,

    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NULL,

    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',

    PRIMARY KEY (review_id),

    CONSTRAINT fk_review_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id),

    CONSTRAINT fk_review_recommended_place
        FOREIGN KEY (recommend_place_id)
        REFERENCES recommended_places(recommend_place_id),

    CONSTRAINT chk_review_one_place
        CHECK (
            (google_place_id IS NOT NULL AND recommend_place_id IS NULL)
            OR
            (google_place_id IS NULL AND recommend_place_id IS NOT NULL)
        )
);

-- MODULE 4: Foot Tracker - Favourite Places & Exploration History (UC102, UC201)

-- Places table (no dependencies)
--
-- Canonical place records referenced by Favourite Places and Exploration
-- History. Distinct from hidden_place_cache (Module 2), which is a disposable,
-- refreshable cache of raw Google Places results - a row here is a place the
-- app has kept a permanent reference to (favourited or actually visited),
-- independent of whether the Google cache bucket it originated from has since
-- expired or been refreshed.
CREATE TABLE IF NOT EXISTS places (
    place_id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    address VARCHAR(250) NOT NULL,
    category VARCHAR(50) NOT NULL,
    description LONGTEXT DEFAULT NULL,
    latitude DECIMAL(18,2) DEFAULT NULL,
    longitude DECIMAL(18,2) DEFAULT NULL,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL
);

-- Favourite place table (depends on users)
--
-- One row per (user, place) - uq_user_place prevents favouriting the same
-- place twice. Unlike foot_tracker_log below, this table intentionally has
-- NO duplicates: favouriting is a toggle, not a visit log.
CREATE TABLE IF NOT EXISTS favourite_place (
    favourite_place_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    place_id VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    primary_type VARCHAR(100) NOT NULL,
    address VARCHAR(500) DEFAULT NULL,
    latitude DOUBLE NOT NULL,
    longitude DOUBLE NOT NULL,
    last_visit_at DATETIME DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_favourite_place_users_user_id FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,

    UNIQUE KEY uq_user_place (user_id, place_id)
);

-- Foot tracker log table (depends on users, places)
--
-- One row per completed visit, recorded only once GPS arrival has been
-- verified during navigation (UC201). Unlike favourite_place, duplicates are
-- intentional: visiting the same place three times produces three rows,
-- since this table is the source of Exploration History rather than a
-- favourites toggle. place_id is nullable with ON DELETE SET NULL - a visit
-- record must survive even if the place it points to is later removed.
--
-- title/primary_type/address/latitude/longitude are denormalized copies of
-- the place's details at the time of the visit (mirroring favourite_place's
-- shape) rather than a join through place_id, so History still displays
-- correctly even when place_id is NULL.
CREATE TABLE IF NOT EXISTS foot_tracker_log (
    log_id VARCHAR(255) PRIMARY KEY,
    user_id INT NOT NULL,
    place_id VARCHAR(255) DEFAULT NULL,
    title LONGTEXT,
    primary_type LONGTEXT,
    address LONGTEXT,
    latitude DOUBLE DEFAULT NULL,
    longitude DOUBLE DEFAULT NULL,
    distance_km DECIMAL(18,2) DEFAULT NULL,
    started_at DATETIME(6) DEFAULT NULL,
    ended_at DATETIME(6) DEFAULT NULL,
    status VARCHAR(20) NOT NULL,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,

    CONSTRAINT fk_foot_tracker_log_users_user_id FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_foot_tracker_log_places_place_id FOREIGN KEY (place_id) REFERENCES places(place_id) ON DELETE SET NULL,

    INDEX ix_foot_tracker_log_user_id (user_id),
    INDEX ix_foot_tracker_log_place_id (place_id)
);
