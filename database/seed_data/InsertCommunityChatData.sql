USE exploremy_dev;

-- ============================================================================
-- MODULE: Communication — group membership + chat seed data
--
-- Seeds joined-group records and realistic chat threads for the 5 users from
-- InsertUserData.sql (alice, bob, carol, dave, erin) across 4 of the district
-- communities from InsertCommunityData.sql.
--
-- Run order:  InsertUserData.sql  ->  InsertCommunityData.sql  ->  this file.
--
-- Every id is looked up by email / community name rather than hardcoded, so
-- this is safe on a database whose AUTO_INCREMENT values are not 1..N. Message
-- ids are captured with LAST_INSERT_ID() into session variables so replies can
-- point at the right parent without knowing any id in advance.
--
-- Covers, on purpose:
--   * a community with all 5 members, and smaller 3-member ones
--   * threaded replies (reply_to_message_id)
--   * a soft-deleted message (is_deleted = TRUE), and a reply pointing at it
--   * a member who joined and later left (is_active = FALSE, left_at set),
--     which is what the rejoin path in ReactivateMemberAsync expects to find
--   * timestamps staggered over the last ~8 days so ordering, "load older"
--     paging and the last-message preview on the community list all look real
-- ============================================================================


-- ----------------------------------------------------------------------------
-- Optional cleanup — uncomment to re-run this script from a clean slate.
-- Deletes ONLY the rows this script creates (message_attachment rows cascade
-- from message). Leaves users and communities alone.
-- ----------------------------------------------------------------------------
-- DELETE m FROM message m
--   JOIN community c ON c.community_id = m.community_id
--   JOIN users u ON u.user_id = m.sender_user_id
--  WHERE c.name IN ('Kuala Lumpur Community','Petaling Community','Timur Laut Community','Langkawi Community')
--    AND u.email IN ('alice@example.com','bob@example.com','carol@example.com','dave@example.com','erin@example.com');
-- DELETE cm FROM community_member cm
--   JOIN community c ON c.community_id = cm.community_id
--   JOIN users u ON u.user_id = cm.user_id
--  WHERE c.name IN ('Kuala Lumpur Community','Petaling Community','Timur Laut Community','Langkawi Community')
--    AND u.email IN ('alice@example.com','bob@example.com','carol@example.com','dave@example.com','erin@example.com');


-- ----------------------------------------------------------------------------
-- Lookups
-- ----------------------------------------------------------------------------
SET @now := NOW();

SET @u_alice := (SELECT user_id FROM users WHERE email = 'alice@example.com' LIMIT 1);
SET @u_bob   := (SELECT user_id FROM users WHERE email = 'bob@example.com'   LIMIT 1);
SET @u_carol := (SELECT user_id FROM users WHERE email = 'carol@example.com' LIMIT 1);
SET @u_dave  := (SELECT user_id FROM users WHERE email = 'dave@example.com'  LIMIT 1);
SET @u_erin  := (SELECT user_id FROM users WHERE email = 'erin@example.com'  LIMIT 1);

SET @c_kl  := (SELECT community_id FROM community WHERE name = 'Kuala Lumpur Community' LIMIT 1);
SET @c_pj  := (SELECT community_id FROM community WHERE name = 'Petaling Community'     LIMIT 1);
SET @c_pg  := (SELECT community_id FROM community WHERE name = 'Timur Laut Community'   LIMIT 1);
SET @c_lgk := (SELECT community_id FROM community WHERE name = 'Langkawi Community'     LIMIT 1);

-- Sanity check — every value below must be non-NULL before you continue.
-- If any is NULL, the matching seed file above hasn't been run yet.
SELECT @u_alice AS alice, @u_bob AS bob, @u_carol AS carol, @u_dave AS dave, @u_erin AS erin,
       @c_kl AS kl, @c_pj AS petaling, @c_pg AS timur_laut, @c_lgk AS langkawi;


-- ----------------------------------------------------------------------------
-- Joined group records (community_member)
--
-- NOTE on `role`: the app itself only ever writes 'Member' (see
-- ExploreCommunityService's join path). The 'Admin' rows below are seed
-- flavour so the participant list has something other than one repeated
-- label to render — nothing in the backend grants them extra permissions.
-- ----------------------------------------------------------------------------

-- Kuala Lumpur Community — all five users, the busy group
INSERT INTO community_member (community_id, user_id, role, is_active, joined_at, left_at) VALUES
    (@c_kl, @u_alice, 'Admin',  TRUE, @now - INTERVAL 30 DAY, NULL),
    (@c_kl, @u_bob,   'Member', TRUE, @now - INTERVAL 28 DAY, NULL),
    (@c_kl, @u_carol, 'Member', TRUE, @now - INTERVAL 25 DAY, NULL),
    (@c_kl, @u_erin,  'Member', TRUE, @now - INTERVAL 20 DAY, NULL),
    (@c_kl, @u_dave,  'Member', TRUE, @now - INTERVAL 10 DAY, NULL);

-- Petaling Community — three members
INSERT INTO community_member (community_id, user_id, role, is_active, joined_at, left_at) VALUES
    (@c_pj, @u_alice, 'Member', TRUE, @now - INTERVAL 26 DAY, NULL),
    (@c_pj, @u_bob,   'Member', TRUE, @now - INTERVAL 22 DAY, NULL),
    (@c_pj, @u_erin,  'Member', TRUE, @now - INTERVAL 18 DAY, NULL);

-- Timur Laut Community (George Town, Penang) — carol's home group
INSERT INTO community_member (community_id, user_id, role, is_active, joined_at, left_at) VALUES
    (@c_pg, @u_carol, 'Admin',  TRUE, @now - INTERVAL 40 DAY, NULL),
    (@c_pg, @u_alice, 'Member', TRUE, @now - INTERVAL 12 DAY, NULL),
    (@c_pg, @u_dave,  'Member', TRUE, @now - INTERVAL  9 DAY, NULL);

-- Langkawi Community — includes one member who left (rejoin-path test case)
INSERT INTO community_member (community_id, user_id, role, is_active, joined_at, left_at) VALUES
    (@c_lgk, @u_dave, 'Admin',  TRUE,  @now - INTERVAL 60 DAY, NULL),
    (@c_lgk, @u_bob,  'Member', TRUE,  @now - INTERVAL 35 DAY, NULL),
    (@c_lgk, @u_erin, 'Member', FALSE, @now - INTERVAL 30 DAY, @now - INTERVAL 5 DAY);


-- ============================================================================
-- Chat records (message)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Kuala Lumpur Community — started ~2 days ago
-- ----------------------------------------------------------------------------
SET @t := @now - INTERVAL 2 DAY;

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_kl, @u_alice, 'Morning all. Has anyone been to the night market at Jalan Alor recently?', NULL, FALSE, @t + INTERVAL 0 MINUTE);
SET @m_kl1 := LAST_INSERT_ID();

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_kl, @u_bob, 'Went last Saturday. Packed but worth it, go before 7pm if you want a table.', NULL, FALSE, @t + INTERVAL 7 MINUTE);
SET @m_kl2 := LAST_INSERT_ID();

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_kl, @u_carol, 'Noted. Is parking still bad around there?', @m_kl2, FALSE, @t + INTERVAL 12 MINUTE);
SET @m_kl3 := LAST_INSERT_ID();

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_kl, @u_bob, 'Park at Fahrenheit88 and walk over. Much easier than circling Alor itself.', @m_kl3, FALSE, @t + INTERVAL 15 MINUTE);
SET @m_kl4 := LAST_INSERT_ID();

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_kl, @u_dave, 'First time in KL next month. What is worth doing besides the Twin Towers?', NULL, FALSE, @t + INTERVAL 45 MINUTE);
SET @m_kl5 := LAST_INSERT_ID();

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_kl, @u_alice, 'Batu Caves early in the morning, then Central Market for lunch.', @m_kl5, FALSE, @t + INTERVAL 52 MINUTE);
SET @m_kl6 := LAST_INSERT_ID();

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_kl, @u_erin, 'Second Batu Caves. Go before 9am, the stairs are brutal after that.', @m_kl5, FALSE, @t + INTERVAL 58 MINUTE);
SET @m_kl7 := LAST_INSERT_ID();

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_kl, @u_dave, 'Appreciate it, both on the list now.', NULL, FALSE, @t + INTERVAL 63 MINUTE);
SET @m_kl8 := LAST_INSERT_ID();

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_kl, @u_carol, 'Does anyone know if the KL Tower skybridge is open again?', NULL, FALSE, @t + INTERVAL 180 MINUTE);
SET @m_kl9 := LAST_INSERT_ID();

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_kl, @u_alice, 'Reopened about two weeks ago. Book online, the walk-in queue is long.', @m_kl9, FALSE, @t + INTERVAL 187 MINUTE);
SET @m_kl10 := LAST_INSERT_ID();

-- Soft-deleted message. The row stays; the API is expected to hide the content.
INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_kl, @u_bob, 'wrong group, sorry', NULL, TRUE, @t + INTERVAL 240 MINUTE);
SET @m_kl11 := LAST_INSERT_ID();

-- Edge case worth eyeballing in the UI: a live reply whose parent is deleted.
INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_kl, @u_carol, 'No worries.', @m_kl11, FALSE, @t + INTERVAL 244 MINUTE);
SET @m_kl12 := LAST_INSERT_ID();

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_kl, @u_erin, 'Anyone up for a hike at Bukit Tabur this weekend?', NULL, FALSE, @t + INTERVAL 300 MINUTE);
SET @m_kl13 := LAST_INSERT_ID();

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_kl, @u_alice, 'I am in. Saturday 7am?', @m_kl13, FALSE, @t + INTERVAL 305 MINUTE);
SET @m_kl14 := LAST_INSERT_ID();

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_kl, @u_erin, 'Works for me. I will post the meetup point on Friday.', @m_kl14, FALSE, @t + INTERVAL 310 MINUTE);


-- ----------------------------------------------------------------------------
-- Petaling Community — started ~1 day ago
-- ----------------------------------------------------------------------------
SET @t := @now - INTERVAL 1 DAY;

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_pj, @u_alice, 'Has anyone tried the new ramen place in SS15?', NULL, FALSE, @t + INTERVAL 0 MINUTE);
SET @m_pj1 := LAST_INSERT_ID();

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_pj, @u_erin, 'Yes, the queue gets long after 12pm. Go at 11:30 and you walk straight in.', NULL, FALSE, @t + INTERVAL 9 MINUTE);
SET @m_pj2 := LAST_INSERT_ID();

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_pj, @u_bob, 'Is that the one next to the old cinema?', @m_pj2, FALSE, @t + INTERVAL 14 MINUTE);
SET @m_pj3 := LAST_INSERT_ID();

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_pj, @u_erin, 'That is the one.', @m_pj3, FALSE, @t + INTERVAL 16 MINUTE);
SET @m_pj4 := LAST_INSERT_ID();

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_pj, @u_alice, 'Adding it to the list, thanks both.', NULL, FALSE, @t + INTERVAL 20 MINUTE);

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_pj, @u_bob, 'Heads up, One Utama parking rates went up again this month.', NULL, FALSE, @t + INTERVAL 95 MINUTE);


-- ----------------------------------------------------------------------------
-- Timur Laut Community — started ~5 days ago
-- ----------------------------------------------------------------------------
SET @t := @now - INTERVAL 5 DAY;

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_pg, @u_carol, 'Welcome everyone. This group is for George Town and the areas around it.', NULL, FALSE, @t + INTERVAL 0 MINUTE);
SET @m_pg1 := LAST_INSERT_ID();

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_pg, @u_alice, 'Thanks. Planning a Penang trip in October, when is best for street food?', NULL, FALSE, @t + INTERVAL 30 MINUTE);
SET @m_pg2 := LAST_INSERT_ID();

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_pg, @u_carol, 'Evenings along Chulia Street, or Gurney Drive if you want a lot of variety in one spot.', @m_pg2, FALSE, @t + INTERVAL 38 MINUTE);
SET @m_pg3 := LAST_INSERT_ID();

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_pg, @u_dave, 'Is the Penang Hill funicular worth queuing for?', NULL, FALSE, @t + INTERVAL 120 MINUTE);
SET @m_pg4 := LAST_INSERT_ID();

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_pg, @u_carol, 'On a weekday morning the queue is half as long, and the view is worth it on a clear day.', @m_pg4, FALSE, @t + INTERVAL 131 MINUTE);
SET @m_pg5 := LAST_INSERT_ID();

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_pg, @u_alice, 'Any tips for seeing the murals without the crowds?', NULL, FALSE, @t + INTERVAL 200 MINUTE);
SET @m_pg6 := LAST_INSERT_ID();

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_pg, @u_carol, 'Armenian Street has most of the famous ones. Early morning if you want photos without people in them.', @m_pg6, FALSE, @t + INTERVAL 209 MINUTE);


-- ----------------------------------------------------------------------------
-- Langkawi Community — started ~8 days ago (erin has since left the group)
-- ----------------------------------------------------------------------------
SET @t := @now - INTERVAL 8 DAY;

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_lgk, @u_dave, 'Starting this for anyone heading to Langkawi. Ferries, island hopping, duty free, all welcome.', NULL, FALSE, @t + INTERVAL 0 MINUTE);
SET @m_lgk1 := LAST_INSERT_ID();

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_lgk, @u_bob, 'Which terminal is better to sail from, Kuala Perlis or Kuala Kedah?', NULL, FALSE, @t + INTERVAL 25 MINUTE);
SET @m_lgk2 := LAST_INSERT_ID();

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_lgk, @u_dave, 'Kuala Kedah has more departures. Perlis is the shorter crossing if you can time it.', @m_lgk2, FALSE, @t + INTERVAL 33 MINUTE);
SET @m_lgk3 := LAST_INSERT_ID();

-- Sent while erin was still a member, before she left 5 days ago.
INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_lgk, @u_erin, 'The Sky Bridge was closed when I went last year. Is it open now?', NULL, FALSE, @t + INTERVAL 150 MINUTE);
SET @m_lgk4 := LAST_INSERT_ID();

INSERT INTO message (community_id, sender_user_id, content, reply_to_message_id, is_deleted, sent_at)
VALUES (@c_lgk, @u_dave, 'Open again since March, and the cable car ticket includes it now.', @m_lgk4, FALSE, @t + INTERVAL 160 MINUTE);


-- ----------------------------------------------------------------------------
-- Verification
-- ----------------------------------------------------------------------------
SELECT c.name                                   AS community,
       COUNT(DISTINCT cm.user_id)               AS members_total,
       SUM(cm.is_active)                        AS members_active,
       (SELECT COUNT(*) FROM message m WHERE m.community_id = c.community_id) AS messages
  FROM community c
  JOIN community_member cm ON cm.community_id = c.community_id
 WHERE c.name IN ('Kuala Lumpur Community','Petaling Community','Timur Laut Community','Langkawi Community')
 GROUP BY c.community_id, c.name
 ORDER BY messages DESC;
