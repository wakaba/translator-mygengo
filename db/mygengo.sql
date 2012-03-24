
CREATE TABLE job (
  id BIGINT UNSIGNED NOT NULL,
  source_lang VARCHAR(6) NOT NULL,
  target_lang VARCHAR(6) NOT NULL,
  source_body BLOB NOT NULL,
  target_body BLOB NOT NULL,
  status VARCHAR(15) NOT NULL,
  data MEDIUMBLOB NOT NULL,
  job_created TIMESTAMP NOT NULL DEFAULT 0,
  updated TIMESTAMP NOT NULL DEFAULT 0,
  approved TIMESTAMP NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY (job_created),
  KEY (updated),
  KEY (status, updated),
  KEY (approved)
) DEFAULT CHARSET=BINARY;
