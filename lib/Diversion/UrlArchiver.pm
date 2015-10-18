package Diversion::UrlArchiver {
    use v5.18;
    use Moo;
    use HTTP::Tiny;
    use Encode;
    use JSON;
    use DBI;
    use Digest::SHA1 'sha1_hex';
    use Data::Binary qw(is_binary);

    with 'Diversion::AppRole';

    my $JSON = JSON->new->canonical->pretty;

    has dbh_index =>  (
        is => "ro",
        default => sub {
            return DBI->connect(
                "dbi:SQLite:dbname=$ENV{HOME}/var/Diversion/url_archive/index.sqlite3",
                undef,
                undef,
                { AutoCommit => 1 }
            );
        }
    );

    sub get {
        my ($self, $url) = @_;

        my $blob_store = $self->blob_store;
        my $dbh = $self->dbh_index;

        my $sth_insert = $dbh->prepare(q{ INSERT INTO uri_archive(uri, created_at, sha1_digest) VALUES (?,?,?)});
        my $sth_check = $dbh->prepare(q{ SELECT 1 FROM uri_archive WHERE uri = ? AND sha1_digest = ? LIMIT 1});

        my $response = HTTP::Tiny->new( timeout => 60 )->get($url);

        if (is_binary($response->{content})) {
            $response->{content} = { sha1_digest => $blob_store->put($response->{content}) };
        }

        my $response_digest = $blob_store->put("". $JSON->encode($response));

        $sth_check->execute($url, $response_digest);
        if ($sth_check->fetchrow_array) {
            say "OLD $url";
        } else {
            $sth_insert->execute($url, 0+time, $response_digest);
            say "STORE $url " . ( ref($response->{content}) ? "#binary" : "" );
        }

        return $response;
    }
};
1;
