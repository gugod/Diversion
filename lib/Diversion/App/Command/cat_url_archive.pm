package Diversion::App::Command::cat_url_archive;
use v5.18;
use Diversion::App -command;
use Diversion::UrlArchiver;

sub execute {
    my ($self) = @_;
    my $dbh = Diversion::UrlArchiver->new->dbh_index;
    my $rows = $dbh->selectall_arrayref("SELECT distinct uri FROM uri_archive", {Slice=>{}});
    $dbh->disconnect;
    for my $row (@$rows) {
        say $row->{uri};
    }
}

1;
