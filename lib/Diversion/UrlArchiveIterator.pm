package Diversion::UrlArchiveIterator;
use v5.18;
use Moo;
with 'Diversion::Db';

use Diversion::UrlArchiver;

has _ext_cursor => (
    is => "rw",
    predicate => 1
);

has _cursor => (
    is => "rw",
    predicate => 1,
);

has sql_where_clause => (
    is => "ro",
    predicate => 1
);

has sql_order_clause => (
    is => "ro",
    predicate => 1
);

has reified => (
    is => "rw",
    default => sub { [ ] }
);

sub reify {
    my ($self) = @_;
    my $o = Diversion::UrlArchiver->new;
    my $ext_cursor = $self->_has_ext_cursor ? $self->_ext_cursor : 0;

    my $rows = $self->db_open(
        url => sub {
            my ($dbh) = @_;
            my $SELECT_CLAUSE = "SELECT uri,sha1_digest,created_at FROM uri_archive";
            my $ORDER_CLAUSE = "ORDER BY uri ASC";

            if ($self->has_sql_order_clause) {
                $ORDER_CLAUSE = "ORDER BY " . $self->sql_order_clause;
            }

            if ($self->has_sql_where_clause) {
                my ($WHERE_CLAUSE, @values) = @{$self->sql_where_clause};
                $dbh->selectall_arrayref("$SELECT_CLAUSE WHERE $WHERE_CLAUSE $ORDER_CLAUSE LIMIT ?,1000", {Slice=>{}}, @values, $ext_cursor);
            } else {
                $dbh->selectall_arrayref("$SELECT_CLAUSE $ORDER_CLAUSE LIMIT ?,1000", {Slice=>{}}, $ext_cursor);
            }
        }
    );

    $self->reified($rows);
    $self->_ext_cursor( $ext_cursor + @$rows );
    $self->_cursor( 0 );
    return $self;
}

sub next {
    my ($self) = @_;

    $self->reify unless $self->_has_cursor;

    my $i = $self->_cursor;
    if ($i == @{$self->reified}) {
        $self->reify;
        $i = $self->_cursor;
    }
    $self->_cursor($i+1);
    return $self->reified->[$i];
}

1;
