use v5.14;

package Diversion::FeedArchiver {
    use Moo;
    with "Diversion::Service";

    use Encode;
    use IO::All;
    use Digest::SHA1 qw<sha1_hex>;
    use Sereal::Encoder;

    use Log::Any qw($log);

    use JSON;

    use Diversion::FeedFetcher;
    use Diversion::ContentExtractor;
    use Diversion::UrlArchiver;

    sub fetch_then_archive {
        my ($self, $url) = @_;

        my $JSON = JSON->new->canonical->utf8->pretty;

        $self->db_open(
            "feed",
            sub {
                my ($dbh) = @_;

                my $feed = Diversion::FeedFetcher->new(url => $url)->feed;
                my $digest = $self->blob_store->put( "". $JSON->encode( $feed ) );

                my ($exists) = @{ $dbh->selectcol_arrayref(q{ SELECT 1 FROM feed_archive WHERE uri = ? AND sha1_digest = ? LIMIT 1}) };
                return if $exists;
                $dbh->do(q{ INSERT INTO feed_archive(uri, created_at, sha1_digest) VALUES (?,?,?)}, {}, $url, 0+time, $digest);
            }
        );
    }
};

1;
