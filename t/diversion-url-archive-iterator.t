use v5.18;
use strict;
use Diversion::UrlArchiveIterator;

my $iter = Diversion::UrlArchiveIterator->new();

while (my $url = $iter->next()) {
    say $url;
}
