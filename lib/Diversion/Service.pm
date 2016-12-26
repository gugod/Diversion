package Diversion::Service;
use Moo::Role;
use Diversion::BlobStore;
use Diversion::App;
use DBI;

has blob_store => (
    is => "ro",
    default => sub {
        my $root = Diversion::App->config->{blob_store}{root} // "$ENV{HOME}/var/Diversion/blob_store/";
        return Diversion::BlobStore->new(root => $root);
    }
);

sub db_open {
    my ($self, $db_name, $cb) = @_;
    my $conf = Diversion::App->config->{database}{$db_name} || die "No config for $db_name";
    my $dbh = DBI->connect(
        $conf->{dsn},
        $conf->{username},
        $conf->{password},
        { AutoCommit => 1 }
    );
    if ($cb) {
        my $ret = $cb->($dbh);
        $dbh->disconnect;
        return $ret;        
    } else {
        return $dbh;
    }
}

1;
