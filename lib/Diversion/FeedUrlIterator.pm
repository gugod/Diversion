package Diversion::FeedUrlIterator;
use v5.18;
use Moo;
with 'Diversion::Iterator', 'Diversion::AppRole';

use JSON::XS;
use Diversion::UrlArchiveIterator;

my $JSON = JSON::XS->new;

has url_archive_iterator => (
    is => "ro",
    default => sub { Diversion::UrlArchiveIterator->new( sql_order_clause => "uri" ) }
);

sub reify {
    my ($self) = @_;
    my $rows = [];
    my $iter = $self->url_archive_iterator;
    my $last = "";
    while ((@$rows < 10) && (my $row = $iter->next)) {
        next unless $row->{uri} =~ /^https?:/ && $last ne $row->{uri};
        my $blob = $self->blob_store->get($row->{sha1_digest});
        unless (defined($blob)) {
            warn "Blob is missing: $row->{sha1_digest} $row->{uri}";
            next;
        }
        my $res = $JSON->decode( $blob );
        next unless defined($res->{headers}{"content-type"}) && $res->{headers}{"content-type"} =~ /atom|rss/;

        $last = $row->{uri};
        push @$rows, $row;
    }
    $self->reified($rows);
    $self->_cursor(0);
    return $self;
}

1;
