package Diversion::BlobStore;
use Moo;
use Digest::SHA1 qw(sha1_hex);
use File::Next;
use File::Spec;
use File::Path qw(make_path);
use PerlIO::via::gzip;

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

sub _fh_ro {
    my ($self, $digest) = @_;
    my $fh;
    my $f = $self->_filename($digest);
    my $f_gz = $f . ".gz";
    if (-f $f_gz) {
	open $fh, "<:via(gzip)", $f_gz;
    } elsif (-f $f) {
	open $fh, "<", $f;
    }
    return $fh;
}

sub _fh_rw {
    my ($self, $digest) = @_;
    my ($path, $f) = $self->_filename($digest);
    my $f_gz = $f . ".gz";
    return undef if -f $f_gz || -f $f;
    make_path($path) unless -d $path;
    open(my $fh, ">", $f) or die $!;
    return $fh;
}

sub _filename {
    my ($self, $digest) = @_;
    my $pre  = substr($digest,0,4);
    my $suf = substr($digest,4);
    my $dir = File::Spec->catdir($self->root, $pre);
    my $file = File::Spec->catfile($dir, $suf);
    return ($dir, $file);
}

sub put {
    my ($self, $data) = @_;
    my $digest = $self->digest_function->($data);
    if (my $fh = $self->_fh_rw($digest)) {
	print $fh $data;
    }
    return $digest;
}

sub get {
    my ($self, $digest) = @_;
    my $fh = $self->_fh_ro($digest);
    if ($fh) {
	local $/ = undef;
	return scalar <$fh>;
    }
    return undef;
}

sub exists {
    my ($self, $digest) = @_;
    return $self->_fh_ro($digest) ? 1 : 0;
}

sub delete {
    my ($self, $digest) = @_;
    my $f = $self->_filename($digest);
    my $f_gz = $f . ".gz";
    if (-f $f_gz) {
        unlink($f_gz);
    }
    if (-f $f) {
        unlink($f);
    }
    return undef;
}

sub each {
    my ($self, $cb) = @_;
    my $files = File::Next::files( $self->root );
    my $prefix_length = length($self->root);
    while ( defined ( my $file = $files->() ) ) {
        my $digest = substr($file, $prefix_length, 4) . substr($file, $prefix_length + 5, 36);
        $cb->($digest);
    }
}

1;
