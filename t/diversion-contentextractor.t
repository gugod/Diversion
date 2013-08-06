#!/usr/bin/env perl

use strict;
use Test::Spec;
use Encode;
use Diversion::ContentFetcher;
use Diversion::ContentExtractor;

describe "Diversion::ContentExtractor" => sub {
    # my $url = "http://gugod.org/2013/04/learn-from-failure/";
    my $url = "http://blog.libertytimes.com.tw/kang1021/2013/08/06/146031";
    my $content;
    my $extractor;

    before each => sub {
        my $fetcher = Diversion::ContentFetcher->new( url => $url );
        $content = $fetcher->content;

        $extractor = Diversion::ContentExtractor->new( content => $content );
    };

    describe "the method 'title'" => sub {
        before each => sub {
            can_ok $extractor, "title";
        };

        it "returns scalar" => sub {
            my $r = $extractor->title();

            ok defined($r);
            ok ref($r) eq '';
            ok Encode::is_utf8($r);
        };
    };

    describe "the method 'text'", => sub {
        before each => sub {
            can_ok $extractor, "text";
        };

        it "returns scalar" => sub {
            my $r = $extractor->text();

            ok defined($r);
            ok ref($r) eq '';
            ok Encode::is_utf8($r);
        };
    };
};

runtests;
