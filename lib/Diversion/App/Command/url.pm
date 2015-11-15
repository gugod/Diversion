package Diversion::App::Command::url;
use v5.18;
use Moo;
with 'Diversion::AppRole', 'Diversion::Db';
use Diversion::App -command;

use Diversion::UrlArchiveIterator;
use JSON::XS;
use URI::Split qw(uri_split);

sub opt_spec {
    return (
        ["aggregation=s", "Do aggregation"],
        ["only-content-type=s", "Only the specify content-type"],
        ["only-binary", "Only binary"],
        ["show-status-code", "Show status code"],
    )
}

sub execute {
    my ($self, $opt) = @_;
    my $JSON = JSON::XS->new;
    my $should_load_res = keys %$opt > 0;
    my $last = "";
    my $iter = Diversion::UrlArchiveIterator->new();
    my %aggs;

    while (my $row = $iter->next) {
        my $res;
        if ($should_load_res) {
            my $blob = $self->blob_store->get($row->{sha1_digest});
            $res = $JSON->decode( $blob ) if $blob;
        }

        next if $opt->{only_content_type} && defined($res->{headers}{"content-type"}) && index($res->{headers}{"content-type"}, $opt->{only_content_type}) < 0;
        next if $opt->{only_binary} && !ref($res->{content});

        if ($last ne $row->{uri}) {
            $last = $row->{uri};

            if ($opt->{aggregation}) {
                if ($opt->{aggregation} eq 'host') {
                    my $host = (uri_split($row->{uri}))[1] // "";
                    $aggs{host}{$host}++;
                }
                next;
            }

            if ($opt->{show_status_code}) {
                say $res->{status}, "\t", $last;
            } else {
                say $last;
            }
            if ($opt->{delete}) {
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

    if (%aggs) {
        for my $k (keys %aggs) {
            for my $bucket (sort { $aggs{$k}{$b} <=> $aggs{$k}{$a} } keys %{$aggs{$k}}) {
                say $aggs{$k}{$bucket} . "\t" . $bucket, "\t";
            }
        }
    }
}

1;
