#!/usr/bin/env perl
use strict;
use v5.14;
use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/../local/lib/perl5";

use Diversion::FeedArchiver;

my $feed_url = shift or die "Missing URL in arg";

my $archiver = Diversion::FeedArchiver->new( url => $feed_url );

$archiver->run;
