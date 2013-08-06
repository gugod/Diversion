#!/usr/bin/env perl

use strict;
use Test::Spec;
use Encode ();
use Diversion::UrlFetcher;

describe "Diversion::UrlFetcher" => sub {
    # my $url = "http://gugod.org/2013/04/learn-from-failure/";
    my $url = "http://blog.libertytimes.com.tw/kang1021/2013/08/06/146031";
    my $fetcher;

    before each => sub {
        $fetcher = Diversion::UrlFetcher->new( url => $url );
    };

    describe "the method 'content'", => sub {
        before each => sub {
            can_ok $fetcher, "content";
        };

        it "returns decoded scalar" => sub {
            my $r = $fetcher->content();

            ok defined($r);
            ok ref($r) eq '';
            ok Encode::is_utf8($r);
        };
    };
};

runtests;
