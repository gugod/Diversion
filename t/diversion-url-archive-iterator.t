use v5.36;

use Diversion::UrlArchiveIterator;

my $iter = Diversion::UrlArchiveIterator->new();

while (my $row = $iter->next()) {
    say $row->{uri};
}
