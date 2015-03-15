package Diversion::App;
use App::Cmd::Setup -app;

sub set_config {
    my ($self, $config) = @_;
    $self->{_app}{config} = $config;
    return $self;
}

sub config {
    my ($self) = @_;
    return $self->{_app}{config} //= {};
}

1;
