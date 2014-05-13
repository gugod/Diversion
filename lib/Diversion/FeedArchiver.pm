use v5.14;

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

    sub BUILD {
        my $self = shift;
        my $es = $self->elasticsearch;
        $es->{index} = "diversion";
    }

    sub _build_fetcher {
        my ($self) = @_;
        return Diversion::FeedFetcher->new(url => $self->url);
    }

    sub create_index_unless_exists {
        my ($self) = @_;
        my $es = $self->elasticsearch;
        return if $es->exists();
        $es->put(
            index => "diversion",
            body => {
                settings => {
                    index => {
                        number_of_shards   => 8,
                        number_of_replicas => 0,
                    }
                },
                mappings => {
                    feed_entry => {
                        _timestamp => { enabled => 1, path => "last_seen" },
                        properties => {
                            first_seen => { type => "date", first_seen => "basic_date_time_no_millis" },
                            last_seen =>  { type => "date", first_seen => "basic_date_time_no_millis" },

                            guid => { type => "string", index => "not_analyzed" },
                            title => { type => "string" },
                            description => { type => "string" },
                            category => { type => "string" },
                            author => { type => "string" },
                        }
                    }
                }
            }
        );
    }

    sub fetch_then_archive {
        my ($self) = @_;

        $self->create_index_unless_exists;

        my %bulk;

        my @t = (gmtime)[5,4,3,2,1,0];
        $t[0] += 1900;
        $t[1] += 1;
        my $now = sprintf("%4d-%02d-%02dT%02d:%02d:%02dZ", @t);
        my $stripper = HTML::Restrict->new;

        $self->fetcher->each_entry(
            sub {
                my ($entry, $i) = @_;
                my $data = { last_seen => $now };
                $data->{$_} = $entry->{$_} for qw(title pubDate author id guid category);
                $data->{$_} = $stripper->process($entry->{$_}) for qw(description summary);
                $data->{author} = $entry->{author} || $entry->{creator};
                $bulk{ $entry->{link} } = $data;
            }
        );

        my $es = $self->elasticsearch;
        my @bulk_body = map {
            ({ update => { _id => $_ } },
             { doc => $bulk{$_}, upsert => { first_seen => $now, %{ $bulk{$_} } } })
        } keys %bulk;
        if (@bulk_body) {
            my ($status, $res) = $es->bulk( type => "feed_entry", body => \@bulk_body );
            if (substr($status,0,1) eq '2' && !$res->{errors}) {
                $log->debug("Success\n");
            } else {
                $log->debug("Failed" . $Elastijk::JSON->encode($res) . "\n");
            }
        } else {
            $log->info("Nothing to update. All feed entries are the same as it was.");
        }
    }
};

1;
