-- --------------------------------------------------------
-- Host:                         /mnt/Data/Dataku/Coding/Python/shroomery-main/db.sqlite3
-- Server version:               3.54.0
-- Server OS:                    
-- HeidiSQL Version:             12.22.1.841
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES  */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;


-- Dumping database structure for db
CREATE DATABASE "db";
;

-- Dumping structure for table db.auth_group
CREATE TABLE IF NOT EXISTS "auth_group" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "name" varchar(150) NOT NULL UNIQUE);
;

-- Dumping data for table db.auth_group: 0 rows

-- Dumping structure for table db.auth_group_permissions
CREATE TABLE IF NOT EXISTS "auth_group_permissions" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "group_id" integer NOT NULL REFERENCES "auth_group" ("id") DEFERRABLE INITIALLY DEFERRED, "permission_id" integer NOT NULL REFERENCES "auth_permission" ("id") DEFERRABLE INITIALLY DEFERRED);
CREATE UNIQUE INDEX "auth_group_permissions_group_id_permission_id_0cd325b0_uniq" ON "auth_group_permissions" ("group_id", "permission_id");
CREATE INDEX "auth_group_permissions_group_id_b120cbf9" ON "auth_group_permissions" ("group_id");
CREATE INDEX "auth_group_permissions_permission_id_84c5c92e" ON "auth_group_permissions" ("permission_id");

-- Dumping data for table db.auth_group_permissions: 0 rows

-- Dumping structure for table db.auth_permission
CREATE TABLE IF NOT EXISTS "auth_permission" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "content_type_id" integer NOT NULL REFERENCES "django_content_type" ("id") DEFERRABLE INITIALLY DEFERRED, "codename" varchar(100) NOT NULL, "name" varchar(255) NOT NULL);
CREATE UNIQUE INDEX "auth_permission_content_type_id_codename_01ab375a_uniq" ON "auth_permission" ("content_type_id", "codename");
CREATE INDEX "auth_permission_content_type_id_2f476e4b" ON "auth_permission" ("content_type_id");

-- Dumping data for table db.auth_permission: 288 rows
INSERT INTO "auth_permission" ("id", "content_type_id", "codename", "name") VALUES
	(1, 1, 'add_logentry', 'Can add log entry'),
	(2, 1, 'change_logentry', 'Can change log entry'),
	(3, 1, 'delete_logentry', 'Can delete log entry'),
	(4, 1, 'view_logentry', 'Can view log entry'),
	(5, 3, 'add_permission', 'Can add permission'),
	(6, 3, 'change_permission', 'Can change permission'),
	(7, 3, 'delete_permission', 'Can delete permission'),
	(8, 3, 'view_permission', 'Can view permission'),
	(9, 2, 'add_group', 'Can add group'),
	(10, 2, 'change_group', 'Can change group'),
	(11, 2, 'delete_group', 'Can delete group'),
	(12, 2, 'view_group', 'Can view group'),
	(13, 4, 'add_contenttype', 'Can add content type'),
	(14, 4, 'change_contenttype', 'Can change content type'),
	(15, 4, 'delete_contenttype', 'Can delete content type'),
	(16, 4, 'view_contenttype', 'Can view content type'),
	(17, 5, 'add_session', 'Can add session'),
	(18, 5, 'change_session', 'Can change session'),
	(19, 5, 'delete_session', 'Can delete session'),
	(20, 5, 'view_session', 'Can view session'),
	(21, 12, 'add_lot', 'Can add lot'),
	(22, 12, 'change_lot', 'Can change lot'),
	(23, 12, 'delete_lot', 'Can delete lot'),
	(24, 12, 'view_lot', 'Can view lot'),
	(25, 37, 'add_tenant', 'Can add tenant'),
	(26, 37, 'change_tenant', 'Can change tenant'),
	(27, 37, 'delete_tenant', 'Can delete tenant'),
	(28, 37, 'view_tenant', 'Can view tenant'),
	(29, 23, 'add_material', 'Can add material'),
	(30, 23, 'change_material', 'Can change material'),
	(31, 23, 'delete_material', 'Can delete material'),
	(32, 23, 'view_material', 'Can view material'),
	(33, 13, 'add_lotmaterial', 'Can add lot material'),
	(34, 13, 'change_lotmaterial', 'Can change lot material'),
	(35, 13, 'delete_lotmaterial', 'Can delete lot material'),
	(36, 13, 'view_lotmaterial', 'Can view lot material'),
	(37, 38, 'add_user', 'Can add user'),
	(38, 38, 'change_user', 'Can change user'),
	(39, 38, 'delete_user', 'Can delete user'),
	(40, 38, 'view_user', 'Can view user'),
	(41, 10, 'add_inoculationrun', 'Can add inoculation run'),
	(42, 10, 'change_inoculationrun', 'Can change inoculation run'),
	(43, 10, 'delete_inoculationrun', 'Can delete inoculation run'),
	(44, 10, 'view_inoculationrun', 'Can view inoculation run'),
	(45, 9, 'add_inoculationbatch', 'Can add inoculation batch'),
	(46, 9, 'change_inoculationbatch', 'Can change inoculation batch'),
	(47, 9, 'delete_inoculationbatch', 'Can delete inoculation batch'),
	(48, 9, 'view_inoculationbatch', 'Can view inoculation batch'),
	(49, 11, 'add_location', 'Can add location'),
	(50, 11, 'change_location', 'Can change location'),
	(51, 11, 'delete_location', 'Can delete location'),
	(52, 11, 'view_location', 'Can view location'),
	(53, 14, 'add_lotmovement', 'Can add lot movement'),
	(54, 14, 'change_lotmovement', 'Can change lot movement'),
	(55, 14, 'delete_lotmovement', 'Can delete lot movement'),
	(56, 14, 'view_lotmovement', 'Can view lot movement'),
	(57, 35, 'add_sterilizationrun', 'Can add sterilization run'),
	(58, 35, 'change_sterilizationrun', 'Can change sterilization run'),
	(59, 35, 'delete_sterilizationrun', 'Can delete sterilization run'),
	(60, 35, 'view_sterilizationrun', 'Can view sterilization run'),
	(61, 34, 'add_sterilizationinput', 'Can add sterilization input'),
	(62, 34, 'change_sterilizationinput', 'Can change sterilization input'),
	(63, 34, 'delete_sterilizationinput', 'Can delete sterilization input'),
	(64, 34, 'view_sterilizationinput', 'Can view sterilization input'),
	(65, 8, 'add_incubationrecord', 'Can add incubation record'),
	(66, 8, 'change_incubationrecord', 'Can change incubation record'),
	(67, 8, 'delete_incubationrecord', 'Can delete incubation record'),
	(68, 8, 'view_incubationrecord', 'Can view incubation record'),
	(69, 24, 'add_materialmovement', 'Can add material movement'),
	(70, 24, 'change_materialmovement', 'Can change material movement'),
	(71, 24, 'delete_materialmovement', 'Can delete material movement'),
	(72, 24, 'view_materialmovement', 'Can view material movement'),
	(73, 36, 'add_supplier', 'Can add supplier'),
	(74, 36, 'change_supplier', 'Can change supplier'),
	(75, 36, 'delete_supplier', 'Can delete supplier'),
	(76, 36, 'view_supplier', 'Can view supplier'),
	(77, 25, 'add_materialpurchase', 'Can add material purchase'),
	(78, 25, 'change_materialpurchase', 'Can change material purchase'),
	(79, 25, 'delete_materialpurchase', 'Can delete material purchase'),
	(80, 25, 'view_materialpurchase', 'Can view material purchase'),
	(81, 26, 'add_materialpurchaseline', 'Can add material purchase line'),
	(82, 26, 'change_materialpurchaseline', 'Can change material purchase line'),
	(83, 26, 'delete_materialpurchaseline', 'Can delete material purchase line'),
	(84, 26, 'view_materialpurchaseline', 'Can view material purchase line'),
	(85, 27, 'add_recipe', 'Can add recipe'),
	(86, 27, 'change_recipe', 'Can change recipe'),
	(87, 27, 'delete_recipe', 'Can delete recipe'),
	(88, 27, 'view_recipe', 'Can view recipe'),
	(89, 29, 'add_recipeversion', 'Can add recipe version'),
	(90, 29, 'change_recipeversion', 'Can change recipe version'),
	(91, 29, 'delete_recipeversion', 'Can delete recipe version'),
	(92, 29, 'view_recipeversion', 'Can view recipe version'),
	(93, 28, 'add_recipeline', 'Can add recipe line'),
	(94, 28, 'change_recipeline', 'Can change recipe line'),
	(95, 28, 'delete_recipeline', 'Can delete recipe line'),
	(96, 28, 'view_recipeline', 'Can view recipe line'),
	(97, 16, 'add_machine', 'Can add machine'),
	(98, 16, 'change_machine', 'Can change machine'),
	(99, 16, 'delete_machine', 'Can delete machine'),
	(100, 16, 'view_machine', 'Can view machine'),
	(101, 20, 'add_machinerate', 'Can add machine rate'),
	(102, 20, 'change_machinerate', 'Can change machine rate'),
	(103, 20, 'delete_machinerate', 'Can delete machine rate'),
	(104, 20, 'view_machinerate', 'Can view machine rate'),
	(105, 21, 'add_machineusage', 'Can add machine usage'),
	(106, 21, 'change_machineusage', 'Can change machine usage'),
	(107, 21, 'delete_machineusage', 'Can delete machine usage'),
	(108, 21, 'view_machineusage', 'Can view machine usage'),
	(109, 7, 'add_generaloverheadmonth', 'Can add general overhead month'),
	(110, 7, 'change_generaloverheadmonth', 'Can change general overhead month'),
	(111, 7, 'delete_generaloverheadmonth', 'Can delete general overhead month'),
	(112, 7, 'view_generaloverheadmonth', 'Can view general overhead month'),
	(113, 6, 'add_generaloverheadline', 'Can add general overhead line'),
	(114, 6, 'change_generaloverheadline', 'Can change general overhead line'),
	(115, 6, 'delete_generaloverheadline', 'Can delete general overhead line'),
	(116, 6, 'view_generaloverheadline', 'Can view general overhead line'),
	(117, 15, 'add_lotoverheadallocation', 'Can add lot overhead allocation'),
	(118, 15, 'change_lotoverheadallocation', 'Can change lot overhead allocation'),
	(119, 15, 'delete_lotoverheadallocation', 'Can delete lot overhead allocation'),
	(120, 15, 'view_lotoverheadallocation', 'Can view lot overhead allocation'),
	(121, 18, 'add_machineenergybill', 'Can add machine energy bill'),
	(122, 18, 'change_machineenergybill', 'Can change machine energy bill'),
	(123, 18, 'delete_machineenergybill', 'Can delete machine energy bill'),
	(124, 18, 'view_machineenergybill', 'Can view machine energy bill'),
	(125, 19, 'add_machineenergyreconciliation', 'Can add machine energy reconciliation'),
	(126, 19, 'change_machineenergyreconciliation', 'Can change machine energy reconciliation'),
	(127, 19, 'delete_machineenergyreconciliation', 'Can delete machine energy reconciliation'),
	(128, 19, 'view_machineenergyreconciliation', 'Can view machine energy reconciliation'),
	(129, 22, 'add_machineusageadjustment', 'Can add machine usage adjustment'),
	(130, 22, 'change_machineusageadjustment', 'Can change machine usage adjustment'),
	(131, 22, 'delete_machineusageadjustment', 'Can delete machine usage adjustment'),
	(132, 22, 'view_machineusageadjustment', 'Can view machine usage adjustment'),
	(133, 17, 'add_machinedepreciation', 'Can add machine depreciation'),
	(134, 17, 'change_machinedepreciation', 'Can change machine depreciation'),
	(135, 17, 'delete_machinedepreciation', 'Can delete machine depreciation'),
	(136, 17, 'view_machinedepreciation', 'Can view machine depreciation'),
	(137, 30, 'add_seedlot', 'Can add seed lot'),
	(138, 30, 'change_seedlot', 'Can change seed lot'),
	(139, 30, 'delete_seedlot', 'Can delete seed lot'),
	(140, 30, 'view_seedlot', 'Can view seed lot'),
	(141, 31, 'add_seedmovement', 'Can add seed movement'),
	(142, 31, 'change_seedmovement', 'Can change seed movement'),
	(143, 31, 'delete_seedmovement', 'Can delete seed movement'),
	(144, 31, 'view_seedmovement', 'Can view seed movement'),
	(145, 33, 'add_seedproductionrun', 'Can add seed production run'),
	(146, 33, 'change_seedproductionrun', 'Can change seed production run'),
	(147, 33, 'delete_seedproductionrun', 'Can delete seed production run'),
	(148, 33, 'view_seedproductionrun', 'Can view seed production run'),
	(149, 32, 'add_seedproductionmaterial', 'Can add seed production material'),
	(150, 32, 'change_seedproductionmaterial', 'Can change seed production material'),
	(151, 32, 'delete_seedproductionmaterial', 'Can delete seed production material'),
	(152, 32, 'view_seedproductionmaterial', 'Can view seed production material'),
	(153, 39, 'add_variety', 'Can add variety'),
	(154, 39, 'change_variety', 'Can change variety'),
	(155, 39, 'delete_variety', 'Can delete variety'),
	(156, 39, 'view_variety', 'Can view variety'),
	(157, 40, 'add_buyer', 'Can add buyer'),
	(158, 40, 'change_buyer', 'Can change buyer'),
	(159, 40, 'delete_buyer', 'Can delete buyer'),
	(160, 40, 'view_buyer', 'Can view buyer'),
	(161, 41, 'add_harvest', 'Can add harvest'),
	(162, 41, 'change_harvest', 'Can change harvest'),
	(163, 41, 'delete_harvest', 'Can delete harvest'),
	(164, 41, 'view_harvest', 'Can view harvest'),
	(165, 42, 'add_sale', 'Can add sale'),
	(166, 42, 'change_sale', 'Can change sale'),
	(167, 42, 'delete_sale', 'Can delete sale'),
	(168, 42, 'view_sale', 'Can view sale'),
	(169, 43, 'add_saleline', 'Can add sale line'),
	(170, 43, 'change_saleline', 'Can change sale line'),
	(171, 43, 'delete_saleline', 'Can delete sale line'),
	(172, 43, 'view_saleline', 'Can view sale line'),
	(173, 48, 'add_order', 'Can add order'),
	(174, 48, 'change_order', 'Can change order'),
	(175, 48, 'delete_order', 'Can delete order'),
	(176, 48, 'view_order', 'Can view order'),
	(177, 46, 'add_invoice', 'Can add invoice'),
	(178, 46, 'change_invoice', 'Can change invoice'),
	(179, 46, 'delete_invoice', 'Can delete invoice'),
	(180, 46, 'view_invoice', 'Can view invoice'),
	(181, 49, 'add_orderline', 'Can add order line'),
	(182, 49, 'change_orderline', 'Can change order line'),
	(183, 49, 'delete_orderline', 'Can delete order line'),
	(184, 49, 'view_orderline', 'Can view order line'),
	(185, 47, 'add_invoiceline', 'Can add invoice line'),
	(186, 47, 'change_invoiceline', 'Can change invoice line'),
	(187, 47, 'delete_invoiceline', 'Can delete invoice line'),
	(188, 47, 'view_invoiceline', 'Can view invoice line'),
	(189, 50, 'add_payment', 'Can add payment'),
	(190, 50, 'change_payment', 'Can change payment'),
	(191, 50, 'delete_payment', 'Can delete payment'),
	(192, 50, 'view_payment', 'Can view payment'),
	(193, 44, 'add_customeraccess', 'Can add customer access'),
	(194, 44, 'change_customeraccess', 'Can change customer access'),
	(195, 44, 'delete_customeraccess', 'Can delete customer access'),
	(196, 44, 'view_customeraccess', 'Can view customer access'),
	(197, 45, 'add_customerprice', 'Can add customer price'),
	(198, 45, 'change_customerprice', 'Can change customer price'),
	(199, 45, 'delete_customerprice', 'Can delete customer price'),
	(200, 45, 'view_customerprice', 'Can view customer price'),
	(201, 52, 'add_module', 'Can add module'),
	(202, 52, 'change_module', 'Can change module'),
	(203, 52, 'delete_module', 'Can delete module'),
	(204, 52, 'view_module', 'Can view module'),
	(205, 53, 'add_plan', 'Can add plan'),
	(206, 53, 'change_plan', 'Can change plan'),
	(207, 53, 'delete_plan', 'Can delete plan'),
	(208, 53, 'view_plan', 'Can view plan'),
	(209, 54, 'add_planmodule', 'Can add plan module'),
	(210, 54, 'change_planmodule', 'Can change plan module'),
	(211, 54, 'delete_planmodule', 'Can delete plan module'),
	(212, 54, 'view_planmodule', 'Can view plan module'),
	(213, 56, 'add_subscription', 'Can add subscription'),
	(214, 56, 'change_subscription', 'Can change subscription'),
	(215, 56, 'delete_subscription', 'Can delete subscription'),
	(216, 56, 'view_subscription', 'Can view subscription'),
	(217, 57, 'add_userrole', 'Can add user role'),
	(218, 57, 'change_userrole', 'Can change user role'),
	(219, 57, 'delete_userrole', 'Can delete user role'),
	(220, 57, 'view_userrole', 'Can view user role'),
	(221, 55, 'add_rolepermission', 'Can add role permission'),
	(222, 55, 'change_rolepermission', 'Can change role permission'),
	(223, 55, 'delete_rolepermission', 'Can delete role permission'),
	(224, 55, 'view_rolepermission', 'Can view role permission'),
	(225, 51, 'add_auditlog', 'Can add audit log'),
	(226, 51, 'change_auditlog', 'Can change audit log'),
	(227, 51, 'delete_auditlog', 'Can delete audit log'),
	(228, 51, 'view_auditlog', 'Can view audit log'),
	(229, 58, 'add_productionphase', 'Can add production phase'),
	(230, 58, 'change_productionphase', 'Can change production phase'),
	(231, 58, 'delete_productionphase', 'Can delete production phase'),
	(232, 58, 'view_productionphase', 'Can view production phase'),
	(233, 60, 'add_device', 'Can add device'),
	(234, 60, 'change_device', 'Can change device'),
	(235, 60, 'delete_device', 'Can delete device'),
	(236, 60, 'view_device', 'Can view device'),
	(237, 61, 'add_employee', 'Can add employee'),
	(238, 61, 'change_employee', 'Can change employee'),
	(239, 61, 'delete_employee', 'Can delete employee'),
	(240, 61, 'view_employee', 'Can view employee'),
	(241, 59, 'add_attendance', 'Can add attendance'),
	(242, 59, 'change_attendance', 'Can change attendance'),
	(243, 59, 'delete_attendance', 'Can delete attendance'),
	(244, 59, 'view_attendance', 'Can view attendance'),
	(245, 62, 'add_leave', 'Can add leave'),
	(246, 62, 'change_leave', 'Can change leave'),
	(247, 62, 'delete_leave', 'Can delete leave'),
	(248, 62, 'view_leave', 'Can view leave'),
	(249, 63, 'add_payroll', 'Can add payroll'),
	(250, 63, 'change_payroll', 'Can change payroll'),
	(251, 63, 'delete_payroll', 'Can delete payroll'),
	(252, 63, 'view_payroll', 'Can view payroll'),
	(253, 64, 'add_sensor', 'Can add sensor'),
	(254, 64, 'change_sensor', 'Can change sensor'),
	(255, 64, 'delete_sensor', 'Can delete sensor'),
	(256, 64, 'view_sensor', 'Can view sensor'),
	(257, 65, 'add_sensorreading', 'Can add sensor reading'),
	(258, 65, 'change_sensorreading', 'Can change sensor reading'),
	(259, 65, 'delete_sensorreading', 'Can delete sensor reading'),
	(260, 65, 'view_sensorreading', 'Can view sensor reading'),
	(261, 66, 'add_bagloglogging', 'Can add Logging Baglog'),
	(262, 66, 'change_bagloglogging', 'Can change Logging Baglog'),
	(263, 66, 'delete_bagloglogging', 'Can delete Logging Baglog'),
	(264, 66, 'view_bagloglogging', 'Can view Logging Baglog'),
	(265, 67, 'add_plasticpreset', 'Can add Preset Plastik'),
	(266, 67, 'change_plasticpreset', 'Can change Preset Plastik'),
	(267, 67, 'delete_plasticpreset', 'Can delete Preset Plastik'),
	(268, 67, 'view_plasticpreset', 'Can view Preset Plastik'),
	(269, 68, 'add_phasematerialusage', 'Can add Pemakaian Bahan Fase'),
	(270, 68, 'change_phasematerialusage', 'Can change Pemakaian Bahan Fase'),
	(271, 68, 'delete_phasematerialusage', 'Can delete Pemakaian Bahan Fase'),
	(272, 68, 'view_phasematerialusage', 'Can view Pemakaian Bahan Fase'),
	(273, 69, 'add_harvestoverheadallocation', 'Can add Alokasi Overhead Fruiting'),
	(274, 69, 'change_harvestoverheadallocation', 'Can change Alokasi Overhead Fruiting'),
	(275, 69, 'delete_harvestoverheadallocation', 'Can delete Alokasi Overhead Fruiting'),
	(276, 69, 'view_harvestoverheadallocation', 'Can view Alokasi Overhead Fruiting'),
	(277, 70, 'add_costadjustment', 'Can add Penyesuaian Biaya Produksi'),
	(278, 70, 'change_costadjustment', 'Can change Penyesuaian Biaya Produksi'),
	(279, 70, 'delete_costadjustment', 'Can delete Penyesuaian Biaya Produksi'),
	(280, 70, 'view_costadjustment', 'Can view Penyesuaian Biaya Produksi'),
	(281, 71, 'add_fingerprintdevice', 'Can add fingerprint device'),
	(282, 71, 'change_fingerprintdevice', 'Can change fingerprint device'),
	(283, 71, 'delete_fingerprintdevice', 'Can delete fingerprint device'),
	(284, 71, 'view_fingerprintdevice', 'Can view fingerprint device'),
	(285, 72, 'add_fingerprintlog', 'Can add fingerprint log'),
	(286, 72, 'change_fingerprintlog', 'Can change fingerprint log'),
	(287, 72, 'delete_fingerprintlog', 'Can delete fingerprint log'),
	(288, 72, 'view_fingerprintlog', 'Can view fingerprint log');

-- Dumping structure for table db.django_admin_log
CREATE TABLE IF NOT EXISTS "django_admin_log" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "object_id" text NULL, "object_repr" varchar(200) NOT NULL, "action_flag" smallint unsigned NOT NULL CHECK ("action_flag" >= 0), "change_message" text NOT NULL, "content_type_id" integer NULL REFERENCES "django_content_type" ("id") DEFERRABLE INITIALLY DEFERRED, "user_id" bigint NOT NULL REFERENCES "produksi_user" ("id") DEFERRABLE INITIALLY DEFERRED, "action_time" datetime NOT NULL);
CREATE INDEX "django_admin_log_content_type_id_c4bce8eb" ON "django_admin_log" ("content_type_id");
CREATE INDEX "django_admin_log_user_id_c564eba6" ON "django_admin_log" ("user_id");

-- Dumping data for table db.django_admin_log: 30 rows
INSERT INTO "django_admin_log" ("id", "object_id", "object_repr", "action_flag", "change_message", "content_type_id", "user_id", "action_time") VALUES
	(1, '5', 'smoke_10fafc7a@test.com', '3', '', 38, 1, '2026-11-12 00:33:38.941776'),
	(2, '21', 'smoke_16c3f52c@test.com', '3', '', 38, 1, '2026-11-12 00:34:32.450217'),
	(3, '19', 'smoke_2fa11bf0@test.com', '3', '', 38, 1, '2026-11-12 00:34:32.450290'),
	(4, '16', 'smoke_3704a999@test.com', '3', '', 38, 1, '2026-11-12 00:34:32.450392'),
	(5, '18', 'smoke_3886d874@test.com', '3', '', 38, 1, '2026-11-12 00:34:32.450426'),
	(6, '8', 'smoke_53631f06@test.com', '3', '', 38, 1, '2026-11-12 00:34:32.450446'),
	(7, '7', 'smoke_5d982402@test.com', '3', '', 38, 1, '2026-11-12 00:34:32.450464'),
	(8, '13', 'smoke_723b737d@test.com', '3', '', 38, 1, '2026-11-12 00:34:32.450483'),
	(9, '10', 'smoke_799acf2f@test.com', '3', '', 38, 1, '2026-11-12 00:34:32.450501'),
	(10, '23', 'smoke_83ec1742@test.com', '3', '', 38, 1, '2026-11-12 00:34:32.450520'),
	(11, '15', 'smoke_948844cc@test.com', '3', '', 38, 1, '2026-11-12 00:34:32.450538'),
	(12, '12', 'smoke_9575a831@test.com', '3', '', 38, 1, '2026-11-12 00:34:32.450556'),
	(13, '9', 'smoke_bde01832@test.com', '3', '', 38, 1, '2026-11-12 00:34:32.450573'),
	(14, '6', 'smoke_c137d381@test.com', '3', '', 38, 1, '2026-11-12 00:34:32.450605'),
	(15, '17', 'smoke_dbe7dc68@test.com', '3', '', 38, 1, '2026-11-12 00:34:32.450621'),
	(16, '11', 'smoke_dd7570a5@test.com', '3', '', 38, 1, '2026-11-12 00:34:32.450638'),
	(17, '20', 'smoke_dffe4026@test.com', '3', '', 38, 1, '2026-11-12 00:34:32.450655'),
	(18, '24', 'smoke_e0f65227@test.com', '3', '', 38, 1, '2026-11-12 00:34:32.450671'),
	(19, '22', 'smoke_e1010c32@test.com', '3', '', 38, 1, '2026-11-12 00:34:32.450688'),
	(20, '14', 'smoke_e1d5c3f8@test.com', '3', '', 38, 1, '2026-11-12 00:34:32.450705'),
	(21, '4', 'smoke_f74c83e0@test.com', '3', '', 38, 1, '2026-11-12 00:34:32.450722'),
	(22, '27', 'staff@test.com', '3', '', 38, 1, '2026-11-12 00:34:32.450739'),
	(23, '3', 'test@test.com', '3', '', 38, 1, '2026-11-12 00:34:32.450757'),
	(24, '25', 'test@x.id', '3', '', 38, 1, '2026-11-12 00:34:32.450777'),
	(25, '26', 'testform@x.id', '3', '', 38, 1, '2026-11-12 00:34:32.450794'),
	(26, '32', 'Test', '3', '', 37, 1, '2026-11-12 00:36:12.287214'),
	(27, '24', 'Toko Test e0f65227', '2', '[{"changed": {"fields": ["Status"]}}]', 37, 1, '2026-11-12 00:44:29.732736'),
	(28, '31', 'Test', '3', '', 37, 1, '2026-11-12 01:36:11.599840'),
	(29, '30', 'Test', '3', '', 37, 1, '2026-11-12 01:36:29.124823'),
	(30, '29', 'Test', '3', '', 37, 1, '2026-11-12 01:36:29.124889');

-- Dumping structure for table db.django_content_type
CREATE TABLE IF NOT EXISTS "django_content_type" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "app_label" varchar(100) NOT NULL, "model" varchar(100) NOT NULL);
CREATE UNIQUE INDEX "django_content_type_app_label_model_76bd3d3b_uniq" ON "django_content_type" ("app_label", "model");

-- Dumping data for table db.django_content_type: 72 rows
INSERT INTO "django_content_type" ("id", "app_label", "model") VALUES
	(1, 'admin', 'logentry'),
	(2, 'auth', 'group'),
	(3, 'auth', 'permission'),
	(4, 'contenttypes', 'contenttype'),
	(5, 'sessions', 'session'),
	(6, 'produksi', 'generaloverheadline'),
	(7, 'produksi', 'generaloverheadmonth'),
	(8, 'produksi', 'incubationrecord'),
	(9, 'produksi', 'inoculationbatch'),
	(10, 'produksi', 'inoculationrun'),
	(11, 'produksi', 'location'),
	(12, 'produksi', 'lot'),
	(13, 'produksi', 'lotmaterial'),
	(14, 'produksi', 'lotmovement'),
	(15, 'produksi', 'lotoverheadallocation'),
	(16, 'produksi', 'machine'),
	(17, 'produksi', 'machinedepreciation'),
	(18, 'produksi', 'machineenergybill'),
	(19, 'produksi', 'machineenergyreconciliation'),
	(20, 'produksi', 'machinerate'),
	(21, 'produksi', 'machineusage'),
	(22, 'produksi', 'machineusageadjustment'),
	(23, 'produksi', 'material'),
	(24, 'produksi', 'materialmovement'),
	(25, 'produksi', 'materialpurchase'),
	(26, 'produksi', 'materialpurchaseline'),
	(27, 'produksi', 'recipe'),
	(28, 'produksi', 'recipeline'),
	(29, 'produksi', 'recipeversion'),
	(30, 'produksi', 'seedlot'),
	(31, 'produksi', 'seedmovement'),
	(32, 'produksi', 'seedproductionmaterial'),
	(33, 'produksi', 'seedproductionrun'),
	(34, 'produksi', 'sterilizationinput'),
	(35, 'produksi', 'sterilizationrun'),
	(36, 'produksi', 'supplier'),
	(37, 'produksi', 'tenant'),
	(38, 'produksi', 'user'),
	(39, 'produksi', 'variety'),
	(40, 'produksi', 'buyer'),
	(41, 'produksi', 'harvest'),
	(42, 'produksi', 'sale'),
	(43, 'produksi', 'saleline'),
	(44, 'produksi', 'customeraccess'),
	(45, 'produksi', 'customerprice'),
	(46, 'produksi', 'invoice'),
	(47, 'produksi', 'invoiceline'),
	(48, 'produksi', 'order'),
	(49, 'produksi', 'orderline'),
	(50, 'produksi', 'payment'),
	(51, 'produksi', 'auditlog'),
	(52, 'produksi', 'module'),
	(53, 'produksi', 'plan'),
	(54, 'produksi', 'planmodule'),
	(55, 'produksi', 'rolepermission'),
	(56, 'produksi', 'subscription'),
	(57, 'produksi', 'userrole'),
	(58, 'produksi', 'productionphase'),
	(59, 'produksi', 'attendance'),
	(60, 'produksi', 'device'),
	(61, 'produksi', 'employee'),
	(62, 'produksi', 'leave'),
	(63, 'produksi', 'payroll'),
	(64, 'produksi', 'sensor'),
	(65, 'produksi', 'sensorreading'),
	(66, 'produksi', 'bagloglogging'),
	(67, 'produksi', 'plasticpreset'),
	(68, 'produksi', 'phasematerialusage'),
	(69, 'produksi', 'harvestoverheadallocation'),
	(70, 'produksi', 'costadjustment'),
	(71, 'produksi', 'fingerprintdevice'),
	(72, 'produksi', 'fingerprintlog');

-- Dumping structure for table db.django_migrations
CREATE TABLE IF NOT EXISTS "django_migrations" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "app" varchar(255) NOT NULL, "name" varchar(255) NOT NULL, "applied" datetime NOT NULL);

-- Dumping data for table db.django_migrations: 63 rows
INSERT INTO "django_migrations" ("id", "app", "name", "applied") VALUES
	(1, 'contenttypes', '0001_initial', '2026-11-05 12:01:36.469401'),
	(2, 'contenttypes', '0002_remove_content_type_name', '2026-11-05 12:01:36.480010'),
	(3, 'auth', '0001_initial', '2026-11-05 12:01:36.501598'),
	(4, 'auth', '0002_alter_permission_name_max_length', '2026-11-05 12:01:36.515052'),
	(5, 'auth', '0003_alter_user_email_max_length', '2026-11-05 12:01:36.523627'),
	(6, 'auth', '0004_alter_user_username_opts', '2026-11-05 12:01:36.533175'),
	(7, 'auth', '0005_alter_user_last_login_null', '2026-11-05 12:01:36.543300'),
	(8, 'auth', '0006_require_contenttypes_0002', '2026-11-05 12:01:36.546975'),
	(9, 'auth', '0007_alter_validators_add_error_messages', '2026-11-05 12:01:36.556778'),
	(10, 'auth', '0008_alter_user_username_max_length', '2026-11-05 12:01:36.565381'),
	(11, 'auth', '0009_alter_user_last_name_max_length', '2026-11-05 12:01:36.575805'),
	(12, 'auth', '0010_alter_group_name_max_length', '2026-11-05 12:01:36.586557'),
	(13, 'auth', '0011_update_proxy_permissions', '2026-11-05 12:01:36.594132'),
	(14, 'auth', '0012_alter_user_first_name_max_length', '2026-11-05 12:01:36.603065'),
	(15, 'produksi', '0001_initial', '2026-11-05 12:01:36.676514'),
	(16, 'admin', '0001_initial', '2026-11-05 12:01:36.693786'),
	(17, 'admin', '0002_logentry_remove_auto_add', '2026-11-05 12:01:36.712599'),
	(18, 'admin', '0003_logentry_add_action_flag_choices', '2026-11-05 12:01:36.723949'),
	(19, 'produksi', '0002_lot_phase_lot_variety_inoculationrun_and_more', '2026-11-05 12:01:37.078037'),
	(20, 'produksi', '0003_remove_lotmovement_lot_movement_delta_matches_kind_and_more', '2026-11-05 12:01:37.133713'),
	(21, 'produksi', '0004_lot_lot_valid_quantities', '2026-11-05 12:01:37.159817'),
	(22, 'produksi', '0005_materialmovement', '2026-11-05 12:01:37.191316'),
	(23, 'produksi', '0006_remove_materialmovement_material_movement_sign_matches_kind_and_more', '2026-11-05 12:01:37.301110'),
	(24, 'produksi', '0007_supplier_materialpurchase_materialpurchaseline_and_more', '2026-11-05 12:01:37.408949'),
	(25, 'produksi', '0008_recipe_recipeversion_recipeline_lot_recipe_version_and_more', '2026-11-05 12:01:37.624057'),
	(26, 'produksi', '0009_machine_machinerate_machineusage', '2026-11-05 12:01:37.726518'),
	(27, 'produksi', '0010_generaloverheadmonth_generaloverheadline_lotoverheadallocation', '2026-11-05 12:01:37.821428'),
	(28, 'produksi', '0011_machineenergybill_machineenergyreconciliation_and_more', '2026-11-05 12:01:38.185469'),
	(29, 'produksi', '0012_seedlot_seedmovement_seedproductionrun_and_more', '2026-11-05 12:01:38.426702'),
	(30, 'sessions', '0001_initial', '2026-11-05 12:01:38.435625'),
	(31, 'produksi', '0013_remove_seedlot_seed_lot_source_matches_generation_and_more', '2026-11-05 13:04:50.610945'),
	(32, 'produksi', '0014_alter_tenant_logo', '2026-11-05 13:10:40.413821'),
	(33, 'produksi', '0015_material_material_type_material_min_stock_and_more', '2026-11-08 00:58:54.836101'),
	(34, 'produksi', '0016_variety_alter_lot_variety_and_more', '2026-11-08 09:43:41.326596'),
	(35, 'produksi', '0017_m5_harvest_sale', '2026-11-11 05:15:19.175081'),
	(36, 'produksi', '0018_m5b_portal_pesanan', '2026-11-11 06:26:56.060736'),
	(37, 'produksi', '0019_m6_roles_audit_subscription', '2026-11-11 08:54:14.093566'),
	(38, 'produksi', '0020_add_production_phase_to_material', '2026-11-11 09:49:10.199609'),
	(39, 'produksi', '0021_add_production_phase_model', '2026-11-11 10:54:51.511564'),
	(40, 'produksi', '0022_add_production_phase_model', '2026-11-11 11:10:25.875612'),
	(41, 'produksi', '0023_alter_generaloverheadline_options_and_more', '2026-11-12 04:09:13.694308'),
	(42, 'produksi', '0024_alter_productionphase_options', '2026-11-12 04:09:13.767515'),
	(43, 'produksi', '0025_add_usage_classification_to_material', '2026-11-12 05:41:18.414852'),
	(44, 'produksi', '0026_add_email_verified_to_user', '2026-11-12 09:46:37.119786'),
	(45, 'produksi', '0027_device_employee_attendance_leave_payroll_sensor_and_more', '2026-11-12 10:09:03.507795'),
	(46, 'produksi', '0028_recipe_variety_master', '2026-11-12 15:48:40.521106'),
	(47, 'produksi', '0029_recipe_standard_yield', '2026-11-12 16:22:03.530734'),
	(48, 'produksi', '0030_validate_recipe_standard_yield', '2026-11-12 16:24:40.227600'),
	(49, 'produksi', '0031_bagloglogging', '2026-11-13 04:59:35.020586'),
	(50, 'produksi', '0032_remove_bagloglogging_is_plastic_preset_plasticpreset_and_more', '2026-11-13 05:42:59.024907'),
	(51, 'produksi', '0033_machine_category_material_cost_role_and_more', '2026-11-13 15:13:38.191747'),
	(52, 'produksi', '0034_seed_fruiting_phase', '2026-11-13 15:13:38.457476'),
	(53, 'produksi', '0035_phasematerialusage_and_more', '2026-11-13 15:30:53.923980'),
	(54, 'produksi', '0036_remove_bagloglogging_baglog_logging_nonnegative_costs_and_more', '2026-11-13 16:05:18.039699'),
	(55, 'produksi', '0037_sterilization_input_snapshot_costs', '2026-11-13 16:13:26.657031'),
	(56, 'produksi', '0038_inoculation_machine_overhead_harvest_selling_price', '2026-11-13 16:18:38.583521'),
	(57, 'produksi', '0039_harvest_overhead_fruiting_snapshot', '2026-11-13 17:22:56.746482'),
	(58, 'produksi', '0040_harvestoverheadallocation_and_more', '2026-11-14 06:22:11.776507'),
	(59, 'produksi', '0041_phase7_late_cost', '2026-11-14 06:47:22.325109'),
	(60, 'produksi', '0042_add_garden_user_theme', '2026-11-14 10:29:51.733238'),
	(61, 'produksi', '0043_add_payroll_salary_wage_fields', '2026-11-15 23:04:57.647154'),
	(62, 'produksi', '0044_set_default_total_salary', '2026-11-15 23:05:55.200976'),
	(63, 'produksi', '0045_add_fingerprint_models', '2026-11-15 23:15:06.568390');

-- Dumping structure for table db.django_session
CREATE TABLE IF NOT EXISTS "django_session" ("session_key" varchar(40) NOT NULL PRIMARY KEY, "session_data" text NOT NULL, "expire_date" datetime NOT NULL);
;
CREATE INDEX "django_session_expire_date_a5c62663" ON "django_session" ("expire_date");

-- Dumping data for table db.django_session: 35 rows
INSERT INTO "django_session" ("session_key", "session_data", "expire_date") VALUES
	('0abxq8h4vd4km9l1kuf41zxh06t35bn9', '.eJxVjMsKgzAQAP9lzyUkq8bgsfd-g2z20dgWBaOn0n8vgof2OjPMG0batzLuVddxEhgA4fLLMvFT50PIg-b74niZt3XK7kjcaau7LaKv69n-DQrVAgNEJlXm4FuvlpLE1MbOo3DPTe4DJmtMtLccAiH6LInEDDF1nAORwecLBGU5Dw:1xSBgm:6Y021KcRw66hiiJM_oGhUdkWANmX3jj-c55aTfGyUOE', '2026-11-28 11:12:56.223496'),
	('1ao2v926d14d2z13y660rspq12tetcb6', '.eJxVjLsOgzAMAP_FcxUl1OTB2J1vQHbsFNoKJAJT1X-vkBja9e50bxho38Zhr7oOk0AHDi6_jCk_dT6EPGi-LyYv87ZObI7EnLaafhF93c72bzBSHaGDFLwt5DjYUsil7HJjE6JIQqSrcrQtI6uENkiJgjloQI9JojbeF4HPF-vTOEo:1xOwP7:d-dhrbL2e6tHm940q72pvYI9na8fuVTbFMzz3Ml064E', '2026-11-19 12:17:17.677612'),
	('1cau97njsoceoj4c310zh2fh2i3qoyuq', '.eJxVjMsOgjAQAP9lz6bptmsfHL3zDaTsthY1kFA4Gf_dkHDQ68xk3jCkfavD3vI6TAIdoIbLLxwTP_N8GHmk-b4oXuZtnUZ1JOq0TfWL5NftbP8GNbUKHZC4wFfS6Ek7ZoqRLKPRxYuXUOJosVAKBksJpmDIYiw6q5m9phQtfL7l5zdE:1xR0mn:QcCuxMhHeZUZk6aUvAp8TnyzqFBoDXiGcjDL9Uzz_88', '2026-11-25 05:22:17.310884'),
	('1zvmudt2pn2p2drqga0tcp81trvxq4wl', '.eJxVjMsKgzAQAP9lzyUkq8bgsfd-g2z20dgWBaOn0n8vgof2OjPMG0batzLuVddxEhgA4fLLMvFT50PIg-b74niZt3XK7kjcaau7LaKv69n-DQrVAgNEJlXm4FuvlpLE1MbOo3DPTe4DJmtMtLccAiH6LInEDDF1nAORwecLBGU5Dw:1xPvsj:BXZv_Fs8aeQKz6J2vzdPIVDNSGoM7mdoHzmPUUl9x30', '2026-11-22 05:55:57.018168'),
	('2h1g4yj34ty9z4izwgkey0im85o00fm7', '.eJxVjEsOgjAUAO_y1qaRUvph6Z4zkPfps6iBhMLKeHdDwkK3M5N5w4j7Vsa95nWcBHqwHi6_kJCfeT6MPHC-L4aXeVsnMkdiTlvNsEh-3c72b1CwFuiBSZisqmNMkTnl1ARp4pUscqtBgvjUUucQvWrucsPROQ3shSSKtvD5AlNtOfs:1xR54U:Pl-BoBqUuQRKwA2NvNDzDPjw146bCQzJCJG2aOLMIto', '2026-11-25 09:56:50.246013'),
	('38vrb8n91t9h4k728b8ho3vo36cesjhq', '.eJxVjMsKwyAQAP9lz0Usurrm2Hu_QdZXTVsUYnIK_fcSyKG9zgyzg-dtrX4befFzggkMXH5Z4PjK7RDpye3RRextXeYgjkScdoh7T_l9O9u_QeVRYYJCFK1ONmrSMSCzLvKKBhNpqxwxIiEV42RwVunILnNARLJFSbJE8PkC2IE3Hw:1xR0lD:DsATxQmiqF30LjBZTZGuswIj3ufkpg0fMCPYYUmgwu8', '2026-11-25 05:20:39.452931'),
	('4ph9aace6fkvl17u7cqd84bsaxp3qymj', '.eJxVjDEOgzAMAP_iuYowTXDC2J03INtJGtoKJAJT1b9XSAztene6N4y8b2Xca1rHKUIP6ODyC4X1mebDxAfP98XoMm_rJOZIzGmrGZaYXrez_RsUrgV66FS9eBRWsYRKLGSvIUpo2oZy2zlMGJi85hiIW85iNaFzyXnFjix8vh6oOGs:1xR0oF:jpQFVYcvZ3G5FbK1kc0uhAg9bbDf4Veet9hLHbiwS5c', '2026-11-25 05:23:47.814533'),
	('95bleyi2va87dmarway4v3xo6kjatpbx', '.eJxVjDEOgzAMAP_iuYqIEyBm7N43IJvYhbYCicBU9e8VEkO73p3uDT3v29jvRdd-ytBBC5dfJjw8dT5EfvB8X9ywzNs6iTsSd9ribkvW1_Vs_wYjlxE6CLVmIaM6kfdsNWIbGiOxJBRTFTOqRc8YklFEE64ajMmzEGoMavD5At3MN7w:1xR0lX:TQnxI2b85Rdz7xrDNI6jXd50XprJ1J49b9UvfcDTHbQ', '2026-11-25 05:20:59.082987'),
	('a7jam18lrljwhf0kjerqtxmh3399soux', '.eJxVjEsOgjAUAO_y1qahr7QFlu49A3m_Cmog4bMy3t2QsNDtzGTe0NO-Df2-2tKPCh1ggMsvZJKnTYfRB0332ck8bcvI7kjcaVd3m9Ve17P9Gwy0DtBBI7EOgTGUIMSIKfvaWjMtyIxWWcomyKoSMTWx9cra5LqiKmkq7OHzBRvZOLo:1xR1tK:B57ew4GB7skW8zpkx_7RVHm58r6EWB1Ux5Ji98YYOCY', '2026-11-25 06:33:06.541188'),
	('awf8l2hqvagvvbjvd1p0b8irdyegut1i', '.eJxVjLsOwjAMAP_FM4qaNo1JR_Z-Q2U7MSmgROpjQvw7qtQB1rvTvWGifcvTvqZlmiMM0MPllzHJM5VDxAeVezVSy7bMbI7EnHY1Y43pdTvbv0GmNcMA2AZBcY56Dok1Erei7C312mDL4sNVLAbbRatImixqcLZDddR4RIbPFwd-OG8:1xR0ke:JzBFDJkVldkbTqeowzta2gWo1uc21ACc55_IY2fwo4o', '2026-11-25 05:20:04.690111'),
	('bq99wjma6jtc8t209kak7x1juiofrutq', '.eJxVjDsKwzAQBe-ydRArWauPy_Q5g1j9YifBBsuuQu4eBC6S6sHM8N4Q-NincLSyhTnDCErD5RdGTs-ydJMfvNxXkdZl3-YoeiJO28RtzeV1Pdu_g4nbBCNQJkUJscTBGlOcdwm9snEwPDhlvalSUTXS60pMWLXlvqlKSxglwucL4H826A:1xR27e:a2zhRuAg1uHpnrT8gfPHz4PVc-EQFP04bdX2O8kEMVs', '2026-11-25 06:47:54.885519'),
	('cnbyf49s8b6t7dgnja4omla7afvir1b2', '.eJxVjMsOwiAQAP9lz4ZsgYL06L3fQHZ5SNXQpLQn478bkh70OjOZN3g69uKPlja_RJhgsHD5hUzhmWo38UH1voqw1n1bWPREnLaJeY3pdTvbv0GhVmACgxrJyZiSw5EHppyQdXTOOjRXNZoopcsYWIdsmJUOSqHthEgHZvh8AQqvOIg:1xR1Io:eEIPDNVCI0At0rEi2tRvfjvUrTg8KvI9pM9_-yDOWyo', '2026-11-25 05:55:22.038468'),
	('e4lmjr2iwnpknczprgnor4u84pcw0kiv', '.eJxVjMsKgzAQAP9lzyUkq8bgsfd-g2z20dgWBaOn0n8vgof2OjPMG0batzLuVddxEhgA4fLLMvFT50PIg-b74niZt3XK7kjcaau7LaKv69n-DQrVAgNEJlXm4FuvlpLE1MbOo3DPTe4DJmtMtLccAiH6LInEDDF1nAORwecLBGU5Dw:1xRwAv:57JSD06N9KbGHL8SQlIUbos8pAQHXsFJ6CLIK8yQdRs', '2026-11-27 18:39:01.973899'),
	('fb76z3yk7ere364hgbm70kkdbilfz1xl', '.eJxVjDEOwjAMAP_iGUUJdYPdkZ03RE6ckAJqpaadEH9HlTrAene6NwTZ1hq2lpcwKgxAcPplUdIzT7vQh0z32aR5Wpcxmj0xh23mNmt-XY_2b1ClVRggijIi9irEhMgZc7KF9SxaOroUEWTXKRbvS0LHiYkoW7LRJe_7CJ8v-oo4Kw:1xR0mG:CWIBlikr42LY8K6OV8N311QZxObmbwJB7RBG3oXfgvg', '2026-11-25 05:21:44.306446'),
	('fck09hkfpnieays0qcr6gmojnxvi213p', '.eJxVjMsKgzAQAP9lzyUkq8bgsfd-g2z20dgWBaOn0n8vgof2OjPMG0batzLuVddxEhgA4fLLMvFT50PIg-b74niZt3XK7kjcaau7LaKv69n-DQrVAgNEJlXm4FuvlpLE1MbOo3DPTe4DJmtMtLccAiH6LInEDDF1nAORwecLBGU5Dw:1xPzNA:cqPBaaPW0o4ge_JG3ucJeqbUkS8z0WdKPYljQI9fWnc', '2026-11-22 09:39:36.522500'),
	('fqup55nbuf9zcy96vnkf8hydfskfwmp7', '.eJxVjMsOgjAQAP9lz6Yp0MeWo3e_odl2txY1kFA4Gf_dkHDQ68xk3hBp32rcm6xxYhhhgMsvS5SfMh-CHzTfF5WXeVunpI5Enbap28Lyup7t36BSqzBCQYM4mE6y7RMaLsX0nfZObAoBxTkU6l1IzDp7ItQomYPPbL0U7wt8vuE2OGQ:1xR0ju:9UO4Z3891IESFtmunW5-vCrExwxt10O_ImJWRkieYdI', '2026-11-25 05:19:18.635509'),
	('icv8bnbs883lpuse820cv42hp8bznd0v', '.eJxVjDEKwzAMAP-iuRg5xJGdsXvfYGTJrtOWBOJkKv17CWRo17vj3hB532rcW17jpDCChcsvSyzPPB9CHzzfFyPLvK1TMkdiTtvMbdH8up7t36ByqzACS1fCoFmdY1KU5Il6xs5rsYOQY0IbSkjIRUroHHqPLitbEukdEny-_l44NQ:1xRP1w:nA9H89ogqy0pJL-FiyHawebFRja4YhAw4wkJNlU5dcg', '2026-11-26 07:15:32.934873'),
	('igrehf6lm1ottafq0aql999vhyqzf9fc', '.eJxVjMsKgzAQAP9lzyUkq8bgsfd-g2z20dgWBaOn0n8vgof2OjPMG0batzLuVddxEhgA4fLLMvFT50PIg-b74niZt3XK7kjcaau7LaKv69n-DQrVAgNEJlXm4FuvlpLE1MbOo3DPTe4DJmtMtLccAiH6LInEDDF1nAORwecLBGU5Dw:1xSApa:CmJU9OlVY-e_Hb7YB2h_3sJ2f1NnkgLyKK2Sj8AymDI', '2026-11-28 10:17:58.752494'),
	('k2sqbh6jv1eit0mc7gdgr75pxsrwkosr', '.eJxVjMsOwiAQAP9lz4a0UBbo0bvfQBaWlaqhSR8n47-bJj3odWYyb4i0bzXua1nixDCC0XD5hYnys7TD8IPafVZ5btsyJXUk6rSrus1cXtez_RtUWiuMkNmZwbsQeAiojVjbD4zixQolJNHJEPqMwRXGvuvEFEk-kEPvSLyFzxcFzDg4:1xSCxJ:DLgn7eOoFEgu2aLu2HHXB38r97Orlno9LFiijtQHctE', '2026-11-28 12:34:05.489618'),
	('kecov9vwah0zxl6ifb1v0ts305bw8r0v', '.eJxVjDkOwjAQAP-yNbJiO3HslPS8wVrvgQMokXJUiL-jSCmgnRnNGzLuW837KkseGQawES6_sCA9ZToMP3C6z4bmaVvGYo7EnHY1t5nldT3bv0HFtcIAjShb9Z6lt0FFEnmNMbS-o45C1OTIN4p9qyrSYIdoAybHbF1JwSb4fAEvMzjY:1xR1Ui:xqySNK4-e6Wb4L69k1TmRfeyvCwPmodvFFlkO7ozF5I', '2026-11-25 06:07:40.460938'),
	('laota11pohkp3u2e2atr2nu6b5ya1rz3', '.eJxVjLsOgzAMAP_FcxU1IQ6YsTvfgGzHKbQVSDymqv9eITG0693p3tDzvg39vtrSjxlaCHD5ZcL6tOkQ-cHTfXY6T9syijsSd9rVdXO21-1s_wYDrwO0gExiXtEiSWlUGK_oqVIKlWQfUEsoRY2Sx4qQstSpqUmZQkzRZ4PPF_j8OBs:1xOwPj:i3d_jikjV8oSgT7wN3I7zcB2s6-BezF4Zs6QQq4B5dw', '2026-11-19 12:17:55.659163'),
	('n77t2bik21zcdbbhlkke7ebl1mpa9vx2', '.eJxVjEsOgjAUAO_y1qbpa6GlLN1zhuZ9qqAGEgor490NCQvdzkzmDZn2bcx7LWueFHpwCJdfyCTPMh9GHzTfFyPLvK0TmyMxp61mWLS8rmf7NxipjtBDQgpJQvCxFSuoETurntlTUC5Nk1zjJNxiUkyWU1t86DqLJOxcFLHw-QL0Zjee:1xR1kC:KtoeJMXcXZBSdzQxgEc6ZNlaY5txKQgRXdKOR1lrHPw', '2026-11-25 06:23:40.186899'),
	('oolhxclglpbt9techrhmbbhanf0tk704', '.eJxVjE0OgjAUBu_y1qbpH6WydM8ZyGu_YlHTJhRWxrsbEha6nZnMmybetzztLa3TAhpIWbr8wsDxmcph8OByryLWsq1LEEciTtvEWJFet7P9G2RumQbS3FlObu5dP8cA56C0lMrDITkoaToOsDrByt7Ca-_nDlbHeGUj2YA-XxOKOFc:1xR0o0:_Lzz5pq7xzoAQnpbNi-FmnsH2nP9kbMw05EOEZ58yGo', '2026-11-25 05:23:32.913178'),
	('owsrp6gbvu5uz6yabgfrxvwem7wg1keh', '.eJxVjEEOwiAQAP-yZ0MKpZTt0btvILuwSNWUpLQn499Nkx70OjOZNwTatxL2JmuYE0zQd3D5hUzxKcth0oOWe1WxLts6szoSddqmbjXJ63q2f4NCrcAESEyYXbTZGG0HrzlRIpEBMWvvOz-yWOedJo955L5HowfjLI_RcpcFPl8UyDgZ:1xROdw:lH-0ZOtDsyscgz9SnOj8x_hRT1CQGXSqrIBxbY5peQU', '2026-11-26 06:50:44.716603'),
	('pucv9fi5g8ktom964ghg1rca2h78iptx', '.eJxVjEEOwiAQAP-yZ0NQoECP3n0DWXYXqRqalPZk_Ltp0oNeZybzhoTbWtPWZUkTwwgRTr8sIz2l7YIf2O6zormty5TVnqjDdnWbWV7Xo_0bVOwVRqDAaKJQJsMDodNhEPY--Jz9xbNjjeSNaBtDLA7JFH3GaC1JNrEUgc8XEnk5DA:1xR0mb:1aKlJZMlwrtfz0v_3j0OzGR8i95GX7JT44M0dvh1CzU', '2026-11-25 05:22:05.416911'),
	('qk1q92tbwe5n4o128wgykxe24mld9dlp', '.eJxVjEEOwiAQRe_C2hCoMIBL956hYZhBqgaS0q6MdzckXej2v_f-W8xx38q8d17nhcRFaBCn3xFjenIdhB6x3ptMrW7rgnIo8qBd3hrx63q4fwcl9jJqTJZdgszaJEfGTk55PwWd2RJ4RYGDQYJADr0JjPZsDaACyCmAV-LzBRmxOAY:1xR0oS:bnmORnt3mvaENOlyfuoQQN_b1G-NBOWbT7syKJxTqW4', '2026-11-25 05:24:00.328666'),
	('qsf5x3z58b9jq69hlwn6zga1wt0duo0z', '.eJxVjMsKwjAQAP9lzxJqwubRo3e_IWw2G1OVFJr2VPx3KfSg15lhdoi0rTVuXZY4ZRhBI1x-YSJ-STtMflJ7zIrnti5TUkeiTtvVfc7yvp3t36BSrzACWu2Ei3eMZBwFRCFmZ01JPJSENmR3DX5AZzN6TWgoFSqWyQiLD_D5AhtuOOQ:1xR52e:IUWd_y6iUJdYkcwtzBDM1v85gtYsBP_KyowZdggjs0U', '2026-11-25 09:54:56.502110'),
	('r3eoaqi7frvhqw02leyoo2oq255eingm', '.eJxVjEEOwiAQAP-yZ0NgpUB79N43NLsslaqBpLQn499Nkx70OjOZN0y0b3naW1qnRWAARLj8Qqb4TOUw8qByryrWsq0LqyNRp21qrJJet7P9G2RqGQawXpisGE4mXJ3vI7LVlkzHglGi69jP2tqkxWPgqJ2ZTULHvRftkQJ8vhIUOCA:1xR1t2:LuqKtsVe1zGYLXRIGtlIQyKZRhELbqUMh3FR9M2r554', '2026-11-25 06:32:48.398675'),
	('r99ww60lgctiwne6q6dxynp0y6ot82s3', '.eJxVjMsOwiAQAP-FsyG8XIpH735Ds7CLVA0kpT0Z_92Q9KDXmcm8xYz7Vua98zovJC5CG3H6hRHTk-sw9MB6bzK1uq1LlCORh-3y1ohf16P9GxTsZXw1OQugUIeY2J8BsqKJpxyUS-AzerJEjnSwiq0BpGwBk4IQDCbnxOcLAM44Bw:1xR0nC:COhsQhXgoGmoash-Is3fdB6mTYJGfJTaGE9CtzFruw0', '2026-11-25 05:22:42.395119'),
	('tilpicqgmsp4dztxme5gjmpuowti4am4', '.eJxVjDEOgzAMAP_iuYpIYkjC2L1viBzbFNoKJAJT1b9XSAztene6N2TatzHvVdc8CfSAcPllhfip8yHkQfN9MbzM2zoVcyTmtNXcFtHX9Wz_BiPVEXpwMmgTopQmKlrfNuw5aemCZY1MiD7ZQN6iI2L2GG3rBh9EOsHUMcLnC-jGN80:1xR0kM:wPgNu43_QamWPAzdaZp-aYSP1DCBMHwvwuARDyHHk_8', '2026-11-25 05:19:46.211443'),
	('ubl9azt7lpb75d5d9xncovcqk0hnore5', '.eJxVjDEOgzAMAP_iuYpCCDEwdu8bkGM7hbZKJAJT1b9XSAztene6N0y0b_O0V12nRWAEN8DlF0bip-bDyIPyvRgueVuXaI7EnLaaWxF9Xc_2bzBTnWEEHzBF22mv5EQjJ9e0yVuigJ21jesDtipemchjUhzECzci1nEbIiN8viR6OOw:1xROdH:VAWVMzOF6HS4DZtuJjrrN6b-lNKyvGevUZLQoOYyugo', '2026-11-26 06:50:03.902742'),
	('uigd4lh2njsz18v9bmk1clu4d35l9a72', '.eJxVjEsKgzAUAO_y1iXwYozGZfc9g7yf1bYkYHRVevciuGi3M8O8YaR9m8e92jouCgMgwuUXMsnT8mH0QflenJS8rQu7I3Gnre5W1F7Xs_0bzFRnGMALSpQoFFoUP0VD9BP11jCZpkCd9CqNmGFkpRSUfN91bfAsiZMYfL40Ozl8:1xR0n0:m4joCxB0nRfz9MsmhzcShkoRXJ6gB0z5b-4fULtJHJg', '2026-11-25 05:22:30.943532'),
	('uz340lq425ln6nh0df9puks7ocpawf78', '.eJxVjDkOwjAQAP-yNbJ8rjcp6XmD5WONAyiR4qRC_B1FSgHtzGjeEOK-tbB3XsNUYARl4PILU8xPng9THnG-LyIv87ZOSRyJOG0Xt6Xw63q2f4MWe4MRdE4VS8qmYuXsBkIirNEjRdSSjKVqtbOMhMpXqbzTbigDs_KyKO3g8wUO6Ddr:1xR0nQ:EbFsz66lELI8lOGRmpktd9vC-8w1MeX4SaL-8euGRJo', '2026-11-25 05:22:56.509585'),
	('ym2ghhrc2bv0k0ttdg00ym5o0dkzf6cb', '.eJxVjMsOwiAQAP9lz4aA4AI9evcbyC4PqRpISnsy_rtp0oNeZybzhkDbWsM28hLmBBMoD6dfyBSfue0mPajdu4i9rcvMYk_EYYe49ZRf16P9G1QaFSYwNkslrSMu0SbNVAwbx4WNtVm5S-RUfHZKepTGUWTNmNBh0XhGiQY-XyPbOEU:1xR1Uu:r1bmnQkLJ9UMJ6SdRPnnHMr177Hy0ulmpRBlZpDZqVs', '2026-11-25 06:07:52.839943'),
	('z6sehqnetdw2vg4awcsky77p4o4vyglw', '.eJxVjEEOwiAQAP-yZ0OkUGB79N43kGUBqRpISnsy_t006UGvM5N5g6d9K37vafVLhAmGK1x-YSB-pnqY-KB6b4Jb3dYliCMRp-1ibjG9bmf7NyjUC0xgtLY2BW2ILbvIQeEg2aGRpMixYzSaeKSALE1yAXPC7AjzGMkqifD5AhXJOLk:1xR1bO:OYew7GgMUG2aifb8uAAt8SXWjPWxXTF86ePiFBsat5Q', '2026-11-25 06:14:34.632103');

-- Dumping structure for table db.produksi_attendance
CREATE TABLE IF NOT EXISTS "produksi_attendance" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "date" date NOT NULL, "status" varchar(10) NOT NULL, "check_in" time NULL, "check_out" time NULL, "notes" varchar(200) NOT NULL, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, "employee_id" bigint NOT NULL REFERENCES "produksi_employee" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "attendance_unique_employee_date_per_tenant" UNIQUE ("tenant_id", "employee_id", "date"));
;
CREATE INDEX "produksi_attendance_tenant_id_9ff44af0" ON "produksi_attendance" ("tenant_id");
CREATE INDEX "produksi_attendance_employee_id_fd732c54" ON "produksi_attendance" ("employee_id");

-- Dumping data for table db.produksi_attendance: 40 rows
INSERT INTO "produksi_attendance" ("id", "date", "status", "check_in", "check_out", "notes", "tenant_id", "employee_id") VALUES
	(1, '2026-05-18', 'present', NULL, '09:44:08', 'Sinkron dari mesin Mesin Absensi Simulator (UID 4). | Sinkron dari mesin Mesin Absensi Simulator', 1, 4),
	(2, '2026-05-18', 'present', NULL, '09:12:27', 'Sinkron dari mesin Mesin Absensi Simulator (UID 2). | Sinkron dari mesin Mesin Absensi Simulator', 1, 2),
	(3, '2026-05-18', 'present', NULL, '10:03:54', 'Sinkron dari mesin Mesin Absensi Simulator (UID 3). | Sinkron dari mesin Mesin Absensi Simulator', 1, 3),
	(4, '2026-05-18', 'present', NULL, '10:02:47', 'Sinkron dari mesin Mesin Absensi Simulator (UID 5). | Sinkron dari mesin Mesin Absensi Simulator', 1, 5),
	(5, '2026-05-18', 'present', NULL, '10:41:20', 'Sinkron dari mesin Mesin Absensi Simulator (UID 1). | Sinkron dari mesin Mesin Absensi Simulator', 1, 1),
	(6, '2026-05-19', 'present', NULL, '09:43:31', 'Sinkron dari mesin Mesin Absensi Simulator (UID 5). | Sinkron dari mesin Mesin Absensi Simulator', 1, 5),
	(7, '2026-05-19', 'present', NULL, '09:36:52', 'Sinkron dari mesin Mesin Absensi Simulator (UID 4). | Sinkron dari mesin Mesin Absensi Simulator', 1, 4),
	(8, '2026-05-19', 'present', NULL, '10:19:42', 'Sinkron dari mesin Mesin Absensi Simulator (UID 1). | Sinkron dari mesin Mesin Absensi Simulator', 1, 1),
	(9, '2026-05-19', 'present', NULL, '09:04:45', 'Sinkron dari mesin Mesin Absensi Simulator (UID 3). | Sinkron dari mesin Mesin Absensi Simulator', 1, 3),
	(10, '2026-05-19', 'present', NULL, '10:01:46', 'Sinkron dari mesin Mesin Absensi Simulator (UID 2). | Sinkron dari mesin Mesin Absensi Simulator', 1, 2),
	(11, '2026-05-20', 'present', NULL, '10:01:52', 'Sinkron dari mesin Mesin Absensi Simulator (UID 3). | Sinkron dari mesin Mesin Absensi Simulator', 1, 3),
	(12, '2026-05-20', 'present', NULL, '10:47:30', 'Sinkron dari mesin Mesin Absensi Simulator (UID 2). | Sinkron dari mesin Mesin Absensi Simulator', 1, 2),
	(13, '2026-05-20', 'present', NULL, '10:29:43', 'Sinkron dari mesin Mesin Absensi Simulator (UID 4). | Sinkron dari mesin Mesin Absensi Simulator', 1, 4),
	(14, '2026-05-20', 'present', NULL, '10:49:40', 'Sinkron dari mesin Mesin Absensi Simulator (UID 1). | Sinkron dari mesin Mesin Absensi Simulator', 1, 1),
	(15, '2026-05-20', 'present', NULL, '10:52:15', 'Sinkron dari mesin Mesin Absensi Simulator (UID 5). | Sinkron dari mesin Mesin Absensi Simulator', 1, 5),
	(16, '2026-11-11', 'present', NULL, '16:30:00', 'Sinkron dari mesin Mesin Absensi Simulator (UID 2). | Sinkron dari mesin Mesin Absensi Simulator', 1, 2),
	(17, '2026-11-11', 'present', NULL, '16:30:00', 'Sinkron dari mesin Mesin Absensi Simulator (UID 5). | Sinkron dari mesin Mesin Absensi Simulator', 1, 5),
	(18, '2026-11-11', 'present', NULL, '16:30:00', 'Sinkron dari mesin Mesin Absensi Simulator (UID 4). | Sinkron dari mesin Mesin Absensi Simulator', 1, 4),
	(19, '2026-11-11', 'present', NULL, '16:30:00', 'Sinkron dari mesin Mesin Absensi Simulator (UID 1). | Sinkron dari mesin Mesin Absensi Simulator', 1, 1),
	(20, '2026-11-11', 'present', NULL, '16:30:00', 'Sinkron dari mesin Mesin Absensi Simulator (UID 3). | Sinkron dari mesin Mesin Absensi Simulator', 1, 3),
	(21, '2026-11-12', 'present', NULL, '16:30:00', 'Sinkron dari mesin Mesin Absensi Simulator (UID 2). | Sinkron dari mesin Mesin Absensi Simulator', 1, 2),
	(22, '2026-11-12', 'present', NULL, '16:30:00', 'Sinkron dari mesin Mesin Absensi Simulator (UID 5). | Sinkron dari mesin Mesin Absensi Simulator', 1, 5),
	(23, '2026-11-12', 'present', NULL, '16:30:00', 'Sinkron dari mesin Mesin Absensi Simulator (UID 4). | Sinkron dari mesin Mesin Absensi Simulator', 1, 4),
	(24, '2026-11-12', 'present', NULL, '16:30:00', 'Sinkron dari mesin Mesin Absensi Simulator (UID 1). | Sinkron dari mesin Mesin Absensi Simulator', 1, 1),
	(25, '2026-11-12', 'present', NULL, '16:30:00', 'Sinkron dari mesin Mesin Absensi Simulator (UID 3). | Sinkron dari mesin Mesin Absensi Simulator', 1, 3),
	(26, '2026-11-13', 'present', NULL, '16:30:00', 'Sinkron dari mesin Mesin Absensi Simulator (UID 2). | Sinkron dari mesin Mesin Absensi Simulator', 1, 2),
	(27, '2026-11-13', 'present', NULL, '16:30:00', 'Sinkron dari mesin Mesin Absensi Simulator (UID 5). | Sinkron dari mesin Mesin Absensi Simulator', 1, 5),
	(28, '2026-11-13', 'present', NULL, '16:30:00', 'Sinkron dari mesin Mesin Absensi Simulator (UID 4). | Sinkron dari mesin Mesin Absensi Simulator', 1, 4),
	(29, '2026-11-13', 'present', NULL, '16:30:00', 'Sinkron dari mesin Mesin Absensi Simulator (UID 1). | Sinkron dari mesin Mesin Absensi Simulator', 1, 1),
	(30, '2026-11-13', 'present', NULL, '16:30:00', 'Sinkron dari mesin Mesin Absensi Simulator (UID 3). | Sinkron dari mesin Mesin Absensi Simulator', 1, 3),
	(31, '2026-11-14', 'present', NULL, '16:30:00', 'Sinkron dari mesin Mesin Absensi Simulator (UID 2). | Sinkron dari mesin Mesin Absensi Simulator', 1, 2),
	(32, '2026-11-14', 'present', NULL, '16:30:00', 'Sinkron dari mesin Mesin Absensi Simulator (UID 5). | Sinkron dari mesin Mesin Absensi Simulator', 1, 5),
	(33, '2026-11-14', 'present', NULL, '16:30:00', 'Sinkron dari mesin Mesin Absensi Simulator (UID 4). | Sinkron dari mesin Mesin Absensi Simulator', 1, 4),
	(34, '2026-11-14', 'present', NULL, '16:30:00', 'Sinkron dari mesin Mesin Absensi Simulator (UID 1). | Sinkron dari mesin Mesin Absensi Simulator', 1, 1),
	(35, '2026-11-14', 'present', NULL, '16:30:00', 'Sinkron dari mesin Mesin Absensi Simulator (UID 3). | Sinkron dari mesin Mesin Absensi Simulator', 1, 3),
	(36, '2026-11-15', 'present', NULL, '16:30:00', 'Sinkron dari mesin Mesin Absensi Simulator (UID 2). | Sinkron dari mesin Mesin Absensi Simulator', 1, 2),
	(37, '2026-11-15', 'present', NULL, '16:30:00', 'Sinkron dari mesin Mesin Absensi Simulator (UID 5). | Sinkron dari mesin Mesin Absensi Simulator', 1, 5),
	(38, '2026-11-15', 'present', NULL, '16:30:00', 'Sinkron dari mesin Mesin Absensi Simulator (UID 4). | Sinkron dari mesin Mesin Absensi Simulator', 1, 4),
	(39, '2026-11-15', 'present', NULL, '16:30:00', 'Sinkron dari mesin Mesin Absensi Simulator (UID 1). | Sinkron dari mesin Mesin Absensi Simulator', 1, 1),
	(40, '2026-11-15', 'present', NULL, '16:30:00', 'Sinkron dari mesin Mesin Absensi Simulator (UID 3). | Sinkron dari mesin Mesin Absensi Simulator', 1, 3);

-- Dumping structure for table db.produksi_auditlog
CREATE TABLE IF NOT EXISTS "produksi_auditlog" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "action" varchar(20) NOT NULL, "object_id" integer unsigned NULL CHECK ("object_id" >= 0), "object_repr" varchar(200) NOT NULL, "field_name" varchar(100) NOT NULL, "old_value" text NOT NULL, "new_value" text NOT NULL, "ip_address" char(39) NULL, "user_agent" text NOT NULL, "created_at" datetime NOT NULL, "content_type_id" integer NULL REFERENCES "django_content_type" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, "user_id" bigint NULL REFERENCES "produksi_user" ("id") DEFERRABLE INITIALLY DEFERRED);
CREATE INDEX "produksi_auditlog_content_type_id_fe97b7ef" ON "produksi_auditlog" ("content_type_id");
CREATE INDEX "produksi_auditlog_tenant_id_e4766b9e" ON "produksi_auditlog" ("tenant_id");
CREATE INDEX "produksi_auditlog_user_id_b718defb" ON "produksi_auditlog" ("user_id");
CREATE INDEX "audit_log_tenant_date_idx" ON "produksi_auditlog" ("tenant_id", "created_at");
CREATE INDEX "audit_log_tenant_action_idx" ON "produksi_auditlog" ("tenant_id", "action");
CREATE INDEX "audit_log_object_idx" ON "produksi_auditlog" ("tenant_id", "content_type_id", "object_id");

-- Dumping data for table db.produksi_auditlog: 0 rows

-- Dumping structure for table db.produksi_bagloglogging
CREATE TABLE IF NOT EXISTS "produksi_bagloglogging" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "code" varchar(30) NOT NULL, "logging_date" date NOT NULL, "qty_baglog" integer unsigned NOT NULL CHECK ("qty_baglog" >= 0), "material_qty" decimal NOT NULL, "material_unit_price" decimal NOT NULL, "material_cost" decimal NOT NULL, "base_material_cost" decimal NOT NULL, "machine_overhead" decimal NOT NULL, "total_cost" decimal NOT NULL, "unit_cost" decimal NOT NULL, "created_at" datetime NOT NULL, "material_id" bigint NULL REFERENCES "produksi_material" ("id") DEFERRABLE INITIALLY DEFERRED, "mixing_lot_id" bigint NOT NULL REFERENCES "produksi_lot" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, "plastic_preset_id" bigint NULL REFERENCES "produksi_plasticpreset" ("id") DEFERRABLE INITIALLY DEFERRED, "material_overhead" decimal NOT NULL, "mixing_total_cost" decimal NOT NULL, "qty_out" integer unsigned NOT NULL CHECK ("qty_out" >= 0), "reject" integer unsigned NOT NULL CHECK ("reject" >= 0), CONSTRAINT "baglog_logging_unique_code" UNIQUE ("tenant_id", "code"), CONSTRAINT "baglog_logging_positive_qty" CHECK ("qty_baglog" > 0), CONSTRAINT "baglog_logging_valid_quantities" CHECK (("reject" >= 0 AND "reject" < ("qty_baglog") AND "qty_out" = ("qty_baglog" - "reject"))), CONSTRAINT "baglog_logging_nonnegative_costs" CHECK (("material_qty" >= '0' AND "material_unit_price" >= '0' AND "material_cost" >= '0' AND "base_material_cost" >= '0' AND "mixing_total_cost" >= '0' AND "material_overhead" >= '0' AND "machine_overhead" >= '0' AND "total_cost" >= '0' AND "unit_cost" >= '0')));
;
CREATE INDEX "produksi_bagloglogging_material_id_c7831d7f" ON "produksi_bagloglogging" ("material_id");
CREATE INDEX "produksi_bagloglogging_mixing_lot_id_bc215dbe" ON "produksi_bagloglogging" ("mixing_lot_id");
CREATE INDEX "produksi_bagloglogging_tenant_id_33dfe940" ON "produksi_bagloglogging" ("tenant_id");
CREATE INDEX "produksi_bagloglogging_plastic_preset_id_2568aa9a" ON "produksi_bagloglogging" ("plastic_preset_id");

-- Dumping data for table db.produksi_bagloglogging: 2 rows
INSERT INTO "produksi_bagloglogging" ("id", "code", "logging_date", "qty_baglog", "material_qty", "material_unit_price", "material_cost", "base_material_cost", "machine_overhead", "total_cost", "unit_cost", "created_at", "material_id", "mixing_lot_id", "tenant_id", "plastic_preset_id", "material_overhead", "mixing_total_cost", "qty_out", "reject") VALUES
	(1, 'LOG-20261113-01', '2026-11-13', 320, 1.6, 40000, 64000, 182200, 0, 246200, 769.375, '2026-11-13 05:53:26.622504', 3, 1, 1, 1, 0, 182200, 320, 0),
	(2, 'LOG-20261116-01', '2026-11-16', 450, 2.3, 40000, 92000, 223450, 0, 315450, 701, '2026-11-16 13:39:38.520350', 3, 8, 1, 1, 0, 223450, 450, 0);

-- Dumping structure for table db.produksi_buyer
CREATE TABLE IF NOT EXISTS "produksi_buyer" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "name" varchar(120) NOT NULL, "contact" varchar(160) NOT NULL, "address" text NOT NULL, "is_active" bool NOT NULL, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "buyer_unique_name" UNIQUE ("tenant_id", "name"));
;
CREATE INDEX "produksi_buyer_tenant_id_cd62a3bc" ON "produksi_buyer" ("tenant_id");

-- Dumping data for table db.produksi_buyer: 10 rows
INSERT INTO "produksi_buyer" ("id", "name", "contact", "address", "is_active", "tenant_id") VALUES
	(1, 'Pembeli Toko', '0812345678', 'Jl. Test', 1, 9),
	(2, 'Pembeli Toko', '0812345678', 'Jl. Test', 0, 10),
	(3, 'Pembeli Toko', '0812345678', 'Jl. Test', 1, 11),
	(4, 'Pembeli Toko', '0812345678', 'Jl. Test', 1, 12),
	(5, 'Pembeli Toko', '0812345678', 'Jl. Test', 1, 13),
	(6, 'Pembeli Toko', '0812345678', 'Jl. Test', 1, 14),
	(7, 'Pembeli Toko', '0812345678', 'Jl. Test', 1, 15),
	(8, 'Pembeli Toko', '0812345678', 'Jl. Test', 1, 16),
	(9, 'Pembeli Toko', '0812345678', 'Jl. Test', 1, 17),
	(10, 'Agam', '081222545221', 'Kp. Tegalaja', 1, 1);

-- Dumping structure for table db.produksi_costadjustment
CREATE TABLE IF NOT EXISTS "produksi_costadjustment" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "amount" decimal NOT NULL, "capitalized_amount" decimal NOT NULL, "expensed_amount" decimal NOT NULL, "stock_quantity" integer unsigned NOT NULL CHECK ("stock_quantity" >= 0), "processed_quantity" integer unsigned NOT NULL CHECK ("processed_quantity" >= 0), "reason" varchar(240) NOT NULL, "occurred_on" date NOT NULL, "recognized_on" date NOT NULL, "reference" varchar(120) NOT NULL, "recorded_at" datetime NOT NULL, "baglog_logging_id" bigint NULL REFERENCES "produksi_bagloglogging" ("id") DEFERRABLE INITIALLY DEFERRED, "harvest_id" bigint NULL REFERENCES "produksi_harvest" ("id") DEFERRABLE INITIALLY DEFERRED, "lot_id" bigint NULL REFERENCES "produksi_lot" ("id") DEFERRABLE INITIALLY DEFERRED, "overhead_month_id" bigint NULL REFERENCES "produksi_generaloverheadmonth" ("id") DEFERRABLE INITIALLY DEFERRED, "recorded_by_id" bigint NULL REFERENCES "produksi_user" ("id") DEFERRABLE INITIALLY DEFERRED, "sterilization_input_id" bigint NULL REFERENCES "produksi_sterilizationinput" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "cost_adjustment_nonzero_amount" CHECK (("amount" > '0' OR "amount" < '0')), CONSTRAINT "cost_adjustment_single_target" CHECK ((("baglog_logging_id" IS NULL AND "harvest_id" IS NULL AND "lot_id" IS NOT NULL AND "overhead_month_id" IS NULL AND "sterilization_input_id" IS NULL) OR ("baglog_logging_id" IS NOT NULL AND "harvest_id" IS NULL AND "lot_id" IS NULL AND "overhead_month_id" IS NULL AND "sterilization_input_id" IS NULL) OR ("baglog_logging_id" IS NULL AND "harvest_id" IS NULL AND "lot_id" IS NULL AND "overhead_month_id" IS NULL AND "sterilization_input_id" IS NOT NULL) OR ("baglog_logging_id" IS NULL AND "harvest_id" IS NOT NULL AND "lot_id" IS NULL AND "overhead_month_id" IS NULL AND "sterilization_input_id" IS NULL) OR ("baglog_logging_id" IS NULL AND "harvest_id" IS NULL AND "lot_id" IS NULL AND "overhead_month_id" IS NOT NULL AND "sterilization_input_id" IS NULL))));
CREATE INDEX "produksi_costadjustment_baglog_logging_id_33712874" ON "produksi_costadjustment" ("baglog_logging_id");
CREATE INDEX "produksi_costadjustment_harvest_id_e5a29aaf" ON "produksi_costadjustment" ("harvest_id");
CREATE INDEX "produksi_costadjustment_lot_id_7ef95970" ON "produksi_costadjustment" ("lot_id");
CREATE INDEX "produksi_costadjustment_overhead_month_id_af423da7" ON "produksi_costadjustment" ("overhead_month_id");
CREATE INDEX "produksi_costadjustment_recorded_by_id_1c7927e9" ON "produksi_costadjustment" ("recorded_by_id");
CREATE INDEX "produksi_costadjustment_sterilization_input_id_a5095aac" ON "produksi_costadjustment" ("sterilization_input_id");
CREATE INDEX "produksi_costadjustment_tenant_id_f758b7bc" ON "produksi_costadjustment" ("tenant_id");
CREATE INDEX "cost_adj_tenant_date_idx" ON "produksi_costadjustment" ("tenant_id", "recognized_on");
CREATE INDEX "cost_adj_tenant_lot_idx" ON "produksi_costadjustment" ("tenant_id", "lot_id");

-- Dumping data for table db.produksi_costadjustment: 0 rows

-- Dumping structure for table db.produksi_customeraccess
CREATE TABLE IF NOT EXISTS "produksi_customeraccess" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "status" varchar(12) NOT NULL, "invitation_token" varchar(64) NOT NULL, "invitation_expires_at" datetime NULL, "granted_at" datetime NOT NULL, "buyer_id" bigint NOT NULL REFERENCES "produksi_buyer" ("id") DEFERRABLE INITIALLY DEFERRED, "granted_by_id" bigint NULL REFERENCES "produksi_user" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, "user_id" bigint NULL REFERENCES "produksi_user" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "customer_access_unique_buyer" UNIQUE ("tenant_id", "buyer_id"));
;
CREATE INDEX "produksi_customeraccess_buyer_id_5e2a5bf3" ON "produksi_customeraccess" ("buyer_id");
CREATE INDEX "produksi_customeraccess_granted_by_id_82b44316" ON "produksi_customeraccess" ("granted_by_id");
CREATE INDEX "produksi_customeraccess_tenant_id_e8585712" ON "produksi_customeraccess" ("tenant_id");
CREATE INDEX "produksi_customeraccess_user_id_025faced" ON "produksi_customeraccess" ("user_id");

-- Dumping data for table db.produksi_customeraccess: 1 rows
INSERT INTO "produksi_customeraccess" ("id", "status", "invitation_token", "invitation_expires_at", "granted_at", "buyer_id", "granted_by_id", "tenant_id", "user_id") VALUES
	(1, 'active', '', NULL, '2026-11-12 06:42:21.659000', 10, 2, 1, NULL);

-- Dumping structure for table db.produksi_customerprice
CREATE TABLE IF NOT EXISTS "produksi_customerprice" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "price_per_kg" decimal NOT NULL, "effective_from" date NOT NULL, "buyer_id" bigint NOT NULL REFERENCES "produksi_buyer" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, "variety_id" bigint NOT NULL REFERENCES "produksi_variety" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "customer_price_unique" UNIQUE ("tenant_id", "buyer_id", "variety_id", "effective_from"), CONSTRAINT "customer_price_nonnegative" CHECK ("price_per_kg" >= '0'));
;
CREATE INDEX "produksi_customerprice_buyer_id_220b21c4" ON "produksi_customerprice" ("buyer_id");
CREATE INDEX "produksi_customerprice_tenant_id_b5755f90" ON "produksi_customerprice" ("tenant_id");
CREATE INDEX "produksi_customerprice_variety_id_018c2255" ON "produksi_customerprice" ("variety_id");

-- Dumping data for table db.produksi_customerprice: 0 rows

-- Dumping structure for table db.produksi_device
CREATE TABLE IF NOT EXISTS "produksi_device" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "name" varchar(100) NOT NULL, "device_type" varchar(20) NOT NULL, "serial_number" varchar(50) NOT NULL, "ip_address" char(39) NULL, "location" varchar(100) NOT NULL, "status" varchar(15) NOT NULL, "last_seen" datetime NULL, "notes" text NOT NULL, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "device_unique_name_per_tenant" UNIQUE ("tenant_id", "name"));
;
CREATE INDEX "produksi_device_tenant_id_27f57d70" ON "produksi_device" ("tenant_id");

-- Dumping data for table db.produksi_device: 1 rows
INSERT INTO "produksi_device" ("id", "name", "device_type", "serial_number", "ip_address", "location", "status", "last_seen", "notes", "tenant_id") VALUES
	(1, 'Sensor-Hub-Gudang-1', 'sensor_hub', 'SIM-SENSOR-HUB-GUDANG-1', '127.0.0.1', 'Kumbung A (Simulator)', 'online', NULL, 'Didaftarkan oleh seed_simulator_devices. Bacaaan dihasilkan oleh simulator IoT (MQTT / file fallback).', 1);

-- Dumping structure for table db.produksi_employee
CREATE TABLE IF NOT EXISTS "produksi_employee" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "nik" varchar(20) NOT NULL UNIQUE, "name" varchar(100) NOT NULL, "gender" varchar(10) NOT NULL, "birth_date" date NULL, "join_date" date NOT NULL, "phone" varchar(20) NOT NULL, "email" varchar(254) NOT NULL, "address" text NOT NULL, "department" varchar(50) NOT NULL, "position" varchar(50) NOT NULL, "base_salary" decimal NOT NULL, "status" varchar(12) NOT NULL, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, "device_uid" varchar(20) NOT NULL, CONSTRAINT "employee_unique_nik_per_tenant" UNIQUE ("tenant_id", "nik"));
;
;
CREATE INDEX "produksi_employee_tenant_id_89fd1f2e" ON "produksi_employee" ("tenant_id");

-- Dumping data for table db.produksi_employee: 5 rows
INSERT INTO "produksi_employee" ("id", "nik", "name", "gender", "birth_date", "join_date", "phone", "email", "address", "department", "position", "base_salary", "status", "tenant_id", "device_uid") VALUES
	(1, 'SIM-001', 'Budi Santoso', 'male', NULL, '2026-11-16', '', '', '', 'Produksi', 'Operator', 3500000, 'active', 1, '1'),
	(2, 'SIM-002', 'Siti Rahayu', 'female', NULL, '2026-11-16', '', '', '', 'Produksi', 'Operator', 3500000, 'active', 1, '2'),
	(3, 'SIM-003', 'Agus Setiawan', 'male', NULL, '2026-11-16', '', '', '', 'Produksi', 'Operator', 3500000, 'active', 1, '3'),
	(4, 'SIM-004', 'Dewi Lestari', 'female', NULL, '2026-11-16', '', '', '', 'Produksi', 'Operator', 3500000, 'active', 1, '4'),
	(5, 'SIM-005', 'Joko Prakoso', 'male', NULL, '2026-11-16', '', '', '', 'Produksi', 'Administrator', 3500000, 'active', 1, '5');

-- Dumping structure for table db.produksi_fingerprintdevice
CREATE TABLE IF NOT EXISTS "produksi_fingerprintdevice" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "name" varchar(100) NOT NULL, "ip_address" char(39) NOT NULL, "port" integer unsigned NOT NULL CHECK ("port" >= 0), "serial_number" varchar(50) NOT NULL, "location" varchar(100) NOT NULL, "status" varchar(15) NOT NULL, "last_sync" datetime NULL, "notes" text NOT NULL, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "fingerprintdevice_unique_name_per_tenant" UNIQUE ("tenant_id", "name"), CONSTRAINT "fingerprintdevice_unique_ip_port_per_tenant" UNIQUE ("tenant_id", "ip_address", "port"));
;
;
CREATE INDEX "produksi_fingerprintdevice_tenant_id_e78bd64e" ON "produksi_fingerprintdevice" ("tenant_id");

-- Dumping data for table db.produksi_fingerprintdevice: 1 rows
INSERT INTO "produksi_fingerprintdevice" ("id", "name", "ip_address", "port", "serial_number", "location", "status", "last_sync", "notes", "tenant_id") VALUES
	(1, 'Mesin Absensi Simulator', '127.0.0.1', 4370, 'SIMULATORFP001', 'Gudang Utama (Simulator)', 'online', '2026-11-16 06:55:46.360474', 'Didaftarkan oleh seed_simulator_devices. Jalankan simulator di port yang sama untuk tes sinkronisasi.', 1);

-- Dumping structure for table db.produksi_fingerprintlog
CREATE TABLE IF NOT EXISTS "produksi_fingerprintlog" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "uid" varchar(20) NOT NULL, "timestamp" datetime NOT NULL, "verify_type" varchar(10) NOT NULL, "status" varchar(10) NOT NULL, "processed" bool NOT NULL, "notes" varchar(200) NOT NULL, "device_id" bigint NOT NULL REFERENCES "produksi_fingerprintdevice" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "fingerprintlog_unique_device_uid_timestamp_per_tenant" UNIQUE ("tenant_id", "device_id", "uid", "timestamp"));
;
CREATE INDEX "produksi_fingerprintlog_device_id_ce23bc20" ON "produksi_fingerprintlog" ("device_id");
CREATE INDEX "produksi_fingerprintlog_tenant_id_b23d23f2" ON "produksi_fingerprintlog" ("tenant_id");
CREATE INDEX "produksi_fi_tenant__0bbdbd_idx" ON "produksi_fingerprintlog" ("tenant_id", "device_id", "timestamp" DESC);
CREATE INDEX "produksi_fi_tenant__04a948_idx" ON "produksi_fingerprintlog" ("tenant_id", "processed");

-- Dumping data for table db.produksi_fingerprintlog: 102 rows
INSERT INTO "produksi_fingerprintlog" ("id", "uid", "timestamp", "verify_type", "status", "processed", "notes", "device_id", "tenant_id") VALUES
	(1, '3', '2026-11-15 07:30:00', 'fp', 'check_in', 1, 'Seed data simulator.', 1, 1),
	(2, '3', '2026-11-15 16:30:00', 'fp', 'check_out', 1, 'Seed data simulator.', 1, 1),
	(3, '1', '2026-11-15 07:30:00', 'fp', 'check_in', 1, 'Seed data simulator.', 1, 1),
	(4, '1', '2026-11-15 16:30:00', 'fp', 'check_out', 1, 'Seed data simulator.', 1, 1),
	(5, '4', '2026-11-15 07:30:00', 'fp', 'check_in', 1, 'Seed data simulator.', 1, 1),
	(6, '4', '2026-11-15 16:30:00', 'fp', 'check_out', 1, 'Seed data simulator.', 1, 1),
	(7, '5', '2026-11-15 07:30:00', 'fp', 'check_in', 1, 'Seed data simulator.', 1, 1),
	(8, '5', '2026-11-15 16:30:00', 'fp', 'check_out', 1, 'Seed data simulator.', 1, 1),
	(9, '2', '2026-11-15 07:30:00', 'fp', 'check_in', 1, 'Seed data simulator.', 1, 1),
	(10, '2', '2026-11-15 16:30:00', 'fp', 'check_out', 1, 'Seed data simulator.', 1, 1),
	(11, '3', '2026-11-14 07:30:00', 'fp', 'check_in', 1, 'Seed data simulator.', 1, 1),
	(12, '3', '2026-11-14 16:30:00', 'fp', 'check_out', 1, 'Seed data simulator.', 1, 1),
	(13, '1', '2026-11-14 07:30:00', 'fp', 'check_in', 1, 'Seed data simulator.', 1, 1),
	(14, '1', '2026-11-14 16:30:00', 'fp', 'check_out', 1, 'Seed data simulator.', 1, 1),
	(15, '4', '2026-11-14 07:30:00', 'fp', 'check_in', 1, 'Seed data simulator.', 1, 1),
	(16, '4', '2026-11-14 16:30:00', 'fp', 'check_out', 1, 'Seed data simulator.', 1, 1),
	(17, '5', '2026-11-14 07:30:00', 'fp', 'check_in', 1, 'Seed data simulator.', 1, 1),
	(18, '5', '2026-11-14 16:30:00', 'fp', 'check_out', 1, 'Seed data simulator.', 1, 1),
	(19, '2', '2026-11-14 07:30:00', 'fp', 'check_in', 1, 'Seed data simulator.', 1, 1),
	(20, '2', '2026-11-14 16:30:00', 'fp', 'check_out', 1, 'Seed data simulator.', 1, 1),
	(21, '3', '2026-11-13 07:30:00', 'fp', 'check_in', 1, 'Seed data simulator.', 1, 1),
	(22, '3', '2026-11-13 16:30:00', 'fp', 'check_out', 1, 'Seed data simulator.', 1, 1),
	(23, '1', '2026-11-13 07:30:00', 'fp', 'check_in', 1, 'Seed data simulator.', 1, 1),
	(24, '1', '2026-11-13 16:30:00', 'fp', 'check_out', 1, 'Seed data simulator.', 1, 1),
	(25, '4', '2026-11-13 07:30:00', 'fp', 'check_in', 1, 'Seed data simulator.', 1, 1),
	(26, '4', '2026-11-13 16:30:00', 'fp', 'check_out', 1, 'Seed data simulator.', 1, 1),
	(27, '5', '2026-11-13 07:30:00', 'fp', 'check_in', 1, 'Seed data simulator.', 1, 1),
	(28, '5', '2026-11-13 16:30:00', 'fp', 'check_out', 1, 'Seed data simulator.', 1, 1),
	(29, '2', '2026-11-13 07:30:00', 'fp', 'check_in', 1, 'Seed data simulator.', 1, 1),
	(30, '2', '2026-11-13 16:30:00', 'fp', 'check_out', 1, 'Seed data simulator.', 1, 1),
	(31, '3', '2026-11-12 07:30:00', 'fp', 'check_in', 1, 'Seed data simulator.', 1, 1),
	(32, '3', '2026-11-12 16:30:00', 'fp', 'check_out', 1, 'Seed data simulator.', 1, 1),
	(33, '1', '2026-11-12 07:30:00', 'fp', 'check_in', 1, 'Seed data simulator.', 1, 1),
	(34, '1', '2026-11-12 16:30:00', 'fp', 'check_out', 1, 'Seed data simulator.', 1, 1),
	(35, '4', '2026-11-12 07:30:00', 'fp', 'check_in', 1, 'Seed data simulator.', 1, 1),
	(36, '4', '2026-11-12 16:30:00', 'fp', 'check_out', 1, 'Seed data simulator.', 1, 1),
	(37, '5', '2026-11-12 07:30:00', 'fp', 'check_in', 1, 'Seed data simulator.', 1, 1),
	(38, '5', '2026-11-12 16:30:00', 'fp', 'check_out', 1, 'Seed data simulator.', 1, 1),
	(39, '2', '2026-11-12 07:30:00', 'fp', 'check_in', 1, 'Seed data simulator.', 1, 1),
	(40, '2', '2026-11-12 16:30:00', 'fp', 'check_out', 1, 'Seed data simulator.', 1, 1),
	(41, '3', '2026-11-11 07:30:00', 'fp', 'check_in', 1, 'Seed data simulator.', 1, 1),
	(42, '3', '2026-11-11 16:30:00', 'fp', 'check_out', 1, 'Seed data simulator.', 1, 1),
	(43, '1', '2026-11-11 07:30:00', 'fp', 'check_in', 1, 'Seed data simulator.', 1, 1),
	(44, '1', '2026-11-11 16:30:00', 'fp', 'check_out', 1, 'Seed data simulator.', 1, 1),
	(45, '4', '2026-11-11 07:30:00', 'fp', 'check_in', 1, 'Seed data simulator.', 1, 1),
	(46, '4', '2026-11-11 16:30:00', 'fp', 'check_out', 1, 'Seed data simulator.', 1, 1),
	(47, '5', '2026-11-11 07:30:00', 'fp', 'check_in', 1, 'Seed data simulator.', 1, 1),
	(48, '5', '2026-11-11 16:30:00', 'fp', 'check_out', 1, 'Seed data simulator.', 1, 1),
	(49, '2', '2026-11-11 07:30:00', 'fp', 'check_in', 1, 'Seed data simulator.', 1, 1),
	(50, '2', '2026-11-11 16:30:00', 'fp', 'check_out', 1, 'Seed data simulator.', 1, 1),
	(51, '1', '2026-05-18 01:38:56', '0', 'check_in', 1, '', 1, 1),
	(52, '1', '2026-05-18 10:41:20', '0', 'check_out', 1, '', 1, 1),
	(53, '1', '2026-05-18 01:45:17', '0', 'check_in', 1, '', 1, 1),
	(54, '2', '2026-05-18 00:40:54', '0', 'check_in', 1, '', 1, 1),
	(55, '2', '2026-05-18 01:11:37', '0', 'check_in', 1, '', 1, 1),
	(56, '2', '2026-05-18 09:12:27', '0', 'check_out', 1, '', 1, 1),
	(57, '3', '2026-05-18 00:41:50', '0', 'check_in', 1, '', 1, 1),
	(58, '3', '2026-05-18 10:02:56', '0', 'check_out', 1, '', 1, 1),
	(59, '3', '2026-05-18 00:48:40', '0', 'check_in', 1, '', 1, 1),
	(60, '3', '2026-05-18 10:03:54', '0', 'check_out', 1, '', 1, 1),
	(61, '4', '2026-05-18 00:05:47', '0', 'check_in', 1, '', 1, 1),
	(62, '4', '2026-05-18 09:38:55', '0', 'check_out', 1, '', 1, 1),
	(63, '4', '2026-05-18 00:34:15', '0', 'check_in', 1, '', 1, 1),
	(64, '4', '2026-05-18 09:44:08', '0', 'check_out', 1, '', 1, 1),
	(65, '5', '2026-05-18 01:16:09', '0', 'check_in', 1, '', 1, 1),
	(66, '5', '2026-05-18 10:02:47', '0', 'check_out', 1, '', 1, 1),
	(67, '5', '2026-05-18 00:46:09', '0', 'check_in', 1, '', 1, 1),
	(68, '1', '2026-05-19 00:38:24', '0', 'check_in', 1, '', 1, 1),
	(69, '1', '2026-05-19 09:42:35', '0', 'check_out', 1, '', 1, 1),
	(70, '1', '2026-05-19 01:45:37', '0', 'check_in', 1, '', 1, 1),
	(71, '1', '2026-05-19 10:19:42', '0', 'check_out', 1, '', 1, 1),
	(72, '2', '2026-05-19 01:22:08', '0', 'check_in', 1, '', 1, 1),
	(73, '2', '2026-05-19 09:59:13', '0', 'check_out', 1, '', 1, 1),
	(74, '2', '2026-05-19 01:12:46', '0', 'check_in', 1, '', 1, 1),
	(75, '2', '2026-05-19 10:01:46', '0', 'check_out', 1, '', 1, 1),
	(76, '3', '2026-05-19 01:46:59', '0', 'check_in', 1, '', 1, 1),
	(77, '3', '2026-05-19 09:04:45', '0', 'check_out', 1, '', 1, 1),
	(78, '3', '2026-05-19 00:47:09', '0', 'check_in', 1, '', 1, 1),
	(79, '4', '2026-05-19 00:36:04', '0', 'check_in', 1, '', 1, 1),
	(80, '4', '2026-05-19 09:36:52', '0', 'check_out', 1, '', 1, 1),
	(81, '4', '2026-05-19 01:10:19', '0', 'check_in', 1, '', 1, 1),
	(82, '4', '2026-05-19 09:03:42', '0', 'check_out', 1, '', 1, 1),
	(83, '5', '2026-05-19 00:15:43', '0', 'check_in', 1, '', 1, 1),
	(84, '5', '2026-05-19 00:18:11', '0', 'check_in', 1, '', 1, 1),
	(85, '5', '2026-05-19 09:43:31', '0', 'check_out', 1, '', 1, 1),
	(86, '1', '2026-05-20 01:55:25', '0', 'check_in', 1, '', 1, 1),
	(87, '1', '2026-05-20 10:49:40', '0', 'check_out', 1, '', 1, 1),
	(88, '1', '2026-05-20 01:17:34', '0', 'check_in', 1, '', 1, 1),
	(89, '1', '2026-05-20 10:46:44', '0', 'check_out', 1, '', 1, 1),
	(90, '2', '2026-05-20 00:29:00', '0', 'check_in', 1, '', 1, 1),
	(91, '2', '2026-05-20 10:47:30', '0', 'check_out', 1, '', 1, 1),
	(92, '2', '2026-05-20 01:59:15', '0', 'check_in', 1, '', 1, 1),
	(93, '3', '2026-05-20 01:39:28', '0', 'check_in', 1, '', 1, 1),
	(94, '3', '2026-05-20 10:01:52', '0', 'check_out', 1, '', 1, 1),
	(95, '3', '2026-05-20 00:25:21', '0', 'check_in', 1, '', 1, 1),
	(96, '4', '2026-05-20 01:18:42', '0', 'check_in', 1, '', 1, 1),
	(97, '4', '2026-05-20 10:29:43', '0', 'check_out', 1, '', 1, 1),
	(98, '4', '2026-05-20 01:07:17', '0', 'check_in', 1, '', 1, 1),
	(99, '4', '2026-05-20 09:58:53', '0', 'check_out', 1, '', 1, 1),
	(100, '5', '2026-05-20 01:35:54', '0', 'check_in', 1, '', 1, 1),
	(101, '5', '2026-05-20 10:52:15', '0', 'check_out', 1, '', 1, 1),
	(102, '5', '2026-05-20 01:37:16', '0', 'check_in', 1, '', 1, 1);

-- Dumping structure for table db.produksi_generaloverheadline
CREATE TABLE IF NOT EXISTS "produksi_generaloverheadline" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "category" varchar(60) NOT NULL, "description" varchar(160) NOT NULL, "amount" decimal NOT NULL, "month_id" bigint NOT NULL REFERENCES "produksi_generaloverheadmonth" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "overhead_line_nonnegative" CHECK ("amount" >= '0'), CONSTRAINT "overhead_line_unique_item" UNIQUE ("month_id", "category", "description"));
;
CREATE INDEX "produksi_generaloverheadline_month_id_89a36779" ON "produksi_generaloverheadline" ("month_id");
CREATE INDEX "produksi_generaloverheadline_tenant_id_0bb86ce8" ON "produksi_generaloverheadline" ("tenant_id");

-- Dumping data for table db.produksi_generaloverheadline: 0 rows

-- Dumping structure for table db.produksi_generaloverheadmonth
CREATE TABLE IF NOT EXISTS "produksi_generaloverheadmonth" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "year" smallint unsigned NOT NULL CHECK ("year" >= 0), "month" smallint unsigned NOT NULL CHECK ("month" >= 0), "status" varchar(12) NOT NULL, "total_cost" decimal NOT NULL, "baglogs_produced" integer unsigned NOT NULL CHECK ("baglogs_produced" >= 0), "rate_per_baglog" decimal NULL, "rate_source" varchar(12) NOT NULL, "closed_at" datetime NULL, "created_at" datetime NOT NULL, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, "harvest_kg" decimal NOT NULL, "rate_per_kg" decimal NULL, "scope" varchar(12) NOT NULL, CONSTRAINT "overhead_month_valid_month" CHECK (("month" >= 1 AND "month" <= 12)), CONSTRAINT "overhead_month_nonnegative_total" CHECK ("total_cost" >= '0'), CONSTRAINT "overhead_month_unique_period" UNIQUE ("tenant_id", "scope", "year", "month"), CONSTRAINT "overhead_month_nonnegative_harvest" CHECK ("harvest_kg" >= '0'));
;
CREATE INDEX "produksi_generaloverheadmonth_tenant_id_34d18909" ON "produksi_generaloverheadmonth" ("tenant_id");

-- Dumping data for table db.produksi_generaloverheadmonth: 1 rows
INSERT INTO "produksi_generaloverheadmonth" ("id", "year", "month", "status", "total_cost", "baglogs_produced", "rate_per_baglog", "rate_source", "closed_at", "created_at", "tenant_id", "harvest_kg", "rate_per_kg", "scope") VALUES
	(1, '2026', '11', 'provisional', 0, 0, NULL, '', NULL, '2026-11-08 00:59:57.897139', 1, 0, NULL, 'production');

-- Dumping structure for table db.produksi_harvest
CREATE TABLE IF NOT EXISTS "produksi_harvest" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "harvest_date" date NOT NULL, "quantity_kg" decimal NOT NULL, "baglogs_harvested" integer unsigned NOT NULL CHECK ("baglogs_harvested" >= 0), "grade" varchar(40) NOT NULL, "note" varchar(240) NOT NULL, "created_at" datetime NOT NULL, "location_id" bigint NOT NULL REFERENCES "produksi_location" ("id") DEFERRABLE INITIALLY DEFERRED, "lot_id" bigint NOT NULL REFERENCES "produksi_lot" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, "selling_price_per_kg" decimal NOT NULL, "overhead_fruiting_per_kg" decimal NOT NULL, "cost_per_baglog" decimal NULL, CONSTRAINT "harvest_positive_kg_and_baglogs" CHECK (("quantity_kg" > '0' AND "baglogs_harvested" > 0)), CONSTRAINT "harvest_nonnegative_prices" CHECK (("selling_price_per_kg" >= '0' AND "overhead_fruiting_per_kg" >= '0' AND ("cost_per_baglog" IS NULL OR "cost_per_baglog" >= '0'))));
CREATE INDEX "produksi_harvest_location_id_ae7595eb" ON "produksi_harvest" ("location_id");
CREATE INDEX "produksi_harvest_lot_id_e9e4753b" ON "produksi_harvest" ("lot_id");
CREATE INDEX "produksi_harvest_tenant_id_23a5e9fb" ON "produksi_harvest" ("tenant_id");
CREATE INDEX "harvest_lot_date_idx" ON "produksi_harvest" ("tenant_id", "lot_id", "harvest_date");

-- Dumping data for table db.produksi_harvest: 5 rows
INSERT INTO "produksi_harvest" ("id", "harvest_date", "quantity_kg", "baglogs_harvested", "grade", "note", "created_at", "location_id", "lot_id", "tenant_id", "selling_price_per_kg", "overhead_fruiting_per_kg", "cost_per_baglog") VALUES
	(1, '2026-11-10', 10, 50, 'A', 'Test', '2026-11-11 05:22:56.798698', 2, 2, 13, 0, 0, 5000),
	(2, '2026-11-10', 10000, 50, 'A', 'Test', '2026-11-11 05:23:33.186224', 3, 3, 14, 0, 0, 5000),
	(3, '2026-11-10', 10000, 50, 'A', 'Test', '2026-11-11 05:23:48.091902', 4, 4, 15, 0, 0, 5000),
	(4, '2026-11-10', 10000, 50, 'A', 'Test', '2026-11-11 05:24:00.633083', 5, 5, 16, 0, 0, 5000),
	(5, '2026-11-10', 10000, 50, 'A', 'Test', '2026-11-11 05:55:22.317627', 6, 6, 17, 0, 0, 5000);

-- Dumping structure for table db.produksi_harvestoverheadallocation
CREATE TABLE IF NOT EXISTS "produksi_harvestoverheadallocation" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "rate_per_kg" decimal NOT NULL, "quantity_kg" decimal NOT NULL, "amount" decimal NOT NULL, "is_final" bool NOT NULL, "updated_at" datetime NOT NULL, "harvest_id" bigint NOT NULL REFERENCES "produksi_harvest" ("id") DEFERRABLE INITIALLY DEFERRED, "month_id" bigint NOT NULL REFERENCES "produksi_generaloverheadmonth" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "harvest_overhead_allocation_unique" UNIQUE ("month_id", "harvest_id"), CONSTRAINT "harvest_overhead_allocation_valid" CHECK (("rate_per_kg" >= '0' AND "quantity_kg" > '0' AND "amount" >= '0')));
;
CREATE INDEX "produksi_harvestoverheadallocation_harvest_id_56058b15" ON "produksi_harvestoverheadallocation" ("harvest_id");
CREATE INDEX "produksi_harvestoverheadallocation_month_id_d683767f" ON "produksi_harvestoverheadallocation" ("month_id");
CREATE INDEX "produksi_harvestoverheadallocation_tenant_id_498acca4" ON "produksi_harvestoverheadallocation" ("tenant_id");

-- Dumping data for table db.produksi_harvestoverheadallocation: 0 rows

-- Dumping structure for table db.produksi_incubationrecord
CREATE TABLE IF NOT EXISTS "produksi_incubationrecord" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "started_on" date NOT NULL, "planned_days" integer unsigned NOT NULL CHECK ("planned_days" >= 0), "completed_on" date NULL, "lot_id" bigint NOT NULL UNIQUE REFERENCES "produksi_lot" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "incubation_positive_duration" CHECK ("planned_days" > 0));
;
CREATE INDEX "produksi_incubationrecord_tenant_id_ed806138" ON "produksi_incubationrecord" ("tenant_id");

-- Dumping data for table db.produksi_incubationrecord: 0 rows

-- Dumping structure for table db.produksi_inoculationbatch
CREATE TABLE IF NOT EXISTS "produksi_inoculationbatch" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "variety" varchar(80) NOT NULL, "qty_in" integer unsigned NOT NULL CHECK ("qty_in" >= 0), "reject" integer unsigned NOT NULL CHECK ("reject" >= 0), "qty_out" integer unsigned NOT NULL CHECK ("qty_out" >= 0), "seed_lot_code" varchar(80) NOT NULL, "seed_bottles" decimal NOT NULL, "seed_unit_cost" decimal NOT NULL, "support_materials_total" decimal NOT NULL, "total_cost" decimal NOT NULL, "unit_cost" decimal NOT NULL, "loss_memo" decimal NOT NULL, "output_lot_id" bigint NOT NULL UNIQUE REFERENCES "produksi_lot" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, "run_id" bigint NOT NULL REFERENCES "produksi_inoculationrun" ("id") DEFERRABLE INITIALLY DEFERRED, "seed_lot_id" bigint NULL REFERENCES "produksi_seedlot" ("id") DEFERRABLE INITIALLY DEFERRED, "machine_overhead" decimal NOT NULL, CONSTRAINT "inoculation_unique_variety" UNIQUE ("run_id", "variety"), CONSTRAINT "inoculation_valid_batch_totals" CHECK (("qty_in" > 0 AND "qty_out" > 0 AND "qty_out" = ("qty_in" - "reject") AND "seed_bottles" >= '0' AND "seed_unit_cost" >= '0' AND "support_materials_total" >= '0' AND "machine_overhead" >= '0' AND "total_cost" >= '0' AND "unit_cost" >= '0' AND "loss_memo" >= '0')));
;
;
CREATE INDEX "produksi_inoculationbatch_tenant_id_ed03dac7" ON "produksi_inoculationbatch" ("tenant_id");
CREATE INDEX "produksi_inoculationbatch_run_id_06de3ce5" ON "produksi_inoculationbatch" ("run_id");
CREATE INDEX "produksi_inoculationbatch_seed_lot_id_b330c5dd" ON "produksi_inoculationbatch" ("seed_lot_id");

-- Dumping data for table db.produksi_inoculationbatch: 0 rows

-- Dumping structure for table db.produksi_inoculationrun
CREATE TABLE IF NOT EXISTS "produksi_inoculationrun" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "code" varchar(30) NOT NULL, "run_date" date NOT NULL, "support_materials_total" decimal NOT NULL, "source_lot_id" bigint NOT NULL REFERENCES "produksi_lot" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "inoculation_unique_code" UNIQUE ("tenant_id", "code"), CONSTRAINT "inoculation_nonnegative_support_cost" CHECK ("support_materials_total" >= '0'));
;
CREATE INDEX "produksi_inoculationrun_source_lot_id_74a19e7e" ON "produksi_inoculationrun" ("source_lot_id");
CREATE INDEX "produksi_inoculationrun_tenant_id_5ae6822d" ON "produksi_inoculationrun" ("tenant_id");

-- Dumping data for table db.produksi_inoculationrun: 0 rows

-- Dumping structure for table db.produksi_invoice
CREATE TABLE IF NOT EXISTS "produksi_invoice" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "invoice_date" date NOT NULL, "due_date" date NOT NULL, "reference" varchar(80) NOT NULL, "status" varchar(12) NOT NULL, "notes" varchar(240) NOT NULL, "created_at" datetime NOT NULL, "buyer_id" bigint NOT NULL REFERENCES "produksi_buyer" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, "order_id" bigint NOT NULL REFERENCES "produksi_order" ("id") DEFERRABLE INITIALLY DEFERRED);
CREATE INDEX "invoice_due_date_idx" ON "produksi_invoice" ("tenant_id", "due_date");
CREATE INDEX "produksi_invoice_buyer_id_77f5a968" ON "produksi_invoice" ("buyer_id");
CREATE INDEX "produksi_invoice_tenant_id_af2ef1f9" ON "produksi_invoice" ("tenant_id");
CREATE INDEX "produksi_invoice_order_id_f5c126da" ON "produksi_invoice" ("order_id");

-- Dumping data for table db.produksi_invoice: 0 rows

-- Dumping structure for table db.produksi_invoiceline
CREATE TABLE IF NOT EXISTS "produksi_invoiceline" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "quantity_kg" decimal NOT NULL, "price_per_kg" decimal NOT NULL, "line_total" decimal NOT NULL, "invoice_id" bigint NOT NULL REFERENCES "produksi_invoice" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, "order_line_id" bigint NOT NULL REFERENCES "produksi_orderline" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "invoice_line_valid" CHECK (("quantity_kg" > '0' AND "price_per_kg" >= '0' AND "line_total" >= '0')));
CREATE INDEX "produksi_invoiceline_invoice_id_2e4e29de" ON "produksi_invoiceline" ("invoice_id");
CREATE INDEX "produksi_invoiceline_tenant_id_fb653301" ON "produksi_invoiceline" ("tenant_id");
CREATE INDEX "produksi_invoiceline_order_line_id_067126aa" ON "produksi_invoiceline" ("order_line_id");

-- Dumping data for table db.produksi_invoiceline: 0 rows

-- Dumping structure for table db.produksi_leave
CREATE TABLE IF NOT EXISTS "produksi_leave" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "leave_type" varchar(30) NOT NULL, "start_date" date NOT NULL, "end_date" date NOT NULL, "days" integer NOT NULL, "reason" text NOT NULL, "status" varchar(10) NOT NULL, "approved_at" datetime NULL, "approved_by_id" bigint NULL REFERENCES "produksi_user" ("id") DEFERRABLE INITIALLY DEFERRED, "employee_id" bigint NOT NULL REFERENCES "produksi_employee" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED);
CREATE INDEX "produksi_leave_approved_by_id_03cb3610" ON "produksi_leave" ("approved_by_id");
CREATE INDEX "produksi_leave_employee_id_4130027c" ON "produksi_leave" ("employee_id");
CREATE INDEX "produksi_leave_tenant_id_01309ae2" ON "produksi_leave" ("tenant_id");

-- Dumping data for table db.produksi_leave: 0 rows

-- Dumping structure for table db.produksi_location
CREATE TABLE IF NOT EXISTS "produksi_location" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "name" varchar(100) NOT NULL, "kind" varchar(12) NOT NULL, "is_active" bool NOT NULL, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "location_unique_name" UNIQUE ("tenant_id", "name"));
;
CREATE INDEX "produksi_location_tenant_id_82b1bd21" ON "produksi_location" ("tenant_id");

-- Dumping data for table db.produksi_location: 12 rows
INSERT INTO "produksi_location" ("id", "name", "kind", "is_active", "tenant_id") VALUES
	(1, 'Wawan', 'fruiting', 1, 1),
	(2, 'Kumbung A', 'fruiting', 1, 13),
	(3, 'Kumbung A', 'fruiting', 1, 14),
	(4, 'Kumbung A', 'fruiting', 1, 15),
	(5, 'Kumbung A', 'fruiting', 1, 16),
	(6, 'Kumbung A', 'fruiting', 1, 17),
	(7, 'Lokasi 1', 'storage', 1, 33),
	(8, 'Lokasi 2', 'storage', 1, 33),
	(9, 'Lokasi 1', 'storage', 1, 35),
	(10, 'Lokasi 2', 'storage', 1, 35),
	(11, 'Lokasi 1', 'storage', 1, 36),
	(12, 'Lokasi 2', 'storage', 1, 36);

-- Dumping structure for table db.produksi_lot
CREATE TABLE IF NOT EXISTS "produksi_lot" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "code" varchar(30) NOT NULL, "mixed_date" date NOT NULL, "qty_in" integer unsigned NOT NULL CHECK ("qty_in" >= 0), "reject" integer unsigned NOT NULL CHECK ("reject" >= 0), "qty_out" integer unsigned NOT NULL CHECK ("qty_out" >= 0), "machine_overhead" decimal NOT NULL, "total_cost" decimal NOT NULL, "unit_cost" decimal NOT NULL, "loss_memo" decimal NOT NULL, "cost_status" varchar(12) NOT NULL, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, "phase" varchar(12) NOT NULL, "recipe_version_id" bigint NULL REFERENCES "produksi_recipeversion" ("id") DEFERRABLE INITIALLY DEFERRED, "variety_id" bigint NULL REFERENCES "produksi_variety" ("id") DEFERRABLE INITIALLY DEFERRED, "material_overhead" decimal NOT NULL, "estimated_baglog_qty" integer unsigned NULL CHECK ("estimated_baglog_qty" >= 0), CONSTRAINT "lot_unique_code" UNIQUE ("tenant_id", "code"), CONSTRAINT "lot_valid_quantities" CHECK (("qty_in" > 0 AND "reject" < ("qty_in") AND "qty_out" = ("qty_in" - "reject"))));
;
CREATE INDEX "produksi_lot_tenant_id_4b678c5b" ON "produksi_lot" ("tenant_id");
CREATE INDEX "produksi_lot_recipe_version_id_2a61193f" ON "produksi_lot" ("recipe_version_id");
CREATE INDEX "produksi_lot_variety_id_a38aa70f" ON "produksi_lot" ("variety_id");

-- Dumping data for table db.produksi_lot: 9 rows
INSERT INTO "produksi_lot" ("id", "code", "mixed_date", "qty_in", "reject", "qty_out", "machine_overhead", "total_cost", "unit_cost", "loss_memo", "cost_status", "tenant_id", "phase", "recipe_version_id", "variety_id", "material_overhead", "estimated_baglog_qty") VALUES
	(1, 'MX-20261108-01', '2026-11-08', 320, 0, 320, 0, 246200, 769.375, 0, 'provisional', 1, 'logged', NULL, NULL, 0, 320),
	(2, 'LOT-723b', '2026-11-01', 100, 0, 100, 0, 500000, 5000, 0, 'provisional', 13, 'inoculated', NULL, 4, 0, NULL),
	(3, 'LOT-e1d5', '2026-11-01', 100, 0, 100, 0, 500000, 5000, 0, 'provisional', 14, 'inoculated', NULL, 5, 0, NULL),
	(4, 'LOT-9488', '2026-11-01', 100, 0, 100, 0, 500000, 5000, 0, 'provisional', 15, 'inoculated', NULL, 6, 0, NULL),
	(5, 'LOT-3704', '2026-11-01', 100, 0, 100, 0, 500000, 5000, 0, 'provisional', 16, 'inoculated', NULL, 7, 0, NULL),
	(6, 'LOT-dbe7', '2026-11-01', 100, 0, 100, 0, 500000, 5000, 0, 'provisional', 17, 'inoculated', NULL, 8, 0, NULL),
	(7, 'ST-20261112-01', '2026-11-12', 130, 0, 130, 0, 106518.75, 819.375, 0, 'provisional', 1, 'sterilized', NULL, NULL, 0, NULL),
	(8, 'MX-20261116-01', '2026-11-16', 450, 0, 450, 0, 315450, 701, 0, 'provisional', 1, 'logged', NULL, NULL, 0, 392),
	(9, 'MX-20261116-02', '2026-11-16', 410, 0, 410, 49500, 157500, 384.1463, 0, 'provisional', 1, 'mixed', 3, NULL, 0, 410);

-- Dumping structure for table db.produksi_lotmaterial
CREATE TABLE IF NOT EXISTS "produksi_lotmaterial" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "qty" decimal NOT NULL, "lot_id" bigint NOT NULL REFERENCES "produksi_lot" ("id") DEFERRABLE INITIALLY DEFERRED, "material_id" bigint NOT NULL REFERENCES "produksi_material" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, "unit_price" decimal NOT NULL);
CREATE INDEX "produksi_lotmaterial_lot_id_751cd250" ON "produksi_lotmaterial" ("lot_id");
CREATE INDEX "produksi_lotmaterial_material_id_16690f12" ON "produksi_lotmaterial" ("material_id");
CREATE INDEX "produksi_lotmaterial_tenant_id_afbe9194" ON "produksi_lotmaterial" ("tenant_id");

-- Dumping data for table db.produksi_lotmaterial: 10 rows
INSERT INTO "produksi_lotmaterial" ("id", "qty", "lot_id", "material_id", "tenant_id", "unit_price") VALUES
	(1, 10, 1, 1, 1, 9000),
	(2, 30, 1, 2, 1, 3000),
	(3, 0.02, 1, 4, 1, 30000),
	(4, 0.2, 1, 5, 1, 8000),
	(5, 12, 8, 1, 1, 9000),
	(6, 36, 8, 2, 1, 3000),
	(7, 0.015, 8, 4, 1, 30000),
	(8, 0.2, 8, 5, 1, 8000),
	(9, 3, 8, 18, 1, 1800),
	(10, 12, 9, 1, 1, 9000);

-- Dumping structure for table db.produksi_lotmovement
CREATE TABLE IF NOT EXISTS "produksi_lotmovement" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "kind" varchar(14) NOT NULL, "delta" integer NOT NULL, "transfer_id" char(32) NULL, "recorded_at" datetime NOT NULL, "note" varchar(240) NOT NULL, "location_id" bigint NOT NULL REFERENCES "produksi_location" ("id") DEFERRABLE INITIALLY DEFERRED, "lot_id" bigint NOT NULL REFERENCES "produksi_lot" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "lot_movement_transfer_reference" CHECK ((("kind" IN ('transfer_in', 'transfer_out') AND "transfer_id" IS NOT NULL) OR ("kind" IN ('in', 'contaminated', 'reject', 'adjustment') AND "transfer_id" IS NULL))), CONSTRAINT "lot_movement_delta_matches_kind" CHECK ((("delta" > 0 AND "kind" IN ('in', 'transfer_in', 'adjustment')) OR ("delta" < 0 AND "kind" IN ('transfer_out', 'contaminated', 'reject', 'adjustment')))));
CREATE INDEX "produksi_lotmovement_location_id_316723c0" ON "produksi_lotmovement" ("location_id");
CREATE INDEX "produksi_lotmovement_lot_id_f3e493a7" ON "produksi_lotmovement" ("lot_id");
CREATE INDEX "produksi_lotmovement_tenant_id_37bda234" ON "produksi_lotmovement" ("tenant_id");
CREATE INDEX "movement_lot_location_idx" ON "produksi_lotmovement" ("tenant_id", "lot_id", "location_id");

-- Dumping data for table db.produksi_lotmovement: 0 rows

-- Dumping structure for table db.produksi_lotoverheadallocation
CREATE TABLE IF NOT EXISTS "produksi_lotoverheadallocation" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "rate_per_baglog" decimal NOT NULL, "baglog_quantity" integer unsigned NOT NULL CHECK ("baglog_quantity" >= 0), "amount" decimal NOT NULL, "is_final" bool NOT NULL, "updated_at" datetime NOT NULL, "lot_id" bigint NOT NULL REFERENCES "produksi_lot" ("id") DEFERRABLE INITIALLY DEFERRED, "month_id" bigint NOT NULL REFERENCES "produksi_generaloverheadmonth" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "lot_overhead_allocation_unique" UNIQUE ("month_id", "lot_id"), CONSTRAINT "lot_overhead_allocation_valid" CHECK (("rate_per_baglog" >= '0' AND "baglog_quantity" > 0 AND "amount" >= '0')));
;
CREATE INDEX "produksi_lotoverheadallocation_lot_id_e045c464" ON "produksi_lotoverheadallocation" ("lot_id");
CREATE INDEX "produksi_lotoverheadallocation_month_id_4e00ac96" ON "produksi_lotoverheadallocation" ("month_id");
CREATE INDEX "produksi_lotoverheadallocation_tenant_id_02fab442" ON "produksi_lotoverheadallocation" ("tenant_id");

-- Dumping data for table db.produksi_lotoverheadallocation: 0 rows

-- Dumping structure for table db.produksi_machine
CREATE TABLE IF NOT EXISTS "produksi_machine" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "name" varchar(120) NOT NULL, "energy_type" varchar(16) NOT NULL, "consumption_unit" varchar(20) NOT NULL, "consumption_per_hour" decimal NOT NULL, "capacity" decimal NULL, "capacity_unit" varchar(30) NOT NULL, "is_active" bool NOT NULL, "created_at" datetime NOT NULL, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, "purchase_cost" decimal NOT NULL, "residual_value" decimal NOT NULL, "useful_life_months" integer unsigned NULL CHECK ("useful_life_months" >= 0), "in_service_date" date NULL, "category" varchar(20) NOT NULL, CONSTRAINT "machine_unique_name" UNIQUE ("tenant_id", "name"), CONSTRAINT "machine_nonnegative_consumption" CHECK ("consumption_per_hour" >= '0'), CONSTRAINT "machine_positive_capacity" CHECK (("capacity" IS NULL OR "capacity" > '0')), CONSTRAINT "machine_valid_acquisition_values" CHECK (("purchase_cost" >= '0' AND "residual_value" >= '0')), CONSTRAINT "machine_residual_not_above_cost" CHECK ("residual_value" <= ("purchase_cost")));
;
CREATE INDEX "produksi_machine_tenant_id_1f73e0f4" ON "produksi_machine" ("tenant_id");

-- Dumping data for table db.produksi_machine: 3 rows
INSERT INTO "produksi_machine" ("id", "name", "energy_type", "consumption_unit", "consumption_per_hour", "capacity", "capacity_unit", "is_active", "created_at", "tenant_id", "purchase_cost", "residual_value", "useful_life_months", "in_service_date", "category") VALUES
	(1, 'Press Baglog', 'electricity', 'KwH', 1, 600, 'Baglog', 1, '2026-11-08 13:37:06.358261', 1, 6000000, 1500000, 72, '2026-11-08', 'other'),
	(2, 'Mixer', 'fuel', 'Liter', 3.3, 1200, 'Baglog', 1, '2026-11-08 13:40:36.108016', 1, 5000000, 1000000, 72, '2026-11-08', 'other'),
	(3, 'Drum 1', 'bbg', 'Tabung', 0.2, 130, 'Baglog', 1, '2026-11-13 06:45:46.067423', 1, 450000, 20000, 72, '2026-11-14', 'steamer');

-- Dumping structure for table db.produksi_machinedepreciation
CREATE TABLE IF NOT EXISTS "produksi_machinedepreciation" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "acquisition_cost" decimal NOT NULL, "residual_value" decimal NOT NULL, "useful_life_months" integer unsigned NOT NULL CHECK ("useful_life_months" >= 0), "in_service_days" smallint unsigned NOT NULL CHECK ("in_service_days" >= 0), "period_days" smallint unsigned NOT NULL CHECK ("period_days" >= 0), "amount" decimal NOT NULL, "created_at" datetime NOT NULL, "machine_id" bigint NOT NULL REFERENCES "produksi_machine" ("id") DEFERRABLE INITIALLY DEFERRED, "month_id" bigint NOT NULL REFERENCES "produksi_generaloverheadmonth" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "machine_depreciation_unique_month" UNIQUE ("month_id", "machine_id"), CONSTRAINT "machine_depreciation_valid_snapshot" CHECK (("acquisition_cost" >= '0' AND "residual_value" >= '0' AND "useful_life_months" > 0 AND "in_service_days" > 0 AND "period_days" > 0 AND "amount" >= '0')));
;
CREATE INDEX "produksi_machinedepreciation_machine_id_9fbf05d0" ON "produksi_machinedepreciation" ("machine_id");
CREATE INDEX "produksi_machinedepreciation_month_id_f66c6456" ON "produksi_machinedepreciation" ("month_id");
CREATE INDEX "produksi_machinedepreciation_tenant_id_40545378" ON "produksi_machinedepreciation" ("tenant_id");

-- Dumping data for table db.produksi_machinedepreciation: 0 rows

-- Dumping structure for table db.produksi_machineenergybill
CREATE TABLE IF NOT EXISTS "produksi_machineenergybill" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "energy_type" varchar(16) NOT NULL, "unit" varchar(20) NOT NULL, "period_start" date NOT NULL, "period_end" date NOT NULL, "billed_quantity" decimal NOT NULL, "billed_amount" decimal NOT NULL, "reference" varchar(100) NOT NULL, "note" varchar(240) NOT NULL, "status" varchar(12) NOT NULL, "created_at" datetime NOT NULL, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "energy_bill_valid_period" CHECK ("period_end" >= ("period_start")), CONSTRAINT "energy_bill_valid_amounts" CHECK (("billed_quantity" > '0' AND "billed_amount" >= '0')), CONSTRAINT "energy_bill_unique_period" UNIQUE ("tenant_id", "energy_type", "unit", "period_start", "period_end"));
;
CREATE INDEX "produksi_machineenergybill_tenant_id_d1823915" ON "produksi_machineenergybill" ("tenant_id");

-- Dumping data for table db.produksi_machineenergybill: 1 rows
INSERT INTO "produksi_machineenergybill" ("id", "energy_type", "unit", "period_start", "period_end", "billed_quantity", "billed_amount", "reference", "note", "status", "created_at", "tenant_id") VALUES
	(1, 'electricity', 'KwH', '2026-11-08', '2026-12-08', 1, 325000, '', '', 'draft', '2026-11-08 13:42:32.183154', 1);

-- Dumping structure for table db.produksi_machineenergyreconciliation
CREATE TABLE IF NOT EXISTS "produksi_machineenergyreconciliation" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "estimated_quantity" decimal NOT NULL, "estimated_cost" decimal NOT NULL, "quantity_variance" decimal NOT NULL, "cost_variance" decimal NOT NULL, "reconciled_at" datetime NOT NULL, "bill_id" bigint NOT NULL UNIQUE REFERENCES "produksi_machineenergybill" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED);
;
CREATE INDEX "produksi_machineenergyreconciliation_tenant_id_1379cae2" ON "produksi_machineenergyreconciliation" ("tenant_id");

-- Dumping data for table db.produksi_machineenergyreconciliation: 0 rows

-- Dumping structure for table db.produksi_machinerate
CREATE TABLE IF NOT EXISTS "produksi_machinerate" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "energy_type" varchar(16) NOT NULL, "unit" varchar(20) NOT NULL, "rate_per_unit" decimal NOT NULL, "effective_from" date NOT NULL, "source_note" varchar(240) NOT NULL, "created_at" datetime NOT NULL, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "machine_rate_unique_effective" UNIQUE ("tenant_id", "energy_type", "unit", "effective_from"), CONSTRAINT "machine_rate_nonnegative" CHECK ("rate_per_unit" >= '0'));
;
CREATE INDEX "produksi_machinerate_tenant_id_c44c43f6" ON "produksi_machinerate" ("tenant_id");

-- Dumping data for table db.produksi_machinerate: 1 rows
INSERT INTO "produksi_machinerate" ("id", "energy_type", "unit", "rate_per_unit", "effective_from", "source_note", "created_at", "tenant_id") VALUES
	(1, 'electricity', 'KwH', 1500, '2026-11-08', '', '2026-11-08 13:32:33.633278', 1);

-- Dumping structure for table db.produksi_machineusage
CREATE TABLE IF NOT EXISTS "produksi_machineusage" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "process_name" varchar(60) NOT NULL, "usage_date" date NOT NULL, "duration_hours" decimal NOT NULL, "consumption_quantity" decimal NOT NULL, "consumption_unit" varchar(20) NOT NULL, "rate_per_unit" decimal NOT NULL, "total_cost" decimal NOT NULL, "baglog_quantity" integer unsigned NOT NULL CHECK ("baglog_quantity" >= 0), "cost_per_baglog" decimal NOT NULL, "is_actual_consumption" bool NOT NULL, "recorded_at" datetime NOT NULL, "lot_id" bigint NULL REFERENCES "produksi_lot" ("id") DEFERRABLE INITIALLY DEFERRED, "machine_id" bigint NOT NULL REFERENCES "produksi_machine" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "machine_usage_valid_amounts" CHECK (("duration_hours" > '0' AND "consumption_quantity" > '0' AND "rate_per_unit" >= '0' AND "total_cost" >= '0' AND "cost_per_baglog" >= '0')));
CREATE INDEX "produksi_machineusage_lot_id_287f2ca5" ON "produksi_machineusage" ("lot_id");
CREATE INDEX "produksi_machineusage_machine_id_fafd94ff" ON "produksi_machineusage" ("machine_id");
CREATE INDEX "produksi_machineusage_tenant_id_80034c40" ON "produksi_machineusage" ("tenant_id");

-- Dumping data for table db.produksi_machineusage: 1 rows
INSERT INTO "produksi_machineusage" ("id", "process_name", "usage_date", "duration_hours", "consumption_quantity", "consumption_unit", "rate_per_unit", "total_cost", "baglog_quantity", "cost_per_baglog", "is_actual_consumption", "recorded_at", "lot_id", "machine_id", "tenant_id") VALUES
	(1, 'Mixing', '2026-11-16', 1.5, 4.95, 'Liter', 10000, 49500, 410, 120.73170731707317, 0, '2026-11-16 13:43:35.270784', 9, 2, 1);

-- Dumping structure for table db.produksi_machineusageadjustment
CREATE TABLE IF NOT EXISTS "produksi_machineusageadjustment" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "amount_delta" decimal NOT NULL, "reconciliation_id" bigint NOT NULL REFERENCES "produksi_machineenergyreconciliation" ("id") DEFERRABLE INITIALLY DEFERRED, "usage_id" bigint NOT NULL REFERENCES "produksi_machineusage" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "machine_usage_adjustment_once" UNIQUE ("usage_id"));
;
CREATE INDEX "produksi_machineusageadjustment_reconciliation_id_bfdf65a7" ON "produksi_machineusageadjustment" ("reconciliation_id");
CREATE INDEX "produksi_machineusageadjustment_usage_id_fd7c2a4d" ON "produksi_machineusageadjustment" ("usage_id");
CREATE INDEX "produksi_machineusageadjustment_tenant_id_ca02c287" ON "produksi_machineusageadjustment" ("tenant_id");

-- Dumping data for table db.produksi_machineusageadjustment: 0 rows

-- Dumping structure for table db.produksi_material
CREATE TABLE IF NOT EXISTS "produksi_material" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "name" varchar(120) NOT NULL, "unit" varchar(20) NOT NULL, "unit_price" decimal NOT NULL, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, "material_type" varchar(60) NOT NULL, "min_stock" decimal NOT NULL, "production_phase_id" bigint NULL REFERENCES "produksi_productionphase" ("id") DEFERRABLE INITIALLY DEFERRED, "usage_classification" varchar(60) NOT NULL, "cost_role" varchar(12) NOT NULL, CONSTRAINT "material_unique_name" UNIQUE ("tenant_id", "name"), CONSTRAINT "material_min_stock_nonnegative" CHECK ("min_stock" >= '0'));
;
CREATE INDEX "produksi_material_tenant_id_b8895dc6" ON "produksi_material" ("tenant_id");
CREATE INDEX "produksi_material_production_phase_id_cbe14f4f" ON "produksi_material" ("production_phase_id");

-- Dumping data for table db.produksi_material: 18 rows
INSERT INTO "produksi_material" ("id", "name", "unit", "unit_price", "tenant_id", "material_type", "min_stock", "production_phase_id", "usage_classification", "cost_role") VALUES
	(1, 'Serbuk Kayu', 'karung', 9000, 1, 'Bahan Baku', 20, 1, 'keduanya', 'direct'),
	(2, 'Dedak', 'kg', 3000, 1, 'Bahan Baku', 25, 1, 'keduanya', 'direct'),
	(3, 'Plastik Baglog Lipat KW', 'kg', 40000, 1, 'Bahan Baku', 10, 2, 'baglog', 'direct'),
	(4, 'EM-4', 'liter', 30000, 1, 'Bahan Baku', 2, 1, 'baglog', 'direct'),
	(5, 'Molase', 'liter', 8000, 1, 'Bahan Baku', 10, 1, 'baglog', 'direct'),
	(6, 'Tepung Jagung', 'kg', 8000, 1, 'Bahan Baku', 15, 1, 'bibit', 'direct'),
	(7, 'Plastik Jamur', 'kg', 45000, 1, 'Bahan Kemasan', 1, 5, '', 'direct'),
	(8, 'Karung', 'pcs', 3000, 1, 'Bahan Pendukung', 250, 141, '', 'direct'),
	(9, 'Alkohol', 'liter', 20000, 1, 'Bahan Pendukung', 2, 4, 'bibit', 'direct'),
	(10, 'Spirtus', 'liter', 20000, 1, 'Bahan Pendukung', 2, 4, 'keduanya', 'direct'),
	(11, 'Kertas Koran', 'kg', 18000, 1, 'Bahan Pendukung', 2, 4, 'keduanya', 'direct'),
	(12, 'Cincin Baglog', 'pcs', 150, 1, 'Bahan Baku', 1000, 4, 'keduanya', 'direct'),
	(13, 'Gas LPG', 'pcs', 20000, 1, 'Bahan Bakar', 4, 3, 'keduanya', 'direct'),
	(14, 'Kayu Bakar', 'unit', 300000, 1, 'Bahan Bakar', 2, 3, 'baglog', 'direct'),
	(15, 'Karet Gelang', 'kg', 24000, 1, 'Bahan Pendukung', 0.5, 4, 'keduanya', 'direct'),
	(16, 'Majun', 'kg', 8000, 1, 'Bahan Pendukung', 10, 4, 'keduanya', 'direct'),
	(17, 'Bibit F2', 'botol', 8000, 1, 'Bahan Baku', 50, 4, 'baglog', 'direct'),
	(18, 'Kapur CaCo3', 'kg', 1800, 1, 'Bahan Baku', 10, 1, 'keduanya', 'direct');

-- Dumping structure for table db.produksi_materialmovement
CREATE TABLE IF NOT EXISTS "produksi_materialmovement" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "kind" varchar(16) NOT NULL, "quantity_delta" decimal NOT NULL, "unit_cost" decimal NOT NULL, "value_delta" decimal NOT NULL, "recorded_at" datetime NOT NULL, "note" varchar(240) NOT NULL, "lot_id" bigint NULL REFERENCES "produksi_lot" ("id") DEFERRABLE INITIALLY DEFERRED, "material_id" bigint NOT NULL REFERENCES "produksi_material" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "material_movement_nonnegative_unit_cost" CHECK ("unit_cost" >= '0'), CONSTRAINT "material_movement_sign_matches_kind" CHECK ((("kind" IN ('opening', 'purchase', 'adjustment_in') AND "quantity_delta" > '0' AND "value_delta" >= '0') OR ("kind" IN ('consumption', 'adjustment_out') AND "quantity_delta" < '0' AND "value_delta" <= '0') OR ("kind" = 'reversal' AND NOT ("quantity_delta" = '0')))));
CREATE INDEX "produksi_materialmovement_lot_id_44543b49" ON "produksi_materialmovement" ("lot_id");
CREATE INDEX "produksi_materialmovement_material_id_0eff6094" ON "produksi_materialmovement" ("material_id");
CREATE INDEX "produksi_materialmovement_tenant_id_c6a47c12" ON "produksi_materialmovement" ("tenant_id");
CREATE INDEX "material_movement_order_idx" ON "produksi_materialmovement" ("tenant_id", "material_id", "id");

-- Dumping data for table db.produksi_materialmovement: 31 rows
INSERT INTO "produksi_materialmovement" ("id", "kind", "quantity_delta", "unit_cost", "value_delta", "recorded_at", "note", "lot_id", "material_id", "tenant_id") VALUES
	(1, 'opening', 68, 9000, 612000, '2026-11-08 05:55:56.916484', 'Saldo awal bahan', NULL, 1, 1),
	(2, 'opening', 16, 3000, 48000, '2026-11-08 05:55:56.923729', 'Saldo awal bahan', NULL, 2, 1),
	(3, 'opening', 15, 40000, 600000, '2026-11-08 05:55:56.930564', 'Saldo awal bahan', NULL, 3, 1),
	(4, 'opening', 2, 30000, 60000, '2026-11-08 05:55:56.937216', 'Saldo awal bahan', NULL, 4, 1),
	(5, 'opening', 5, 8000, 40000, '2026-11-08 05:55:56.945145', 'Saldo awal bahan', NULL, 5, 1),
	(6, 'opening', 30, 8000, 240000, '2026-11-08 05:55:56.949478', 'Saldo awal bahan', NULL, 6, 1),
	(7, 'opening', 2, 45000, 90000, '2026-11-08 05:55:56.957580', 'Saldo awal bahan', NULL, 7, 1),
	(8, 'opening', 50, 3000, 150000, '2026-11-08 05:55:56.961446', 'Saldo awal bahan', NULL, 8, 1),
	(9, 'opening', 5, 20000, 100000, '2026-11-08 05:55:56.968245', 'Saldo awal bahan', NULL, 9, 1),
	(10, 'opening', 5, 20000, 100000, '2026-11-08 05:55:56.974477', 'Saldo awal bahan', NULL, 10, 1),
	(11, 'opening', 5, 18000, 90000, '2026-11-08 05:55:56.978241', 'Saldo awal bahan', NULL, 11, 1),
	(12, 'opening', 5000, 150, 750000, '2026-11-08 05:55:56.981976', 'Saldo awal bahan', NULL, 12, 1),
	(13, 'opening', 20, 20000, 400000, '2026-11-08 05:55:56.988616', 'Saldo awal bahan', NULL, 13, 1),
	(14, 'opening', 5, 300000, 1500000, '2026-11-08 05:55:56.993236', 'Saldo awal bahan', NULL, 14, 1),
	(15, 'opening', 5, 24000, 120000, '2026-11-08 05:55:56.999154', 'Saldo awal bahan', NULL, 15, 1),
	(16, 'opening', 25, 8000, 200000, '2026-11-08 05:55:57.007092', 'Saldo awal bahan', NULL, 16, 1),
	(17, 'purchase', 100, 3000, 300000, '2026-11-08 06:01:01.763188', 'Pembelian 1', NULL, 2, 1),
	(18, 'consumption', -10, 9000, -90000, '2026-11-08 06:03:18.471271', 'Pemakaian untuk lot MX-20261108-01', 1, 1, 1),
	(19, 'consumption', -30, 3000, -90000, '2026-11-08 06:03:18.483864', 'Pemakaian untuk lot MX-20261108-01', 1, 2, 1),
	(20, 'consumption', -0.02, 30000, -600, '2026-11-08 06:03:18.490584', 'Pemakaian untuk lot MX-20261108-01', 1, 4, 1),
	(21, 'consumption', -0.2, 8000, -1600, '2026-11-08 06:03:18.500478', 'Pemakaian untuk lot MX-20261108-01', 1, 5, 1),
	(22, 'opening', 150, 8000, 1200000, '2026-11-08 13:45:29.250756', 'Saldo awal bahan', NULL, 17, 1),
	(23, 'opening', 360, 1800, 648000, '2026-11-12 13:19:13.444162', 'Saldo awal bahan', NULL, 18, 1),
	(24, 'consumption', -1.6, 40000, -64000, '2026-11-13 05:53:26.628463', 'Pemakaian logging LOG-20261113-01', 1, 3, 1),
	(25, 'consumption', -12, 9000, -108000, '2026-11-16 12:32:02.069984', 'Pemakaian untuk lot MX-20261116-01', 8, 1, 1),
	(26, 'consumption', -36, 3000, -108000, '2026-11-16 12:32:02.081125', 'Pemakaian untuk lot MX-20261116-01', 8, 2, 1),
	(27, 'consumption', -0.015, 30000, -450, '2026-11-16 12:32:02.092074', 'Pemakaian untuk lot MX-20261116-01', 8, 4, 1),
	(28, 'consumption', -0.2, 8000, -1600, '2026-11-16 12:32:02.097476', 'Pemakaian untuk lot MX-20261116-01', 8, 5, 1),
	(29, 'consumption', -3, 1800, -5400, '2026-11-16 12:32:02.102438', 'Pemakaian untuk lot MX-20261116-01', 8, 18, 1),
	(30, 'consumption', -2.3, 40000, -92000, '2026-11-16 13:39:38.537213', 'Pemakaian logging LOG-20261116-01', 8, 3, 1),
	(31, 'consumption', -12, 9000, -108000, '2026-11-16 13:43:02.421012', 'Pemakaian untuk lot MX-20261116-02', 9, 1, 1);

-- Dumping structure for table db.produksi_materialpurchase
CREATE TABLE IF NOT EXISTS "produksi_materialpurchase" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "purchase_date" date NOT NULL, "reference" varchar(80) NOT NULL, "status" varchar(10) NOT NULL, "note" varchar(240) NOT NULL, "posted_at" datetime NULL, "created_at" datetime NOT NULL, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, "supplier_id" bigint NULL REFERENCES "produksi_supplier" ("id") DEFERRABLE INITIALLY DEFERRED);
CREATE INDEX "produksi_materialpurchase_tenant_id_4880a9bc" ON "produksi_materialpurchase" ("tenant_id");
CREATE INDEX "produksi_materialpurchase_supplier_id_25b73ca9" ON "produksi_materialpurchase" ("supplier_id");

-- Dumping data for table db.produksi_materialpurchase: 1 rows
INSERT INTO "produksi_materialpurchase" ("id", "purchase_date", "reference", "status", "note", "posted_at", "created_at", "tenant_id", "supplier_id") VALUES
	(1, '2026-11-08', '', 'posted', '', '2026-11-08 06:01:01.765377', '2026-11-08 06:00:45.272292', 1, NULL);

-- Dumping structure for table db.produksi_materialpurchaseline
CREATE TABLE IF NOT EXISTS "produksi_materialpurchaseline" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "quantity" decimal NOT NULL, "unit_price" decimal NOT NULL, "material_id" bigint NOT NULL REFERENCES "produksi_material" ("id") DEFERRABLE INITIALLY DEFERRED, "purchase_id" bigint NOT NULL REFERENCES "produksi_materialpurchase" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "purchase_line_unique_material" UNIQUE ("purchase_id", "material_id"), CONSTRAINT "purchase_line_valid_quantity_price" CHECK (("quantity" > '0' AND "unit_price" >= '0')));
;
CREATE INDEX "produksi_materialpurchaseline_material_id_bb8d5904" ON "produksi_materialpurchaseline" ("material_id");
CREATE INDEX "produksi_materialpurchaseline_purchase_id_585067fa" ON "produksi_materialpurchaseline" ("purchase_id");
CREATE INDEX "produksi_materialpurchaseline_tenant_id_fc09e072" ON "produksi_materialpurchaseline" ("tenant_id");

-- Dumping data for table db.produksi_materialpurchaseline: 1 rows
INSERT INTO "produksi_materialpurchaseline" ("id", "quantity", "unit_price", "material_id", "purchase_id", "tenant_id") VALUES
	(1, 100, 3000, 2, 1, 1);

-- Dumping structure for table db.produksi_module
CREATE TABLE IF NOT EXISTS "produksi_module" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "code" varchar(50) NOT NULL, "name" varchar(100) NOT NULL, "description" text NOT NULL, "is_core" bool NOT NULL, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "module_unique_code_per_tenant" UNIQUE ("tenant_id", "code"));
;
CREATE INDEX "produksi_module_tenant_id_6b1175e0" ON "produksi_module" ("tenant_id");

-- Dumping data for table db.produksi_module: 29 rows
INSERT INTO "produksi_module" ("id", "code", "name", "description", "is_core", "tenant_id") VALUES
	(1, 'ModInt', 'Modul Inti', '', 1, 1),
	(2, 'bibit', 'Produksi bibit', '', 0, 1),
	(3, 'hr', 'SDM dan tenaga kerja', '', 0, 1),
	(4, 'keuangan', 'Keuangan dan HPP', '', 0, 1),
	(5, 'pengaturan', 'Pengaturan tenant', '', 1, 1),
	(6, 'penjualan', 'Panen dan penjualan', '', 0, 1),
	(7, 'persediaan', 'Persediaan bahan', '', 1, 1),
	(8, 'portal', 'Portal pelanggan', '', 0, 1),
	(9, 'produksi', 'Produksi baglog', '', 1, 1),
	(10, 'produksi', 'Produksi', '', 1, 33),
	(11, 'persediaan', 'Persediaan', '', 1, 33),
	(12, 'pengaturan', 'Pengaturan', '', 1, 33),
	(13, 'produksi', 'Produksi', '', 1, 35),
	(14, 'persediaan', 'Persediaan', '', 1, 35),
	(15, 'pengaturan', 'Pengaturan', '', 1, 35),
	(16, 'produksi', 'Produksi', '', 1, 36),
	(17, 'persediaan', 'Persediaan', '', 1, 36),
	(18, 'pengaturan', 'Pengaturan', '', 1, 36),
	(19, 'bibit', 'Produksi bibit', '', 0, 37),
	(20, 'hr', 'SDM dan tenaga kerja', '', 0, 37),
	(21, 'keuangan', 'Keuangan dan HPP', '', 0, 37),
	(22, 'pengaturan', 'Pengaturan tenant', '', 1, 37),
	(23, 'penjualan', 'Panen dan penjualan', '', 0, 37),
	(24, 'persediaan', 'Persediaan bahan', '', 1, 37),
	(25, 'portal', 'Portal pelanggan', '', 0, 37),
	(26, 'produksi', 'Produksi baglog', '', 1, 37),
	(27, 'iot', 'IoT dan Sensor', '', 0, 37),
	(28, 'iot', 'IoT dan Sensor', '', 0, 1),
	(29, 'laporan', 'Laporan dan Analitik', '', 0, 1);

-- Dumping structure for table db.produksi_order
CREATE TABLE IF NOT EXISTS "produksi_order" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "order_date" date NOT NULL, "reference" varchar(80) NOT NULL, "status" varchar(20) NOT NULL, "notes" varchar(240) NOT NULL, "created_at" datetime NOT NULL, "buyer_id" bigint NOT NULL REFERENCES "produksi_buyer" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED);
CREATE INDEX "order_date_idx" ON "produksi_order" ("tenant_id", "order_date");
CREATE INDEX "produksi_order_buyer_id_913936af" ON "produksi_order" ("buyer_id");
CREATE INDEX "produksi_order_tenant_id_5ec2ebaa" ON "produksi_order" ("tenant_id");

-- Dumping data for table db.produksi_order: 0 rows

-- Dumping structure for table db.produksi_orderline
CREATE TABLE IF NOT EXISTS "produksi_orderline" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "quantity_kg" decimal NOT NULL, "price_per_kg" decimal NOT NULL, "line_total" decimal NOT NULL, "harvest_id" bigint NOT NULL REFERENCES "produksi_harvest" ("id") DEFERRABLE INITIALLY DEFERRED, "order_id" bigint NOT NULL REFERENCES "produksi_order" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "order_line_valid" CHECK (("quantity_kg" > '0' AND "price_per_kg" >= '0' AND "line_total" >= '0')));
CREATE INDEX "produksi_orderline_harvest_id_b3262d49" ON "produksi_orderline" ("harvest_id");
CREATE INDEX "produksi_orderline_order_id_9170d549" ON "produksi_orderline" ("order_id");
CREATE INDEX "produksi_orderline_tenant_id_a847bd7e" ON "produksi_orderline" ("tenant_id");

-- Dumping data for table db.produksi_orderline: 0 rows

-- Dumping structure for table db.produksi_payment
CREATE TABLE IF NOT EXISTS "produksi_payment" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "payment_date" date NOT NULL, "method" varchar(12) NOT NULL, "reference" varchar(80) NOT NULL, "notes" varchar(240) NOT NULL, "created_at" datetime NOT NULL, "invoice_id" bigint NOT NULL REFERENCES "produksi_invoice" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, "amount" decimal NOT NULL);
CREATE INDEX "produksi_payment_invoice_id_c5da9ff2" ON "produksi_payment" ("invoice_id");
CREATE INDEX "produksi_payment_tenant_id_7ecf29ed" ON "produksi_payment" ("tenant_id");

-- Dumping data for table db.produksi_payment: 0 rows

-- Dumping structure for table db.produksi_payroll
CREATE TABLE IF NOT EXISTS "produksi_payroll" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "month" integer NOT NULL, "year" integer NOT NULL, "base_salary" decimal NOT NULL, "overtime_pay" decimal NOT NULL, "bonus" decimal NOT NULL, "deduction" decimal NOT NULL, "paid_date" date NULL, "notes" varchar(200) NOT NULL, "employee_id" bigint NOT NULL REFERENCES "produksi_employee" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, "allowance" decimal NOT NULL, "approval_reference" varchar(100) NOT NULL, "ledger_account" varchar(100) NOT NULL, "liability_balance" decimal NOT NULL, "net_salary" decimal NOT NULL, "other_deduction" decimal NOT NULL, "payment_mode" varchar(20) NOT NULL, "prepared_by" varchar(100) NOT NULL, "reconciliation_status" varchar(15) NOT NULL, "reviewed_by" varchar(100) NOT NULL, "source_document" varchar(100) NOT NULL, "ssf_pf_contribution" decimal NOT NULL, "tds" decimal NOT NULL, "total_salary" decimal NOT NULL, CONSTRAINT "payroll_unique_employee_month_year_per_tenant" UNIQUE ("tenant_id", "employee_id", "month", "year"));
;
CREATE INDEX "produksi_payroll_employee_id_e0173dfa" ON "produksi_payroll" ("employee_id");
CREATE INDEX "produksi_payroll_tenant_id_2a6df762" ON "produksi_payroll" ("tenant_id");

-- Dumping data for table db.produksi_payroll: 0 rows

-- Dumping structure for table db.produksi_phasematerialusage
CREATE TABLE IF NOT EXISTS "produksi_phasematerialusage" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "quantity" decimal NOT NULL, "unit_cost" decimal NOT NULL, "total_cost" decimal NOT NULL, "is_overhead" bool NOT NULL, "created_at" datetime NOT NULL, "inoculation_run_id" bigint NULL REFERENCES "produksi_inoculationrun" ("id") DEFERRABLE INITIALLY DEFERRED, "logging_id" bigint NULL REFERENCES "produksi_bagloglogging" ("id") DEFERRABLE INITIALLY DEFERRED, "lot_id" bigint NULL REFERENCES "produksi_lot" ("id") DEFERRABLE INITIALLY DEFERRED, "material_id" bigint NOT NULL REFERENCES "produksi_material" ("id") DEFERRABLE INITIALLY DEFERRED, "sterilization_run_id" bigint NULL REFERENCES "produksi_sterilizationrun" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "phase_material_usage_single_cost_object" CHECK ((("inoculation_run_id" IS NULL AND "logging_id" IS NULL AND "lot_id" IS NOT NULL AND "sterilization_run_id" IS NULL) OR ("inoculation_run_id" IS NULL AND "logging_id" IS NOT NULL AND "lot_id" IS NULL AND "sterilization_run_id" IS NULL) OR ("inoculation_run_id" IS NULL AND "logging_id" IS NULL AND "lot_id" IS NULL AND "sterilization_run_id" IS NOT NULL) OR ("inoculation_run_id" IS NOT NULL AND "logging_id" IS NULL AND "lot_id" IS NULL AND "sterilization_run_id" IS NULL))), CONSTRAINT "phase_material_usage_valid_amounts" CHECK (("quantity" > '0' AND "unit_cost" >= '0' AND "total_cost" >= '0')));
CREATE INDEX "produksi_phasematerialusage_inoculation_run_id_bfcac5ba" ON "produksi_phasematerialusage" ("inoculation_run_id");
CREATE INDEX "produksi_phasematerialusage_logging_id_afb9b146" ON "produksi_phasematerialusage" ("logging_id");
CREATE INDEX "produksi_phasematerialusage_lot_id_c247d66d" ON "produksi_phasematerialusage" ("lot_id");
CREATE INDEX "produksi_phasematerialusage_material_id_08db0f82" ON "produksi_phasematerialusage" ("material_id");
CREATE INDEX "produksi_phasematerialusage_sterilization_run_id_60073c29" ON "produksi_phasematerialusage" ("sterilization_run_id");
CREATE INDEX "produksi_phasematerialusage_tenant_id_5b3066e7" ON "produksi_phasematerialusage" ("tenant_id");

-- Dumping data for table db.produksi_phasematerialusage: 0 rows

-- Dumping structure for table db.produksi_plan
CREATE TABLE IF NOT EXISTS "produksi_plan" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "name" varchar(100) NOT NULL, "description" text NOT NULL, "price_monthly" decimal NOT NULL, "max_locations" integer unsigned NOT NULL CHECK ("max_locations" >= 0), "max_machines" integer unsigned NOT NULL CHECK ("max_machines" >= 0), "max_users" integer unsigned NOT NULL CHECK ("max_users" >= 0), "is_active" bool NOT NULL, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "plan_unique_name_per_tenant" UNIQUE ("tenant_id", "name"));
;
CREATE INDEX "produksi_plan_tenant_id_7ed635f6" ON "produksi_plan" ("tenant_id");

-- Dumping data for table db.produksi_plan: 8 rows
INSERT INTO "produksi_plan" ("id", "name", "description", "price_monthly", "max_locations", "max_machines", "max_users", "is_active", "tenant_id") VALUES
	(1, 'Basic', '', 500000, 10, 5, 5, 1, 1),
	(2, 'Premium', '', 1500000, 1000, 1000, 1000, 1, 1),
	(3, 'Basic', '', 0, 2, 2, 2, 1, 33),
	(4, 'Basic', '', 0, 2, 2, 2, 1, 35),
	(5, 'Basic', '', 0, 2, 2, 2, 1, 36),
	(6, 'Basic', 'Produksi baglog, persediaan bahan, serta panen dan penjualan.', 0, 5, 10, 5, 1, 37),
	(7, 'Pro', 'Basic ditambah keuangan/HPP, SDM, dan produksi bibit.', 0, 5, 10, 5, 1, 37),
	(8, 'Premium', 'Seluruh modul, termasuk portal pelanggan.', 0, 5, 10, 5, 1, 37);

-- Dumping structure for table db.produksi_planmodule
CREATE TABLE IF NOT EXISTS "produksi_planmodule" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "module_id" bigint NOT NULL REFERENCES "produksi_module" ("id") DEFERRABLE INITIALLY DEFERRED, "plan_id" bigint NOT NULL REFERENCES "produksi_plan" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "plan_module_unique" UNIQUE ("plan_id", "module_id"));
;
CREATE INDEX "produksi_planmodule_module_id_3f294b76" ON "produksi_planmodule" ("module_id");
CREATE INDEX "produksi_planmodule_plan_id_24de592f" ON "produksi_planmodule" ("plan_id");

-- Dumping data for table db.produksi_planmodule: 27 rows
INSERT INTO "produksi_planmodule" ("id", "module_id", "plan_id") VALUES
	(1, 6, 1),
	(2, 2, 2),
	(3, 3, 2),
	(4, 4, 2),
	(5, 6, 2),
	(6, 8, 2),
	(7, 10, 3),
	(8, 11, 3),
	(9, 12, 3),
	(10, 13, 4),
	(11, 14, 4),
	(12, 15, 4),
	(13, 16, 5),
	(14, 17, 5),
	(15, 18, 5),
	(16, 23, 6),
	(17, 19, 7),
	(18, 20, 7),
	(19, 21, 7),
	(20, 23, 7),
	(21, 19, 8),
	(22, 20, 8),
	(23, 21, 8),
	(24, 23, 8),
	(25, 25, 8),
	(26, 28, 2),
	(27, 29, 2);

-- Dumping structure for table db.produksi_plasticpreset
CREATE TABLE IF NOT EXISTS "produksi_plasticpreset" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "name" varchar(120) NOT NULL, "size" varchar(60) NOT NULL, "units_per_kg" decimal NOT NULL, "effective_from" date NOT NULL, "is_active" bool NOT NULL, "created_at" datetime NOT NULL, "material_id" bigint NOT NULL REFERENCES "produksi_material" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "plastic_preset_unique_name" UNIQUE ("tenant_id", "name"), CONSTRAINT "plastic_preset_positive_units_per_kg" CHECK ("units_per_kg" > '0'));
;
CREATE INDEX "produksi_plasticpreset_material_id_7b4c5065" ON "produksi_plasticpreset" ("material_id");
CREATE INDEX "produksi_plasticpreset_tenant_id_a790a289" ON "produksi_plasticpreset" ("tenant_id");

-- Dumping data for table db.produksi_plasticpreset: 1 rows
INSERT INTO "produksi_plasticpreset" ("id", "name", "size", "units_per_kg", "effective_from", "is_active", "created_at", "material_id", "tenant_id") VALUES
	(1, 'KW 18 x 35', '18 x 35', 197, '2026-11-13', 1, '2026-11-13 05:51:02.975702', 3, 1);

-- Dumping structure for table db.produksi_productionphase
CREATE TABLE IF NOT EXISTS "produksi_productionphase" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "name" varchar(50) NOT NULL, "code" varchar(30) NOT NULL, "color" varchar(20) NOT NULL, "is_active" bool NOT NULL, "order" integer unsigned NOT NULL CHECK ("order" >= 0), "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "production_phase_unique_code_per_tenant" UNIQUE ("tenant_id", "code"), CONSTRAINT "production_phase_unique_name_per_tenant" UNIQUE ("tenant_id", "name"));
;
;
CREATE INDEX "produksi_productionphase_tenant_id_76e3f92d" ON "produksi_productionphase" ("tenant_id");

-- Dumping data for table db.produksi_productionphase: 174 rows
INSERT INTO "produksi_productionphase" ("id", "name", "code", "color", "is_active", "order", "tenant_id") VALUES
	(1, 'Mixing', 'mixing', '#2563eb', 1, 1, 1),
	(2, 'Logging (Pembuatan Baglog)', 'logging', '#059669', 1, 2, 1),
	(3, 'Sterilisasi', 'sterilization', '#d97706', 1, 3, 1),
	(4, 'Inokulasi', 'inoculation', '#7c3aed', 1, 4, 1),
	(5, 'Semua Fase', 'all', '#6b7280', 1, 5, 1),
	(6, 'Mixing', 'mixing', '#2563eb', 1, 1, 2),
	(7, 'Logging (Pembuatan Baglog)', 'logging', '#059669', 1, 2, 2),
	(8, 'Sterilisasi', 'sterilization', '#d97706', 1, 3, 2),
	(9, 'Inokulasi', 'inoculation', '#7c3aed', 1, 4, 2),
	(10, 'Semua Fase', 'all', '#6b7280', 1, 5, 2),
	(11, 'Mixing', 'mixing', '#2563eb', 1, 1, 3),
	(12, 'Logging (Pembuatan Baglog)', 'logging', '#059669', 1, 2, 3),
	(13, 'Sterilisasi', 'sterilization', '#d97706', 1, 3, 3),
	(14, 'Inokulasi', 'inoculation', '#7c3aed', 1, 4, 3),
	(15, 'Semua Fase', 'all', '#6b7280', 1, 5, 3),
	(16, 'Mixing', 'mixing', '#2563eb', 1, 1, 4),
	(17, 'Logging (Pembuatan Baglog)', 'logging', '#059669', 1, 2, 4),
	(18, 'Sterilisasi', 'sterilization', '#d97706', 1, 3, 4),
	(19, 'Inokulasi', 'inoculation', '#7c3aed', 1, 4, 4),
	(20, 'Semua Fase', 'all', '#6b7280', 1, 5, 4),
	(21, 'Mixing', 'mixing', '#2563eb', 1, 1, 5),
	(22, 'Logging (Pembuatan Baglog)', 'logging', '#059669', 1, 2, 5),
	(23, 'Sterilisasi', 'sterilization', '#d97706', 1, 3, 5),
	(24, 'Inokulasi', 'inoculation', '#7c3aed', 1, 4, 5),
	(25, 'Semua Fase', 'all', '#6b7280', 1, 5, 5),
	(26, 'Mixing', 'mixing', '#2563eb', 1, 1, 6),
	(27, 'Logging (Pembuatan Baglog)', 'logging', '#059669', 1, 2, 6),
	(28, 'Sterilisasi', 'sterilization', '#d97706', 1, 3, 6),
	(29, 'Inokulasi', 'inoculation', '#7c3aed', 1, 4, 6),
	(30, 'Semua Fase', 'all', '#6b7280', 1, 5, 6),
	(31, 'Mixing', 'mixing', '#2563eb', 1, 1, 7),
	(32, 'Logging (Pembuatan Baglog)', 'logging', '#059669', 1, 2, 7),
	(33, 'Sterilisasi', 'sterilization', '#d97706', 1, 3, 7),
	(34, 'Inokulasi', 'inoculation', '#7c3aed', 1, 4, 7),
	(35, 'Semua Fase', 'all', '#6b7280', 1, 5, 7),
	(36, 'Mixing', 'mixing', '#2563eb', 1, 1, 8),
	(37, 'Logging (Pembuatan Baglog)', 'logging', '#059669', 1, 2, 8),
	(38, 'Sterilisasi', 'sterilization', '#d97706', 1, 3, 8),
	(39, 'Inokulasi', 'inoculation', '#7c3aed', 1, 4, 8),
	(40, 'Semua Fase', 'all', '#6b7280', 1, 5, 8),
	(41, 'Mixing', 'mixing', '#2563eb', 1, 1, 9),
	(42, 'Logging (Pembuatan Baglog)', 'logging', '#059669', 1, 2, 9),
	(43, 'Sterilisasi', 'sterilization', '#d97706', 1, 3, 9),
	(44, 'Inokulasi', 'inoculation', '#7c3aed', 1, 4, 9),
	(45, 'Semua Fase', 'all', '#6b7280', 1, 5, 9),
	(46, 'Mixing', 'mixing', '#2563eb', 1, 1, 10),
	(47, 'Logging (Pembuatan Baglog)', 'logging', '#059669', 1, 2, 10),
	(48, 'Sterilisasi', 'sterilization', '#d97706', 1, 3, 10),
	(49, 'Inokulasi', 'inoculation', '#7c3aed', 1, 4, 10),
	(50, 'Semua Fase', 'all', '#6b7280', 1, 5, 10),
	(51, 'Mixing', 'mixing', '#2563eb', 1, 1, 11),
	(52, 'Logging (Pembuatan Baglog)', 'logging', '#059669', 1, 2, 11),
	(53, 'Sterilisasi', 'sterilization', '#d97706', 1, 3, 11),
	(54, 'Inokulasi', 'inoculation', '#7c3aed', 1, 4, 11),
	(55, 'Semua Fase', 'all', '#6b7280', 1, 5, 11),
	(56, 'Mixing', 'mixing', '#2563eb', 1, 1, 12),
	(57, 'Logging (Pembuatan Baglog)', 'logging', '#059669', 1, 2, 12),
	(58, 'Sterilisasi', 'sterilization', '#d97706', 1, 3, 12),
	(59, 'Inokulasi', 'inoculation', '#7c3aed', 1, 4, 12),
	(60, 'Semua Fase', 'all', '#6b7280', 1, 5, 12),
	(61, 'Mixing', 'mixing', '#2563eb', 1, 1, 13),
	(62, 'Logging (Pembuatan Baglog)', 'logging', '#059669', 1, 2, 13),
	(63, 'Sterilisasi', 'sterilization', '#d97706', 1, 3, 13),
	(64, 'Inokulasi', 'inoculation', '#7c3aed', 1, 4, 13),
	(65, 'Semua Fase', 'all', '#6b7280', 1, 5, 13),
	(66, 'Mixing', 'mixing', '#2563eb', 1, 1, 14),
	(67, 'Logging (Pembuatan Baglog)', 'logging', '#059669', 1, 2, 14),
	(68, 'Sterilisasi', 'sterilization', '#d97706', 1, 3, 14),
	(69, 'Inokulasi', 'inoculation', '#7c3aed', 1, 4, 14),
	(70, 'Semua Fase', 'all', '#6b7280', 1, 5, 14),
	(71, 'Mixing', 'mixing', '#2563eb', 1, 1, 15),
	(72, 'Logging (Pembuatan Baglog)', 'logging', '#059669', 1, 2, 15),
	(73, 'Sterilisasi', 'sterilization', '#d97706', 1, 3, 15),
	(74, 'Inokulasi', 'inoculation', '#7c3aed', 1, 4, 15),
	(75, 'Semua Fase', 'all', '#6b7280', 1, 5, 15),
	(76, 'Mixing', 'mixing', '#2563eb', 1, 1, 16),
	(77, 'Logging (Pembuatan Baglog)', 'logging', '#059669', 1, 2, 16),
	(78, 'Sterilisasi', 'sterilization', '#d97706', 1, 3, 16),
	(79, 'Inokulasi', 'inoculation', '#7c3aed', 1, 4, 16),
	(80, 'Semua Fase', 'all', '#6b7280', 1, 5, 16),
	(81, 'Mixing', 'mixing', '#2563eb', 1, 1, 17),
	(82, 'Logging (Pembuatan Baglog)', 'logging', '#059669', 1, 2, 17),
	(83, 'Sterilisasi', 'sterilization', '#d97706', 1, 3, 17),
	(84, 'Inokulasi', 'inoculation', '#7c3aed', 1, 4, 17),
	(85, 'Semua Fase', 'all', '#6b7280', 1, 5, 17),
	(86, 'Mixing', 'mixing', '#2563eb', 1, 1, 18),
	(87, 'Logging (Pembuatan Baglog)', 'logging', '#059669', 1, 2, 18),
	(88, 'Sterilisasi', 'sterilization', '#d97706', 1, 3, 18),
	(89, 'Inokulasi', 'inoculation', '#7c3aed', 1, 4, 18),
	(90, 'Semua Fase', 'all', '#6b7280', 1, 5, 18),
	(91, 'Mixing', 'mixing', '#2563eb', 1, 1, 19),
	(92, 'Logging (Pembuatan Baglog)', 'logging', '#059669', 1, 2, 19),
	(93, 'Sterilisasi', 'sterilization', '#d97706', 1, 3, 19),
	(94, 'Inokulasi', 'inoculation', '#7c3aed', 1, 4, 19),
	(95, 'Semua Fase', 'all', '#6b7280', 1, 5, 19),
	(96, 'Mixing', 'mixing', '#2563eb', 1, 1, 20),
	(97, 'Logging (Pembuatan Baglog)', 'logging', '#059669', 1, 2, 20),
	(98, 'Sterilisasi', 'sterilization', '#d97706', 1, 3, 20),
	(99, 'Inokulasi', 'inoculation', '#7c3aed', 1, 4, 20),
	(100, 'Semua Fase', 'all', '#6b7280', 1, 5, 20),
	(101, 'Mixing', 'mixing', '#2563eb', 1, 1, 21),
	(102, 'Logging (Pembuatan Baglog)', 'logging', '#059669', 1, 2, 21),
	(103, 'Sterilisasi', 'sterilization', '#d97706', 1, 3, 21),
	(104, 'Inokulasi', 'inoculation', '#7c3aed', 1, 4, 21),
	(105, 'Semua Fase', 'all', '#6b7280', 1, 5, 21),
	(106, 'Mixing', 'mixing', '#2563eb', 1, 1, 22),
	(107, 'Logging (Pembuatan Baglog)', 'logging', '#059669', 1, 2, 22),
	(108, 'Sterilisasi', 'sterilization', '#d97706', 1, 3, 22),
	(109, 'Inokulasi', 'inoculation', '#7c3aed', 1, 4, 22),
	(110, 'Semua Fase', 'all', '#6b7280', 1, 5, 22),
	(111, 'Mixing', 'mixing', '#2563eb', 1, 1, 23),
	(112, 'Logging (Pembuatan Baglog)', 'logging', '#059669', 1, 2, 23),
	(113, 'Sterilisasi', 'sterilization', '#d97706', 1, 3, 23),
	(114, 'Inokulasi', 'inoculation', '#7c3aed', 1, 4, 23),
	(115, 'Semua Fase', 'all', '#6b7280', 1, 5, 23),
	(116, 'Mixing', 'mixing', '#2563eb', 1, 1, 24),
	(117, 'Logging (Pembuatan Baglog)', 'logging', '#059669', 1, 2, 24),
	(118, 'Sterilisasi', 'sterilization', '#d97706', 1, 3, 24),
	(119, 'Inokulasi', 'inoculation', '#7c3aed', 1, 4, 24),
	(120, 'Semua Fase', 'all', '#6b7280', 1, 5, 24),
	(121, 'Mixing', 'mixing', '#2563eb', 1, 1, 25),
	(122, 'Logging (Pembuatan Baglog)', 'logging', '#059669', 1, 2, 25),
	(123, 'Sterilisasi', 'sterilization', '#d97706', 1, 3, 25),
	(124, 'Inokulasi', 'inoculation', '#7c3aed', 1, 4, 25),
	(125, 'Semua Fase', 'all', '#6b7280', 1, 5, 25),
	(126, 'Mixing', 'mixing', '#2563eb', 1, 1, 26),
	(127, 'Logging (Pembuatan Baglog)', 'logging', '#059669', 1, 2, 26),
	(128, 'Sterilisasi', 'sterilization', '#d97706', 1, 3, 26),
	(129, 'Inokulasi', 'inoculation', '#7c3aed', 1, 4, 26),
	(130, 'Semua Fase', 'all', '#6b7280', 1, 5, 26),
	(131, 'Mixing', 'mixing', '#2563eb', 1, 1, 27),
	(132, 'Logging (Pembuatan Baglog)', 'logging', '#059669', 1, 2, 27),
	(133, 'Sterilisasi', 'sterilization', '#d97706', 1, 3, 27),
	(134, 'Inokulasi', 'inoculation', '#7c3aed', 1, 4, 27),
	(135, 'Semua Fase', 'all', '#6b7280', 1, 5, 27),
	(136, 'Mixing', 'mixing', '#2563eb', 1, 1, 28),
	(137, 'Logging (Pembuatan Baglog)', 'logging', '#059669', 1, 2, 28),
	(138, 'Sterilisasi', 'sterilization', '#d97706', 1, 3, 28),
	(139, 'Inokulasi', 'inoculation', '#7c3aed', 1, 4, 28),
	(140, 'Semua Fase', 'all', '#6b7280', 1, 5, 28),
	(141, 'Transfer Baglog', 'tb', '#2563eb', 1, 7, 1),
	(142, 'Fruiting', 'fruiting', '#b45309', 1, 8, 1),
	(143, 'Fruiting', 'fruiting', '#b45309', 1, 6, 2),
	(144, 'Fruiting', 'fruiting', '#b45309', 1, 6, 3),
	(145, 'Fruiting', 'fruiting', '#b45309', 1, 6, 4),
	(146, 'Fruiting', 'fruiting', '#b45309', 1, 6, 5),
	(147, 'Fruiting', 'fruiting', '#b45309', 1, 6, 6),
	(148, 'Fruiting', 'fruiting', '#b45309', 1, 6, 7),
	(149, 'Fruiting', 'fruiting', '#b45309', 1, 6, 8),
	(150, 'Fruiting', 'fruiting', '#b45309', 1, 6, 9),
	(151, 'Fruiting', 'fruiting', '#b45309', 1, 6, 10),
	(152, 'Fruiting', 'fruiting', '#b45309', 1, 6, 11),
	(153, 'Fruiting', 'fruiting', '#b45309', 1, 6, 12),
	(154, 'Fruiting', 'fruiting', '#b45309', 1, 6, 13),
	(155, 'Fruiting', 'fruiting', '#b45309', 1, 6, 14),
	(156, 'Fruiting', 'fruiting', '#b45309', 1, 6, 15),
	(157, 'Fruiting', 'fruiting', '#b45309', 1, 6, 16),
	(158, 'Fruiting', 'fruiting', '#b45309', 1, 6, 17),
	(159, 'Fruiting', 'fruiting', '#b45309', 1, 6, 18),
	(160, 'Fruiting', 'fruiting', '#b45309', 1, 6, 19),
	(161, 'Fruiting', 'fruiting', '#b45309', 1, 6, 20),
	(162, 'Fruiting', 'fruiting', '#b45309', 1, 6, 21),
	(163, 'Fruiting', 'fruiting', '#b45309', 1, 6, 22),
	(164, 'Fruiting', 'fruiting', '#b45309', 1, 6, 23),
	(165, 'Fruiting', 'fruiting', '#b45309', 1, 6, 24),
	(166, 'Fruiting', 'fruiting', '#b45309', 1, 6, 25),
	(167, 'Fruiting', 'fruiting', '#b45309', 1, 6, 26),
	(168, 'Fruiting', 'fruiting', '#b45309', 1, 6, 27),
	(169, 'Fruiting', 'fruiting', '#b45309', 1, 6, 28),
	(170, 'Fruiting', 'fruiting', '#b45309', 1, 1, 33),
	(171, 'Fruiting', 'fruiting', '#b45309', 1, 1, 34),
	(172, 'Fruiting', 'fruiting', '#b45309', 1, 1, 35),
	(173, 'Fruiting', 'fruiting', '#b45309', 1, 1, 36),
	(174, 'Fruiting', 'fruiting', '#b45309', 1, 1, 37);

-- Dumping structure for table db.produksi_recipe
CREATE TABLE IF NOT EXISTS "produksi_recipe" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "name" varchar(120) NOT NULL, "is_active" bool NOT NULL, "created_at" datetime NOT NULL, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, "variety_id" bigint NULL REFERENCES "produksi_variety" ("id") DEFERRABLE INITIALLY DEFERRED, "standard_baglog_count" integer unsigned NOT NULL CHECK ("standard_baglog_count" >= 0), CONSTRAINT "recipe_unique_name_variety" UNIQUE ("tenant_id", "name", "variety_id"), CONSTRAINT "recipe_positive_standard_baglog_count" CHECK ("standard_baglog_count" > 0));
;
CREATE INDEX "produksi_recipe_tenant_id_1d534f15" ON "produksi_recipe" ("tenant_id");
CREATE INDEX "produksi_recipe_variety_id_6ed643e8" ON "produksi_recipe" ("variety_id");

-- Dumping data for table db.produksi_recipe: 1 rows
INSERT INTO "produksi_recipe" ("id", "name", "is_active", "created_at", "tenant_id", "variety_id", "standard_baglog_count") VALUES
	(3, 'Resep Asep', 1, '2026-11-13 03:34:50.532990', 1, 1, 30);

-- Dumping structure for table db.produksi_recipeline
CREATE TABLE IF NOT EXISTS "produksi_recipeline" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "quantity_per_baglog" decimal NOT NULL, "material_id" bigint NOT NULL REFERENCES "produksi_material" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, "version_id" bigint NOT NULL REFERENCES "produksi_recipeversion" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "recipe_line_unique_material" UNIQUE ("version_id", "material_id"), CONSTRAINT "recipe_line_positive_quantity" CHECK ("quantity_per_baglog" > '0'));
;
CREATE INDEX "produksi_recipeline_material_id_791d0d39" ON "produksi_recipeline" ("material_id");
CREATE INDEX "produksi_recipeline_tenant_id_9fd6f042" ON "produksi_recipeline" ("tenant_id");
CREATE INDEX "produksi_recipeline_version_id_24a6c211" ON "produksi_recipeline" ("version_id");

-- Dumping data for table db.produksi_recipeline: 10 rows
INSERT INTO "produksi_recipeline" ("id", "quantity_per_baglog", "material_id", "tenant_id", "version_id") VALUES
	(6, 1, 1, 1, 2),
	(7, 3, 2, 1, 2),
	(8, 0.005, 4, 1, 2),
	(9, 0.2, 5, 1, 2),
	(10, 0.5, 18, 1, 2),
	(11, 1, 1, 1, 3),
	(12, 3, 2, 1, 3),
	(13, 0.05, 4, 1, 3),
	(14, 0.2, 5, 1, 3),
	(15, 1.5, 18, 1, 3);

-- Dumping structure for table db.produksi_recipeversion
CREATE TABLE IF NOT EXISTS "produksi_recipeversion" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "version_number" integer unsigned NOT NULL CHECK ("version_number" >= 0), "effective_from" date NOT NULL, "note" varchar(240) NOT NULL, "created_at" datetime NOT NULL, "recipe_id" bigint NOT NULL REFERENCES "produksi_recipe" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, "standard_material_id" bigint NULL REFERENCES "produksi_material" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "recipe_version_unique_number" UNIQUE ("recipe_id", "version_number"), CONSTRAINT "recipe_version_positive_number" CHECK ("version_number" > 0));
;
CREATE INDEX "produksi_recipeversion_recipe_id_8fe56d31" ON "produksi_recipeversion" ("recipe_id");
CREATE INDEX "produksi_recipeversion_tenant_id_9a148233" ON "produksi_recipeversion" ("tenant_id");
CREATE INDEX "produksi_recipeversion_standard_material_id_b476d578" ON "produksi_recipeversion" ("standard_material_id");

-- Dumping data for table db.produksi_recipeversion: 2 rows
INSERT INTO "produksi_recipeversion" ("id", "version_number", "effective_from", "note", "created_at", "recipe_id", "tenant_id", "standard_material_id") VALUES
	(2, 1, '2026-11-13', 'Versi 1', '2026-11-13 03:34:50.549997', 3, 1, 1),
	(3, 2, '2026-11-13', 'Versi 2', '2026-11-16 08:50:28.791716', 3, 1, 1);

-- Dumping structure for table db.produksi_rolepermission
CREATE TABLE IF NOT EXISTS "produksi_rolepermission" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "codename" varchar(100) NOT NULL, "name" varchar(200) NOT NULL, "role_id" bigint NOT NULL REFERENCES "produksi_userrole" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "role_permission_unique" UNIQUE ("role_id", "codename"));
;
CREATE INDEX "produksi_rolepermission_role_id_d023e0e8" ON "produksi_rolepermission" ("role_id");

-- Dumping data for table db.produksi_rolepermission: 0 rows

-- Dumping structure for table db.produksi_sale
CREATE TABLE IF NOT EXISTS "produksi_sale" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "sale_date" date NOT NULL, "reference" varchar(80) NOT NULL, "status" varchar(10) NOT NULL, "notes" varchar(240) NOT NULL, "created_at" datetime NOT NULL, "buyer_id" bigint NOT NULL REFERENCES "produksi_buyer" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED);
CREATE INDEX "produksi_sale_buyer_id_ffede5b3" ON "produksi_sale" ("buyer_id");
CREATE INDEX "produksi_sale_tenant_id_86d7c48f" ON "produksi_sale" ("tenant_id");
CREATE INDEX "sale_date_idx" ON "produksi_sale" ("tenant_id", "sale_date");

-- Dumping data for table db.produksi_sale: 5 rows
INSERT INTO "produksi_sale" ("id", "sale_date", "reference", "status", "notes", "created_at", "buyer_id", "tenant_id") VALUES
	(1, '2026-11-11', 'INV-001', 'draft', 'Test', '2026-11-11 05:22:56.810245', 5, 13),
	(2, '2026-11-11', 'INV-001', 'draft', 'Test', '2026-11-11 05:23:33.203119', 6, 14),
	(3, '2026-11-11', 'INV-001', 'draft', 'Test', '2026-11-11 05:23:48.104193', 7, 15),
	(4, '2026-11-11', 'INV-001', 'posted', 'Test', '2026-11-11 05:24:00.645240', 8, 16),
	(5, '2026-11-11', 'INV-001', 'posted', 'Test', '2026-11-11 05:55:22.331456', 9, 17);

-- Dumping structure for table db.produksi_saleline
CREATE TABLE IF NOT EXISTS "produksi_saleline" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "quantity_kg" decimal NOT NULL, "price_per_kg" decimal NOT NULL, "line_total" decimal NOT NULL, "harvest_id" bigint NOT NULL REFERENCES "produksi_harvest" ("id") DEFERRABLE INITIALLY DEFERRED, "sale_id" bigint NOT NULL REFERENCES "produksi_sale" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "sale_line_valid" CHECK (("quantity_kg" > '0' AND "price_per_kg" >= '0' AND "line_total" >= '0')));
CREATE INDEX "produksi_saleline_harvest_id_c684860c" ON "produksi_saleline" ("harvest_id");
CREATE INDEX "produksi_saleline_sale_id_1768000b" ON "produksi_saleline" ("sale_id");
CREATE INDEX "produksi_saleline_tenant_id_272f11b1" ON "produksi_saleline" ("tenant_id");

-- Dumping data for table db.produksi_saleline: 4 rows
INSERT INTO "produksi_saleline" ("id", "quantity_kg", "price_per_kg", "line_total", "harvest_id", "sale_id", "tenant_id") VALUES
	(1, 5000, 25000, 125000000, 2, 2, 14),
	(2, 5000, 25000, 125000000, 3, 3, 15),
	(3, 5000, 25000, 125000000, 4, 4, 16),
	(4, 5000, 25000, 125000000, 5, 5, 17);

-- Dumping structure for table db.produksi_seedlot
CREATE TABLE IF NOT EXISTS "produksi_seedlot" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "code" varchar(40) NOT NULL, "generation" varchar(2) NOT NULL, "source" varchar(12) NOT NULL, "recorded_on" date NOT NULL, "quantity" integer unsigned NOT NULL CHECK ("quantity" >= 0), "reject" integer unsigned NOT NULL CHECK ("reject" >= 0), "qty_out" integer unsigned NOT NULL CHECK ("qty_out" >= 0), "total_cost" decimal NOT NULL, "unit_cost" decimal NOT NULL, "supplier_name" varchar(120) NOT NULL, "purchase_reference" varchar(100) NOT NULL, "note" varchar(240) NOT NULL, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, "parent_lot_id" bigint NULL REFERENCES "produksi_seedlot" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "seed_lot_unique_code" UNIQUE ("tenant_id", "code"), CONSTRAINT "seed_lot_valid_quantities_costs" CHECK (("quantity" >= 0 AND "reject" >= 0 AND "qty_out" = ("quantity" - "reject") AND "total_cost" >= '0' AND "unit_cost" >= '0')), CONSTRAINT "seed_lot_source_matches_generation" CHECK ((("generation" = 'F0' AND "parent_lot_id" IS NULL AND "source" = 'recorded') OR ("generation" = 'F1' AND "parent_lot_id" IS NULL AND "source" = 'purchased') OR ("generation" = 'F1' AND "parent_lot_id" IS NOT NULL AND "source" = 'produced') OR ("generation" = 'F2' AND "parent_lot_id" IS NULL AND "source" = 'purchased') OR ("generation" = 'F2' AND "parent_lot_id" IS NOT NULL AND "source" = 'produced'))));
;
CREATE INDEX "produksi_seedlot_tenant_id_89d710c3" ON "produksi_seedlot" ("tenant_id");
CREATE INDEX "produksi_seedlot_parent_lot_id_5ba6d951" ON "produksi_seedlot" ("parent_lot_id");

-- Dumping data for table db.produksi_seedlot: 0 rows

-- Dumping structure for table db.produksi_seedmovement
CREATE TABLE IF NOT EXISTS "produksi_seedmovement" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "kind" varchar(16) NOT NULL, "quantity_delta" decimal NOT NULL, "unit_cost" decimal NOT NULL, "value_delta" decimal NOT NULL, "recorded_at" datetime NOT NULL, "note" varchar(240) NOT NULL, "inoculation_batch_id" bigint NULL REFERENCES "produksi_inoculationbatch" ("id") DEFERRABLE INITIALLY DEFERRED, "seed_lot_id" bigint NOT NULL REFERENCES "produksi_seedlot" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "seed_movement_sign_matches_kind" CHECK ((("kind" IN ('opening', 'purchase', 'production', 'adjustment_in') AND "quantity_delta" > '0' AND "value_delta" >= '0') OR ("kind" IN ('consumption', 'adjustment_out') AND "quantity_delta" < '0' AND "value_delta" <= '0'))), CONSTRAINT "seed_movement_nonnegative_unit_cost" CHECK ("unit_cost" >= '0'));
CREATE INDEX "seed_movement_order_idx" ON "produksi_seedmovement" ("tenant_id", "seed_lot_id", "id");
CREATE INDEX "produksi_seedmovement_inoculation_batch_id_e9cb37de" ON "produksi_seedmovement" ("inoculation_batch_id");
CREATE INDEX "produksi_seedmovement_seed_lot_id_071dae2f" ON "produksi_seedmovement" ("seed_lot_id");
CREATE INDEX "produksi_seedmovement_tenant_id_b926c284" ON "produksi_seedmovement" ("tenant_id");

-- Dumping data for table db.produksi_seedmovement: 0 rows

-- Dumping structure for table db.produksi_seedproductionmaterial
CREATE TABLE IF NOT EXISTS "produksi_seedproductionmaterial" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "quantity" decimal NOT NULL, "unit_cost" decimal NOT NULL, "total_cost" decimal NOT NULL, "material_id" bigint NOT NULL REFERENCES "produksi_material" ("id") DEFERRABLE INITIALLY DEFERRED, "run_id" bigint NOT NULL REFERENCES "produksi_seedproductionrun" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "seed_run_unique_material" UNIQUE ("run_id", "material_id"), CONSTRAINT "seed_run_material_valid_cost" CHECK (("quantity" > '0' AND "unit_cost" >= '0' AND "total_cost" >= '0')));
;
CREATE INDEX "produksi_seedproductionmaterial_material_id_95ed7910" ON "produksi_seedproductionmaterial" ("material_id");
CREATE INDEX "produksi_seedproductionmaterial_run_id_aa74c140" ON "produksi_seedproductionmaterial" ("run_id");
CREATE INDEX "produksi_seedproductionmaterial_tenant_id_c28ff7a5" ON "produksi_seedproductionmaterial" ("tenant_id");

-- Dumping data for table db.produksi_seedproductionmaterial: 0 rows

-- Dumping structure for table db.produksi_seedproductionrun
CREATE TABLE IF NOT EXISTS "produksi_seedproductionrun" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "code" varchar(40) NOT NULL, "production_date" date NOT NULL, "input_bottles" decimal NOT NULL, "material_cost" decimal NOT NULL, "sterilization_cost" decimal NOT NULL, "total_cost" decimal NOT NULL, "created_at" datetime NOT NULL, "output_lot_id" bigint NOT NULL UNIQUE REFERENCES "produksi_seedlot" ("id") DEFERRABLE INITIALLY DEFERRED, "source_lot_id" bigint NOT NULL REFERENCES "produksi_seedlot" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "seed_production_unique_code" UNIQUE ("tenant_id", "code"), CONSTRAINT "seed_production_valid_costs" CHECK (("input_bottles" > '0' AND "material_cost" >= '0' AND "sterilization_cost" >= '0' AND "total_cost" >= '0')));
;
;
CREATE INDEX "produksi_seedproductionrun_source_lot_id_ade4e7e2" ON "produksi_seedproductionrun" ("source_lot_id");
CREATE INDEX "produksi_seedproductionrun_tenant_id_3a202b83" ON "produksi_seedproductionrun" ("tenant_id");

-- Dumping data for table db.produksi_seedproductionrun: 0 rows

-- Dumping structure for table db.produksi_sensor
CREATE TABLE IF NOT EXISTS "produksi_sensor" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "name" varchar(100) NOT NULL, "sensor_type" varchar(20) NOT NULL, "unit" varchar(20) NOT NULL, "min_threshold" decimal NULL, "max_threshold" decimal NULL, "is_active" bool NOT NULL, "device_id" bigint NOT NULL REFERENCES "produksi_device" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "sensor_unique_name_per_device_per_tenant" UNIQUE ("tenant_id", "device_id", "name"));
;
CREATE INDEX "produksi_sensor_device_id_77dc9495" ON "produksi_sensor" ("device_id");
CREATE INDEX "produksi_sensor_tenant_id_838e5745" ON "produksi_sensor" ("tenant_id");

-- Dumping data for table db.produksi_sensor: 6 rows
INSERT INTO "produksi_sensor" ("id", "name", "sensor_type", "unit", "min_threshold", "max_threshold", "is_active", "device_id", "tenant_id") VALUES
	(1, 'Suhu', 'temperature', '°C', NULL, NULL, 1, 1, 1),
	(2, 'Kelembaban', 'humidity', '%', NULL, NULL, 1, 1, 1),
	(3, 'CO2', 'co2', 'ppm', NULL, NULL, 1, 1, 1),
	(4, 'Cahaya', 'light', 'lux', NULL, NULL, 1, 1, 1),
	(5, 'Kelembaban Tanah', 'soil_moisture', '%', NULL, NULL, 1, 1, 1),
	(6, 'Tinggi Air', 'water_level', 'cm', NULL, NULL, 1, 1, 1);

-- Dumping structure for table db.produksi_sensorreading
CREATE TABLE IF NOT EXISTS "produksi_sensorreading" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "value" decimal NOT NULL, "recorded_at" datetime NOT NULL, "sensor_id" bigint NOT NULL REFERENCES "produksi_sensor" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED);
CREATE INDEX "produksi_sensorreading_sensor_id_ab4b58e6" ON "produksi_sensorreading" ("sensor_id");
CREATE INDEX "produksi_sensorreading_tenant_id_c16c1b76" ON "produksi_sensorreading" ("tenant_id");
CREATE INDEX "produksi_se_tenant__3001f6_idx" ON "produksi_sensorreading" ("tenant_id", "sensor_id", "recorded_at" DESC);

-- Dumping data for table db.produksi_sensorreading: 30 rows
INSERT INTO "produksi_sensorreading" ("id", "value", "recorded_at", "sensor_id", "tenant_id") VALUES
	(1, 27, '2026-11-16 06:55:27.287205', 1, 1),
	(2, 26.3, '2026-11-16 06:55:27.288218', 1, 1),
	(3, 27.8, '2026-11-16 06:55:27.288759', 1, 1),
	(4, 25.4, '2026-11-16 06:55:27.289236', 1, 1),
	(5, 28, '2026-11-16 06:55:27.289719', 1, 1),
	(6, 78.1, '2026-11-16 06:55:27.290172', 2, 1),
	(7, 71.3, '2026-11-16 06:55:27.290648', 2, 1),
	(8, 75.6, '2026-11-16 06:55:27.291121', 2, 1),
	(9, 84.4, '2026-11-16 06:55:27.291950', 2, 1),
	(10, 70.5, '2026-11-16 06:55:27.292847', 2, 1),
	(11, 868, '2026-11-16 06:55:27.293422', 3, 1),
	(12, 602, '2026-11-16 06:55:27.293888', 3, 1),
	(13, 658, '2026-11-16 06:55:27.294331', 3, 1),
	(14, 692, '2026-11-16 06:55:27.294795', 3, 1),
	(15, 884, '2026-11-16 06:55:27.295244', 3, 1),
	(16, 497, '2026-11-16 06:55:27.295815', 4, 1),
	(17, 380, '2026-11-16 06:55:27.296252', 4, 1),
	(18, 698, '2026-11-16 06:55:27.296734', 4, 1),
	(19, 226, '2026-11-16 06:55:27.297271', 4, 1),
	(20, 393, '2026-11-16 06:55:27.297825', 4, 1),
	(21, 63.2, '2026-11-16 06:55:27.298506', 5, 1),
	(22, 61.5, '2026-11-16 06:55:27.298986', 5, 1),
	(23, 67.5, '2026-11-16 06:55:27.299770', 5, 1),
	(24, 58.1, '2026-11-16 06:55:27.300716', 5, 1),
	(25, 65.1, '2026-11-16 06:55:27.301676', 5, 1),
	(26, 21.2, '2026-11-16 06:55:27.302341', 6, 1),
	(27, 29.1, '2026-11-16 06:55:27.302983', 6, 1),
	(28, 21.4, '2026-11-16 06:55:27.303571', 6, 1),
	(29, 38.8, '2026-11-16 06:55:27.304058', 6, 1),
	(30, 37.6, '2026-11-16 06:55:27.304528', 6, 1);

-- Dumping structure for table db.produksi_sterilizationinput
CREATE TABLE IF NOT EXISTS "produksi_sterilizationinput" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "qty" integer unsigned NOT NULL CHECK ("qty" >= 0), "source_lot_id" bigint NOT NULL REFERENCES "produksi_lot" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, "run_id" bigint NOT NULL REFERENCES "produksi_sterilizationrun" ("id") DEFERRABLE INITIALLY DEFERRED, "total_cost" decimal NOT NULL, "unit_cost" decimal NOT NULL, CONSTRAINT "sterilization_input_unique_lot" UNIQUE ("run_id", "source_lot_id"), CONSTRAINT "sterilization_input_positive_qty" CHECK ("qty" > 0), CONSTRAINT "sterilization_input_nonnegative_costs" CHECK (("unit_cost" >= '0' AND "total_cost" >= '0')));
;
CREATE INDEX "produksi_sterilizationinput_source_lot_id_d34b538f" ON "produksi_sterilizationinput" ("source_lot_id");
CREATE INDEX "produksi_sterilizationinput_tenant_id_c009243a" ON "produksi_sterilizationinput" ("tenant_id");
CREATE INDEX "produksi_sterilizationinput_run_id_f0489f90" ON "produksi_sterilizationinput" ("run_id");

-- Dumping data for table db.produksi_sterilizationinput: 1 rows
INSERT INTO "produksi_sterilizationinput" ("id", "qty", "source_lot_id", "tenant_id", "run_id", "total_cost", "unit_cost") VALUES
	(1, 130, 1, 1, 1, 100018.75, 769.375);

-- Dumping structure for table db.produksi_sterilizationrun
CREATE TABLE IF NOT EXISTS "produksi_sterilizationrun" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "code" varchar(30) NOT NULL, "run_date" date NOT NULL, "capacity" integer unsigned NOT NULL CHECK ("capacity" >= 0), "qty_in" integer unsigned NOT NULL CHECK ("qty_in" >= 0), "reject" integer unsigned NOT NULL CHECK ("reject" >= 0), "qty_out" integer unsigned NOT NULL CHECK ("qty_out" >= 0), "cost_per_baglog" decimal NOT NULL, "total_cost" decimal NOT NULL, "unit_cost" decimal NOT NULL, "loss_memo" decimal NOT NULL, "output_lot_id" bigint NOT NULL UNIQUE REFERENCES "produksi_lot" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, "material_overhead" decimal NOT NULL, CONSTRAINT "sterilization_unique_code" UNIQUE ("tenant_id", "code"), CONSTRAINT "sterilization_valid_totals" CHECK (("capacity" > 0 AND "qty_in" > 0 AND "qty_in" <= ("capacity") AND "qty_out" > 0 AND "qty_out" = ("qty_in" - "reject") AND "cost_per_baglog" >= '0' AND "material_overhead" >= '0' AND "total_cost" >= '0' AND "unit_cost" >= '0' AND "loss_memo" >= '0')));
;
;
CREATE INDEX "produksi_sterilizationrun_tenant_id_afd1e7f2" ON "produksi_sterilizationrun" ("tenant_id");

-- Dumping data for table db.produksi_sterilizationrun: 1 rows
INSERT INTO "produksi_sterilizationrun" ("id", "code", "run_date", "capacity", "qty_in", "reject", "qty_out", "cost_per_baglog", "total_cost", "unit_cost", "loss_memo", "output_lot_id", "tenant_id", "material_overhead") VALUES
	(1, 'SR-20261112-01', '2026-11-12', 130, 130, 0, 130, 250, 106518.75, 819.375, 0, 7, 1, 0);

-- Dumping structure for table db.produksi_subscription
CREATE TABLE IF NOT EXISTS "produksi_subscription" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "status" varchar(20) NOT NULL, "started_at" datetime NOT NULL, "expires_at" datetime NULL, "auto_renew" bool NOT NULL, "plan_id" bigint NOT NULL REFERENCES "produksi_plan" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED);
CREATE INDEX "produksi_subscription_plan_id_20674baf" ON "produksi_subscription" ("plan_id");
CREATE INDEX "produksi_subscription_tenant_id_2580fc74" ON "produksi_subscription" ("tenant_id");

-- Dumping data for table db.produksi_subscription: 6 rows
INSERT INTO "produksi_subscription" ("id", "status", "started_at", "expires_at", "auto_renew", "plan_id", "tenant_id") VALUES
	(1, 'cancelled', '2026-11-12 06:14:32.543233', NULL, 0, 1, 1),
	(2, 'active', '2026-11-12 06:40:17.064127', NULL, 0, 2, 1),
	(3, 'active', '2026-11-12 06:49:33.973464', NULL, 0, 3, 33),
	(4, 'active', '2026-11-12 06:50:03.855013', NULL, 0, 4, 35),
	(5, 'active', '2026-11-12 06:50:44.681853', NULL, 0, 5, 36),
	(6, 'active', '2026-11-12 09:30:49.441638', NULL, 0, 6, 37);

-- Dumping structure for table db.produksi_supplier
CREATE TABLE IF NOT EXISTS "produksi_supplier" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "name" varchar(120) NOT NULL, "contact" varchar(160) NOT NULL, "is_active" bool NOT NULL, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "supplier_unique_name" UNIQUE ("tenant_id", "name"));
;
CREATE INDEX "produksi_supplier_tenant_id_a2654baa" ON "produksi_supplier" ("tenant_id");

-- Dumping data for table db.produksi_supplier: 0 rows

-- Dumping structure for table db.produksi_tenant
CREATE TABLE IF NOT EXISTS "produksi_tenant" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "name" varchar(120) NOT NULL, "status" varchar(10) NOT NULL, "created_at" datetime NOT NULL, "accent_color" varchar(7) NOT NULL, "address" text NOT NULL, "phone" varchar(30) NOT NULL, "logo" varchar(100) NOT NULL);

-- Dumping data for table db.produksi_tenant: 33 rows
INSERT INTO "produksi_tenant" ("id", "name", "status", "created_at", "accent_color", "address", "phone", "logo") VALUES
	(1, 'Wawan', 'approved', '2026-11-05 12:16:57.168811', '#2f6bea', '', '', ''),
	(2, 'Toko Jamur Test', 'rejected', '2026-11-11 05:19:16.839385', '#2563eb', '', '', ''),
	(3, 'Toko Jamur Test', 'rejected', '2026-11-11 05:19:28.492551', '#2563eb', '', '', ''),
	(4, 'Toko Test f74c83e0', 'rejected', '2026-11-11 05:19:44.427379', '#2563eb', '', '', ''),
	(5, 'Toko Test 10fafc7a', 'rejected', '2026-11-11 05:20:02.841955', '#2563eb', '', '', ''),
	(6, 'Toko Test c137d381', 'rejected', '2026-11-11 05:20:37.646240', '#2563eb', '', '', ''),
	(7, 'Toko Test 5d982402', 'rejected', '2026-11-11 05:20:57.034756', '#2563eb', '', '', ''),
	(8, 'Toko Test 53631f06', 'rejected', '2026-11-11 05:21:42.562878', '#2563eb', '', '', ''),
	(9, 'Toko Test bde01832', 'rejected', '2026-11-11 05:22:03.666511', '#2563eb', '', '', ''),
	(10, 'Toko Test 799acf2f', 'rejected', '2026-11-11 05:22:15.325133', '#2563eb', '', '', ''),
	(11, 'Toko Test dd7570a5', 'rejected', '2026-11-11 05:22:29.179915', '#2563eb', '', '', ''),
	(12, 'Toko Test 9575a831', 'rejected', '2026-11-11 05:22:40.592114', '#2563eb', '', '', ''),
	(13, 'Toko Test 723b737d', 'rejected', '2026-11-11 05:22:54.666967', '#2563eb', '', '', ''),
	(14, 'Toko Test e1d5c3f8', 'rejected', '2026-11-11 05:23:31.137853', '#2563eb', '', '', ''),
	(15, 'Toko Test 948844cc', 'rejected', '2026-11-11 05:23:45.980319', '#2563eb', '', '', ''),
	(16, 'Toko Test 3704a999', 'rejected', '2026-11-11 05:23:58.575792', '#2563eb', '', '', ''),
	(17, 'Toko Test dbe7dc68', 'rejected', '2026-11-11 05:55:20.247631', '#2563eb', '', '', ''),
	(18, 'Toko Test 3886d874', 'rejected', '2026-11-11 06:07:38.436375', '#2563eb', '', '', ''),
	(19, 'Toko Test 2fa11bf0', 'rejected', '2026-11-11 06:07:50.867005', '#2563eb', '', '', ''),
	(20, 'Toko Test dffe4026', 'rejected', '2026-11-11 06:14:32.835971', '#2563eb', '', '', ''),
	(21, 'Toko Test 16c3f52c', 'rejected', '2026-11-11 06:23:38.255198', '#2563eb', '', '', ''),
	(22, 'Toko Test e1010c32', 'rejected', '2026-11-11 06:32:46.537899', '#2563eb', '', '', ''),
	(23, 'Toko Test 83ec1742', 'rejected', '2026-11-11 06:33:04.788047', '#2563eb', '', '', ''),
	(24, 'Toko Test e0f65227', 'rejected', '2026-11-11 06:47:53.085915', '#2563eb', '', '', ''),
	(25, 'Test', 'rejected', '2026-11-11 09:54:55.495064', '#2563eb', '', '', ''),
	(26, 'Test', 'rejected', '2026-11-11 09:55:02.777487', '#2563eb', '', '', ''),
	(27, 'Test', 'rejected', '2026-11-11 09:55:30.426750', '#2563eb', '', '', ''),
	(28, 'TestForm', 'rejected', '2026-11-11 09:56:49.338620', '#2563eb', '', '', ''),
	(33, 'Test', 'rejected', '2026-11-12 06:49:33.031460', '#2563eb', '', '', ''),
	(34, 'Test', 'rejected', '2026-11-12 06:49:46.160298', '#2563eb', '', '', ''),
	(35, 'Test Quota', 'rejected', '2026-11-12 06:50:02.922475', '#2563eb', '', '', ''),
	(36, 'Test Quota 2', 'rejected', '2026-11-12 06:50:43.718630', '#2563eb', '', '', ''),
	(37, 'Aji', 'approved', '2026-11-12 08:47:08.281789', '#2563eb', '', '', '');

-- Dumping structure for table db.produksi_user
CREATE TABLE IF NOT EXISTS "produksi_user" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "password" varchar(128) NOT NULL, "last_login" datetime NULL, "is_superuser" bool NOT NULL, "username" varchar(150) NOT NULL UNIQUE, "first_name" varchar(150) NOT NULL, "last_name" varchar(150) NOT NULL, "email" varchar(254) NOT NULL, "is_staff" bool NOT NULL, "is_active" bool NOT NULL, "date_joined" datetime NOT NULL, "tenant_id" bigint NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, "is_tenant_admin" bool NOT NULL, "is_email_verified" bool NOT NULL, "theme" varchar(6) NOT NULL, CONSTRAINT "user_superuser_xor_tenant" CHECK ((("is_superuser" = 1 AND "tenant_id" IS NULL) OR ("is_superuser" = 0 AND "tenant_id" IS NOT NULL))));
;
CREATE INDEX "produksi_user_tenant_id_1bbf96cf" ON "produksi_user" ("tenant_id");

-- Dumping data for table db.produksi_user: 7 rows
INSERT INTO "produksi_user" ("id", "password", "last_login", "is_superuser", "username", "first_name", "last_name", "email", "is_staff", "is_active", "date_joined", "tenant_id", "is_tenant_admin", "is_email_verified", "theme") VALUES
	(1, 'pbkdf2_sha256$1500000$qXovMm9LgzQ5hEQrAjMtQU$AMDaUGho5zIHXrU9EYOSx2FZdjbwnRrGZGid33X1G3Q=', '2026-11-13 03:26:59.359943', 1, 'admin', '', '', 'admin@jamur.lokal', 1, 1, '2026-11-05 12:02:18.496817', NULL, 0, 0, 'dark'),
	(2, 'pbkdf2_sha256$1500000$yMWKccWPTl18EVfEzkO0Ny$bpP8zzGHxHimz1EtahgeCrKXDflqtkI0ZXTwic2L2fM=', '2026-11-14 11:12:56.218978', 0, 'wawan@jamur.lokal', '', '', 'wawan@jamur.lokal', 0, 1, '2026-11-05 12:16:57.170697', 1, 1, 0, 'dark'),
	(28, 'pbkdf2_sha256$1500000$OnYO9gw8jnGYrbG5OFwdK5$d0nBPz97jPZLmBAbKUbl5SpBaDuxJjyiOjT0v4NDo8o=', NULL, 0, 'test@x.id', '', '', 'test@x.id', 0, 1, '2026-11-12 06:49:33.035131', 33, 1, 0, 'dark'),
	(29, 'pbkdf2_sha256$1500000$PRccghiCNCgTGXuTQ9DyDA$3ZvrkjyTfVrg+ft7ZKASLTmv6cSrqqe0oWcp9TPNu+M=', '2026-11-12 06:50:03.898658', 0, 'quota@x.id', '', '', 'quota@x.id', 0, 1, '2026-11-12 06:50:02.925966', 35, 1, 0, 'dark'),
	(30, 'pbkdf2_sha256$1500000$dhrlXc143lcI44PaDV0QuP$bQEJOU4FY9YPfabCWJxXSqJkUvE/wVasKo8fbmcZ65g=', '2026-11-12 06:50:44.713010', 0, 'quota2@x.id', '', '', 'quota2@x.id', 0, 1, '2026-11-12 06:50:43.722144', 36, 1, 0, 'dark'),
	(31, 'pbkdf2_sha256$1500000$EZAF6PwOiOI8dX7p10pEFz$D0RlvFGhQQFqhaDq7mCKR9Vh0+Md4TRmVWkc/EOIqZ4=', '2026-11-12 09:31:06.721531', 0, 'aji@jamur.lokal', '', '', 'aji@jamur.lokal', 0, 1, '2026-11-12 08:47:08.324779', 37, 1, 0, 'dark'),
	(32, 'pbkdf2_sha256$1500000$vfVmfVZMxl5dllbW7u93Fk$JjP1Hdij9flPMHo6H3QbNgJAFuiPUCUm7FhVX2p5Puw=', '2026-11-14 12:34:05.479746', 1, 'admin@platform.id', '', '', 'admin@platform.id', 1, 1, '2026-11-14 12:33:30.597190', NULL, 0, 0, 'dark');

-- Dumping structure for table db.produksi_user_groups
CREATE TABLE IF NOT EXISTS "produksi_user_groups" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "user_id" bigint NOT NULL REFERENCES "produksi_user" ("id") DEFERRABLE INITIALLY DEFERRED, "group_id" integer NOT NULL REFERENCES "auth_group" ("id") DEFERRABLE INITIALLY DEFERRED);
CREATE UNIQUE INDEX "produksi_user_groups_user_id_group_id_b118b671_uniq" ON "produksi_user_groups" ("user_id", "group_id");
CREATE INDEX "produksi_user_groups_user_id_4b9d111d" ON "produksi_user_groups" ("user_id");
CREATE INDEX "produksi_user_groups_group_id_69c9cb9f" ON "produksi_user_groups" ("group_id");

-- Dumping data for table db.produksi_user_groups: 0 rows

-- Dumping structure for table db.produksi_userrole
CREATE TABLE IF NOT EXISTS "produksi_userrole" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "role" varchar(20) NOT NULL, "group_id" integer NULL REFERENCES "auth_group" ("id") DEFERRABLE INITIALLY DEFERRED, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, "user_id" bigint NOT NULL REFERENCES "produksi_user" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "user_role_unique_per_tenant" UNIQUE ("tenant_id", "user_id"));
;
CREATE INDEX "produksi_userrole_group_id_e8c73ff9" ON "produksi_userrole" ("group_id");
CREATE INDEX "produksi_userrole_tenant_id_ccdd2f66" ON "produksi_userrole" ("tenant_id");
CREATE INDEX "produksi_userrole_user_id_4bb3b4cc" ON "produksi_userrole" ("user_id");

-- Dumping data for table db.produksi_userrole: 0 rows

-- Dumping structure for table db.produksi_user_user_permissions
CREATE TABLE IF NOT EXISTS "produksi_user_user_permissions" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "user_id" bigint NOT NULL REFERENCES "produksi_user" ("id") DEFERRABLE INITIALLY DEFERRED, "permission_id" integer NOT NULL REFERENCES "auth_permission" ("id") DEFERRABLE INITIALLY DEFERRED);
CREATE UNIQUE INDEX "produksi_user_user_permissions_user_id_permission_id_672c9aed_uniq" ON "produksi_user_user_permissions" ("user_id", "permission_id");
CREATE INDEX "produksi_user_user_permissions_user_id_82e136e0" ON "produksi_user_user_permissions" ("user_id");
CREATE INDEX "produksi_user_user_permissions_permission_id_97a50b0d" ON "produksi_user_user_permissions" ("permission_id");

-- Dumping data for table db.produksi_user_user_permissions: 0 rows

-- Dumping structure for table db.produksi_variety
CREATE TABLE IF NOT EXISTS "produksi_variety" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "name" varchar(80) NOT NULL, "code" varchar(12) NOT NULL, "incubation_days" smallint unsigned NULL CHECK ("incubation_days" >= 0), "is_active" bool NOT NULL, "tenant_id" bigint NOT NULL REFERENCES "produksi_tenant" ("id") DEFERRABLE INITIALLY DEFERRED, CONSTRAINT "variety_unique_name" UNIQUE ("tenant_id", "name"), CONSTRAINT "variety_unique_code" UNIQUE ("tenant_id", "code"), CONSTRAINT "variety_positive_incubation_days" CHECK (("incubation_days" IS NULL OR "incubation_days" > 0)));
;
;
CREATE INDEX "produksi_variety_tenant_id_085889f2" ON "produksi_variety" ("tenant_id");

-- Dumping data for table db.produksi_variety: 11 rows
INSERT INTO "produksi_variety" ("id", "name", "code", "incubation_days", "is_active", "tenant_id") VALUES
	(1, 'Tiram Putih', 'TP', '30', 1, 1),
	(2, 'Tiram Coklat', 'TC', '30', 1, 1),
	(3, 'Jamur Kuping', 'JK', NULL, 0, 1),
	(4, 'Tiram Putih', 'TP723B', '30', 1, 13),
	(5, 'Tiram Putih', 'TPE1D5', '30', 1, 14),
	(6, 'Tiram Putih', 'TP9488', '30', 1, 15),
	(7, 'Tiram Putih', 'TP3704', '30', 1, 16),
	(8, 'Tiram Putih', 'TPDBE7', '30', 1, 17),
	(9, 'Tiram Putih', 'TP', NULL, 1, 37),
	(10, 'Tiram Coklat', 'TC', NULL, 1, 37),
	(11, 'Jamur Kuping', 'JK', NULL, 1, 37);

/*!40103 SET TIME_ZONE=IFNULL(@OLD_TIME_ZONE, 'system') */;
/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IFNULL(@OLD_FOREIGN_KEY_CHECKS, 1) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40111 SET SQL_NOTES=IFNULL(@OLD_SQL_NOTES, 1) */;
