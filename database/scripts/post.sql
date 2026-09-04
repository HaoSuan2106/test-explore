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