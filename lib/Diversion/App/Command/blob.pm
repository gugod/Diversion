package Diversion::App::Command::blob;
use v5.18;

use Moo;
with 'Diversion::Service';
use Diversion::App -command;

sub opt_spec {
    return (
        ["orphan", "List blob id that are not referenced anywhere"],
        ["delete", "Delete the blob"],
    )
}

sub execute {
    my ($self, $opt) = @_;

    if ($opt->{orphan}) {
        my $dbh_url = $self->db_open('url');
        my $dbh_feed = $self->db_open('feed');
        $self->blob_store->each(
            sub {
                my ($digest) = @_;
                my $x = $dbh_url->selectcol_arrayref(q{ SELECT 1 from uri_archive WHERE sha1_digest = ? LIMIT 1}, {}, $digest);
                return if $x->[0];

                my $y = $dbh_feed->selectcol_arrayref(q{ SELECT 1 from feed_archive WHERE sha1_digest = ? LIMIT 1}, {}, $digest);
                return if $y->[0];

                say $digest;
                if ($opt->{delete}) {
                    $self->blob_store->delete($digest);
                }
            }
        );
        $dbh_url->disconnect;
        $dbh_feed->disconnect;
    } else {
        $self->blob_store->each(sub {my ($digest) = @_; say $digest });
    }
}

1;
