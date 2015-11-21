package Diversion::DistinctUrlIterator;
use v5.18;
use Moo;
with 'Diversion::Iterator', 'Diversion::Service';

use JSON::XS;
use Diversion::UrlArchiveIterator;

my $JSON = JSON::XS->new;

has url_archive_iterator => (
    is => "ro",
    default => sub { Diversion::UrlArchiveIterator->new( sql_order_clause => "uri, created_at DESC" ) }
);

sub reify {
    my ($self) = @_;
    my $rows = [];
    my $iter = $self->url_archive_iterator;
    my $last = $iter->next;
    while ((@$rows < 1) && (my $row = $iter->next)) {
        next unless $row->{uri} =~ /^https?:/;
        next if $last->{uri} eq $row->{uri};
        if ($self->blob_store->exists($last->{sha1_digest})) {
            push(@$rows, $last);
        } else {
            warn "Blob is missing: $last->{sha1_digest} $last->{uri}";
        }
        $last = $row;
    }
    $self->reified($rows);
    $self->_cursor(0);
    return $self;
}

1;
