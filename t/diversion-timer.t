
use v5.14;
use strict;
use warnings;

package Joy;
use Moo;
with 'Diversion::Timer';

package main;

use Test::Spec;

describe "Joy" => sub {
    it "is a Timer itself" => sub {
        my $obj  = Joy->new;

        my $x = $obj->an_hour_ago;

        ok( $obj->looks_like_iso8601($x) );
    };
};

runtests;
