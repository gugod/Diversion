package Diversion::App::Command::list_urls;
use v5.18;
use Moo;
with 'Diversion::AppRole';
use Diversion::App -command;

use Diversion::UrlArchiveIterator;
use JSON::XS;

sub opt_spec {
    return (
        ["content-type=s", "Only the content-type"],
        ["only-binary", "Only binary"],
    )
}

sub execute {
    my ($self, $opt) = @_;
    my $JSON = JSON::XS->new;
    my $should_load_res = keys %$opt > 0;
    my $last = "";
    my $iter = Diversion::UrlArchiveIterator->new();
    while (my $row = $iter->next) {
        my $res;
        if ($should_load_res) {
            my $blob = $self->blob_store->get($row->{sha1_digest});
            $res = $JSON->decode( $blob );            
        }

        next if $opt->{content_type} && defined($res->{headers}{"content-type"}) && index($res->{headers}{"content-type"}, $opt->{content_type}) < 0;
        next if $opt->{only_binary} && !ref($res->{content});

        say($last = $row->{uri}) if $last ne $row->{uri};
    }
}

1;
