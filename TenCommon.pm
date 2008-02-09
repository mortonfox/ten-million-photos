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

    my $xmlp = new XML::Simple;
    my $xm = $xmlp->XMLin($response->{_content}, forcearray=>['photo']);

    my $photos = $xm->{photos};
    print "Page $photos->{page} of $photos->{pages}...\n";

    my $photolist = $photos->{photo};
    my @photoarr;

    for my $id (keys %{$photolist}) {
	my $photo = $photolist->{$id};
	$photo->{id} = $id;
	$photo->{url} = "http://www.flickr.com/photos/$photo->{owner}/$photo->{id}";
	push @photoarr, $photo;
    }
    ( $photos->{pages}, \@photoarr );
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


use DBI;

my $DBNAME = "10pool.db";
my $TBLNAME = "statstable";

sub OpenDB {
    my $dbh = DBI->connect("dbi:SQLite:dbname=$DBNAME", "", "",
	{ RaiseError => 1, AutoCommit => 1 });

    # Create the table if it does not exist.
    my $sth = $dbh->prepare("PRAGMA table_info($TBLNAME)")
	or die $dbh->errstr;
    $sth->execute
	or die $sth->errstr;

    my @row = $sth->fetchrow_array;
    if (!@row) {
	$sth->err and
	    die $sth->errstr;
	print "Table $TBLNAME not present\n";
	$sth = $dbh->prepare("CREATE TABLE $TBLNAME (" .
	    "key INTEGER PRIMARY KEY, " .
	    "startpage INTEGER, endpage INTEGER, " .
	    "lowdate INTEGER, highdate INTEGER, " . 
	    "stats TEXT, " . 
	    "timestamp INTEGER" .
	    ")") or die $dbh->errstr;
	$sth->execute
	    or die $sth->errstr;
    }
    $dbh;
}

sub CloseDB {
    my $dbh = shift;
    $dbh->disconnect;
}

sub AddToDB {
    my $dbh = shift;

    my $startpage = shift;
    my $endpage = shift;
    my $lowdate = shift;
    my $highdate = shift;
    my $stats = shift;

    my $sth = $dbh->prepare("INSERT INTO $TBLNAME (startpage, endpage, lowdate, highdate, stats, timestamp) VALUES (?, ?, ?, ?, ?, ?)") 
	or die $dbh->errstr;
    $sth->execute($startpage, $endpage, $lowdate, $highdate, $stats, time) 
	or die $sth->errstr;
}

sub HighestDateInDB {
    my $dbh = shift;

    my $highestdate = 0;
    my $toppage = 0;

    my $sth = $dbh->prepare("SELECT endpage, highdate FROM $TBLNAME WHERE highdate = (SELECT max(highdate) FROM $TBLNAME)")
	or die $dbh->errstr;
    $sth->execute
	or die $sth->errstr;

    my @row;
    if (@row = $sth->fetchrow_array) {
	($toppage, $highestdate) = @row;
    }
    elsif ($sth->err) {
	die $sth->errstr;
    }

    ($highestdate, $toppage);
}

sub OwnerStatsFromDB {
    my $dbh = shift;

    my %owners;

    my $sth = $dbh->prepare("SELECT stats FROM $TBLNAME")
	or die $dbh->errstr;
    $sth->execute
	or die $sth->errstr;

    my @row;
    while (@row = $sth->fetchrow_array) {
	for my $line (split(/\n/, $row[0])) {
	    my ($count, $owner, $ownername) = split(/,/, $line, 3);
	    defined $ownername or next;

	    unless (defined $owners{$owner}) {
		$owners{$owner} = { 
		    owner => $owner,
		    name => $ownername,
		    count => 0 
		};
	    }
	    $owners{$owner}{count} += $count;
	}
    }
    $sth->err and die $sth->errstr;

    \%owners;
}

BEGIN {
    my $pagelen = 500;

    # These two functions assume that $pagelen is 500. Isolate them to this
    # block.

    sub GetTotalPages {
	my ($totalpages, undef, undef, undef) = GetPage($groupid, 1, $pagelen);
	$totalpages;
    }

    sub GetDateRange {
	my $pagenum = shift;
	my (undef, $lodate, $hidate, undef) = GetPage($groupid, $pagenum, $pagelen);
	($lodate, $hidate);
    }
}

# Do binary search to find the page number containing a specific date.
sub FindPage {
    my $lower = 1;
    my $upper = shift;
    my $date = shift;

    print "Binary search: low=$lower upr=$upper Looking for date $date...\n";

    while (1) {
	my $mid = int(($lower + $upper) / 2);

	my ($lodate, $hidate) = GetDateRange($mid);

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
		$crec->{names}{$owner} = 
		    encode("iso-8859-1", $photo->{ownername});
		$crec->{counts}{$owner} = 0;
	    }
	    $crec->{counts}{$owner}++;
	}
    }

    return ($totalpages, $lodate, $hidate);
} # CountPhotos

1;

__END__
