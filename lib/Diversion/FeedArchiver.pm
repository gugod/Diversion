package Diversion::FeedArchiver {
    use Moo;
    use HTML::Restrict;
    use Encode;
    use Log::Any qw($log);

    use Diversion::FeedFetcher;
    use Diversion::UrlFetcher;
    use Diversion::ContentExtractor;

    with ('Diversion::ElasticSearchConnector');

    has url => (
        is => "ro",
        required => 1
    );

    has fetcher => (
        is => "lazy",
    );

    sub _build_fetcher {
        my ($self) = @_;
        return Diversion::FeedFetcher->new(url => $self->url);
    }

    sub create_index_unless_exists {
        my ($self) = @_;
        my $es = $self->elasticsearch;
        return if $es->exists;
        $es->put(
            index => "diversion",
            body => {
                settings => {
                    index => {
                        number_of_shards   => 8,
                        number_of_replicas => 0,
                    }
                },
            }
        );
    }

    sub fetch_then_archive {
        my ($self) = @_;

        $self->create_index_unless_exists;

        my %bulk;

        $self->fetcher->each_entry(
            sub {
                my ($entry, $i) = @_;

                my @t = (gmtime)[5,4,3,2,1,0];
                $t[0] += 1900;
                $t[1] += 1;
                my $now = sprintf("%4d-%02d-%02dT%02d:%02d:%02d", @t);

                my $data = { updated_at =>  $now };

                for (qw(title pubDate author id guid author category description)) {
                    $data->{$_} = $entry->{$_};
                }

                my $stripper = HTML::Restrict->new;
                $data->{description} = $stripper->process($data->{description});

                my $entry_link = $entry->{link};

                $bulk{$entry_link} = $data;
            }
        );

        my $es = $self->elasticsearch;
        $es->{index} = "diversion";
        $es->{type}  = "feed_entry";

        my @bulk_body = map { ({ index => { _id => $_ } }, $bulk{$_} ) } keys %bulk;
        if (@bulk_body) {
            my ($status, $res) = $es->bulk(body => \@bulk_body);
            if (substr($status,0,1) eq '2') {
                $log->debug("Success\n");
            } else {
                $log->debug("Failed" . $Elastijk::JSON->encode($res->{errors}) . "\n");
            }
        } else {
            $log->info("Nothing to update. All feed entries are the same as it was.");
        }
    }
};

1;
