package Diversion::App::Command::url;
# ABSTRACT: List all urls in database (one url per line)
use v5.18;
use Moo;
with 'Diversion::Service';
use Diversion::App -command;

use Diversion::UrlArchiveIterator;
use JSON::XS;
use URI::Split qw(uri_split);

sub opt_spec {
    return (
        ["aggregation=s", "Do aggregation"],
        ["only-host=s", "Only the URL from this host"],
        ["only-content-type=s", "Only the specify content-type"],
        ["only-binary", "Only binary"],
        ["only-missing-blob", "Only the one with missing blob."],
        ["show-status-code", "Show status code"],
        ["delete", "Delete what's found"],
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
            my $blob = $self->blob_store->get($row->{response_sha1_digest});
            if (defined($blob)) {
                $res = $JSON->decode( $blob );
                next if $opt->{only_missing_blob};
            } elsif ($opt->{only_missing_blob}) {
                say( $row->{response_sha1_digest} . "\t" . $row->{uri} );
                if ($opt->{delete}) {
                    $self->delete_blob_and_uri_archive_reference($row->{response_sha1_digest});
                }
                next;
            }
        }

        if ($opt->{only_host}) {
            my $host = (uri_split($row->{uri}))[1] // "";
            next unless $host && $host eq $opt->{only_host};
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
                $self->delete_blob_and_uri_archive_reference($row->{response_sha1_digest});
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

sub delete_blob_and_uri_archive_reference {
    my ($self, $sha1_digest) = @_;
    $self->blob_store->delete($sha1_digest);
    $self->db_open(
        url => sub {
            my ($dbh) = @_;
            $dbh->do("DELETE FROM uri_archive WHERE response_sha1_digest = ?", {}, $sha1_digest);
        }
    );
}

no Moo;
1;
