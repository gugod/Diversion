package Diversion::UrlArchiver {
    use v5.18;
    use Moo;
    use HTTP::Tiny;
    use Encode;
    use JSON;
    use DBI;
    use Digest::SHA1 'sha1_hex';

    use Diversion::BlobStore;

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

    has blob_store => (
        is => "ro",
        default => sub {
            return Diversion::BlobStore->new(
                root => "$ENV{HOME}/var/Diversion/blob_store/"
            );
        }
    );

    sub get {
        my ($self, $url) = @_;
        my $blob_store = $self->blob_store;
        my $http = HTTP::Tiny->new( timeout => 6 );
        my $JSON = JSON->new->canonical->pretty;
        my $response = $http->get($url);
        my $dbh = $self->dbh_index;
        my $sth_insert = $dbh->prepare(q{ INSERT INTO uri_archive(uri, created_at, content_sha1_digest, header_sha1_digest) VALUES (?,?,?,?)});
        my $sth_check = $dbh->prepare(q{ SELECT 1 FROM uri_archive WHERE uri = ? AND content_sha1_digest = ? LIMIT 1});

        if ( $response->{status} eq '200' ) {
            my $header_dump_json = $JSON->encode($response->{headers});
            my $header_digest = $blob_store->put($header_dump_json);
            my $content_digest = $blob_store->put($response->{content});

            $sth_check->execute($url, $content_digest);
            if ($sth_check->fetchrow_array) {
                say "OLD $url";
            } else {
                $sth_insert->execute($url, 0+time, $content_digest, $header_digest);
                say "NEW $url";
            }
        } else {
            say "ERROR: $response->{status}";
        }

        return $response;
    }

    sub put {
    }

};
1;
