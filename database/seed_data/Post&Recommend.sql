INSERT INTO community_posts
(post_id, author_id, tagged_place_id, title, description, views_count, status, created_at, updated_at)
VALUES
('post-001', 1, 'plc-001',
 'Sunset at Batu Caves',
 'Visited Batu Caves in the late afternoon. Sunset light made the limestone cliffs look amazing. Go before sunset if you want better photos.',
 42, 'ACTIVE', '2026-08-25 18:00:00.000000', '2026-08-25 18:00:00.000000'),

('post-002', 2, 'plc-002',
 'Cliff Point Evening Walk',
 'Quiet coastal walking route with a beautiful sunset view. Bring water and allow enough time to walk back before it gets dark.',
 35, 'ACTIVE', '2026-08-26 18:30:00.000000', '2026-08-26 18:30:00.000000'),

('post-003', 3, 'plc-003',
 'Emerald Lake Trail',
 'Beginner-friendly trail around a clear turquoise lake. Trail can become muddy after rain, so proper shoes are recommended.',
 28, 'ACTIVE', '2026-08-27 09:00:00.000000', '2026-08-27 09:00:00.000000'),

('post-004', 4, 'plc-004',
 'KLCC Night View',
 'KLCC Park gives excellent views of Petronas Towers after sunset. Fountain area is a good place for night photography.',
 51, 'ACTIVE', '2026-08-28 19:00:00.000000', '2026-08-28 19:00:00.000000'),

('post-005', 5, 'plc-006',
 'Cameron Highlands Tea Plantation',
 'Morning visit to tea plantation with cool weather and misty hills. Factory tour and tea tasting are worth adding to your trip.',
 39, 'ACTIVE', '2026-08-29 08:00:00.000000', '2026-08-29 08:00:00.000000');


INSERT INTO community_post_images
(image_id, post_id, image_url, display_order, created_at)
VALUES
('img-001', 'post-001', 'https://images.unsplash.com/photo-1596422846543-75c6fc197f07', 1, '2026-08-25 18:00:00.000000'),
('img-002', 'post-001', 'https://images.unsplash.com/photo-1570077188670-e3a8d69ac5ff', 2, '2026-08-25 18:01:00.000000'),
('img-003', 'post-002', 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e', 1, '2026-08-26 18:30:00.000000'),
('img-004', 'post-003', 'https://images.unsplash.com/photo-1503614472-8c93d56e92ce', 1, '2026-08-27 09:00:00.000000'),
('img-005', 'post-004', 'https://images.unsplash.com/photo-1518005020951-eccb494ad742', 1, '2026-08-28 19:00:00.000000'),
('img-006', 'post-005', 'https://images.unsplash.com/photo-1509316975850-ff9c5deb0cd9', 1, '2026-08-29 08:00:00.000000');


INSERT INTO community_post_comments
(comment_id, post_id, author_id, content, likes_count, status, created_at, updated_at)
VALUES
('cmt-001', 'post-001', 2,
 'Sunset photos look amazing. What time did you arrive?',
 4, 'ACTIVE', '2026-08-25 19:00:00.000000', '2026-08-25 19:00:00.000000'),

('cmt-002', 'post-001', 3,
 'I visited last month. Morning was much less crowded.',
 2, 'ACTIVE', '2026-08-25 19:15:00.000000', '2026-08-25 19:15:00.000000'),

('cmt-003', 'post-002', 1,
 'Thanks for sharing. Adding this walking route to my list.',
 3, 'ACTIVE', '2026-08-26 20:00:00.000000', '2026-08-26 20:00:00.000000'),

('cmt-004', 'post-003', 4,
 'Is trail suitable for first-time hikers?',
 1, 'ACTIVE', '2026-08-27 10:00:00.000000', '2026-08-27 10:00:00.000000'),

('cmt-005', 'post-004', 5,
 'KLCC looks great at night. Fountain area is my favourite spot.',
 5, 'ACTIVE', '2026-08-28 20:00:00.000000', '2026-08-28 20:00:00.000000'),

('cmt-006', 'post-005', 2,
 'Morning mist makes tea plantation look beautiful.',
 2, 'ACTIVE', '2026-08-29 09:00:00.000000', '2026-08-29 09:00:00.000000');


INSERT INTO community_post_reactions
(reaction_id, post_id, user_id, reaction_type, status, created_at, updated_at)
VALUES
('rx-001', 'post-001', 2, 'LIKE', 'ACTIVE',
 '2026-08-25 19:10:00.000000', '2026-08-25 19:10:00.000000'),

('rx-002', 'post-001', 3, 'LIKE', 'ACTIVE',
 '2026-08-25 19:20:00.000000', '2026-08-25 19:20:00.000000'),

('rx-003', 'post-002', 4, 'LIKE', 'ACTIVE',
 '2026-08-26 20:10:00.000000', '2026-08-26 20:10:00.000000'),

('rx-004', 'post-003', 1, 'LIKE', 'ACTIVE',
 '2026-08-27 10:15:00.000000', '2026-08-27 10:15:00.000000'),

('rx-005', 'post-004', 5, 'LIKE', 'ACTIVE',
 '2026-08-28 20:15:00.000000', '2026-08-28 20:15:00.000000'),

('rx-006', 'post-005', 2, 'LIKE', 'ACTIVE',
 '2026-08-29 09:15:00.000000', '2026-08-29 09:15:00.000000');


INSERT INTO community_post_reports
(report_id, post_id, reporter_id, reason, status, created_at, withdrawn_at)
VALUES
('rep-001', 'post-001', 4,
 'Inaccurate or outdated place details',
 'ACTIVE', '2026-08-25 20:00:00.000000', NULL),

('rep-002', 'post-002', 5,
 'Other violation',
 'ACTIVE', '2026-08-26 21:00:00.000000', NULL),

('rep-003', 'post-003', 1,
 'Inappropriate or misleading location imagery',
 'ACTIVE', '2026-08-27 11:00:00.000000', NULL),

('rep-004', 'post-004', 2,
 'Commercial Spam Promotion',
 'ACTIVE', '2026-08-28 21:00:00.000000', NULL),

('rep-005', 'post-005', 3,
 'Other violation',
 'WITHDRAWN', '2026-08-29 10:00:00.000000',
 '2026-08-29 11:00:00.000000');

 