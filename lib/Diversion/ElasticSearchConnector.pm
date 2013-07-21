package Diversion::ElasticSearchConnector {
    use Moo::Role;
    use ElasticSearch;

    has elasticsearch => (
        is => "lazy",
        # isa => "ElasticSearch"
    );

    sub _build_elasticsearch {
        my ($self) = @_;
        return ElasticSearch->new( transport => "httptiny" );
    }

};

1;
