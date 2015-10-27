package Diversion::App::Command::blob;
use v5.18;

use Moo;
with 'Diversion::AppRole', 'Diversion::Db';
use Diversion::App -command;

sub opt_spec {
    return (
        ["orphan", "List blob id that are not referenced anywhere"],
    )
}

sub execute {
    my ($self, $opt) = @_;

    if ($opt->{orphan}) {
        $self->db_open(
            url =>
            sub {
                my ($dbh_url) = @_;
                $self->db_open(
                    feed =>
                    sub {
                        my ($dbh_feed) = @_;

                        $self->blob_store->each(
                            sub {
                                my ($digest) = @_;
                                my $x = $dbh_url->selectcol_arrayref(q{ SELECT 1 from uri_archive WHERE sha1_digest = ? LIMIT 1}, {}, $digest);
                                my $y = $dbh_feed->selectcol_arrayref(q{ SELECT 1 from feed_archive WHERE sha1_digest = ? LIMIT 1}, {}, $digest);
                                say $digest unless $x->[0] || $y->[0];
                            }
                        );
                    }
                );
            }
        );
    } else {
        $self->blob_store->each(sub {my ($digest) = @_; say $digest });
    }
}

1;
