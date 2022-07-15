#!/usr/bin/env perl

use strict;
use warnings;

use feature 'say';
use utf8;
use open qw(:std :utf8);

use Time::Local;
use DBI;

my $dbh = DBI->connect("dbi:Pg:dbname=log_parser", 'log_parser_user', '1234567', {AutoCommit => 1});

my $cnt = 0;
while (<>) {
  chomp;

  if (/^
    (?<date>[0-9]{4}-[0-9]{2}-[0-9]{2})
    \s+
    (?<time>[0-9]{2}:[0-9]{2}:[0-9]{2})
    \s+
    (?<log_string>
      (?<internal_id>.*?)
      \s+
      (?<flag>[<=]=|[-=]\>|\*\*)?
      \s+
      (?<address>\S+@\S+)
      .*?
      (?:id=(?<id>.+))?
    )
    $/xi) {
      my ($year, $mon, $mday) = split /-/, $+{date};
      my ($hour, $min, $sec) = split /:/, $+{time};
      my $created = timelocal($sec, $min, $hour, $mday, $mon - 1, $year);

      if ($+{id}) {
        $dbh->do(q|INSERT INTO message (created, id, int_id, str) VALUES (to_timestamp(?) AT TIME ZONE 'UTC', ?, ?, ?)|, undef,
                                       $created, $+{id}, $+{internal_id}, $+{log_string});
      } else {
        $dbh->do(q|INSERT INTO log (created, int_id, str, address) VALUES (to_timestamp(?) AT TIME ZONE 'UTC', ?, ?, ?)|, undef,
                                       $created, $+{internal_id}, $+{log_string}, $+{address});
      }
  }
}
