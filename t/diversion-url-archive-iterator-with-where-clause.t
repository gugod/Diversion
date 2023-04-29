use v5.36;

use Diversion::UrlArchiveIterator;

my $iter = Diversion::UrlArchiveIterator->new(
   sql_where_clause => ["instr(uri,?)", ".com"],
);

while (my $row = $iter->next()) {
    say $row->{uri};
}
