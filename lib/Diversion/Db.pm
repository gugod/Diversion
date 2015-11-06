package Diversion::Db;
use Moo::Role;
use DBI;

use constant db_config => {
    content => [
        "dbi:SQLite:dbname=$ENV{HOME}/var/Diversion/db/content.sqlite3",
        undef, undef, { AutoCommit => 1 }
    ],
    feed => [
        "dbi:SQLite:dbname=$ENV{HOME}/var/Diversion/db/feed.sqlite3",
        undef, undef, { AutoCommit => 1 }
    ],
    url => [
        "dbi:SQLite:dbname=$ENV{HOME}/var/Diversion/db/url.sqlite3",
        undef, undef, { AutoCommit => 1 }
    ]
};

sub db_open {
    my ($self, $db_name, $cb) = @_;
    my $config = db_config->{$db_name} || die;
    my $dbh = DBI->connect( @$config );
    if ($cb) {
        my $ret = $cb->($dbh);
        $dbh->disconnect;
        return $ret;        
    } else {
        return $dbh;
    }
}

1;
