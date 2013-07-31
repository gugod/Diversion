#!/usr/bin/env perl
use strict;
use v5.14;
use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/../local/lib/perl5";

use Diversion::FeedArchiver;

use IO::All;

my $feed_url = shift or die "Missing URL in arg";

my @feeds;
if (-f $feed_url) {
    @feeds = grep { s/\s//g; $_ } io($feed_url)->chomp->getlines;
}
else {
    push @feeds, $feed_url;
}

for (@feeds) {
    eval {
        Diversion::FeedArchiver->new( url => $_ )->fetch_then_archive;
        1;
    } or do {
        say STDERR $@;
    };
}
