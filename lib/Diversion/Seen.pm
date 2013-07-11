package Diversion::Seen;
use Moo;
use IO::All;
use Sereal qw(encode_sereal decode_sereal looks_like_sereal);

has file => ( is => "ro", required => 1 );

has _data => ( is => "rw" );

has dirtiness => (
    is => "rw",
    default => sub { 0 }
);

has tolorance => (
    is => "rw",
    default => sub { 99 }
);

has expiry => (
    is => "ro",
    default => sub { 365*86400 }
);

sub BUILD {
    my ($self) = @_;

    if ( -f $self->file ) {
        my $data = io( $self->file )->all;
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
    $self->dirtiness( ($self->dirtiness||0) + 1 );
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
    my $now = time;
    my $d = $self->_data;
    for my $k (keys %$d) {
        if ( ($now - $d->{$k}) > $self->expiry) {
            delete $d->{$k}
        }
    }

    io($self->file)->assert->print(encode_sereal( $self->_data ));
    $self->dirtiness( 0 );
}

1;
