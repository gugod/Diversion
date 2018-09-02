package Diversion::UrlArchiver {
    use v5.18;
    use Moo;
    with 'Diversion::Service';

    use HTTP::Tiny;
    use Encode;
    use JSON;
    use DBI;
    use DateTime;
    use DateTime::Format::MySQL;

    my $JSON = JSON->new->canonical->pretty;

    sub get_local {
        my ($self, $url) = @_;
        my $uri_id = Diversion::Lookup->new( what => "uri" )->lookup($url);

        my $row = $self->db_open(
            "url",
            sub {
                my ($dbh) = @_;
                return $dbh->selectrow_hashref(q{ SELECT response_sha1_digest,content_sha1_digest FROM uri_archive WHERE uri_id = ? ORDER BY updated_at DESC LIMIT 1}, {}, $uri_id);
            }
        );
        return undef unless $row;

        my $blob_store = $self->blob_store;
        if ((my $response = $blob_store->get($row->{response_sha1_digest})) &&
            (my $response_content = $blob_store->get($row->{content_sha1_digest}))) {
            my $r = $JSON->decode($response);
            $r->{content} = $response_content;
            return $r;
        }
        return undef;
    }

    sub get_remote {
        my ($self, $url) = @_;

        my $blob_store = $self->blob_store;

        my $response = HTTP::Tiny->new(
            timeout => 60,
            max_size => 512000,
            (agent => $ENV{DIVERSION_HTTP_USER_AGENT} || "Diversion ")
        )->get($url);

        return undef unless $response->{success};

        my $response_content = delete $response->{content};
        my $response_content_digest = $blob_store->put($response_content);

        my $response_digest = $blob_store->put("". $JSON->encode($response));

        my $uri_id = Diversion::Lookup->new( what => "uri" )->lookup($url);

        $self->db_open(
            "url",
            sub {
                my ($dbh) = @_;
                my $sth_check = $dbh->prepare(q{ SELECT 1 FROM uri_archive WHERE uri_id = ? AND content_sha1_digest = ? LIMIT 1});
                $sth_check->execute($uri_id, $response_content_digest);
                my $now = DateTime::Format::MySQL->format_datetime( DateTime->from_epoch( epoch => scalar time ) );
                if ($sth_check->fetchrow_array) {
                    $dbh->do(
                        q{ UPDATE uri_archive SET updated_at = ? WHERE uri_id = ? AND content_sha1_digest = ? },
                        {},
                        $now, $uri_id, $response_content_digest
                    );
                } else {
                    $dbh->do(
                        q{ INSERT INTO uri_archive(uri_id, created_at, updated_at, response_sha1_digest, content_sha1_digest) VALUES (?,?,?,?,?) },
                        {},
                        $uri_id, $now, $now, $response_digest, $response_content_digest
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
no Moo;
1;
