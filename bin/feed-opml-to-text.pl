#!/usr/bin/env perl
use v5.14;
use strict;
use warnings;
use XML::XPath;
use TOML;

my $opml_file = shift(@ARGV) or die;
-f $opml_file or die;

my $xp = XML::XPath->new(filename => $opml_file);
my $resultset = $xp->find('//outline[@xmlUrl]');

my @feeds;
for my $node ($resultset->get_nodelist) {
    push @feeds, $node->getAttribute("xmlUrl");
}

say for @feeds;
