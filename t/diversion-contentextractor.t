#!/usr/bin/env perl

use strict;
use Test::Spec;
use Diversion::ContentExtractor;

describe "Diversion::ContentExtractor" => sub {
    my $url = "http://gugod.org/2013/04/learn-from-failure/";
    my $extractor;

    before each => sub {
        $extractor = Diversion::ContentExtractor->new( url => $url );
    };

    describe "the method 'extract'", => sub {
        before each => sub {
            can_ok $extractor, "extract";
        };

        it "returns scalar" => sub {
            my $r = $extractor->extract();

            ok defined($r);
            ok ref($r) eq '';
        };
    };
};

runtests;
