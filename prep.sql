create database email;

use email;

CREATE TABLE `mailusers` (
  `userid` mediumint(9) NOT NULL AUTO_INCREMENT,
  `mailuser` varchar(255) DEFAULT NULL,
  `mailpass` varchar(255) DEFAULT NULL,
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`userid`)
) ENGINE=InnoDB AUTO_INCREMENT=87 DEFAULT CHARSET=latin1
;


CREATE TABLE `messages` (
  `msgid` mediumint(9) NOT NULL AUTO_INCREMENT,
  `msg` mediumblob,
  `mailfrom` varchar(255) DEFAULT NULL,
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `fromip` varchar(15) DEFAULT NULL,
  PRIMARY KEY (`msgid`)
) ENGINE=InnoDB AUTO_INCREMENT=528134 DEFAULT CHARSET=utf8;


CREATE TABLE `rcptto` (
  `rcptto` varchar(255) DEFAULT NULL,
  `msgid` mediumint(9) NOT NULL,
  `viewed` varchar(255) DEFAULT NULL,
  `sender_auth` varchar(60) DEFAULT NULL,
  `mta_status` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

insert into mailusers (mailuser, mailpass) values ('some_real_user_to_let_auth@some_real_domain.com', 'who cares this is just a spam catcher');

