package Diversion::UrlArchiver {
    use v5.18;
    use Moo;
    with 'Diversion::Service';

    use HTTP::Tiny;
    use Encode;
    use JSON;
    use DBI;
    use Digest::SHA1 'sha1_hex';
    use Data::Binary qw(is_binary);

    my $JSON = JSON->new->canonical->pretty;

    sub get_local {
        my ($self, $url) = @_;

        my $response_sha1_digest = $self->db_open(
            "url",
            sub {
                my ($dbh) = @_;
                my ($v) = @{$dbh->selectcol_arrayref(q{ SELECT response_sha1_digest FROM uri_archive WHERE uri = ? ORDER BY updated_at DESC LIMIT 1},{}, $url)};
                return $v;
            }
        );
        return undef unless defined $response_sha1_digest;

        my $blob_store = $self->blob_store;
        if (my $response = $blob_store->get($response_sha1_digest)) {
            return $JSON->decode($response);
        }
        return undef;
    }

    sub get_remote {
        my ($self, $url) = @_;

        my $blob_store = $self->blob_store;

        my $response = HTTP::Tiny->new( timeout => 60, max_size => 512000, (agent => $ENV{DIVERSION_HTTP_USER_AGENT} || "Diversion ") )->get($url);
        my $response_content = delete $response->{content};
        my $response_content_digest = $blob_store->put($response_content);

        my $response_digest = $blob_store->put("". $JSON->encode($response));

        $self->db_open(
            "url",
            sub {
                my ($dbh) = @_;
                my $sth_check = $dbh->prepare(q{ SELECT 1 FROM uri_archive WHERE uri = ? AND content_sha1_digest = ? LIMIT 1});
                $sth_check->execute($url, $response_content_digest);
                my $now = 0+time;
                if ($sth_check->fetchrow_array) {
                    $dbh->do(
                        q{ UPDATE uri_archive SET updated_at = ? WHERE uri = ? AND content_sha1_digest = ? },
                        {},
                        $now, $url, $response_content_digest
                    );
                } else {
                    $dbh->do(
                        q{ INSERT INTO uri_archive(uri, created_at, updated_at, response_sha1_digest, content_sha1_digest) VALUES (?,?,?,?,?) },
                        {},
                        $url, $now, $now, $response_digest, $response_content_digest
                    );
                }
                $sth_check->finish;
            }
        );

        $response->{content} = $response_content;
        return $response;
    }

    sub get {
        my ($self, $url) = @_;
        my $response = $self->get_local($url);
        return $response if defined $response;
        return $self->get_remote($url);
    }
};
1;
