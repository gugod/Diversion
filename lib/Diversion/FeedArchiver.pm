use v5.14;

package Diversion::FeedArchiver {
    use Moo;

    use Encode;
    use IO::All;
    use Digest::SHA1 qw<sha1_hex>;
    use Sereal::Encoder;
    
    use Log::Any qw($log);

    use JSON;

    with "Diversion::AppRole";

    use Diversion::FeedFetcher;
    use Diversion::UrlFetcher;
    use Diversion::ContentExtractor;
    use Diversion::UrlArchiver;
 
    has dbh_index => (
        is => "ro",
        default => sub {
            return DBI->connect(
                "dbi:SQLite:dbname=$ENV{HOME}/var/Diversion/feed_archive/index.sqlite3",
                undef,
                undef,
                { AutoCommit => 1 }
            );
        }
    );

    sub fetch_then_archive {
        my ($self, $url) = @_;

        my $JSON = JSON->new->canonical->utf8->pretty;

        my $dbh = $self->dbh_index;
        my $sth_insert = $dbh->prepare(q{ INSERT INTO feed_archive(uri, created_at, entry_sha1_digest) VALUES (?,?,?)});
        my $sth_check = $dbh->prepare(q{ SELECT 1 FROM feed_archive WHERE uri = ? AND entry_sha1_digest = ? LIMIT 1});

        Diversion::FeedFetcher->new(url => $url)->each_entry(
            sub {
                my ($entry, $i) = @_;
                my $digest = $self->blob_store->put( $JSON->encode($entry) );
                $sth_check->execute($entry->{link}, $digest);
                unless ($sth_check->fetchrow_array) {
                    $sth_insert->execute(
                        $entry->{link},
                        0+time,
                        $digest
                    );
                }
            }
        );
    }
};

1;
