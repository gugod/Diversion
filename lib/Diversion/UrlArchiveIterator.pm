package Diversion::UrlArchiveIterator;
use v5.18;
use Moo;
use Diversion::UrlArchiver;

has _ext_cursor => (
    is => "rw",
    predicate => 1
);

has _cursor => (
    is => "rw",
    predicate => 1,
);

has reified => (
    is => "rw",
    default => sub { [ ] }
);

sub reify {
    my ($self) = @_;
    my $o = Diversion::UrlArchiver->new;
    my $ext_cursor = $self->_has_ext_cursor ? $self->_ext_cursor : 0;
    my $dbh = $o->dbh_index;
    my $rows = $dbh->selectall_arrayref("SELECT uri,sha1_digest,created_at FROM uri_archive ORDER BY uri ASC LIMIT ?,1000", {Slice=>{}}, $ext_cursor);
    $dbh->disconnect;

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
