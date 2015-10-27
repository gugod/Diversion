package Diversion::App::Command::url;
use v5.18;
use Moo;
with 'Diversion::AppRole', 'Diversion::Db';
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
            $res = $JSON->decode( $blob ) if $blob;
        }

        next if $opt->{content_type} && defined($res->{headers}{"content-type"}) && index($res->{headers}{"content-type"}, $opt->{content_type}) < 0;
        next if $opt->{only_binary} && !ref($res->{content});

        if ($last ne $row->{uri}) {
            say($last = $row->{uri});
            $self->blob_store->delete($row->{sha1_digest});
            $self->db_open(
                url => sub {
                    my ($dbh) = @_;
                    $dbh->do("DELETE FROM uri_archive WHERE sha1_digest = ?", {}, $row->{sha1_digest});
                }
            );
        }
    }
}

1;
