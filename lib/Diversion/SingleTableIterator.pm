package Diversion::SingleTableIterator;
use v5.18;
use Moo::Role;
with 'Diversion::Service', 'Diversion::Iterator';

requires 'database';
requires 'table';
requires 'columns';

use DateTime;
use DateTime::Format::MySQL;

has sql_batch_size => (
    is => "ro",
    default => sub { 1000 },
    required => 1,
);

has sql_where_clause => (
    is => "ro",
    predicate => 1
);

has sql_order_clause => (
    is => "ro",
    predicate => 1
);

has _ext_cursor => (
    is => "rw",
    predicate => 1
);

sub reify {
    my ($self) = @_;
    my $ext_cursor = $self->_has_ext_cursor ? $self->_ext_cursor : 0;

    my $db = $self->database;
    my $table = $self->table;
    my $columns_csv = join ",", @{ $self->columns };

    my $rows = $self->db_open(
        $db => sub {
            my ($dbh) = @_;
            
            my $SELECT_CLAUSE = "SELECT $columns_csv FROM $table";
            my $ORDER_CLAUSE = "";

	    my $x = DateTime::Format::MySQL->format_datetime( DateTime->from_epoch( epoch => $self->object_created_at ) );
            my ($WHERE_CLAUSE, @where_values) = ("created_at < ?", $x);

            if ($self->has_sql_order_clause) {
                $ORDER_CLAUSE = "ORDER BY " . $self->sql_order_clause;
            }

            if ($self->has_sql_where_clause) {
                my @w = @{$self->sql_where_clause};
                $WHERE_CLAUSE = "( $WHERE_CLAUSE ) AND ( " . shift(@w) . " )";
                push @where_values, @w;
            }

            return $dbh->selectall_arrayref("$SELECT_CLAUSE WHERE $WHERE_CLAUSE $ORDER_CLAUSE LIMIT ?,".$self->sql_batch_size, {Slice=>{}}, @where_values, $ext_cursor);
        }
    );

    $self->reified($rows);
    $self->_ext_cursor( $ext_cursor + @$rows );
    $self->_cursor( 0 );
    return $self;
}

1;
