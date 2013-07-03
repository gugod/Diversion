#!/usr/bin/env perl

use strict;
use Test::Spec;
use Diversion::ContentExtractor;

describe "Diversion::ContentExtractor" => sub {
    my $url = "http://gugod.org/2013/04/learn-from-failure/";
    my ($extract, $url) = 
    my ($extractor) = @_;

    describe "basic methods", => sub {
        before each => sub {
            $extractor = Diversion::ContentExtractor->new( url => $url );
        };

        it "does do" => sub {
            can_ok $extractor, "extract";
        };
    };
};

runtests;
