package Diversion::Iterator;
use v5.36;
use Moo::Role;

requires 'reify';

has object_created_at => (
    is => "ro",
    default => sub { scalar time }
);

has _cursor => (
    is => "rw",
    predicate => 1,
);

has reified => (
    is => "rw",
    default => sub { [ ] }
);

sub next {
    my ($self) = @_;

    $self->reify unless $self->_has_cursor;

    my $i = $self->_cursor;
    if ($i == @{$self->reified}) {
        $self->reify;
        $i = $self->_cursor;
    }
    $self->_cursor($i+1);
    return $self->reified->[$i];
}

1;
