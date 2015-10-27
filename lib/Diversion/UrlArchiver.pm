package Diversion::UrlArchiver {
    use v5.18;
    use Moo;
    with('Diversion::Db', 'Diversion::AppRole');

    use HTTP::Tiny;
    use Encode;
    use JSON;
    use DBI;
    use Digest::SHA1 'sha1_hex';
    use Data::Binary qw(is_binary);

    my $JSON = JSON->new->canonical->pretty;

    sub get_local {
        my ($self, $url) = @_;

        my $sha1_digest = $self->db_open(
            "url",
            sub {
                my ($dbh) = @_;
                my ($v) = @{$dbh->selectcol_arrayref(q{ SELECT sha1_digest FROM uri_archive WHERE uri = ? ORDER BY created_at DESC LIMIT 1},{}, $url)};
                return $v;
            }
        );
        return undef unless defined $sha1_digest;

        my $blob_store = $self->blob_store;
        if (my $response = $blob_store->get($sha1_digest)) {
            return $JSON->decode($response);
        }
        return undef;
    }

    sub get_remote {
        my ($self, $url) = @_;

        my $blob_store = $self->blob_store;

        my $response = HTTP::Tiny->new( timeout => 60, max_size => 409600 )->get($url);
        if (is_binary($response->{content})) {
            $response->{content} = { sha1_digest => $blob_store->put($response->{content}) };
        }
        my $response_digest = $blob_store->put("". $JSON->encode($response));

        $self->db_open(
            "url",
            sub {
                my ($dbh) = @_;
                my $sth_check = $dbh->prepare(q{ SELECT 1 FROM uri_archive WHERE uri = ? AND sha1_digest = ? LIMIT 1});
                $sth_check->execute($url, $response_digest);
                unless ($sth_check->fetchrow_array) {
                    my $sth_insert = $dbh->prepare(q{ INSERT INTO uri_archive(uri, created_at, sha1_digest) VALUES (?,?,?)});
                    $sth_insert->execute($url, 0+time, $response_digest);
                    $sth_insert->finish;
                }
                $sth_check->finish;
            }
        );

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
