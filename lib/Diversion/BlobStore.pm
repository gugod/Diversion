package Diversion::BlobStore;
use Moo;
use Digest::SHA1 qw(sha1_hex);
use IO::All;

has root => (
    is => "rw",
    required => 1,
);

has digest_function => (
    is => "ro",
    default => sub {
        return \&sha1_hex
    }
);

sub _io {
    my ($self, $digest) = @_;
    my @s = grep $_, split /(....)/, $digest;
    my $o = io->catfile($self->root, @s);
    return $o;
}

sub put {
    my ($self, $data) = @_;
    my $digest = $self->digest_function->($data);
    my $o = $self->_io($digest);
    $o->assert->print($data) unless $o->exists;
    return $digest;
}

sub get {
    my ($self, $digest) = @_;
    my $o = $self->_io($digest);
    return undef unless $o->exists;
    return $o->all;
}

sub get_path {
    my ($self, $digest) = @_;
    my $o = $self->_io($digest);
    return undef unless $o->exists;
    return $o->pathname;
}

1;
