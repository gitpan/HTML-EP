# -*- perl -*-
#
#   HTML::EP    - A Perl based HTML extension.
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

require HTML::EP;
require HTML::EP::Locale;

package HTML::EP::Examples::Glimpse;

$HTML::EP::Examples::Glimpse::VERSION = '0.02';
@HTML::EP::Examples::Glimpse::ISA = qw(HTML::EP::Locale HTML::EP);


sub init {
    my $self = shift;
    if (!exists
        ($self->{'_ep_funcs'}->{'ep-html-ep-examples-glimpse-matchline'})) {
        $self->SUPER::init();
        $self->{'_ep_funcs'}->{'ep-html-ep-examples-glimpse-matchline'} =
            { 'method' => '_ep_html_ep_examples_glimpse_matchline',
              'default' => 'template' };
    }
}


sub _prefs {
    my $self = shift; my $attr = shift; my $prefs = shift;
    my $basedir = $attr->{'basedir'}
        or die "Missing attribute: basedir";
    my $vardir = "$basedir/var";
    die "A directory $vardir does not exist. Please create it, with write "
        . " permissions for the web server, or modify the value of "
        . " basedir in $self->{'env'}->{'PATH_TRANSLATED'}."
            unless -d $vardir;
    my $prefs_file = "$vardir/prefs";
    if (!$prefs) {
        # Load Prefs
        $prefs = $self->{'prefs'} = (do $prefs_file) || {};

        $prefs->{'rootdir'} = $ENV{'DOCUMENT_ROOT'}
            unless exists($prefs->{'rootdir'});
        $prefs->{'dirs'} = "/"
            unless exists($prefs->{'dirs'});
        $prefs->{'dirs_ignored'} =
            (($ENV{'PATH_INFO'} =~ /(.*)\//) ? $1 : "")
                unless exists($prefs->{'dirs_ignored'});
        $prefs->{'suffix'} = ".html .htm"
            unless exists($prefs->{'suffix'});
        foreach my $p (qw(glimpse glimpseindex)) {
            if (!exists($prefs->{"$p\_path"})) {
                foreach my $dir (split(/:/, $ENV{'PATH'})) {
                    if (-x "$dir/$p") {
                        $prefs->{"$p\_path"} = "$dir/$p";
                        last;
                    }
                }
            }
        }
    } else {
        foreach my $p (qw(glimpse glimpseindex)) {
            die ("A program " . $prefs->{"$p\_path"} . " ($p) does not exist")
                unless ($prefs->{"$p\_path"}  and  -x $prefs->{"$p\_path"});
        }

        # Save Prefs
        require Data::Dumper;
        my $dump = Data::Dumper->new([$prefs], ['PREFS']);
        $dump->Indent(1);
        require Symbol;
        my $fh = Symbol::gensym();
        my $d = $dump->Dump();
        if ($self->{'debug'}) {
            print "Saving Preferences to $prefs_file.\n";
            $self->print("Saving data:\n$d\n");
        }
        die "Could not save data into $prefs_file: $!. Please verify whether"
            . " the web server has write permissions in $vardir and on"
            . " $prefs_file."
                unless open($fh, ">$prefs_file")  and  (print $fh ("$d\n"))
                    and close($fh);
    }
    $self->{'glimpse_prefs'} = $prefs;
    wantarray ? ($prefs, $vardir) : $prefs;
}


sub _ep_html_ep_examples_glimpse_load {
    my $self = shift; my $attr = shift;
    my $cgi = $self->{'cgi'};
    my $prefs = $self->_prefs($attr);

    if ($cgi->param('modify')) {
        my $modified = 0;
        foreach my $p ($cgi->param()) {
            if ($p =~ /^glimpse_prefs_(.*)/) {
                my $sp = $1;
                my $old = $prefs->{$sp};
                my $new = $cgi->param($p);
                if (!defined($old)) {
                    if (defined($new)) {
                        $modified = 1;
                        $prefs->{$sp} = $new;
                    }
                } elsif (!defined($new)) {
                    $modified = 1;
                    $prefs->{$sp} = $new;
                } else {
                    $modified = ($new ne $old);
                    $prefs->{$sp} = $new;
                }
            }
        }
        if ($self->{'debug'}) {
            $self->print("Modifications detected.\n");
        }
        $self->_prefs($attr, $prefs);
    }
    '';
}


sub _ep_html_ep_examples_glimpse_create {
    my $self = shift; my $attr = shift;
    my($prefs, $vardir) = $self->_prefs($attr);
    my $debug = $self->{'debug'};

    my $rootdir = $prefs->{'rootdir'};
    my $dirlist = $prefs->{'dirs'};
    $dirlist =~ s/\s+/ /sg;
    $dirlist =~ s/^\s+//;
    $dirlist =~ s/\s+$//;
    my @dirs = map { "$rootdir/$_" } split(/ /, $dirlist);
    $dirlist = $prefs->{'dirs_ignored'};
    $dirlist =~ s/\s+/ /sg;
    $dirlist =~ s/^\s+//;
    $dirlist =~ s/\s+$//;
    my @dirs_ignored = map { "$rootdir/$_" } split(/ /, $dirlist);

    my $matchesDirsIgnored;
    if (@dirs_ignored) {
        my $dirsIgnoredRe = join("|", map { "\\Q$_\\E" } @dirs_ignored);
        my $func = "sub { shift() =~ m[^(?:$dirsIgnoredRe)] }";
        $matchesDirsIgnored = eval $func;
        $self->print("Making function for directory match: $func",
                     " ($matchesDirsIgnored))\n") if $debug;
    } else {
        $matchesDirsIgnored = sub { 0 }
    }
    my $suffixList = $prefs->{'suffix'};
    $suffixList =~ s/\s+/ /sg;
    $suffixList =~ s/^\s+//;
    $suffixList =~ s/\s+$//;
    my @suffix = split(/ /, $suffixList);
    my $matchesSuffix;
    if (@suffix) {
        my $suffixRe = join("|", map { "\\Q$_\\E" } @suffix);
        my $func = "sub { shift() =~ m[(?:$suffixRe)\$] }";
        $matchesSuffix = eval $func;
        $self->print("Making function for suffix match: $func",
                     "($matchesSuffix)\n") if $debug;
    } else {
        $matchesSuffix = sub { 1 }
    }

    my $fileList = '';
    require File::Find;
    File::Find::find
        (sub {
             if (&$matchesDirsIgnored($File::Find::dir)) {
                 $self->print("Skipping directory $File::Find::dir.\n")
                     if $debug;
                 $File::Find::prune = 1;
             } else {
                 my $f = $File::Find::name;
                 my $ok = ((-f $f)  and  &$matchesSuffix($f));
                 $self->print("    $f: $ok\n") if $debug;
                 $fileList .= "$f\n" if $ok;
             }
         }, @dirs);

    die "No files found" unless $fileList;

    my $fh = Symbol::gensym();
    my $command = "$prefs->{'glimpseindex_path'} -b -F -H $vardir -X";
    $self->print("Creating pipe to command $command\n") if $debug;
    die "Error while creating index: $!"
        unless (open($fh, "| $command >$vardir/.glimpse_output 2>&1")  and
                (print $fh $fileList)  and  close($fh));

    $fileList;
}


sub _ep_html_ep_examples_glimpse_matchline {
    my $self = shift; my $attr = shift;
    my $template = defined($attr->{'template'}) ?
        $attr->{'template'} : return undef;
    $self->print("Setting matchline template to $template\n")
        if $self->{'debug'};
    $self->{'line_template'} = $template;
    '';
}

sub _format_MATCHLINE {
    my $self = shift; my $f = shift;
    my $debug = $self->{'debug'};
    my $template = $self->{'line_template'};
    my $lines = $f->{'lines'};
    $self->print("MATCHLINE: f = $f, lines = $lines (", @$lines, ")\n",
                 "line_template = $template\n") if $debug;
    my $output = $self->_ep_list({'items' => $lines,
                                  'item' => 'l',
                                  'template' => $template});
    $self->print("output = ", (defined($output) ? $output : "undef"), "\n")
        if $debug;
    $output;
}

sub _ep_html_ep_examples_glimpse_search {
    my $self = shift; my $attr = shift;
    my($prefs, $vardir) = $self->_prefs($attr);
    my $cgi = $self->{'cgi'};
    my $debug = $self->{'debug'};
    my $start = ($cgi->param('start')  or  0);
    my $max = ($cgi->param('max')  or  $attr->{'max'}  or  20);
    my @opts = ($prefs->{'glimpse_path'}, '-UOnbqy', '-L',
                "0:" . ($start+$max), '-H', $vardir);
    my $case_sensitive = $cgi->param('opt_case_sensitive') ? 1 : 0;
    push(@opts, '-i') unless $case_sensitive;
    my $word_boundary = $cgi->param('word_boundary') ? 1 : 0;
    push(@opts, '-w') if $word_boundary;
    my $whole_file = $cgi->param('opt_whole_file') ? 1 : 0;
    push(@opts, '-W') unless $whole_file;
    my $opt_regex = $cgi->param('opt_regex') ? 1 : 0;
    push(@opts, $opt_regex ? '-e' : '-k');
    my $opt_or = $cgi->param('opt_or') ? 1 : 0;

    # Now for the hard part: Split the search string into words
    my $search = $cgi->param('search');
    $self->{'link_opts'} = $self->{'env'}->{'PATH_INFO'} . "?"
        . join("&", "search=" . URI::Escape::uri_escape($search),
               "max=$max", "opt_case_sensitive=$case_sensitive",
               "word_boundary=$word_boundary", "opt_whole_file=$whole_file",
               "opt_regex=$opt_regex", "opt_or=$opt_or");
    my @words;
    while (length($search)) {
        $search =~ s/^\s+//s;
        if ($search =~ /^"/s) {
            if ($search =~ /"(.*?)"\s+(.*)/s) {
                push(@words, $1);
                $search = $2;
            } else {
                $search =~ s/^"//s;
                $search =~ s/"$//s;
                push(@words, $search);
                last;
            }
        } else {
            $search =~ s/^(\S+)//s;
            push(@words, $1) if $1;
        }
    }
    if (!@words) {
        my $language = $self->{'_ep_language'};
        my $msg;
        if ($language eq 'de') {
            $msg = "Keine Suchbegriffe gefunden";
        } else {
            $msg = "No search strings found";
        }
        $self->_ep_error({'type' => 'user', 'msg' => $msg});
    }
    my $sep = $opt_or ? ';' : ',';

    push(@opts, join($sep, @words));

    # First try using fork() and system() for security reasons.
    my $ok;
    my $tmpnam;
    my $fh = eval {
        my $infh = Symbol::gensym();
        my $outfh = Symbol::gensym();
        pipe ($infh, $outfh) or die "Failed to create pipe: $!";
        my $pid = fork();
        die "Failed to fork: $!" unless defined($pid);
        if (!$pid) {
            # This is the child
            close $infh;
            open(STDOUT, ">&=" . fileno($outfh))
                or die "Failed to reopen STDOUT: $!";
            exec @opts;
            exit 0;
        }
        close $outfh;
        $self->printf("Forked command %s\n", join(" ", @opts)) if $debug;
        $infh;
    } || eval {
        # Rats, doesn't work. :-( Run glimpse by storing the output in
        # a file and read from that file. We need to be aware of shell
        # metacharacters and the like.
        require POSIX;
        $tmpnam = "$vardir/" . POSIX::tmpnam();
        my $command = join(" ", map{ quotemeta $_ } @opts). " >$tmpnam";
        $self->print("Running command $command\n") if $debug;
        system $command or die "system() failed: $!";
        my $infh = Symbol::gensym();
        open($infh, "<$tmpnam")
            or die "Failed to open $tmpnam: $!";
        $infh;
    };
    $self->print("fh = $fh\n") if $debug;
    eval {
        my $blank_seen;
        my (@files, @lines, $file, $title, $lineNum, $byteOffset, $offsetStart,
            $offsetEnd);
        my $fileNum = $start;
        my $ignoreFiles = $start;
        while (defined(my $line = <$fh>)) {
            #$self->print("Glimpse output: $line") if $debug;
            if ($line =~ /^\s*$/) {
                $blank_seen = 1;
                if ($file) {
                    if ($ignoreFiles) {
                        --$ignoreFiles
                    } else {
                        push(@files, {'file' => $file,
                                      'fileNum' => ++$fileNum,
                                      'title' => $title,
                                      'lines' => [@lines]})
                    }
                }
                undef $file;
                undef $lineNum;
                @lines = ();
                #$self->print("Blank line detected\n") if $debug;
            } elsif ($blank_seen) {
                $blank_seen = 0;
                if ($line =~ /^(\S+)\s+(\S.*?)\s+$/) {
                    $file = $1;
                    $title = $2;
                    #$self->print("New file detected: $file, $title\n")
                    #    if $debug;
                } elsif ($line =~ /^(\S+)\:\s*$/) {
                    $file = $title = $1;
                } else {
                    $self->print("Cannot parse file line: $line") if $debug;
                }
            } elsif ($file) {
                if ($lineNum) {
                    push(@lines, {'line' => $line,
                                  'lineNum' => $lineNum,
                                  'byteOffset' => $byteOffset,
                                  'offsetStart' => $offsetStart,
                                  'offsetEnd' => $offsetEnd});
                    #$self->print("Match line detected: $lineNum, $line\n")
                    #    if $debug;
                    undef $lineNum;
                } elsif ($line =~ /^(\d+)\:\s+(\d+)\=\s+\@(\d+)\{(\d+)\}/) {
                    $lineNum = $1;
                    $byteOffset = $2;
                    $offsetStart = $3;
                    $offsetEnd = $4;
                } else {
                    $self->print("Cannot parse line: $line\n") if $debug;
                }
            } else {
                $self->print("Unexpected line: $line\n") if $debug;
            }
        }
        if ($file) {
            if ($ignoreFiles) {
                --$ignoreFiles
            } else {
                push(@files, {'file' => $file,
                              'fileNum' => ++$fileNum,
                              'title' => $title,
                              'lines' => [@lines]})
            }
        }
        $self->print("Found " . scalar(@files) . " files\n") if $debug;
        foreach my $file (@files) {
            my $url = $file->{'file'};
            $url =~ s/^\Q$prefs->{'rootdir'}\E//;
            $url =~ s/^\/+/\//;
            $file->{'url'} = $url;
        }
        $self->{'files'} = \@files;
        if (@files == $max) {
            $self->{'next'} = $start + $max;
        }
        $self->{'prev'} = $start ? $start - $max : -1;
    } unless $@;
    close $fh if $fh;
    undef $fh;
    unlink $tmpnam if $tmpnam;
    '';
}


1;
