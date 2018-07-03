package Diversion::FeedUrlIterator;
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
        if (my $blob = $self->blob_store->get($last->{response_sha1_digest})) {
            my $res = $JSON->decode( $blob );
            push(@$rows, $last) if defined($res->{headers}{"content-type"}) && $res->{headers}{"content-type"} =~ /atom|rss/;
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
