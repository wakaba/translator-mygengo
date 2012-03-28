CREATE TABLE job (
  id BIGINT UNSIGNED NOT NULL,
  job_group_id BIGINT UNSIGNED NOT NULL,
  callback_key BIGINT UNSIGNED NOT NULL,
  source_lang VARCHAR(6) NOT NULL,
  target_lang VARCHAR(6) NOT NULL,
  source_body BLOB NOT NULL,
  target_body BLOB NOT NULL,
  status VARCHAR(15) NOT NULL,
  data MEDIUMBLOB NOT NULL,
  data_updated TIMESTAMP NOT NULL DEFAULT 0,
  comments MEDIUMBLOB NOT NULL,
  comments_updated TIMESTAMP NOT NULL DEFAULT 0,
  feedback MEDIUMBLOB NOT NULL,
  feedback_updated TIMESTAMP NOT NULL DEFAULT 0,
  revisions MEDIUMBLOB NOT NULL,
  revisions_updated TIMESTAMP NOT NULL DEFAULT 0,
  repo_msgid VARCHAR(255),
  repo_data MEDIUMBLOB,
  job_created TIMESTAMP NOT NULL DEFAULT 0,
  updated TIMESTAMP NOT NULL DEFAULT 0,
  approved TIMESTAMP NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY (job_created),
  KEY (job_group_id),
  KEY (comments_updated),
  KEY (updated),
  KEY (status, updated),
  KEY (repo_msgid, updated),
  KEY (source_lang, updated),
  KEY (target_lang, updated),
  KEY (approved)
) DEFAULT CHARSET=BINARY;

CREATE TABLE customer_comment (
  id BIGINT UNSIGNED NOT NULL,
  job_id BIGINT UNSIGNED NOT NULL,
  body MEDIUMBLOB NOT NULL,
  created TIMESTAMP NOT NULL,
  author_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (id),
  KEY (job_id, created),
  KEY (author_id, created),
  KEY (created)
) DEFAULT CHARSET=BINARY;

CREATE TABLE job_approval (
  id BIGINT UNSIGNED NOT NULL,
  job_id BIGINT UNSIGNED NOT NULL,
  comment_for_translator MEDIUMBLOB,
  comment_for_mygengo MEDIUMBLOB,
  comment_is_public BOOL NOT NULl,
  rating DECIMAL(5,2) NOT NULL,
  created TIMESTAMP NOT NULL,
  author_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (id),
  KEY (job_id, created),
  KEY (author_id, created),
  KEY (created)
) DEFAULT CHARSET=BINARY;

CREATE TABLE job_rejection (
  id BIGINT UNSIGNED NOT NULL,
  job_id BIGINT UNSIGNED NOT NULL,
  comment_for_translator MEDIUMBLOB,
  reason VARCHAR(31) NOT NULL,
  follow_up VARCHAR(31) NOT NULL,
  created TIMESTAMP NOT NULL,
  author_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (id),
  KEY (job_id, created),
  KEY (author_id, created),
  KEY (created)
) DEFAULT CHARSET=BINARY;

CREATE TABLE job_cancellation (
  id BIGINT UNSIGNED NOT NULL,
  job_id BIGINT UNSIGNED NOT NULL,
  created TIMESTAMP NOT NULL,
  author_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (id),
  KEY (job_id, created),
  KEY (author_id, created),
  KEY (created)
) DEFAULT CHARSET=BINARY;