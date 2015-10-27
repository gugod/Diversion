package Diversion::App::Command::blob;
use v5.18;

use Moo;
with 'Diversion::AppRole', 'Diversion::Db';
use Diversion::App -command;

sub opt_spec {
    return (
    )
}

sub execute {
    my ($self, $opt) = @_;

    $self->blob_store->each(
        sub {
            my ($digest) = @_;
            say $digest;
        }
    );
}

1;
