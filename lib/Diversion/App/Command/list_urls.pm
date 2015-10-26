package Diversion::App::Command::list_urls;
use v5.18;
use Moo;
with 'Diversion::AppRole';
use Diversion::App -command;

use Diversion::UrlArchiveIterator;
use JSON::XS;

sub opt_spec {
    return (
        ["content-type=s", "Only the content-type"]
    )
}

sub execute {
    my ($self, $opt) = @_;
    my $JSON = JSON::XS->new;
    my $last = "";
    my $iter = Diversion::UrlArchiveIterator->new();
    while (my $row = $iter->next) {
        if ($opt->{content_type}) {
            my $blob = $self->blob_store->get($row->{sha1_digest});
            my $res = $JSON->decode( $blob );
            next unless defined($res->{headers}{"content-type"}) && index($res->{headers}{"content-type"}, $opt->{content_type}) > 0;
        }
        if ($last ne $row->{uri}) {
            say $last = $row->{uri};
        }
    }
}

1;
