package Diversion::UrlArchiveIterator;
use v5.18;
use Moo;
use constant {
    database => "url",
    table => "uri_archive",
    columns => [qw(uri_id response_sha1_digest content_sha1_digest created_at)]
};
with 'Diversion::SingleTableIterator', 'Diversion::Service';

after 'reify' => sub {
    my ($self) = @_;
    my @uri_id = map { $_->{uri_id} } @{$self->reified};
    my $lk = Diversion::Lookup->new( what => "uri" );
    my $lookup = $lk->bulk_lookup_by_id(\@uri_id);
    for (@{$self->reified}) {
        $_->{uri} = $lookup->{$_->{uri_id}};
    }
};


1;
