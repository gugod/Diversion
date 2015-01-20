package Diversion::BlobStore;
use Moo;
use Digest::SHA1 qw(sha1_hex);
use IO::All;

has root => (
    is => "rw",
    required => 1,
);

sub put {
    my ($self, $data) = @_;
    my $digest = sha1_hex($data);

    my $o = io->catfile($self->root, $digest);
    $o->assert->print($data) unless $o->exists;

    return $digest;
}

sub get {
    my ($self, $digest) = @_;
    my $o = io->catfile($self->root, $digest);
    return undef unless $o->exists;
    return $o->all;
}

sub get_path {
    my ($self, $digest) = @_;
    my $o = io->catfile($self->root, $digest);
    return undef unless $o->exists;
    return $o->pathname;
}

1;
