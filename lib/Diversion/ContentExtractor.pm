package Diversion::ContentExtractor {
    use Moo;
    use HTML::ExtractContent;
    use HTTP::Tiny;

    has url => (
        is => "ro",
        required => 1
    );

    sub extract {
        my ($self) = @_;

        my $response = HTTP::Tiny->new( max_size => 409600 )->get( $self->url );

        die "Failed to GET url: @{[ $self->url ]}\n" unless $response->{success};

        my $ex = HTML::ExtractContent->new;
        my $text = $ex->extract($response->{content})->as_text;
        $text =~ tr/\n/ /;
        $text =~ s/\s+/ /g;
        $text =~ s/(\p{Han})\s+(\p{Han})/$1 $2/g;
        return $text;
    }
}

1;
