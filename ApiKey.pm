#!perl -w
use strict;

package ApiKey;
use base 'Exporter';
our @EXPORT = qw($api_key $shared_secret $auth_token $groupid);

my $confname = "apikey.conf";

use Config::Auto;
my $config = Config::Auto::parse($confname);

our $api_key = $config->{api_key};
our $shared_secret = $config->{shared_secret};
our $auth_token = $config->{auth_token};
our $groupid = $config->{groupid};

1;

__END__
