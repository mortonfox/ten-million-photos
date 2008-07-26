#!perl -w
use strict;

use FileHandle;
use File::DosGlob;
use Encode;

use TenCommon;
use TenDB;
use ApiKey;

sub glob_args {
    map { File::DosGlob::glob $_ } @_;
}

# Count a user's photos by setting the page length to 1 and getting the
# number of pages.
sub GetCount {
    my $groupid = shift;
    my $userid = shift;

    my $response = FlickrRetry("flickr.groups.pools.getPhotos",
	{
	    group_id => $groupid,
	    user_id => $userid,
	    per_page => 1
	});
    die "Error: $response->{error_message}\n" unless $response->{success};

    my $xmlp = new XML::Simple;
    my $xm = $xmlp->XMLin($response->{_content});
    my $photos = $xm->{photos};

    ( $photos->{pages}, $photos->{photo}{ownername} );
}

sub main {
    my $dbh = new TenDB;
    my $owners = $dbh->ownerstats;
    undef $dbh;

    my @topusers = (sort { $b->{count} <=> $a->{count} } values %$owners) [0..149];

    my $lineno = 0;
    for my $user (@topusers) {
	$lineno++;
	print "$lineno. Getting photocount for user $user->{name}...\n";
	my $name;
	( $user->{count}, $name ) = GetCount($groupid, $user->{owner});
	$user->{name} = $name || $user->{name};
	$name = encode("iso-8859-1", $user->{name});
	print "$name: $user->{count}\n";
    }

    @topusers = sort { $b->{count} <=> $a->{count} } @topusers;

    my $fh = new FileHandle "newcount.txt", "w";
    defined $fh or die "Can't open newcount.txt for writing: $!\n";

    $lineno = 0;
    for my $user (@topusers) {
	$lineno++;
	my $name = encode("iso-8859-1", $user->{name});
	print $fh "$lineno. $name: $user->{count} (<a href=\"http://www.flickr.com/photos/$user->{owner}\">photos</a> | <a href=\"http://www.flickr.com/groups/10millionphotos/pool/$user->{owner}\">in pool</a>)\n";
    }

    $fh->close;
}

main;

__END__
