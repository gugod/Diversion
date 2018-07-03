package Diversion::ContentExtractor {
    use Moo;
    use Mojo::DOM;
    use Encode ();
    use HTML::ExtractContent;

    has content => ( is => "ro", required => 1 );

    has text => ( is => "lazy" );
    has title => ( is => "lazy" );

    sub _build_text {
        my $self = shift;
        my $ex = HTML::ExtractContent->new;
        my $text = $ex->extract( $self->content )->as_text
            =~ s/(\p{Han})\s+(\p{Han})/$1 $2/gr
            =~ s!^ [^\p{General_Category: Punctuation}]+ $!!xmgr;
        return $text;
    }

    sub _build_title {
        my $self = shift;
        my $dom = Mojo::DOM->new( $self->content );
        my $title = $dom->find("title");
        if ($title->size > 0) {
            return $title->[0]->text;
        }
        return "";
    }
}

no Moo;
1;
