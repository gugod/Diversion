#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Temp qw(tempfile);
use Diversion::Seen;

sub assert {
    my ($condition, $message) = @_;
    if ($condition) {
        ok($condition, $message);
    }
    else {
        die "Assertion failed: $message\n";
    }
}

my $filename = "/tmp/test-diversion-seen-$$.db";

sub seen_something {
    my $seen = Diversion::Seen->new( file => $filename );
    $seen->add("foo");
    $seen->add("bar");
    $seen->_data->{bar} = time - 1 - $seen->expiry * 86400;
}

sub seen_check {
    my $seen = Diversion::Seen->new( file => $filename );

    assert $seen->get("foo"), "saw 'foo' before";
    assert !$seen->get("bar"), "'bar' is expired";
}

seen_something();
seen_check();
unlink($filename);

done_testing;
