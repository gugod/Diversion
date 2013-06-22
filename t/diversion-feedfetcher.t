#!/usr/bin/env perl

use strict;
use Test::Spec;
use Scalar::Util qw(looks_like_number);

use Diversion::FeedFetcher;

my $FEEDURL = "http://gugod.org/atom.xml";

describe "Diversion::FeedFetcher" => sub {
    my ($fetcher);

    before each => sub {
        $fetcher = Diversion::FeedFetcher->new(url => $FEEDURL);
    };

    it "has a 'feed' property that stores the current XML::Feed object." => sub {
        my $feed = $fetcher->feed;
        ok ($feed->isa("XML::FeedPP"));
    };

    describe "The method `each_entry`" => sub {
        before each => sub {
            ok $fetcher->can("each_entry");
            ok ! $fetcher->feed_is_fetched;
        };

        it "takes a callback, and invokes the callback on each entry (XML::FeedPP::Entry)" => sub {
            my $entries = 0;
            $fetcher->each_entry(
                sub {
                    my ($entry, $i) = @_;

                    for my $method (qw(title link)) {
                        ok( $entry->can($method) );
                    }

                    ok( looks_like_number($i) );

                    $entries++
                });

            ok $entries > 0;
            ok $fetcher->feed_is_fetched;
        };

        it "does nothing if the argument is not a subref" => sub {
            $fetcher->each_entry("Nihao");
            ok ! $fetcher->feed_is_fetched;
        };
    };
};

runtests;
