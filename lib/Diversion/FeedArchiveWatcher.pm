package Diversion::FeedArchiveWatcher {
    use Moo;
    with (
        'Diversion::ElasticSearchConnector',
        'Diversion::Timer',
    );

    sub recent_entries {
        my ($self) = @_;

        my $size = 1000;

        my %search_param = (
            index => "diversion",
            type  => "feed_entry",
            query => { match_all => {} },
            from => 0,
            size => $size,
            filter => {
                range => {
                    updated_at => {
                        from => an_hour_ago()
                    }
                }
            },
            sort => [
                { updated_at => "desc" },
            ],
        );

        my $result = $self->elasticsearch->search( %search_param );

        return if $result->{timed_out};

        my @hits = @{ $result->{hits}{hits} };

        my $total_hits = $result->{hits}{total};

        while ( $total_hits > @hits || @hits > 10000 ) {
            $search_param{from} += $size;
            my $result = $self->elasticsearch->search( %search_param );
            last if $result->{timed_out};
            push @hits, @{ $result->{hits}{hits} };

            $total_hits = $result->{hits}{tatal} or last;
        }

        return \@hits;
    }
};

1;

__END__

=begin description

This object knows what's new in the feed archive.

=cut
