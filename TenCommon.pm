#!perl -w
use strict;

# Shared code for 10 Million Photos Flickr group utilities.

package TenCommon;
use base 'Exporter';
our @EXPORT = qw(
    FlickrRetry GenPhotoList GetDateaddedRange GetPage
    OpenDB CloseDB AddToDB HighestDateInDB OwnerStatsFromDB
    GetTotalPages GetDateRange FindPage CountPhotos
);

use Flickr::API;

use XML::Simple;
use LWP::UserAgent;
use Time::HiRes qw(usleep);
use Encode;
use HTML::Entities;

use ApiKey;

my $SLEEPTIME = 500000;

# Query Flickr with retry.
sub FlickrRetry {
    my $method = shift;
    my $param = shift;

    $param->{auth_token} = $auth_token;

    my $retry_count = 0;
    my $response;
    do {
	my $api = new Flickr::API(
	    {
		'key' => $api_key,
		secret => $shared_secret
	    }
	);
	$response = $api->execute_method($method, $param);
	usleep $SLEEPTIME;
    } while $retry_count++ < 5 and not $response->{success};
    $response;
}

# Generate a list of photos from the Flickr query response.
sub GenPhotoList {
    my $response = shift;
    my @photos;
    my $pages;

    for my $node (@{$response->{tree}{children}}) {
	if (defined $node->{name} and $node->{name} eq "photos") {
	    $pages = $node->{attributes}{pages};
	    for my $node2 (@{$node->{children}}) {
		if (defined $node2->{name} and $node2->{name} eq "photo") {
		    my $photo = $node2->{attributes};
		    $photo->{url} = "http://www.flickr.com/photos/$photo->{owner}/$photo->{id}";
		    push @photos, $node2->{attributes};
		}
	    }
	}
    }

    ( $pages, \@photos );
}

# Get highest and lowest values of the dateadded field.
sub GetDateaddedRange {
    my $photolist = shift;
    my $lodate = 0x7FFFFFFF;
    my $hidate = 0;

    for my $photo (@$photolist) {
	my $date = $photo->{dateadded};
	$date < $lodate and $lodate = $date;
	$date > $hidate and $hidate = $date;
    }

    ($lodate, $hidate);
}

sub GetPage {
    my $groupid = shift;
    my $pagenum = shift;
    my $pagelen = shift;

    my $response = FlickrRetry("flickr.groups.pools.getPhotos",
	{
	    group_id => $groupid,
	    per_page => $pagelen,
	    page => $pagenum
	});

    die "Error: $response->{error_message}\n" unless $response->{success};

    my ($totalpages, $photolist) = GenPhotoList($response);
    my ($lodate, $hidate) = GetDateaddedRange($photolist);

    ( $totalpages, $lodate, $hidate, $photolist );
}


# How many pages are there in the pool?
sub GetTotalPages {
    my $pagelen = shift;
    my ($totalpages, undef, undef, undef) = GetPage($groupid, 1, $pagelen);
    $totalpages;
}

sub GetDateRange {
    my $pagenum = shift;
    my $pagelen = shift;
    my (undef, $lodate, $hidate, undef) = GetPage($groupid, $pagenum, $pagelen);
    ($lodate, $hidate);
}

# Do binary search to find the page number containing a specific date.
sub FindPage {
    my $lower = 1;
    my $upper = shift;
    my $date = shift;
    my $pagelen = shift;

    print "Binary search: low=$lower upr=$upper Looking for date $date...\n";

    while (1) {
	my $mid = int(($lower + $upper) / 2);

	my ($lodate, $hidate) = GetDateRange($mid, $pagelen);

	print "Binary search: low=$lower upr=$upper mid=$mid Dates $lodate to $hidate...\n";
	if ($date > $hidate) {
	    $upper = $mid;
	}
	elsif ($date < $lodate) {
	    $lower = $mid;
	}
	else {
	    return $mid;
	}
    }
} # FindPage

# Get photo stats on the specified page. Don't count photos older than
# mindate.
sub CountPhotos {
    my $groupid = shift;
    my $pagenum = shift;
    my $pagelen = shift;
    my $countrecs = shift;

    my ($totalpages, $lodate, $hidate, $photolist) =
	GetPage($groupid, $pagenum, $pagelen);

    for my $photo (@$photolist) {

	for my $crec (@$countrecs) {
	    next if $photo->{dateadded} < $crec->{mindate};

	    my $owner = $photo->{owner};
	    unless (defined $crec->{counts}{$owner}) {
		# $crec->{names}{$owner} = 
		#     encode("iso-8859-1", $photo->{ownername});
		$crec->{names}{$owner} = 
		    encode_entities($photo->{ownername});
		$crec->{counts}{$owner} = 0;
	    }
	    $crec->{counts}{$owner}++;
	}
    }

    return ($totalpages, $lodate, $hidate);
} # CountPhotos

1;

__END__
