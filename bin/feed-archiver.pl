#!/usr/bin/env perl
use v5.18;
use strict;
use warnings;

use IO::All;
use Log::Dispatch;
use Log::Any::Adapter;
use Carp qw(cluck);
use List::Util qw(shuffle);

use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/../local/lib/perl5";
use Diversion::FeedArchiver;

# $SIG{__DIE__} = sub { Carp::cluck(@_); exit };

my $feed_url = shift or die "Missing URL in arg";

my $log = Log::Dispatch->new(
    outputs => [
        [ 'File', min_level => "debug", filename => "/tmp/feed-archiver.log" ],
        [ 'Screen', min_level => "debug" ],
    ]
);
Log::Any::Adapter->set('Dispatch', dispatcher => $log);

my @feeds;
if (-f $feed_url) {
    @feeds = grep { s/\s//g; $_ } io($feed_url)->chomp->getlines;
}
else {
    push @feeds, $feed_url;
}

my $feed_archiver = Diversion::FeedArchiver->new;
for (shuffle @feeds) {
    say "Processing $_";
    eval {
        $feed_archiver->fetch_then_archive( $_ );
        1;
    } or do {
        say STDERR $@;
    };
}
