#!/usr/bin/env perl

use strict;
use Test::Spec;

use Diversion::FeedFetcher;

my $FEEDURL = "http://gugod.org/atom.xml";

describe "Diversion::FeedFetcher" => sub {
    my ($fetcher);

    before each => sub {
        $fetcher = Diversion::FeedFetcher->new(url => $FEEDURL);
    };

    it "has a 'feed' property that stores the current XML::Feed object." => sub {
        my $feed = $fetcher->feed;
        ok ($feed->isa("XML::Feed"));
    };

    it "has a 'each_entry' method that takes a callback, and invokes the callback on each entry (XML::Feed::Entry)" => sub {
        ok $fetcher->can("each_entry");

        my $entries = 0;
        $fetcher->each_entry( sub { $entries++ } );
        ok $entries > 0;
    };
};

runtests;
