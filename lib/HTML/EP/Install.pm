# -*- perl -*-

use strict;
use File::Path ();
use File::Find ();
use File::Copy ();
use File::Spec ();
use Cwd();


package HTML::EP::Install;

use vars qw($VERSION $install_files);

$VERSION = '0.01';
$install_files = '\.(?:html?|ep|gif|jpe?g)$';


sub InstallHtmlFiles {
    my($fromDir, $toDir) = @_ ? @_ : @ARGV;
    my $current_dir = Cwd::cwd();
    chdir $fromDir || die "Failed to change directory to $fromDir: $!";
    my $copySub = sub {
	return unless $_ =~ /$install_files/;
	my $file = $_;
	my $target_dir = File::Spec->catdir($toDir, $File::Find::dir);
	(File::Path::mkpath($target_dir, 0, 0755)
	 or die "Failed to create $target_dir: $!")
	    unless -d $target_dir;
	my $target_file = File::Spec->catfile($target_dir, $file);
	File::Copy::copy($file, $target_file)
	    || die "Failed to copy $File::Find::name to $target_file: $!";
	chmod 0644, $target_file;
    };
    File::Find::find($copySub, ".");
    chdir $current_dir || die "Failed to change directory to $current_dir: $!";
}
