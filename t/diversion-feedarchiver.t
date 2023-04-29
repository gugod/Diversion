#!/usr/bin/env perl
use v5.36;
use Test::Spec;
use Diversion::FeedArchiver;

my $FEEDURL = "http://gugod.org/atom.xml";

describe "Diversion::FeedArchiver" => sub {
    my ($archiver);

    before each => sub {
        $archiver = Diversion::FeedArchiver->new(
            url => $FEEDURL
        );
    };

    it "has a `fetcher` object" => sub {
        isa_ok($archiver->fetcher, "Diversion::FeedFetcher");
    };

    it "stores individual feed entries in ES.";
};

runtests;
