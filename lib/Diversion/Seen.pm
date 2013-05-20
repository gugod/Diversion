package Diversion::Seen;
use Moo;
use File::Slurp qw(read_file write_file);
use Sereal qw(encode_sereal decode_sereal looks_like_sereal);

has file => ( is => "ro", required => 1 );

has _data => ( is => "rw" );

has dirtiness => (
    is => "rw",
    default => 0
);

has tolorance => (
    is => "rw",
    default => 99
);

sub BUILD {
    my ($self) = @_;

    if ( -f $self->file ) {
        my $data = read_file( $self->file );
        if (looks_like_sereal($data)) {
            $self->_data( decode_sereal($data) );
        } else {
            die "The content in file is not recognized.";
        }
    }
    else {
        $self->_data({});
        $self->save;
    }

    return $self;
}

sub DEMOLISH {
    my ($self) = @_;
    $self->save;
}

sub add {
    my ($self, $key) = @_;
    $self->_data->{$key} = time;
    $self->dirtiness( $self->dirtiness + 1 );
    if ($self->dirtiness > $self->tolorance) {
        $self->save;
    }
    return $self->_data->{$key}
}

sub get {
    my ($self, $key) = @_;
    return $self->_data->{$key};
}

sub save {
    my ($self) = @_;
    write_file( $self->file, encode_sereal( $self->_data ) );
    $self->dirtiness( 0 );
}

1;
