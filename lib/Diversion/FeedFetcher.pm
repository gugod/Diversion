use v5.14;

package Diversion::FeedFetcher {
    use Moose;
    use XML::FeedPP;

    has url => (
        is => "ro",
        isa => "Str",
        required => 1
    );

    has feed => (
        is => "ro",
        isa => "XML::FeedPP",
        predicate => "feed_is_fetched",
        lazy_build => 1,
    );

    sub _build_feed {
        my ($self) = @_;
        return XML::FeedPP->new( $self->url );
    }

    sub each_entry {
        my ($self, $cb) = @_;
        return unless ref($cb) eq 'CODE';

        my @entries = $self->feed->uniq_item;
        for my $i (0..$#entries) {
            $cb->($entries[$i], $i);
        }
        return $self;
    }

};

1;
