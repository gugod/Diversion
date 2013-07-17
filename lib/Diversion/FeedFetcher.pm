use v5.14;

package Diversion::FeedFetcher {
    use Moo;
    use XML::FeedPP;
    use Encode qw(decode);

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
        my $feed = XML::FeedPP->new( $self->url );
        $feed->xmlns( "xmlns:media" => "http://search.yahoo.com/mrss" );
        return $feed;
    }

    sub each_entry {
        my ($self, $cb) = @_;
        return unless ref($cb) eq 'CODE';

        my @entries = $self->feed->get_item;
        for my $i (0..$#entries) {
            my $entry = $entries[$i];

            for (qw(title pubDate author guid author category description)) {
                my $v = $entry->$_ or next;
                if (ref($v) eq 'HASH' && $v->{'#text'}) {
                    $v = $v->{'#text'};
                    $v = decode('utf8', $v) unless Encode::is_utf8($v);
                }
                if (ref($v) eq 'ARRAY') {
                    @$v = map { $_ = decode('utf8', $_) unless Encode::is_utf8($_); $_ } @$v;
                }
                unless (ref($v)) {
                    $v = decode("utf8" => $v) unless Encode::is_utf8($v);
                }
                $entry->$_($v);
            }

            $cb->($entry, $i);
        }
        return $self;
    }

};

1;
