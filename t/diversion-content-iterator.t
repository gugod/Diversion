use v5.36;

use Diversion::App;
use Diversion::ContentIterator;

use File::XDG;
use TOML qw(from_toml);

my $xdg = File::XDG->new( name => "diversion" );

my $config_file = $xdg->config_home->file("config.toml");
my $config = from_toml(scalar $config_file->slurp);

my $app = Diversion::App->new->set_config($config);

my $iter = Diversion::ContentIterator->new();

while (my $row = $iter->next()) {
    say $row->{uri};
}
