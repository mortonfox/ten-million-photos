#!perl -w
use strict;

package ApiKey;
use base 'Exporter';
our @EXPORT = qw($api_key $shared_secret $auth_token $groupid);

our $api_key = "insert Flickr API key here";
our $shared_secret = "insert Flickr shared secret here";
our $auth_token = "insert Flickr authentication token here";
our $groupid = '20759249@N00';

1;

__END__
