package Diversion::AppRole;
use Moo::Role;

use Diversion::BlobStore;

has blob_store => (
    is => "ro",
    default => sub {
        return Diversion::BlobStore->new(
            root => "$ENV{HOME}/var/Diversion/blob_store/"
        );
    }
);

1;
