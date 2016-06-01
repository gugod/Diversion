package Diversion::App;
use App::Cmd::Setup -app;

my $CONFIG = {};
sub set_config {
    my ($self, $config) = @_;
    $CONFIG = $self->{_app}{config} = $config;

    for my $n (qw(content feed url)) {
        $CONFIG->{database}{$n}{dsn} //= "dbi:SQLite:dbname=$ENV{HOME}/var/Diversion/db/$n.sqlite3";
    }
    return $self;
}

sub config {
    my ($self) = @_;
    return $CONFIG;
}

1;
