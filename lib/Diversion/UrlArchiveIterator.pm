package Diversion::UrlArchiveIterator;
use v5.18;
use Moo;
with 'Diversion::Service', 'Diversion::Iterator';

use Diversion::UrlArchiver;

has object_created_at => (
    is => "ro",
    default => sub { scalar time }
);

has sql_where_clause => (
    is => "ro",
    predicate => 1
);

has sql_order_clause => (
    is => "ro",
    predicate => 1
);

sub reify {
    my ($self) = @_;
    my $o = Diversion::UrlArchiver->new;
    my $ext_cursor = $self->_has_ext_cursor ? $self->_ext_cursor : 0;

    my $rows = $self->db_open(
        url => sub {
            my ($dbh) = @_;
            my $SELECT_CLAUSE = "SELECT uri,sha1_digest,created_at FROM uri_archive";
            my $ORDER_CLAUSE = "ORDER BY created_at DESC";
            my ($WHERE_CLAUSE, @where_values) = ("created_at < ?", $self->object_created_at);

            if ($self->has_sql_order_clause) {
                $ORDER_CLAUSE = "ORDER BY " . $self->sql_order_clause;
            }

            if ($self->has_sql_where_clause) {
                my @w = @{$self->sql_where_clause};
                $WHERE_CLAUSE = "( $WHERE_CLAUSE ) AND ( " . shift(@w) . " )";
                push @where_values, @w;
            }

            return $dbh->selectall_arrayref("$SELECT_CLAUSE WHERE $WHERE_CLAUSE $ORDER_CLAUSE LIMIT ?,1000", {Slice=>{}}, @where_values, $ext_cursor);
        }
    );

    $self->reified($rows);
    $self->_ext_cursor( $ext_cursor + @$rows );
    $self->_cursor( 0 );
    return $self;
}

1;
