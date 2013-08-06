package Diversion::ContentFetcher {
    use Moo;
    use HTTP::Tiny;
    use Encode;

    has url     => ( is => "ro", required => 1 );
    has title   => ( is => "lazy" );
    has content => ( is => "lazy" );

    has response => ( is => "lazy" );

    sub _build_response {
        my $self = $_[0];
        my $response = HTTP::Tiny->new( max_size => 409600 )->get( $self->url );
        die "Failed to GET url @{[ $self->url ]}" unless $response->{success};
        return $response;
    }

    sub _build_content {
        my $self = $_[0];
        my $response = $self->response;
        my $content = $response->{content};

        unless ( Encode::is_utf8($content) ) {
            my $ct = $response->{headers}{'content-type'};
            my $charset = ($ct && $ct =~ m!charset=(.+)!) ? $1 : "utf8";

            $content = Encode::decode($charset, $content);
        }

        return $content;
    }
};

1;
