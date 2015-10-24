use v5.18;
use strict;
use Diversion::UrlArchiveIterator;

my $iter = Diversion::UrlArchiveIterator->new();

while (my $row = $iter->next()) {
    say $row->{uri};
}
