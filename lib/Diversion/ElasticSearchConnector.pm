package Diversion::ElasticSearchConnector {
    use Moo::Role;

    has elasticsearch => (
        is => "lazy"
    );

    sub _build_elasticsearch {
        my ($self) = @_;
        return ElasticSearch->new( transport => "httptiny" );
    }

};

1;
