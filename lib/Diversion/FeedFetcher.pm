use v5.14;

package Diversion::FeedFetcher {
    use Moo;
    use XML::Loy;
    use Encode qw();

    use Diversion::UrlArchiver;

    has url => (
        is => "ro",
        required => 1
    );

    has feed => (
        is => "lazy",
        predicate => "feed_is_fetched",
    );

    sub _build_feed {
        my ($self) = @_;

        my @entries;
        my $feed = { entry => \@entries };
        my $response = Diversion::UrlArchiver->new->get_remote( $self->url );

        die "Failed to retrieve ". $self->url ." : $response->{reason}" unless $response && $response->{success};
        die "Status Not OK: " . $self->url . " : $response->{reason}" unless $response->{status} == 200;

        my ($enc) = $response->{content} =~ m!\A.+encoding="([^"]+)"!;
        $enc ||= "utf-8";
        $enc = lc($enc);

        my $feed_content =  Encode::decode($enc, $response->{content});

        my $xloy = XML::Loy->new( $feed_content );
        my $root;
        if ($root = $xloy->find("rss")->[0]) {
            for my $tag ("title", "description", "updated") {
                if (my $e = $root->find($tag)->[0]) {
                    $feed->{$tag} = $e->all_text;
                }
            }
        }
        elsif ($root = $xloy->find("feed")->[0]) {
            for my $tag ("id", "title", "description", "updated") {
                if (my $e = $root->find($tag)->[0]) {
                    $feed->{$tag} = $e->all_text;
                }
            }
        }

        $xloy->find("item, entry")->each(
            sub {
                my $el = $_[0];
                push @entries, my $entry = {};

                for my $tag ("content", "thumbnail") {
                    my $e2 = $el->find($tag)->[0];
                    if ($e2) {
                        $entry->{"media_$tag"} = $e2->attr("url");
                    }
                }

                for my $tag ("category", "creator", "author", "title", "link", "description", "summary", "pubDate", "updated") {
                    my $e2 = $el->find($tag)->[0];
                    if ($e2) {
                        $entry->{$tag} = $e2->all_text =~ s!\A\s+!!r =~ s!\s+$!!r;
                    }
                }

                unless ($entry->{link}) {
                    for my $e2 ($el->find("link")->each) {
                        my $type = $e2->attr("type") or next;
                        my $rel = $e2->attr("rel")   or next;
                        if ($type eq "text/html" && $rel eq "alternate") {
                            $entry->{link} = $e2->attr("href");
                        }
                    }
                }

                $entry->{description} = Mojo::DOM->new("<div>" . ($entry->{description}//"") . "</div>")->all_text;

                for (keys %$entry) {
                    $entry->{$_} = Encode::decode_utf8($entry->{$_}) unless Encode::is_utf8($entry->{$_});
                }
                $entry->{title} =~ s!\n! !g;
            }
        );

        return $feed;
    }

    sub each_entry {
        my ($self, $cb) = @_;
        return @{ $self->feed->{entry} } if !$cb;
        return unless ref($cb) eq 'CODE';

        my @entries = @{ $self->feed->{entry} };
        for my $i (0..$#entries) {
            $cb->($entries[$i], $i);
        }
        return $self;
    }

};

no Moo;
1;
