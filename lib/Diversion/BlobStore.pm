package Diversion::BlobStore;
use Moo;
use Digest::SHA1 qw(sha1_hex);
use File::Spec;
use File::Path qw(make_path);
use PerlIO::via::gzip;

use RocksDB;

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

has db => ( is => "lazy" );

sub _build_db {
    my ($self) = @_;
    return RocksDB->new( $self->root, { create_if_missing => 1 });
}

sub put {
    my ($self, $data) = @_;
    my $digest = $self->digest_function->($data);
    $self->db->put("blob $digest", $data);
    return $digest;
}

sub get {
    my ($self, $digest) = @_;
    my $db = $self->db;
    my $k = "blob $digest";
    return $db->exists($k) ? $db->get($k) : undef;
}

1;
