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
        return if $self->elasticsearch->index_exists(index => "diversion");
        $self->elasticsearch->create_index(index => "diversion");
    }

    sub fetch_then_archive {
        my ($self) = @_;

        $self->create_index_unless_exists;

        my %bulk_actions;

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

                $bulk_actions{$entry_link} = {
                    index => {
                        id => $entry_link,
                        data => $data
                    }
                };
            }
        );

        my @entry_urls = keys %bulk_actions;

        my $existing_doc = $self->elasticsearch->mget(
            index => "diversion",
            type => "feed_entry",
            ids => \@entry_urls
        );

        for my $d (@$existing_doc) {
            if ($d->{exists}) {
                my $new_is_old = 1;
                my $new_data = $bulk_actions{$d->{_id}}{index}{data};
                $new_data->{created_at} = $d->{_source}{created_at};
                for (keys %{$d->{_source}}) {
                    next if $_ eq "updated_at";
                    next if $_ =~ /^x_/;

                    if (defined($d->{_source}{$_}) && defined($new_data->{$_}) && $d->{_source}{$_} ne $new_data->{$_}) {
                        $new_is_old = 0;
                        last;
                    }
                }
                if ($new_is_old) {
                    delete $bulk_actions{$d->{_id}};
                }
            }
        }

        if (my @bulk_actions = values %bulk_actions) {
            for (@bulk_actions) {
                my $data = $_->{index}{data};
                my $entry_link = $_->{index}{id};

                $data->{created_at} ||= $data->{updated_at};

                eval {
                    $log->info("Extracting $entry_link");
                    my $extractor = Diversion::ContentExtractor->new(
                        content => Diversion::UrlFetcher->new( url => $entry_link )->content
                    );
                    $data->{x_text}  = $extractor->text;
                    $data->{x_title} = $extractor->title;
                    $log->debug("    Extracted. title= $data->{x_title}");
                    $log->debug("    Extracted. text= " . substr($data->{x_text}, 0, 140) );
                    1;
                } or do {
                    $self->error("ERROR: $@");
                };
            }

            $self->elasticsearch->bulk(
                actions => \@bulk_actions,
                index   => "diversion",
                type    => "feed_entry"
            );
        }
        else {
            $log->info("Nothing to update. All feed entries are the same as it was.");
        }
    }
};

1;
