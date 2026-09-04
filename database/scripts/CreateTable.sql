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

CREATE TABLE `recommended_places` (
  `recommend_place_id` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `primary_type` varchar(100) NOT NULL,
  `latitude` double NOT NULL,
  `longitude` double NOT NULL,
  `rating` double DEFAULT NULL,
  `user_rating_count` int NOT NULL DEFAULT '0',
  `price_level` int DEFAULT NULL,
  `business_status` varchar(50) NOT NULL,
  `description` text,
  `photo_json` json DEFAULT NULL,
  PRIMARY KEY (`recommend_place_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


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
CREATE TABLE `hidden_place_suppression` (
  `hidden_place_suppression_id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL DEFAULT '0',
  `place_id` varchar(255) NOT NULL,
  `recommended_place_id` varchar(255) DEFAULT NULL,
  `name` varchar(255) NOT NULL,
  `reason` varchar(100) NOT NULL,
  `report_count` int NOT NULL DEFAULT '0',
  `suppressed_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`hidden_place_suppression_id`),
  UNIQUE KEY `uq_hidden_place_suppression_user_place` (`user_id`,`place_id`),
  KEY `idx_hidden_place_suppression_place_id` (`place_id`),
  KEY `idx_hidden_place_suppression_recommended_place_id` (`recommended_place_id`),
  KEY `idx_hidden_place_suppression_suppressed_at` (`suppressed_at`)
) ENGINE=InnoDB AUTO_INCREMENT=44 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Place photo table (no dependencies)
--
-- Permanent cache of one photo per place, copied out of Google and into our own
-- Supabase bucket (Google's photo URIs are short-lived). Populated lazily by
-- PlacePhotoService whenever a place is first surfaced by a discovery search -
-- not every place has a row here. FavouritePlaceService looks this table up by
-- place_id to attach a photo to favourited places without re-fetching from
-- Google. See backend/Application/HiddenPlace/PlacePhotos/PlacePhotoService.cs.
CREATE TABLE `place_photo` (
  `place_photo_id` int NOT NULL AUTO_INCREMENT,
  `place_id` varchar(255) NOT NULL,
  `photo_url` varchar(500) NOT NULL,
  `photo_reference` varchar(500) DEFAULT NULL,
  `attribution` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`place_photo_id`),
  UNIQUE KEY `ix_place_photo_place_id` (`place_id`)
) ENGINE=InnoDB AUTO_INCREMENT=36 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `community_posts` (
  `post_id` varchar(36) NOT NULL,
  `author_id` int NOT NULL,
  `tagged_place_id` varchar(255) NOT NULL,
  `title` varchar(100) DEFAULT NULL,
  `description` varchar(2000) NOT NULL,
  `views_count` int NOT NULL DEFAULT '0',
  `status` varchar(20) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`post_id`),
  KEY `ix_community_posts_author_id` (`author_id`),
  KEY `ix_community_posts_status` (`status`),
  CONSTRAINT `fk_community_posts_users_author_id` FOREIGN KEY (`author_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `place_submissions` (
  `submission_id` varchar(36) NOT NULL,
  `submitter_id` int NOT NULL,
  `recommend_place_id` varchar(255) NOT NULL,
  `status` varchar(30) NOT NULL DEFAULT 'UNDER_VOTING',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`submission_id`),
  KEY `idx_place_submissions_submitter_id` (`submitter_id`),
  KEY `idx_place_submissions_recommend_place_id` (`recommend_place_id`),
  KEY `idx_place_submissions_status` (`status`),
  CONSTRAINT `place_submissions_ibfk_1` FOREIGN KEY (`submitter_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
  CONSTRAINT `place_submissions_ibfk_2` FOREIGN KEY (`recommend_place_id`) REFERENCES `recommended_places` (`recommend_place_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `community_post_comments` (
  `comment_id` varchar(36) NOT NULL,
  `post_id` varchar(36) NOT NULL,
  `author_id` int NOT NULL,
  `content` varchar(300) NOT NULL,
  `likes_count` int NOT NULL DEFAULT '0',
  `status` varchar(20) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`comment_id`),
  KEY `ix_community_post_comments_author_id` (`author_id`),
  KEY `ix_community_post_comments_post_id` (`post_id`),
  CONSTRAINT `fk_community_post_comments_community_posts_post_id` FOREIGN KEY (`post_id`) REFERENCES `community_posts` (`post_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_community_post_comments_users_author_id` FOREIGN KEY (`author_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `community_post_images` (
  `image_id` varchar(36) NOT NULL,
  `post_id` varchar(36) NOT NULL,
  `image_url` longtext NOT NULL,
  `display_order` smallint NOT NULL,
  `created_at` datetime(6) NOT NULL,
  PRIMARY KEY (`image_id`),
  UNIQUE KEY `ix_community_post_images_post_id_display_order` (`post_id`,`display_order`),
  KEY `ix_community_post_images_post_id` (`post_id`),
  CONSTRAINT `fk_community_post_images_community_posts_post_id` FOREIGN KEY (`post_id`) REFERENCES `community_posts` (`post_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `community_post_reactions` (
  `reaction_id` varchar(36) NOT NULL,
  `post_id` varchar(36) NOT NULL,
  `user_id` int NOT NULL,
  `reaction_type` varchar(20) NOT NULL,
  `status` varchar(20) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`reaction_id`),
  UNIQUE KEY `ix_community_post_reactions_post_id_user_id` (`post_id`,`user_id`),
  KEY `ix_community_post_reactions_post_id` (`post_id`),
  KEY `ix_community_post_reactions_user_id` (`user_id`),
  CONSTRAINT `fk_community_post_reactions_community_posts_post_id` FOREIGN KEY (`post_id`) REFERENCES `community_posts` (`post_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_community_post_reactions_users_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `community_post_reports` (
  `report_id` varchar(36) NOT NULL,
  `post_id` varchar(36) NOT NULL,
  `reporter_id` int NOT NULL,
  `reason` varchar(100) NOT NULL,
  `status` varchar(20) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `withdrawn_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`report_id`),
  KEY `ix_community_post_reports_post_id` (`post_id`),
  KEY `ix_community_post_reports_reporter_id` (`reporter_id`),
  CONSTRAINT `fk_community_post_reports_community_posts_post_id` FOREIGN KEY (`post_id`) REFERENCES `community_posts` (`post_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_community_post_reports_users_reporter_id` FOREIGN KEY (`reporter_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `recommended_place_verifications` (
  `verification_id` varchar(36) NOT NULL,
  `submission_id` varchar(36) NOT NULL,
  `user_id` int NOT NULL,
  `status` varchar(20) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  PRIMARY KEY (`verification_id`),
  UNIQUE KEY `uq_recommended_place_verifications_submission_user` (`submission_id`,`user_id`),
  KEY `ix_recommended_place_verifications_submission_id` (`submission_id`),
  KEY `ix_recommended_place_verifications_user_id` (`user_id`),
  CONSTRAINT `fk_recommended_place_verifications_place_submissions` FOREIGN KEY (`submission_id`) REFERENCES `place_submissions` (`submission_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_recommended_place_verifications_users` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `user_saved_posts` (
  `saved_id` varchar(36) NOT NULL,
  `post_id` varchar(36) NOT NULL,
  `user_id` int NOT NULL,
  `created_at` datetime(6) NOT NULL,
  PRIMARY KEY (`saved_id`),
  UNIQUE KEY `ix_user_saved_posts_post_id_user_id` (`post_id`,`user_id`),
  KEY `ix_user_saved_posts_post_id` (`post_id`),
  KEY `ix_user_saved_posts_user_id` (`user_id`),
  CONSTRAINT `fk_user_saved_posts_posts_post_id` FOREIGN KEY (`post_id`) REFERENCES `community_posts` (`post_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_user_saved_posts_users_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;



-- Place Review
CREATE TABLE hidden_place_review (
    review_id BIGINT NOT NULL AUTO_INCREMENT,

    google_place_id VARCHAR(255) NULL,
    recommend_place_id VARCHAR(255) NULL,

    user_id INT NOT NULL,

    rating DECIMAL(2,1) NOT NULL,
    comment LONGTEXT NOT NULL,

    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NULL,

    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',

    PRIMARY KEY (review_id),

    CONSTRAINT fk_hidden_place_review_users_user_id
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE,

    INDEX ix_hidden_place_review_google_place_id
        (google_place_id),

    INDEX ix_hidden_place_review_recommend_place_id
        (recommend_place_id),

    INDEX ix_hidden_place_review_user_id
        (user_id)
);

-- Review Photos
CREATE TABLE hidden_place_review_photo (
    review_photo_id BIGINT NOT NULL AUTO_INCREMENT,
    review_id BIGINT NOT NULL,
    photo_url VARCHAR(500) NOT NULL,
    display_order INT NOT NULL,
    created_at DATETIME(6) NOT NULL,

    PRIMARY KEY (review_photo_id),

    CONSTRAINT fk_hidden_place_review_photo_review
        FOREIGN KEY (review_id)
        REFERENCES hidden_place_review(review_id)
        ON DELETE CASCADE,

    INDEX ix_hidden_place_review_photo_review_id
        (review_id),

    UNIQUE KEY ix_hidden_place_review_photo_review_id_display_order
        (review_id, display_order)
);

-- Review Reports
CREATE TABLE hidden_place_review_report (
    report_id BIGINT NOT NULL AUTO_INCREMENT,
    review_id BIGINT NOT NULL,
    user_id INT NOT NULL,
    reason VARCHAR(50) NOT NULL,
    created_at DATETIME(6) NOT NULL,

    PRIMARY KEY (report_id),

    CONSTRAINT fk_hidden_place_review_report_review
        FOREIGN KEY (review_id)
        REFERENCES hidden_place_review(review_id)
        ON DELETE CASCADE,

    INDEX ix_hidden_place_review_report_review_id
        (review_id),

    UNIQUE KEY ix_hidden_place_review_report_review_id_user_id
        (review_id, user_id)
);

-- MODULE 4: Foot Tracker - Favourite Places & Exploration History (UC102, UC201)
--
-- Redesigned 2026-09-01: `places` is now the single canonical, permanent detail
-- store for ANY place (Google-sourced or community-submitted from
-- recommended_places), keyed by place_id. `favourite_place` is a thin (user,
-- place) pointer only - it no longer duplicates place detail per favourite.
-- Pressing the love icon on the Details page upserts the full place detail
-- into `places` first (see FavouritePlaceService.AddFavouritePlaceAsync),
-- then creates/points a favourite_place row at it. See migrations
-- PromoteFavouritePlaceDetailsToPlaces and SyncPlaceCoordinateTypes.

-- Places table (no dependencies)
CREATE TABLE IF NOT EXISTS places (
    place_id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    address VARCHAR(500) NOT NULL,
    description LONGTEXT DEFAULT NULL,
    latitude DOUBLE DEFAULT NULL,
    longitude DOUBLE DEFAULT NULL,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,

    primary_type VARCHAR(100) NOT NULL DEFAULT '',
    primary_type_display_name VARCHAR(100) DEFAULT NULL,
    short_formatted_address VARCHAR(500) DEFAULT NULL,
    rating DOUBLE DEFAULT NULL,
    user_rating_count INT NOT NULL DEFAULT 0,
    price_level INT DEFAULT NULL,
    business_status VARCHAR(50) DEFAULT NULL,
    google_maps_uri VARCHAR(500) DEFAULT NULL,
    national_phone_number VARCHAR(50) DEFAULT NULL,
    website_uri VARCHAR(500) DEFAULT NULL,
    photos_json JSON DEFAULT NULL,
    regular_opening_hours_json JSON DEFAULT NULL,
    accessibility_options_json JSON DEFAULT NULL,
    address_components_json JSON DEFAULT NULL,
    google_maps_links_json JSON DEFAULT NULL,
    viewport_json JSON DEFAULT NULL,
    opening_date DATE DEFAULT NULL
);

-- Favourite place table (depends on users, places)
--
-- One row per (user, place) - uq_user_place prevents favouriting the same
-- place twice. place_id holds either a Google Place ID or a recommended
-- place's recommend_place_id - both are just strings, so one column covers
-- both sources. All place detail lives in `places`, referenced here by
-- fk_favourite_place_places_place_id - this table no longer stores its own
-- copy of name/address/lat-long/rating/etc.
CREATE TABLE IF NOT EXISTS favourite_place (
    favourite_place_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    place_id VARCHAR(255) NOT NULL,
    last_visit_at DATETIME DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_favourite_place_users_user_id FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_favourite_place_places_place_id FOREIGN KEY (place_id) REFERENCES places(place_id) ON DELETE CASCADE,

    UNIQUE KEY uq_user_place (user_id, place_id),
    INDEX ix_favourite_place_place_id (place_id)
);

-- Foot tracker log table (depends on users)
--
-- One row per completed visit, recorded only once GPS arrival has been
-- verified during navigation (UC201). Unlike favourite_place, duplicates are
-- intentional. No FK to places - foot_tracker_log doesn't need that
-- durability; title/primary_type/address/latitude/longitude are denormalized
-- copies of the place's details at the time of the visit.
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

    INDEX ix_foot_tracker_log_user_id (user_id),
    INDEX ix_foot_tracker_log_place_id (place_id)
);

-- MODULE: Communication (Community Chat)
-- NOTE: kept in sync with backend/Persistence/DbContext/MySqlDbContext.cs's
-- OnModelCreating for the Community entities. This hand-written script mirrors
-- the project's existing manual convention (see MODULE 1 above); it is not a
-- substitute for a real EF Core migration. Applied via migration
-- AddCommunityChatModule (2026-09-01) - already run against exploremy_dev.

-- Community table
CREATE TABLE IF NOT EXISTS community (
    community_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(1000) DEFAULT NULL,
    area VARCHAR(100) DEFAULT NULL,
    state VARCHAR(100) DEFAULT NULL,
    latitude DOUBLE DEFAULT NULL,
    longitude DOUBLE DEFAULT NULL,
    image_url VARCHAR(500) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_community_state (state)
);

-- Community member table (depends on community, users)
CREATE TABLE IF NOT EXISTS community_member (
    community_member_id INT AUTO_INCREMENT PRIMARY KEY,
    community_id INT NOT NULL,
    user_id INT NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'Member',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    left_at DATETIME DEFAULT NULL,

    FOREIGN KEY (community_id) REFERENCES community(community_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,

    UNIQUE INDEX idx_member_community_user (community_id, user_id)
);

-- Message table (depends on community, users)
CREATE TABLE IF NOT EXISTS message (
    message_id INT AUTO_INCREMENT PRIMARY KEY,
    community_id INT NOT NULL,
    sender_user_id INT NOT NULL,
    content VARCHAR(2000) DEFAULT NULL,
    reply_to_message_id INT DEFAULT NULL,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (community_id) REFERENCES community(community_id) ON DELETE CASCADE,
    FOREIGN KEY (sender_user_id) REFERENCES users(user_id) ON DELETE RESTRICT,

    INDEX idx_message_community_sent_at (community_id, sent_at)
);

-- Message attachment table (depends on message)
-- place_id is VARCHAR, not INT: real place identifiers are a Google Place ID
-- or a recommended-place submission UUID, both strings. place_latitude/
-- place_longitude/place_primary_type/is_community_place are a snapshot taken
-- at share time (Share Location feature) so reopening a shared place never
-- needs a live re-fetch — see MessageAttachment.cs.
CREATE TABLE IF NOT EXISTS message_attachment (
    attachment_id INT AUTO_INCREMENT PRIMARY KEY,
    message_id INT NOT NULL,
    type VARCHAR(20) NOT NULL, -- "Image" | "PlaceShare"
    media_url VARCHAR(500) DEFAULT NULL,
    place_id VARCHAR(255) DEFAULT NULL,
    place_name VARCHAR(255) DEFAULT NULL,
    place_address VARCHAR(500) DEFAULT NULL,
    place_image_url VARCHAR(500) DEFAULT NULL,
    place_status VARCHAR(50) DEFAULT NULL,
    place_latitude DOUBLE DEFAULT NULL,
    place_longitude DOUBLE DEFAULT NULL,
    place_primary_type VARCHAR(100) DEFAULT NULL,
    is_community_place BOOLEAN NOT NULL DEFAULT FALSE,

    FOREIGN KEY (message_id) REFERENCES message(message_id) ON DELETE CASCADE,

    INDEX idx_attachment_message_id (message_id)
);

-- Message report table (depends on message, users)
CREATE TABLE IF NOT EXISTS message_report (
    report_id INT AUTO_INCREMENT PRIMARY KEY,
    message_id INT NOT NULL,
    reporter_user_id INT NOT NULL,
    reason VARCHAR(500) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (message_id) REFERENCES message(message_id) ON DELETE CASCADE,
    FOREIGN KEY (reporter_user_id) REFERENCES users(user_id) ON DELETE RESTRICT,

    UNIQUE INDEX idx_report_message_reporter (message_id, reporter_user_id)
);