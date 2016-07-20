package Diversion::App::Command::migrate_uri_archive;
use v5.18;
use Diversion::App -command;
use Diversion::UrlArchiver;
use Parallel::ForkManager;
use Log::Any qw($log);

use JSON;

use Moo;
with 'Diversion::Service';

sub execute {
    my ($self, $opt, $args) = @_;

    my $json = JSON->new->canonical;
    my $blob_store = $self->blob_store;

    $self->db_open(
        "url",
        sub {
            my ($dbh) = @_;

            my $sth_insert_v2 = $dbh->prepare(q{ INSERT INTO uri_archive_v2(`uri`,`created_at`,`updated_at`,`response_sha1_digest`,`content_sha1_digest`) VALUES (?,?,?,?,?) });
            my $sth_update_v2 = $dbh->prepare(q{ UPDATE uri_archive_v2 SET updated_at = ?, response_sha1_digest = ? WHERE uri = ? AND content_sha1_digest = ? });
            my $sth_check_v2 = $dbh->prepare(q{ SELECT 1 FROM uri_archive_v2 WHERE uri = ? AND content_sha1_digest = ? });

            my $sth_all_uri_archives = $dbh->prepare(q{ SELECT uri,created_at,sha1_digest FROM uri_archive });
            $sth_all_uri_archives->execute;
            while (my $row = $sth_all_uri_archives->fetchrow_arrayref()) {
                my $blob = $blob_store->get( $row->[2] );
                next unless defined($blob);

                my $http_tiny_response = $json->decode($blob);
                my $content = delete $http_tiny_response->{content};
                my $content_digest = $blob_store->put($content);
                my $blob2 = $json->encode($http_tiny_response);
                my $blob2_digest = $blob_store->put( $blob2 );

                $sth_check_v2->execute($row->[0], $content_digest);
                if ($sth_check_v2->fetchrow_arrayref) {
                    $sth_update_v2->execute(
                        $row->[1],   # updated_at,
                        $blob2_digest, # response_sha1_digest
                        $row->[0],   # uri
                        $content_digest, # content_sha1_digest
                    );
                } else {
                    $sth_insert_v2->execute(
                        $row->[0],   # uri
                        $row->[1],   # created_at
                        $row->[1],   # updated_at,
                        $blob2_digest, # response_sha1_digest
                        $content_digest, # content_sha1_digest
                    );
                }



                say $row->[0];
            }
        }
    );

}

1;

__END__

CREATE TABLE uri_archive_v2 (
    'uri'   varchar(1024) NOT NULL,
    'created_at' int NOT NULL,
    'updated_at' int NOT NULL,
    'response_sha1_digest' char(40) NOT NULL,
    'content_sha1_digest' char(40) NOT NULL,
    PRIMARY KEY (`uri`, `content_sha1_digest`)
);
