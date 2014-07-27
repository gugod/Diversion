use v5.14;

package Diversion::FeedArchiver {
    use Moo;
    use HTML::Restrict;
    use Encode;
    use IO::All;
    use Fcntl 'SEEK_END';
    use Digest::SHA1 qw<sha1_hex>;
    use Sereal::Encoder;
    
    use Log::Any qw($log);

    use Diversion::FeedFetcher;
    use Diversion::UrlFetcher;
    use Diversion::ContentExtractor;

    # with ('Diversion::ElasticSearchConnector');

    has url => (
        is => "ro",
        required => 1
    );

    has storage => (
        is => "ro",
        required => 1,
    );

    has fetcher => (
        is => "lazy",
    );

    has sereal_encoder => (
        is => "lazy"
    );

    sub _build_fetcher {
        my ($self) = @_;
        return Diversion::FeedFetcher->new(url => $self->url);
    }

    sub _build_sereal_encoder {
        return Sereal::Encoder->new({ croak_on_bless => 1 });
    }

    sub fetch_then_archive {
        my ($self) = @_;

        my @t = (gmtime)[5,4,3,2,1,0];
        $t[0] += 1900;
        $t[1] += 1;
        my $now = sprintf("%4d-%02d-%02dT%02d:%02d:%02dZ", @t);
        my $now_ymd = sprintf("%4d-%02d-%02d", @t[0,1,2]);
        my $stripper = HTML::Restrict->new;

        my @bulk;
        $self->fetcher->each_entry(
            sub {
                my ($entry, $i) = @_;
                my $data = {
                    last_seen => $now,
                    _source => $entry,
                    author  => ($entry->{author} || $entry->{creator}),
                };
                $data->{$_} = $stripper->process($entry->{$_}) for qw(description summary);
                push @bulk, $data;
            }
        );

        my $io = io->catfile($self->storage(), $t[0], "${now_ymd}.srl")->assert;
        if ($io->exists) {
            $io->seek( 0, SEEK_END );
        }

        my $encoder = $self->sereal_encoder;
        for (@bulk) {
            $io->print($encoder->encode($_));
        }
    }
};

1;
