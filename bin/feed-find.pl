#!/usr/bin/env perl

use v5.14;
use Feed::Find;
use URI::Escape;

die unless my $url = $ARGV[0];
my @feeds = Feed::Find->find($url);

say for @feeds;

unless (@feeds) {
    say "http://g0vre.herokuapp.com/links2rss?url=" . uri_escape( $url );
}
