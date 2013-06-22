use v5.14;

package Diversion::FeedFetcher {
    use Moose;
    use XML::Feed;
    use URI;

    has url => (
        is => "ro",
        isa => "Str",
        required => 1
    );

    has feed => (
        is => "ro",
        isa => "XML::Feed",
        lazy_build => 1,
    );

    sub _build_feed {
        my ($self) = @_;
        return XML::Feed->parse( URI->new( $self->url ) );
    }

    sub each_entry {
        my ($self, $cb) = @_;
        my $feed = $self->feed;
        my @entries = $feed->entries;
        for my $i (0..$#entries) {
            $cb->($entries[$i], $i);
        }
        return $self;
    }

};

1;
