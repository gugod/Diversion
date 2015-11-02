use v5.18;
use strict;
use Diversion::UrlArchiveIterator;

my $iter = Diversion::UrlArchiveIterator->new(
   sql_where_clause => ["instr(uri,?)", ".com"],
);

while (my $row = $iter->next()) {
    say $row->{uri};
}
