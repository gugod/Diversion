package Diversion::FeedArchiver {
    use Moo;
    use ElasticSearch;
    use Encode;
    use HTML::Restrict;

    use Diversion::FeedFetcher;

    has url => (
        is => "ro",
        required => 1
    );

    has fetcher => (
        is => "lazy",
    );

    has elasticsearch => (
        is => "lazy"
    );

    sub _build_fetcher {
        my ($self) = @_;
        return Diversion::FeedFetcher->new(url => $self->url);
    }

    sub _build_elasticsearch {
        my ($self) = @_;
        return ElasticSearch->new();
    }

    sub run {
        my ($self) = @_;

        my @bulk_actions;

        $self->fetcher->each_entry(
            sub {
                my ($entry, $i) = @_;

                my $data = {
                    created_at => time,
                };

                for (qw(title pubDate author guid author category description)) {
                    my $v = $entry->$_ or next;
                    if (ref($v) eq 'HASH' && $v->{'#text'}) {
                        $v = decode 'utf8', $v->{'#text'};
                    }
                    if (ref($v) eq 'ARRAY') {
                        @$v = map { $_ = decode('utf8', $_) } @$v;
                    }
                    unless (ref($v)) {
                        $v = decode "utf8" => $v;
                    }
                    $data->{$_} = $v;
                }

                my $stripper = HTML::Restrict->new;
                $data->{description} = $stripper->process($data->{description});

                push @bulk_actions, {
                    index => {
                        id => $entry->link,
                        data => $data
                    }
                };
            }
        );

        $self->elasticsearch->bulk(
            actions => \@bulk_actions,
            index   => "diversion",
            type    => "feed_entry"
        );
    }
};

1;
