package Koha::Schema::Subscription;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("subscription");
__PACKAGE__->add_columns(
  "biblionumber",
  { data_type => "INT", default_value => 0, is_nullable => 0, size => 11 },
  "subscriptionid",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 11 },
  "librarian",
  { data_type => "VARCHAR", default_value => "", is_nullable => 1, size => 100 },
  "startdate",
  { data_type => "DATE", default_value => undef, is_nullable => 1, size => 10 },
  "aqbooksellerid",
  { data_type => "INT", default_value => 0, is_nullable => 1, size => 11 },
  "cost",
  { data_type => "INT", default_value => 0, is_nullable => 1, size => 11 },
  "aqbudgetid",
  { data_type => "INT", default_value => 0, is_nullable => 1, size => 11 },
  "weeklength",
  { data_type => "INT", default_value => 0, is_nullable => 1, size => 11 },
  "monthlength",
  { data_type => "INT", default_value => 0, is_nullable => 1, size => 11 },
  "numberlength",
  { data_type => "INT", default_value => 0, is_nullable => 1, size => 11 },
  "periodicity",
  { data_type => "TINYINT", default_value => 0, is_nullable => 1, size => 4 },
  "dow",
  { data_type => "VARCHAR", default_value => "", is_nullable => 1, size => 100 },
  "numberingmethod",
  { data_type => "VARCHAR", default_value => "", is_nullable => 1, size => 100 },
  "notes",
  {
    data_type => "MEDIUMTEXT",
    default_value => undef,
    is_nullable => 1,
    size => 16777215,
  },
  "status",
  { data_type => "VARCHAR", default_value => "", is_nullable => 0, size => 100 },
  "add1",
  { data_type => "INT", default_value => 0, is_nullable => 1, size => 11 },
  "every1",
  { data_type => "INT", default_value => 0, is_nullable => 1, size => 11 },
  "whenmorethan1",
  { data_type => "INT", default_value => 0, is_nullable => 1, size => 11 },
  "setto1",
  { data_type => "INT", default_value => undef, is_nullable => 1, size => 11 },
  "lastvalue1",
  { data_type => "INT", default_value => undef, is_nullable => 1, size => 11 },
  "add2",
  { data_type => "INT", default_value => 0, is_nullable => 1, size => 11 },
  "every2",
  { data_type => "INT", default_value => 0, is_nullable => 1, size => 11 },
  "whenmorethan2",
  { data_type => "INT", default_value => 0, is_nullable => 1, size => 11 },
  "setto2",
  { data_type => "INT", default_value => undef, is_nullable => 1, size => 11 },
  "lastvalue2",
  { data_type => "INT", default_value => undef, is_nullable => 1, size => 11 },
  "add3",
  { data_type => "INT", default_value => 0, is_nullable => 1, size => 11 },
  "every3",
  { data_type => "INT", default_value => 0, is_nullable => 1, size => 11 },
  "innerloop1",
  { data_type => "INT", default_value => 0, is_nullable => 1, size => 11 },
  "innerloop2",
  { data_type => "INT", default_value => 0, is_nullable => 1, size => 11 },
  "innerloop3",
  { data_type => "INT", default_value => 0, is_nullable => 1, size => 11 },
  "whenmorethan3",
  { data_type => "INT", default_value => 0, is_nullable => 1, size => 11 },
  "setto3",
  { data_type => "INT", default_value => undef, is_nullable => 1, size => 11 },
  "lastvalue3",
  { data_type => "INT", default_value => undef, is_nullable => 1, size => 11 },
  "issuesatonce",
  { data_type => "TINYINT", default_value => 1, is_nullable => 0, size => 3 },
  "firstacquidate",
  { data_type => "DATE", default_value => undef, is_nullable => 1, size => 10 },
  "manualhistory",
  { data_type => "TINYINT", default_value => 0, is_nullable => 0, size => 1 },
  "irregularity",
  {
    data_type => "TEXT",
    default_value => undef,
    is_nullable => 1,
    size => 65535,
  },
  "letter",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 1,
    size => 20,
  },
  "numberpattern",
  { data_type => "TINYINT", default_value => 0, is_nullable => 1, size => 3 },
  "distributedto",
  {
    data_type => "TEXT",
    default_value => undef,
    is_nullable => 1,
    size => 65535,
  },
  "internalnotes",
  {
    data_type => "LONGTEXT",
    default_value => undef,
    is_nullable => 1,
    size => 4294967295,
  },
  "callnumber",
  {
    data_type => "TEXT",
    default_value => undef,
    is_nullable => 1,
    size => 65535,
  },
  "location",
  { data_type => "VARCHAR", default_value => "", is_nullable => 1, size => 80 },
  "branchcode",
  { data_type => "VARCHAR", default_value => "", is_nullable => 0, size => 10 },
  "hemisphere",
  { data_type => "TINYINT", default_value => 0, is_nullable => 1, size => 3 },
  "lastbranch",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 1,
    size => 10,
  },
  "serialsadditems",
  { data_type => "TINYINT", default_value => 0, is_nullable => 0, size => 1 },
  "staffdisplaycount",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 1,
    size => 10,
  },
  "opacdisplaycount",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 1,
    size => 10,
  },
  "graceperiod",
  { data_type => "INT", default_value => 0, is_nullable => 0, size => 11 },
);
__PACKAGE__->set_primary_key("subscriptionid");


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-07-25 19:16:56
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:BdXTio5rwDEIT3f42fvk+g


# You can replace this text with custom content, and it will be preserved on regeneration
1;