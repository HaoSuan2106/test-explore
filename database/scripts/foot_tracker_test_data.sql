-- =============================================================
-- foot_tracker_test_data.sql
--
-- Purpose:  Insert test visits into foot_tracker_log for
--           PostReview eligible-attractions and Create Post
--           tagged-place validation tests.
--
-- Dataset:  (see FINAL REPORT for the full mapping)
--   USER_A = user_id 1 (alice@example.com)
--   USER_B = user_id 2 (bob@example.com)
--   PLACE_A = ChIJHdDl1f2fzDERr0bOKRfhHrE (Petronas Towers)
--   PLACE_B = ChIJWU7wDwA3zDERzF9TNbzyjyQ (Batu Caves)
--   PLACE_C = plc-002 (Cliff Point)
--   PLACE_D = ChIJ_aLo6Lo3zDERfunjYgG3jaE (Riasah Travel Sdn Bhd)
--             — used only for the "unvisited place" test
--             (USER_A has no completed visit to PLACE_D).
--
-- Existing rows: 3 records for user 5 (erin) — not touched.
-- =============================================================

SET NAMES utf8mb4;
SET @now = '2026-09-02 00:00:00';

-- ---------------------------------------------------------
-- USER_A: 2× PLACE_A (older + newer, tests dedup),
--         1× PLACE_B, 1× PLACE_C, 1× PLACE_C IN_PROGRESS
-- ---------------------------------------------------------

-- 1. USER_A PLACE_A — older visit (COMPLETED)
INSERT INTO foot_tracker_log (
    log_id, user_id, place_id, title, primary_type, address,
    latitude, longitude, distance_km,
    started_at, ended_at, status, created_at, updated_at
) VALUES (
    'test-ft-u1-pa-old', 1, 'ChIJHdDl1f2fzDERr0bOKRfhHrE',
    'Petronas Towers', 'tourist_attraction',
    'Kuala Lumpur City Centre',
    3.1577, 101.7123, 5.00,
    '2026-08-01 09:00:00', '2026-08-01 10:30:00',
    'COMPLETED', @now, @now
);

-- 2. USER_A PLACE_A — newer visit (COMPLETED) — newest retained
INSERT INTO foot_tracker_log (
    log_id, user_id, place_id, title, primary_type, address,
    latitude, longitude, distance_km,
    started_at, ended_at, status, created_at, updated_at
) VALUES (
    'test-ft-u1-pa-new', 1, 'ChIJHdDl1f2fzDERr0bOKRfhHrE',
    'Petronas Towers', 'tourist_attraction',
    'Kuala Lumpur City Centre',
    3.1577, 101.7123, 5.00,
    '2026-09-15 14:00:00', '2026-09-15 15:30:00',
    'COMPLETED', @now, @now
);

-- 3. USER_A PLACE_B — COMPLETED
INSERT INTO foot_tracker_log (
    log_id, user_id, place_id, title, primary_type, address,
    latitude, longitude, distance_km,
    started_at, ended_at, status, created_at, updated_at
) VALUES (
    'test-ft-u1-pb', 1, 'ChIJWU7wDwA3zDERzF9TNbzyjyQ',
    'Batu Caves', 'tourist_attraction',
    'Gombak, Selangor',
    3.2375, 101.6839, 12.50,
    '2026-08-20 10:00:00', '2026-08-20 11:45:00',
    'COMPLETED', @now, @now
);

-- 4. USER_A PLACE_C — COMPLETED
INSERT INTO foot_tracker_log (
    log_id, user_id, place_id, title, primary_type, address,
    latitude, longitude, distance_km,
    started_at, ended_at, status, created_at, updated_at
) VALUES (
    'test-ft-u1-pc', 1, 'plc-002',
    'Cliff Point', 'natural_feature',
    'Pantai',
    3.1, 101.6, 8.20,
    '2026-09-01 16:00:00', '2026-09-01 17:15:00',
    'COMPLETED', @now, @now
);

-- 5. USER_A PLACE_C — IN_PROGRESS (tests non-completed exclusion)
INSERT INTO foot_tracker_log (
    log_id, user_id, place_id, title, primary_type, address,
    latitude, longitude, distance_km,
    started_at, ended_at, status, created_at, updated_at
) VALUES (
    'test-ft-u1-pc-ip', 1, 'plc-002',
    'Cliff Point', 'natural_feature',
    'Pantai',
    3.1, 101.6, 8.20,
    '2026-09-20 08:00:00', NULL,
    'IN_PROGRESS', @now, @now
);

-- ---------------------------------------------------------
-- USER_B: 1× PLACE_A, 1× PLACE_B
-- ---------------------------------------------------------

-- 6. USER_B PLACE_A — COMPLETED
INSERT INTO foot_tracker_log (
    log_id, user_id, place_id, title, primary_type, address,
    latitude, longitude, distance_km,
    started_at, ended_at, status, created_at, updated_at
) VALUES (
    'test-ft-u2-pa', 2, 'ChIJHdDl1f2fzDERr0bOKRfhHrE',
    'Petronas Towers', 'tourist_attraction',
    'Kuala Lumpur City Centre',
    3.1577, 101.7123, 5.00,
    '2026-09-05 09:30:00', '2026-09-05 10:45:00',
    'COMPLETED', @now, @now
);

-- 7. USER_B PLACE_B — COMPLETED
INSERT INTO foot_tracker_log (
    log_id, user_id, place_id, title, primary_type, address,
    latitude, longitude, distance_km,
    started_at, ended_at, status, created_at, updated_at
) VALUES (
    'test-ft-u2-pb', 2, 'ChIJWU7wDwA3zDERzF9TNbzyjyQ',
    'Batu Caves', 'tourist_attraction',
    'Gombak, Selangor',
    3.2375, 101.6839, 12.50,
    '2026-09-10 13:00:00', '2026-09-10 14:20:00',
    'COMPLETED', @now, @now
);

-- =============================================================
-- VERIFICATION QUERY
-- =============================================================
-- Run after inserts:
-- SELECT * FROM foot_tracker_log WHERE log_id LIKE 'test-ft-%' ORDER BY user_id, started_at;

-- =============================================================
-- CLEANUP
-- =============================================================
-- To remove only the test rows inserted above (safe cleanup):
-- BEGIN;
-- DELETE FROM foot_tracker_log WHERE log_id IN (
--     'test-ft-u1-pa-old','test-ft-u1-pa-new','test-ft-u1-pb',
--     'test-ft-u1-pc','test-ft-u1-pc-ip','test-ft-u2-pa','test-ft-u2-pb'
-- );
-- COMMIT;
-- Verify: SELECT COUNT(*) FROM foot_tracker_log WHERE log_id LIKE 'test-ft-%';
-- (should be 0)