package Diversion::App::Command::cat_url_archive;
use v5.18;
use Diversion::App -command;

use Diversion::UrlArchiver;
use JSON::XS;

sub opt_spec {
    return (
        ["content-type=s", "Only the content-type"]
    )
}

sub execute {
    my ($self, $opt) = @_;
    my $o = Diversion::UrlArchiver->new;
    my $dbh = $o->dbh_index;
    my $rows = $dbh->selectall_arrayref("SELECT uri,sha1_digest,created_at FROM  uri_archive ORDER BY uri ASC, created_at DESC", {Slice=>{}});
    my $JSON = JSON::XS->new;

    my $last = "";
    for my $row (@$rows) {
        if ($opt->{content_type}) {
            my $blob = $o->blob_store->get($row->{sha1_digest});
            my $res = $JSON->decode( $blob );
            next unless index($res->{headers}{"content-type"}, $opt->{content_type}) > 0;
        }
        if ($last ne $row->{uri}) {
            say $last = $row->{uri};
        }
    }

    $dbh->disconnect;
}

1;
