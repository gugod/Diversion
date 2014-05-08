package Diversion::ElasticSearchConnector {
    use Moo::Role;
    use Elastijk;

    has elasticsearch => (
        is => "lazy",
    );

    sub _build_elasticsearch {
        my ($self) = @_;
        return Elastijk->new(host => '127.0.0.1', port => 9200);
    }
};

1;
