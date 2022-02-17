CREATE SCHEMA `micronaut` DEFAULT CHARACTER SET utf8 ;
USE `micronaut`;
CREATE TABLE `hello_world` (
                               `id` bigint(20) NOT NULL AUTO_INCREMENT,
                               `text` varchar(255) DEFAULT NULL,
                               PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=latin1;

INSERT INTO `hello_world` (`text`)
VALUES
('hello world micronaut');