# -*- perl -*-
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
use Data::Dumper ();
use Safe ();
use Fcntl ();


package HTML::EP::Session::Dumper;

sub new {
    my($proto, $ep, $id, $attr) = @_;
    my $class = (ref($proto) || $proto);
    my $session = { '_ep_data' => { 'fh' => $attr->{'fh'} } };
    bless($session, $class);
}

sub open {
    my($proto, $ep, $id, $attr) = @_;
    my $fh = Symbol::gensym();
    sysopen($fh, $id, Fcntl::O_RDWR()|Fcntl::O_CREAT())
	or die "Failed to open $id for writing: $!";
    flock($fh, Fcntl::LOCK_EX()) or die "Failed to lock $id: $!";
    return $proto->new($ep, $id, {'fh' => $fh}) if eof($fh);
    local $/ = undef;
    my $contents = <$fh>;
    die "Failed to read $id: $!" unless defined $contents;
    my $cpt = Safe->new();
    my $self = $cpt->reval($contents);
    my $class = (ref($proto) || $proto);
    die "Failed to eval $id: $@" if $@;
    die "Empty or trashed $id: Returned a false value" unless $self;
    die "Trashed $id: Expected instance of $class, got $self"
	unless ref($self) eq $class;
    $self;
}

sub store {
    my($self, $ep, $id, $locked) = @_;
    my $data = delete $self->{'_ep_data'};
    my $fh = $data->{'fh'};
    my $dump = Data::Dumper->new([$self], ["session"]);
    $dump->Indent(1);
    (seek($fh, 0, 0)  and  (print $fh $dump->Dump())
     and  truncate($fh, 0))
	or die "Failed to update $id: $!";
    if ($locked) {
	$self->{'_ep_data'} = $data;
    }
}


sub delete {
    my($self, $id) = @_;
    if (-f $id) {
	unlink $id or die "Failed to delete $id: $!";
    };
}


1;
