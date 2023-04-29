package Diversion::DistinctUrlIterator;
use v5.36;
use Moo;
with 'Diversion::Iterator', 'Diversion::Service';

use Diversion::UrlArchiveIterator;

has sql_where_clause => (
    is => "ro",
    predicate => 1,
);

has url_archive_iterator => (
    is => "ro",
    default => sub {
        my ($self) = @_;
        Diversion::UrlArchiveIterator->new(
            sql_order_clause => "uri, created_at DESC",
            ($self->has_sql_where_clause) ? (
                sql_where_clause => $self->sql_where_clause
            ):()
        )
    }
);

sub reify {
    my ($self) = @_;
    my $rows = [];
    my $iter = $self->url_archive_iterator;
    my $last = $iter->next;
    while ((@$rows < 1) && (my $row = $iter->next)) {
        next unless $row->{uri} =~ /^https?:/;
        next if $last->{uri} eq $row->{uri};
        if ($self->blob_store->exists($last->{response_sha1_digest})) {
            push(@$rows, $last);
        } else {
            warn "Blob is missing: $last->{response_sha1_digest} $last->{uri}";
        }
        $last = $row;
    }
    $self->reified($rows);
    $self->_cursor(0);
    return $self;
}

no Moo;
1;
