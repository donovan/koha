#!/usr/bin/perl


# Database Updater
# This script checks for required updates to the database.

# Part of the Koha Library Software www.koha.org
# Licensed under the GPL.

# Bugs/ToDo:
# - Would also be a good idea to offer to do a backup at this time...

# NOTE:  If you do something more than once in here, make it table driven.

# NOTE: Please keep the version in kohaversion.pl up-to-date!

use strict;
# use warnings;

# CPAN modules
use DBI;
use Getopt::Long;
# Koha modules
use C4::Context;
use C4::Installer;

use MARC::Record;
use MARC::File::XML ( BinaryEncoding => 'utf8' );
 
# FIXME - The user might be installing a new database, so can't rely
# on /etc/koha.conf anyway.

my $debug = 0;

my (
    $sth, $sti,
    $query,
    %existingtables,    # tables already in database
    %types,
    $table,
    $column,
    $type, $null, $key, $default, $extra,
    $prefitem,          # preference item in systempreferences table
);

my $silent;
GetOptions(
    's' =>\$silent
    );
my $dbh = C4::Context->dbh;
$|=1; # flushes output

=item

    Deal with virtualshelves

=cut

my $DBversion = '3.00.01.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    print "Upgrade to $DBversion done (start of 3.0.1)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.00.01.001';
if ( C4::Context->preference('Version') < TransformToNum($DBversion) ) {
    # use statistics where available
    $dbh->do("
        ALTER TABLE statistics ADD KEY  tmp_stats (type, itemnumber, borrowernumber)
    ");
    $dbh->do("
        UPDATE issues iss
        SET issuedate = (
            SELECT max(datetime)
            FROM statistics 
            WHERE type = 'issue'
            AND itemnumber = iss.itemnumber
            AND borrowernumber = iss.borrowernumber
        )
        WHERE issuedate IS NULL;
    ");  
    $dbh->do("ALTER TABLE statistics DROP KEY tmp_stats");

    # default to last renewal date
    $dbh->do("
        UPDATE issues
        SET issuedate = lastreneweddate
        WHERE issuedate IS NULL
        and lastreneweddate IS NOT NULL
    ");

    my $num_bad_issuedates = $dbh->selectrow_array("SELECT COUNT(*) FROM issues WHERE issuedate IS NULL");
    if ($num_bad_issuedates > 0) {
        print STDERR "After the upgrade to $DBversion, there are still $num_bad_issuedates loan(s) with a NULL (blank) loan date. ",
                     "Please check the issues table in your database.";
    }
    print "Upgrade to $DBversion done (bug 2582: set null issues.issuedate to lastreneweddate)";
    SetVersion($DBversion);
}

$DBversion = "3.00.01.002";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES('AllowRenewalLimitOverride', '0', 'if ON, allows renewal limits to be overridden on the circulation screen',NULL,'YesNo')");
    print "Upgrade to $DBversion done (add new syspref)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.01.003";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
	my $search=$dbh->selectall_arrayref("select * from systempreferences where variable='dontmerge'");
	if (@$search){
		my $search=$dbh->selectall_arrayref("select * from systempreferences where variable='MergeAuthoritiesOnUpdate'");
		if (@$search){
    		$dbh->do("DELETE FROM systempreferences set variable='dontmerge'");
		}
		else {
    		$dbh->do("UPDATE systempreferences set variable='MergeAuthoritiesOnUpdate' ,value=1-value*1 WHERE variable='dontmerge'");
		}
	}
	else {
    	$dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES('MergeAuthoritiesOnUpdate', '1', 'if ON, Updating authorities will automatically updates biblios',NULL,'YesNo')");
	}
    print "Upgrade to $DBversion done (add new syspref MergeAuthoritiesOnUpdate)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.01.004";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
  if (lc(C4::Context->preference('marcflavour')) eq "unimarc"){
    $dbh->do("INSERT IGNORE INTO `marc_tag_structure` (`tagfield`, `liblibrarian`, `libopac`, `repeatable`, `mandatory`, `authorised_value`, `frameworkcode`) VALUES ('099', 'Informations locales', '', 0, 0, '', '');");
    $dbh->do("INSERT IGNORE INTO `marc_tag_structure` (`frameworkcode`,`tagfield`, `liblibrarian`, `libopac`, `repeatable`, `mandatory`, `authorised_value`) SELECT DISTINCT(frameworkcode),'099', 'Informations locales', '', 0, 0, '' from biblio_framework");
    $dbh->do(<<ENDOFSQL);
INSERT IGNORE INTO marc_subfield_structure (`tagfield`, `tagsubfield`, `liblibrarian`, `libopac`, `repeatable`, `mandatory`, `kohafield`, `tab`, `authorised_value`, `authtypecode`, `value_builder`, `isurl`, `hidden`, `seealso`, `link`, `defaultvalue`,frameworkcode )
VALUES ('099', 'c', 'date creation notice (koha)', '', 0, 0, 'biblio.datecreated', -1, '', '', '', NULL, 0, '', '', NULL, ''),
('099', 'd', 'date modification notice (koha)', '', 0, 0, 'biblio.timestamp', -1, '', '', '', NULL, 0, '', '', NULL, ''),
('995', '2', 'Perdu', '', 0, 0, 'items.itemlost', 10, '', '', '', NULL, 1, '', NULL, NULL, '');
ENDOFSQL
    $dbh->do(<<ENDOFSQL1);
INSERT IGNORE INTO marc_subfield_structure (`frameworkcode`,`tagfield`, `tagsubfield`, `liblibrarian`, `libopac`, `repeatable`, `mandatory`, `kohafield`, `tab`, `authorised_value`, `authtypecode`, `value_builder`, `isurl`, `hidden`, seealso, link, defaultvalue )
SELECT DISTINCT(frameworkcode), '099', 'c', 'date creation notice (koha)', '', 0, 0, 'biblio.datecreated', -1, '', '', '', NULL, 0, '', '', NULL from biblio_framework;
ENDOFSQL1
    $dbh->do(<<ENDOFSQL2);
INSERT IGNORE INTO marc_subfield_structure (`frameworkcode`,`tagfield`, `tagsubfield`, `liblibrarian`, `libopac`, `repeatable`, `mandatory`, `kohafield`, `tab`, `authorised_value`, `authtypecode`, `value_builder`, `isurl`, `hidden`, seealso, link, defaultvalue )
SELECT DISTINCT(frameworkcode), '099', 'd', 'date modification notice (koha)', '', 0, 0, 'biblio.timestamp', -1, '', '', '', NULL, 0, '', '', NULL from biblio_framework;
ENDOFSQL2
    $dbh->do(<<ENDOFSQL3);
INSERT IGNORE INTO marc_subfield_structure (`frameworkcode`,`tagfield`, `tagsubfield`, `liblibrarian`, `libopac`, `repeatable`, `mandatory`, `kohafield`, `tab`, `authorised_value`, `authtypecode`, `value_builder`, `isurl`, `hidden`, seealso, link, defaultvalue )
SELECT DISTINCT(frameworkcode), '995', '2', 'Perdu', '', 0, 0, 'items.itemlost', 10, '', '', '', NULL, 1, '', NULL, NULL from biblio_framework;
ENDOFSQL3
      print "Upgrade to $DBversion done (updates MARC framework structure)\n";
    }
    SetVersion ($DBversion);
}

$DBversion = "3.00.01.005";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
   $dbh->do(<<ENDOFNOTFORLOANOVERRIDE);
INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES('AllowNotForLoanOverride', '0', 'if ON, enables the librarian to choose when they want to check out a notForLoan regular item',NULL,'YesNo')
ENDOFNOTFORLOANOVERRIDE
      print "Upgrade to $DBversion done (Adding AllowNotForLoanOverride System preference)\n";
}

$DBversion = "3.00.01.005";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE issuingrules ADD COLUMN `finedays` int(11) default NULL AFTER `fine`");
    print "Upgrade to $DBversion done (Adding a field in issuingrules table)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.01.006";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE `aqbudget` CHANGE `aqbudgetid` `aqbudgetid` INT( 11 ) NOT NULL AUTO_INCREMENT");
    print "Upgrade to $DBversion done (Change the field)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.01.007";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(<<ENDOFRENEWAL);
INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES('RenewalPeriodBase', 'date_due', 'Set whether the renewal date should be counted from the date_due or from the moment the Patron asks for renewal ','date_due|now','Choice');
ENDOFRENEWAL
    print "Upgrade to $DBversion done (Change the field)\n";
    SetVersion ($DBversion);
}
$DBversion = "3.00.02.001";
#01.00.005';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("
        INSERT INTO `letter` (module, code, name, title, content)
        VALUES('reserves', 'HOLD', 'Hold Available for Pickup', 'Hold Available for Pickup at <<branches.branchname>>', 'Dear <<borrowers.firstname>> <<borrowers.surname>>,\r\n\r\nYou have a hold available for pickup as of <<reserves.waitingdate>>:\r\n\r\nTitle: <<biblio.title>>\r\nAuthor: <<biblio.author>>\r\nCopy: <<items.copynumber>>\r\nLocation: <<branches.branchname>>\r\n<<branches.branchaddress1>>\r\n<<branches.branchaddress2>>\r\n<<branches.branchaddress3>>')
    ");
    $dbh->do("INSERT INTO `message_attributes` (message_attribute_id, message_name, takes_days) values(4, 'Hold Filled', 0)");
    $dbh->do("INSERT INTO `message_transports` (message_attribute_id, message_transport_type, is_digest, letter_module, letter_code) values(4, 'sms', 0, 'reserves', 'HOLD')");
    $dbh->do("INSERT INTO `message_transports` (message_attribute_id, message_transport_type, is_digest, letter_module, letter_code) values(4, 'email', 0, 'reserves', 'HOLD')");
    print "Upgrade to $DBversion done (Add letter for holds notifications)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.02.002";
#$DBversion = '3.01.00.006';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE `biblioitems` ADD KEY issn (issn)");
    print "Upgrade to $DBversion done (add index on biblioitems.issn)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.02.003";
#$DBversion = "3.01.00.007";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("UPDATE `systempreferences` SET options='70|10' WHERE variable='intranetmainUserblock'");
    $dbh->do("UPDATE `systempreferences` SET options='70|10' WHERE variable='intranetuserjs'");
    $dbh->do("UPDATE `systempreferences` SET options='70|10' WHERE variable='opacheader'");
    $dbh->do("UPDATE `systempreferences` SET options='70|10' WHERE variable='OpacMainUserBlock'");
    $dbh->do("UPDATE `systempreferences` SET options='70|10' WHERE variable='OpacNav'");
    $dbh->do("UPDATE `systempreferences` SET options='70|10' WHERE variable='opacuserjs'");
    $dbh->do("UPDATE `systempreferences` SET options='30|10', type='Textarea' WHERE variable='OAI-PMH:Set'");
    $dbh->do("UPDATE `systempreferences` SET options='50' WHERE variable='intranetstylesheet'");
    $dbh->do("UPDATE `systempreferences` SET options='50' WHERE variable='intranetcolorstylesheet'");
    $dbh->do("UPDATE `systempreferences` SET options='10' WHERE variable='globalDueDate'");
    $dbh->do("UPDATE `systempreferences` SET type='Integer' WHERE variable='numSearchResults'");
    $dbh->do("UPDATE `systempreferences` SET type='Integer' WHERE variable='OPACnumSearchResults'");
    $dbh->do("UPDATE `systempreferences` SET type='Integer' WHERE variable='ReservesMaxPickupDelay'");
    $dbh->do("UPDATE `systempreferences` SET type='Integer' WHERE variable='TransfersMaxDaysWarning'");
    $dbh->do("UPDATE `systempreferences` SET type='Integer' WHERE variable='StaticHoldsQueueWeight'");
    $dbh->do("UPDATE `systempreferences` SET type='Integer' WHERE variable='holdCancelLength'");
    $dbh->do("UPDATE `systempreferences` SET type='Integer' WHERE variable='XISBNDailyLimit'");
    $dbh->do("UPDATE `systempreferences` SET type='Float' WHERE variable='gist'");
    $dbh->do("UPDATE `systempreferences` SET type='Free' WHERE variable='BakerTaylorUsername'");
    $dbh->do("UPDATE `systempreferences` SET type='Free' WHERE variable='BakerTaylorPassword'");
    $dbh->do("UPDATE `systempreferences` SET type='Textarea', options='70|10' WHERE variable='ISBD'");
    $dbh->do("UPDATE `systempreferences` SET type='Textarea', options='70|10', explanation='Enter a specific hash for NoZebra indexes. Enter : \\\'indexname\\\' => \\\'100a,245a,500*\\\',\\\'index2\\\' => \\\'...\\\'' WHERE variable='NoZebraIndexes'");
    print "Upgrade to $DBversion done (fix display of many sysprefs)\n";
    SetVersion ($DBversion);
}


$DBversion = "3.00.02.004";
#$DBversion = "3.01.00.009";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO permissions (module_bit, code, description) VALUES ( 1, 'circulate_remaining_permissions', 'Remaining circulation permissions')");
    $dbh->do("INSERT INTO permissions (module_bit, code, description) VALUES ( 1, 'override_renewals', 'Override blocked renewals')");
    print "Upgrade to $DBversion done (added subpermissions for circulate permission)\n";
}

$DBversion = "3.00.02.005";
#$DBversion = '3.01.00.010';
if ( C4::Context->preference('Version') < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `borrower_attributes` MODIFY COLUMN `attribute` VARCHAR(64) DEFAULT NULL");
    $dbh->do("ALTER TABLE `borrower_attributes` MODIFY COLUMN `password` VARCHAR(64) DEFAULT NULL");
    print "Upgrade to $DBversion done (bug 2687: increase length of borrower attribute fields)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.02.006";
#$DBversion = '3.01.00.011';
if ( C4::Context->preference('Version') < TransformToNum($DBversion) ) {

    # Yes, the old value was ^M terminated.
    my $bad_value = "function prepareEmailPopup(){\r\n  if (!document.getElementById) return false;\r\n  if (!document.getElementById('reserveemail')) return false;\r\n  rsvlink = document.getElementById('reserveemail');\r\n  rsvlink.onclick = function() {\r\n      doReservePopup();\r\n      return false;\r\n	}\r\n}\r\n\r\nfunction doReservePopup(){\r\n}\r\n\r\nfunction prepareReserveList(){\r\n}\r\n\r\naddLoadEvent(prepareEmailPopup);\r\naddLoadEvent(prepareReserveList);";

    my $intranetuserjs = C4::Context->preference('intranetuserjs');
    if ($intranetuserjs  and  $intranetuserjs eq $bad_value) {
        my $sql = <<'END_SQL';
UPDATE systempreferences
SET value = ''
WHERE variable = 'intranetuserjs'
END_SQL
        $dbh->do($sql);
    }
    print "Upgrade to $DBversion done (removed bogus intranetuserjs syspref)\n";
    SetVersion($DBversion);
}


$DBversion = "3.00.02.007";
#$DBversion = '3.01.00.015';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('OPACAmazonCoverImages', '0', 'Display cover images on OPAC from Amazon Web Services','','YesNo')");

    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('AmazonCoverImages', '0', 'Display Cover Images in Staff Client from Amazon Web Services','','YesNo')");

    $dbh->do("UPDATE systempreferences SET variable='AmazonEnabled' WHERE variable = 'AmazonContent'");

    $dbh->do("UPDATE systempreferences SET variable='OPACAmazonEnabled' WHERE variable = 'OPACAmazonContent'");

    print "Upgrade to $DBversion done (added Syndetics Enhanced Content system preferences)\n";
    SetVersion ($DBversion);
}



$DBversion = "3.00.02.008";
#$DBversion = "3.01.00.018";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE deletedborrowers ADD `smsalertnumber` varchar(50) default NULL");
    print "Upgrade to $DBversion done (added deletedborrowers.smsalertnumber, missed in 3.00.00.091)\n";
    SetVersion ($DBversion);
}


$DBversion = "3.00.02.009";
#$DBversion = '3.01.00.023';
if ( C4::Context->preference('Version') < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE biblioitems        MODIFY COLUMN isbn VARCHAR(30) DEFAULT NULL");
    $dbh->do("ALTER TABLE deletedbiblioitems MODIFY COLUMN isbn VARCHAR(30) DEFAULT NULL");
    $dbh->do("ALTER TABLE import_biblios     MODIFY COLUMN isbn VARCHAR(30) DEFAULT NULL");
    $dbh->do("ALTER TABLE suggestions        MODIFY COLUMN isbn VARCHAR(30) DEFAULT NULL");
    print "Upgrade to $DBversion done (bug 2765: increase width of isbn column in several tables)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.00.02.010';
#$DBversion = '3.01.00.027';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE zebraqueue CHANGE `biblio_auth_number` `biblio_auth_number` bigint(20) unsigned NOT NULL default 0");
    print "Upgrade to $DBversion done (Increased size of zebraqueue biblio_auth_number to address bug 3148.)\n";
    SetVersion ($DBversion);
}

#$DBversion = '3.01.00.028';
$DBversion = '3.00.02.011';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    my $enable_reviews = C4::Context->preference('AmazonEnabled') ? '1' : '0';
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('AmazonReviews', '$enable_reviews', 'Display Amazon reviews on staff interface','','YesNo')");
    print "Upgrade to $DBversion done (added AmazonReviews)\n";
    SetVersion ($DBversion);
}

#$DBversion = '3.01.00.029';
$DBversion = '3.00.02.012';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q( UPDATE language_rfc4646_to_iso639
                SET iso639_2_code = 'spa'
                WHERE rfc4646_subtag = 'es'
                AND   iso639_2_code = 'rus' )
            );
    print "Upgrade to $DBversion done (fixed bug 2599: using Spanish search limit retrieves Russian results)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.01.00.001';
if ( C4::Context->preference('Version') < TransformToNum($DBversion) ) {
    $dbh->do("
        CREATE TABLE hold_fill_targets (
            `borrowernumber` int(11) NOT NULL,
            `biblionumber` int(11) NOT NULL,
            `itemnumber` int(11) NOT NULL,
            `source_branchcode`  varchar(10) default NULL,
            `item_level_request` tinyint(4) NOT NULL default 0,
            PRIMARY KEY `itemnumber` (`itemnumber`),
            KEY `bib_branch` (`biblionumber`, `source_branchcode`),
            CONSTRAINT `hold_fill_targets_ibfk_1` FOREIGN KEY (`borrowernumber`) 
                REFERENCES `borrowers` (`borrowernumber`) ON DELETE CASCADE ON UPDATE CASCADE,
            CONSTRAINT `hold_fill_targets_ibfk_2` FOREIGN KEY (`biblionumber`) 
                REFERENCES `biblio` (`biblionumber`) ON DELETE CASCADE ON UPDATE CASCADE,
            CONSTRAINT `hold_fill_targets_ibfk_3` FOREIGN KEY (`itemnumber`) 
                REFERENCES `items` (`itemnumber`) ON DELETE CASCADE ON UPDATE CASCADE,
            CONSTRAINT `hold_fill_targets_ibfk_4` FOREIGN KEY (`source_branchcode`) 
                REFERENCES `branches` (`branchcode`) ON DELETE CASCADE ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
    ");
    $dbh->do("
        ALTER TABLE tmp_holdsqueue
            ADD item_level_request tinyint(4) NOT NULL default 0
    ");

    print "Upgrade to $DBversion done (add hold_fill_targets table and a column to tmp_holdsqueue)\n";
    SetVersion($DBversion);
}


$DBversion = '3.00.04.004';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('OPACDisplayRequestPriority','0','Show patrons the priority level on holds in the OPAC','','YesNo')");
    print "Upgrade to $DBversion done (added OPACDisplayRequestPriority system preference)\n";
    SetVersion ($DBversion);
}


$DBversion = '3.00.04.008';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {

    $dbh->do("CREATE TABLE branch_transfer_limits (
                          limitId int(8) NOT NULL auto_increment,
                          toBranch varchar(4) NOT NULL,
                          fromBranch varchar(4) NOT NULL,
                          itemtype varchar(4) NOT NULL,
                          PRIMARY KEY  (limitId)
                          ) ENGINE=InnoDB DEFAULT CHARSET=utf8"
                        );

    $dbh->do("INSERT INTO `systempreferences` ( `variable` , `value` , `options` , `explanation` , `type` ) VALUES ( 'UseBranchTransferLimits', '0', '', 'If ON, Koha will will use the rules defined in branch_transfer_limits to decide if an item transfer should be allowed.', 'YesNo')");

    print "Upgrade to $DBversion done (added branch_transfer_limits table and UseBranchTransferLimits system preference)\n";
    SetVersion ($DBversion);
}



$DBversion = "3.00.04.012";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES('AllowHoldPolicyOverride', '0', 'Allow staff to override hold policies when placing holds',NULL,'YesNo')");
    $dbh->do("
        CREATE TABLE `branch_item_rules` (
          `branchcode` varchar(10) NOT NULL,
          `itemtype` varchar(10) NOT NULL,
          `holdallowed` tinyint(1) default NULL,
          PRIMARY KEY  (`itemtype`,`branchcode`),
          KEY `branch_item_rules_ibfk_2` (`branchcode`),
          CONSTRAINT `branch_item_rules_ibfk_1` FOREIGN KEY (`itemtype`) REFERENCES `itemtypes` (`itemtype`) ON DELETE CASCADE ON UPDATE CASCADE,
          CONSTRAINT `branch_item_rules_ibfk_2` FOREIGN KEY (`branchcode`) REFERENCES `branches` (`branchcode`) ON DELETE CASCADE ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
    ");
    $dbh->do("
        CREATE TABLE `default_branch_item_rules` (
          `itemtype` varchar(10) NOT NULL,
          `holdallowed` tinyint(1) default NULL,
          PRIMARY KEY  (`itemtype`),
          CONSTRAINT `default_branch_item_rules_ibfk_1` FOREIGN KEY (`itemtype`) REFERENCES `itemtypes` (`itemtype`) ON DELETE CASCADE ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
    ");
    $dbh->do("
        ALTER TABLE default_branch_circ_rules
            ADD COLUMN holdallowed tinyint(1) NULL
    ");
    $dbh->do("
        ALTER TABLE default_circ_rules
            ADD COLUMN holdallowed tinyint(1) NULL
    ");
    print "Upgrade to $DBversion done (Add tables and system preferences for holds policies)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.00.04.013';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("
        CREATE TABLE item_circulation_alert_preferences (
            id           int(11) AUTO_INCREMENT,
            branchcode   varchar(10) NOT NULL,
            categorycode varchar(10) NOT NULL,
            item_type    varchar(10) NOT NULL,
            notification varchar(16) NOT NULL,
            PRIMARY KEY (id),
            KEY (branchcode, categorycode, item_type, notification)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
    ");

    $dbh->do(q{ ALTER TABLE `message_queue` ADD metadata text DEFAULT NULL           AFTER content;  });
    $dbh->do(q{ ALTER TABLE `message_queue` ADD letter_code varchar(64) DEFAULT NULL AFTER metadata; });

    $dbh->do(q{
        INSERT INTO `letter` (`module`, `code`, `name`, `title`, `content`) VALUES
        ('circulation','CHECKIN','Item Check-in','Check-ins','The following items have been checked in:\r\n----\r\n<<biblio.title>>\r\n----\r\nThank you.');
    });
    $dbh->do(q{
        INSERT INTO `letter` (`module`, `code`, `name`, `title`, `content`) VALUES
        ('circulation','CHECKOUT','Item Checkout','Checkouts','The following items have been checked out:\r\n----\r\n<<biblio.title>>\r\n----\r\nThank you for visiting <<branches.branchname>>.');
    });

    $dbh->do(q{INSERT INTO message_attributes (message_attribute_id, message_name, takes_days) VALUES (5, 'Item Check-in', 0);});
    $dbh->do(q{INSERT INTO message_attributes (message_attribute_id, message_name, takes_days) VALUES (6, 'Item Checkout', 0);});

    $dbh->do(q{INSERT INTO message_transports (message_attribute_id, message_transport_type, is_digest, letter_module, letter_code) VALUES (5, 'email', 0, 'circulation', 'CHECKIN');});
    $dbh->do(q{INSERT INTO message_transports (message_attribute_id, message_transport_type, is_digest, letter_module, letter_code) VALUES (5, 'sms',   0, 'circulation', 'CHECKIN');});
    $dbh->do(q{INSERT INTO message_transports (message_attribute_id, message_transport_type, is_digest, letter_module, letter_code) VALUES (6, 'email', 0, 'circulation', 'CHECKOUT');});
    $dbh->do(q{INSERT INTO message_transports (message_attribute_id, message_transport_type, is_digest, letter_module, letter_code) VALUES (6, 'sms',   0, 'circulation', 'CHECKOUT');});

    print "Upgrade to $DBversion done (data for Email Checkout Slips project)\n";
	 SetVersion ($DBversion);
}

$DBversion = "3.00.04.014";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE `branch_transfer_limits` CHANGE `itemtype` `itemtype` VARCHAR( 4 ) CHARACTER SET utf8 COLLATE utf8_general_ci NULL");
    $dbh->do("ALTER TABLE `branch_transfer_limits` ADD `ccode` VARCHAR( 10 ) NULL ;");
    $dbh->do("INSERT INTO `systempreferences` ( `variable` , `value` , `options` , `explanation` , `type` )
    VALUES (
    'BranchTransferLimitsType', 'ccode', 'itemtype|ccode', 'When using branch transfer limits, choose whether to limit by itemtype or collection code.', 'Choice'
    );");
    
    print "Upgrade to $DBversion done ( Updated table for Branch Transfer Limits)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.00.04.015';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsClientCode', '0', 'Client Code for using Syndetics Solutions content','','free')");

    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsEnabled', '0', 'Turn on Syndetics Enhanced Content','','YesNo')");

    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsCoverImages', '0', 'Display Cover Images from Syndetics','','YesNo')");

    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsTOC', '0', 'Display Table of Content information from Syndetics','','YesNo')");

    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsSummary', '0', 'Display Summary Information from Syndetics','','YesNo')");

    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsEditions', '0', 'Display Editions from Syndetics','','YesNo')");

    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsExcerpt', '0', 'Display Excerpts and first chapters on OPAC from Syndetics','','YesNo')");

    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsReviews', '0', 'Display Reviews on OPAC from Syndetics','','YesNo')");

    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsAuthorNotes', '0', 'Display Notes about the Author on OPAC from Syndetics','','YesNo')");

    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsAwards', '0', 'Display Awards on OPAC from Syndetics','','YesNo')");

    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsSeries', '0', 'Display Series information on OPAC from Syndetics','','YesNo')");

    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsCoverImageSize', 'MC', 'Choose the size of the Syndetics Cover Image to display on the OPAC detail page, MC is Medium, LC is Large','MC|LC','Choice')");
    print "Upgrade to $DBversion done (added Syndetics Enhanced Content system preferences)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.04.016";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('Babeltheque',0,'Turn ON Babeltheque content  - See babeltheque.com to subscribe to this service','','YesNo')");
    print "Upgrade to $DBversion done (Added Babeltheque syspref)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.04.017";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE `subscription` ADD `staffdisplaycount` VARCHAR(10) NULL;");
    $dbh->do("ALTER TABLE `subscription` ADD `opacdisplaycount` VARCHAR(10) NULL;");
    $dbh->do("INSERT INTO `systempreferences` ( `variable` , `value` , `options` , `explanation` , `type` )
    VALUES (
    'StaffSerialIssueDisplayCount', '3', '', 'Number of serial issues to display per subscription in the Staff client', 'Integer'
    );");
	$dbh->do("INSERT INTO `systempreferences` ( `variable` , `value` , `options` , `explanation` , `type` )
    VALUES (
    'OPACSerialIssueDisplayCount', '3', '', 'Number of serial issues to display per subscription in the OPAC', 'Integer'
    );");

    print "Upgrade to $DBversion done ( Updated table for Serials Display)\n";
    SetVersion ($DBversion);
}


$DBversion = "3.00.04.019";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
        $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACShowCheckoutName','0','Displays in the OPAC the name of patron who has checked out the material. WARNING: Most sites should leave this off. It is intended for corporate or special sites which need to track who has the item.','','YesNo')");
    print "Upgrade to $DBversion done (adding OPACShowCheckoutName systempref)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.04.020";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type)VALUES('LibraryThingForLibrariesID','','See:http://librarything.com/forlibraries/','','free')");
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type)VALUES('LibraryThingForLibrariesEnabled','0','Enable or Disable Library Thing for Libraries Features','','YesNo')");
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type)VALUES('LibraryThingForLibrariesTabbedView','0','Put LibraryThingForLibraries Content in Tabs.','','YesNo')");
    print "Upgrade to $DBversion done (adding LibraryThing for Libraries sysprefs)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.04.021";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    my $enable_reviews = C4::Context->preference('OPACAmazonEnabled') ? '1' : '0';
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('OPACAmazonReviews', '$enable_reviews', 'Display Amazon readers reviews on OPAC','','YesNo')");
    print "Upgrade to $DBversion done (adding OPACAmazonReviews syspref)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.00.04.022';
if ( C4::Context->preference('Version') < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `labels_conf` MODIFY COLUMN `formatstring` mediumtext DEFAULT NULL");
    print "Upgrade to $DBversion done (bug 2945: increase size of labels_conf.formatstring)\n";
    SetVersion ($DBversion);
}


$DBversion = "3.00.04.024";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE labels MODIFY COLUMN batch_id int(10) NOT NULL default 1;");
    print "Upgrade to $DBversion done (change labels.batch_id from varchar to int)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.00.04.025';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO `systempreferences` ( `variable` , `value` , `options` , `explanation` , `type` ) VALUES ( 'ceilingDueDate', '', '', 'If set, date due will not be past this date.  Enter date according to the dateformat System Preference', 'free')");

    print "Upgrade to $DBversion done (added ceilingDueDate system preference)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.00.04.026';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO `systempreferences` ( `variable` , `value` , `options` , `explanation` , `type` ) VALUES ( 'numReturnedItemsToShow', '20', '', 'Number of returned items to show on the check-in page', 'Integer')");

    print "Upgrade to $DBversion done (added numReturnedItemsToShow system preference)\n";
    SetVersion ($DBversion);
}


$DBversion = "3.00.04.030";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO `systempreferences` ( `variable` , `value` , `options` , `explanation` , `type` ) VALUES ( 'AllowNotForLoanOverride', '0', '', 'If ON, Koha will allow the librarian to loan a not for loan item.', 'YesNo')");
    print "Upgrade to $DBversion done (added AllowNotForLoanOverride system preference)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.04.031";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE branch_transfer_limits
              MODIFY toBranch   varchar(10) NOT NULL,
              MODIFY fromBranch varchar(10) NOT NULL,
              MODIFY itemtype   varchar(10) NULL");
    print "Upgrade to $DBversion done (fix column widths in branch_transfer_limits)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.04.032";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(<<ENDOFRENEWAL);
INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES('RenewalPeriodBase', 'now', 'Set whether the renewal date should be counted from the date_due or from the moment the Patron asks for renewal ','date_due|now','Choice');
ENDOFRENEWAL
    print "Upgrade to $DBversion done (Change the field)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.04.033";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q/
        ALTER TABLE borrower_message_preferences
        MODIFY borrowernumber int(11) default NULL,
        ADD    categorycode varchar(10) default NULL AFTER borrowernumber,
        ADD KEY `categorycode` (`categorycode`),
        ADD CONSTRAINT `borrower_message_preferences_ibfk_3` 
                       FOREIGN KEY (`categorycode`) REFERENCES `categories` (`categorycode`) 
                       ON DELETE CASCADE ON UPDATE CASCADE
    /);
    print "Upgrade to $DBversion done (DB changes to allow patron category defaults for messaging preferences)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.04.034";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE `subscription` ADD COLUMN `graceperiod` INT(11) NOT NULL default '0';");
    print "Upgrade to $DBversion done (Adding graceperiod column to subscription table)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.00.04.035';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q{ ALTER TABLE `subscription` ADD location varchar(80) NULL DEFAULT '' AFTER callnumber; });
   print "Upgrade to $DBversion done (Adding location to subscription table)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.00.04.036';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("UPDATE systempreferences SET explanation = 'Choose the default detail view in the staff interface; choose between normal, labeled_marc, marc or isbd'
              WHERE variable = 'IntranetBiblioDefaultView'
              AND   explanation = 'IntranetBiblioDefaultView'");
    $dbh->do("UPDATE systempreferences SET type = 'Choice', options = 'normal|marc|isbd|labeled_marc'
              WHERE variable = 'IntranetBiblioDefaultView'");
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type)VALUES('viewISBD','1','Allow display of ISBD view of bibiographic records','','YesNo')");
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type)VALUES('viewLabeledMARC','0','Allow display of labeled MARC view of bibiographic records','','YesNo')");
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type)VALUES('viewMARC','1','Allow display of MARC view of bibiographic records','','YesNo')");
    print "Upgrade to $DBversion done (new viewISBD, viewLabeledMARC, viewMARC sysprefs and tweak IntranetBiblioDefaultView)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.00.04.037';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do('ALTER TABLE authorised_values ADD KEY `lib` (`lib`)');
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type)VALUES('FilterBeforeOverdueReport','0','Do not run overdue report until filter selected','','YesNo')");
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done (added FilterBeforeOverdueReport syspref and new index on authorised_values)\n";
}

=item DropAllForeignKeys($table)

  Drop all foreign keys of the table $table

=cut

sub DropAllForeignKeys {
    my ($table) = @_;
    # get the table description
    my $sth = $dbh->prepare("SHOW CREATE TABLE $table");
    $sth->execute;
    my $vsc_structure = $sth->fetchrow;
    # split on CONSTRAINT keyword
    my @fks = split /CONSTRAINT /,$vsc_structure;
    # parse each entry
    foreach (@fks) {
        # isolate what is before FOREIGN KEY, if there is something, it's a foreign key to drop
        $_ = /(.*) FOREIGN KEY.*/;
        my $id = $1;
        if ($id) {
            # we have found 1 foreign, drop it
            $dbh->do("ALTER TABLE $table DROP FOREIGN KEY $id");
            $id="";
        }
    }
}


=item TransformToNum

  Transform the Koha version from a 4 parts string
  to a number, with just 1 .

=cut

sub TransformToNum {
    my $version = shift;
    # remove the 3 last . to have a Perl number
    $version =~ s/(.*\..*)\.(.*)\.(.*)/$1$2$3/;
    return $version;
}

=item SetVersion

    set the DBversion in the systempreferences

=cut

sub SetVersion {
    my $kohaversion = TransformToNum(shift);
    if (C4::Context->preference('Version')) {
      my $finish=$dbh->prepare("UPDATE systempreferences SET value=? WHERE variable='Version'");
      $finish->execute($kohaversion);
    } else {
      my $finish=$dbh->prepare("INSERT into systempreferences (variable,value,explanation) values ('Version',?,'The Koha database version. WARNING: Do not change this value manually, it is maintained by the webinstaller')");
      $finish->execute($kohaversion);
    }
}
exit;

