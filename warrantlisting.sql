CREATE TABLE IF NOT EXISTS `rj_warrants` (
  `citizenid` varchar(100) NOT NULL,
  `date` text DEFAULT NULL,
  `officer` text DEFAULT NULL,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;