use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new
(
	module_name				=> 'TVShow',
	dist_author				=> 'Barbé Creuly Bastien <bastien.barbe.creuly+perl@gmail.com>',
	dist_abstract			=> 'Tool to rename badly named tv shows',
	requires				=> {
		"File::Path"			=> 0,
		"Getopt::Long"			=> 0,
		"File::Spec::Functions" => 0,
		"File::Copy"			=> 0,
		"File::Basename"		=> 0,
		"File::Find"			=> 0,
	},
	script_files			=> [qw(bin/series-rename)],
);
$build->create_build_script;
