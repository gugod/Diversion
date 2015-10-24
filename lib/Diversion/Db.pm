package Diversion::Db;
use Moo::Role;
use DBI;

use constant db_config => {
    feed => [
        "dbi:SQLite:dbname=$ENV{HOME}/var/Diversion/feed_archive/index.sqlite3",
        undef, undef, { AutoCommit => 1 }
    ],
    url => [
        "dbi:SQLite:dbname=$ENV{HOME}/var/Diversion/url_archive/index.sqlite3",
        undef, undef, { AutoCommit => 1 }
    ]
};

sub db_open {
    my ($self, $db_name, $cb) = @_;
    my $config = db_config->{$db_name} || die;
    my $dbh = DBI->connect( @$config );
    my $ret = $cb->($dbh);
    $dbh->disconnect;
    return $ret;
}

1;
