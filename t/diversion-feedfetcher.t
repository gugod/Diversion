#!/usr/bin/env perl
use v5.36;
use Test::Spec;
use Scalar::Util qw(looks_like_number);

use Diversion::FeedFetcher;

my $FEEDURL = "http://gugod.org/atom.xml";

describe "Diversion::FeedFetcher" => sub {
    my ($fetcher);

    before each => sub {
        $fetcher = Diversion::FeedFetcher->new(url => $FEEDURL);
    };

    describe "The method `each_entry`" => sub {
        before each => sub {
            ok $fetcher->can("each_entry");
            ok ! $fetcher->feed_is_fetched;
        };

        it "takes a callback, and invokes the callback on each entry." => sub {
            my $entries = 0;
            $fetcher->each_entry(
                sub {
                    my ($entry, $i) = @_;

                    for my $attr (qw(title link)) {
                        ok( exists $entry->{$attr} );
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
