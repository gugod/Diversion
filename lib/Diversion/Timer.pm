package Diversion::Timer;
use Moo::Role;

sub fmt {
    return sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ", $_[5]+1900, $_[4]+1, @_[3,2,1,0]);
}

sub looks_like_iso8601 {
    ($_[1]||$_[0]) =~ /\A [0-9]{4} - [0-9]{2} - [0-9]{2} T [0-9]{2} : [0-9]{2} : [0-9]{2} Z/x
}

sub an_hour_ago {
    return fmt(gmtime(time - 3600));
}

1;
