#!perl
#
#   HTML::EP	- A Perl based HTML extension.
#
#
#   Copyright (C) 1998    Jochen Wiedmann
#                         Am Eisteich 9
#                         72555 Metzingen
#                         Germany
#
#                         Phone: +49 7123 14887
#                         Email: joe@ispsoft.de
#
#   All rights reserved.
#
#   You may distribute this module under the terms of either
#   the GNU General Public License or the Artistic License, as
#   specified in the Perl README file.
#
############################################################################

require 5.004;
use strict;

use HTML::EP ();
use HTML::EP::Config ();


$SIG{'__WARN__'} = \&HTML::EP::WarnHandler;
my $self = HTML::EP->new();
$ENV{'PATH_TRANSLATED'} = shift @ARGV if @ARGV; # For IIS
my $path = $ENV{'PATH_TRANSLATED'};
if ($path =~ /(.*)[\/\\]/) {
    chdir $1;
}
$self->CgiRun($path);

exit 0;
