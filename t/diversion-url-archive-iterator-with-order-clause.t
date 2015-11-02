use v5.18;
use strict;
use Diversion::UrlArchiveIterator;

my $iter = Diversion::UrlArchiveIterator->new(
   sql_order_clause => "created_at DESC"
);

while (my $row = $iter->next()) {
    say $row->{created_at} . "\t" . $row->{uri};
}
