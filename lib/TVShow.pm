package TVShow 1.0;
use strict;
use warnings;
use File::Copy "mv";
use File::Spec::Functions qw(catfile catdir); 
use File::Find qw(finddepth);
use File::Path qw(make_path);
use File::Basename qw(fileparse);



my $sep_pattern = "[-*+.x_	~ ]";
our $season_pattern = "(((SE?A?S?O?N?)|(SA?I?S?O?N?)|$sep_pattern)*([0-9]{1,3})$sep_pattern*)?";



sub new_name_file {
	my $description = shift;
	my $new_name = "$description->{'serie_name'} - ";
	$new_name = $new_name . "S$description->{'season'}E" if $description->{'season'};
	$new_name = $new_name . "$description->{'episode'}";
	$new_name = $new_name . ".$description->{'extention'}";
	return $new_name;
}


sub split_file_name {
	my $serie_name		= shift;
	my $old_name		= shift;
	my $season_pattern	= shift;
	$season_pattern		= "" unless $season_pattern;
	$old_name =~ s/[1-9][0-9]{3}//g;
	my $serie_pattern = join("$sep_pattern*", split( /\s/ , $serie_name ) );
	$old_name =~ s/$serie_pattern//ig;
	if( $old_name =~ /^.*?$season_pattern(((EP?I?S?O?D?E?)|$sep_pattern)*([0-9]{1,}($sep_pattern+[0-9]{1,})*)).*\.(\w+)$/i and 
		not ( $old_name =~ /preview/i or $old_name =~ /opening/i or $old_name =~ /ending/i ) )
	{
		my $epd = "";
		my $ext = "";
		if( $season_pattern )
		{
			$epd = sprintf("%02d",$9);
			$ext = $11;
		}else{
			$epd = sprintf("%02d",$4);
			$ext = $6;
		}
		my %description = (
			serie_name => $serie_name,
			episode => $epd,
			extention => $ext,
		);
		$description{'season'}	= sprintf("%02d" ,$5 ) if $1 and $season_pattern;
		return %description;
	}

	return;
}


sub apply_new_name {
	my $file_path		= shift;
	my $old2new			= shift;
	my $serie_root		= shift;
	my $file_name		= shift;
	my $new_name		= shift;
	my $season			= shift;
	my $sub_dir			= shift;
	$season = $season? sprintf( "S%01d" , $season ) : "";
	my $dir_path = catdir( $serie_root , $season );
	$dir_path = $serie_root if not $sub_dir;
	my $new_file_path = catfile( $dir_path , $new_name );
	$old2new->( $file_path , $new_file_path , $dir_path );
}


sub show {
	print $_[0] . " => " . $_[1] . "\n";
}


sub change {
	my $source = shift;
	my $dest = shift;
	my $dir = shift;
	make_path( $dir );
	mv( $source , $dest );
}

sub add_other_rename {
	my $dict	= shift;
	my $source = shift;
	my $dest = shift;
	my $dir = shift;
	if( $dict->{"$dest"} )
	{
		push( @{$dict->{"$dest"}{'sources'}} , $source );
	}else
	{
		my @sources = ( "$source" );
		$dict->{"$dest"} = {
			'dir' => $dir,
			'sources' =>  \@sources  };
	}
}

sub check_unique {
	my $dict = shift;
	my $is_ok = 1;
	while( my ($dest,$parameters) = each(%$dict) )
	{
		if( @{$parameters->{'sources'}} > 1 )
		{
			$is_ok = 0;
			$" = "\n\t";
			print "Problem with $dest, mutliple sources:\n\t@{$parameters->{'sources'}}\n";
		}
	}
	return $is_ok;
}


sub process_action {
	my $dict = shift;
	my $keep_going = shift;
	my $verbose = shift;
	my $dry = shift;
	my $action = shift;
	while( my ($dest,$parameters) = each(%$dict) )
	{
		@{$parameters->{'sources'}} == 1 || ( $keep_going && next ) || ( $! = 82 && die "$dest is an ambiguous target..." );
		show( ${$parameters->{'sources'}}[0] , $dest ) if $verbose;
		$action->( ${$parameters->{'sources'}}[0] , $dest , $parameters->{'dir'}) unless $dry;
	}
	return 1;
}


# getoptions
sub apply_on_file {
	my $file_path			= shift;
	my $file_name			= shift;
	my $serie_name			= shift;
	my $serie_root			= shift;
	my $options				= shift;
	my $old2new				= shift;
	my $season_pattern		= $options->{'pattern'}?$options->{'pattern'}:'';
	my $sub_dir				= $options->{'dir'};
	my $episodes_by_season	= $options->{'nb_episodes'};
	my $season				= $options->{'season'};
	my %description = split_file_name $serie_name , $file_name , $season_pattern;
	$description{'season'} = sprintf( "%02d" , $season ) if $season and %description;
	if( %description and $sub_dir and $episodes_by_season )
	{
		$description{'season_folder'} = 1 + int( abs( $description{'episode'} - 1 ) / $episodes_by_season );
	}
	apply_new_name( $file_path , $old2new , $serie_root , $file_name ,
	   	new_name_file(\%description) ,
		$description{'season_folder'}?$description{'season_folder'}:$description{'season'} ,
	   	$sub_dir ) if %description;
}

sub filter_for_non_recurse {
	my $file_path = shift	;
	my ($name,$path,$suffix) = fileparse($file_path);
	my $action = shift;
	$action->(
		$file_path,
		$name,
		$path );
}
sub non_recurse_find {
	my $action = shift;
	my $directory = shift;
	opendir(my $dh, $directory) || die "can't opendir $directory: $!";
	map { filter_for_non_recurse( catfile($directory,$_) , $action ) } grep { /^[^.]/ && -f catfile( $directory ,$_ ) } readdir($dh) ;
	closedir $dh;
}

sub recurse_find {
	my $action = shift;
	my $directory = shift;
	finddepth(
		sub {
			my $file_path = $File::Find::name;
			my $file_name = $_;
			my $file_dir  = $File::Find::dir;
			$action->(
				$file_path,
				$file_name ,
				$file_dir );
		}  ,
		$directory );
}
1;
