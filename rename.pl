#!/usr/bin/perl -w

#rename.pl
#Robert W. Leach
#10/28/2004
#Los Alamos National Laboratory
#Copyright 2004

markTime();
my $software_version_number = '1.9';

##
## Start Main
##

use strict;
use Getopt::Long;

#Declare variables
my($quiet,
   $help,
   @input_files,
   $version,
   $verbose,
   $force);
my $append_flag  = 0;
my $replace      = 'rename_placeholder';
my $with         = 'rename_placeholder';
my $pattern_mode = 0;
my $number_mode  = 0;
my $increment    = 0;
my $dry_run      = 0;
my $DEBUG        = 0;

#If there are no arguments and no files directed in
if(scalar(@ARGV) == 0)
  {
    usage();
    exit(0);
  }

#Get the input options
GetOptions('r|replace=s'        => \$replace,      #REQUIRED if -w not supplied
           'w|with=s'           => \$with,         #REQUIRED if -r not supplied
	   'p|pattern-mode!'    => \$pattern_mode, #OPTIONAL [Off]
	   'n|number-mode!'     => \$number_mode,  #OPTIONAL [Off]
           'skip-existing-nums!'=> \$increment,    #OPTIONAL [Off]
	   'd|dry-run!'         => \$dry_run,      #OPTIONAL [Off]
	   'f|force!'           => \$force,        #OPTIONAL [Off]
	   'version!'           => \$version,      #OPTIONAL [Off]
	   'q|quiet!'           => \$quiet,        #OPTIONAL [Off]
	   'v|verbose!'         => \$verbose,      #OPTIONAL [Off]
	   'h|help!'            => \$help,         #OPTIONAL [Off]
	   '<>'                 => sub {push(@input_files,$_[0])}
                                                      #OPTIONAL [All files]
          );

#If the user has asked for help, call the help subroutine
if($help)
  {
    help();
    exit(0);
  }

#If the user has asked for the software version, print it
if($version)
  {
    print($software_version_number,"\n");
    exit(0);
  }

#If either of the replace or with flags is not supplied, assume the 1st and 2nd
#non-files are the replace and with strings and turn off the force flag
my @not_files = grep {/\S/ && !(-e $_)} map {glob($_)} @input_files;
if(scalar(@not_files) && $replace eq 'rename_placeholder')
  {
    $replace = shift(@not_files);
    @input_files = grep {$_ ne $replace} @input_files;
    if($force)
      {warning("The force flag will not work without an explicit 'replace' ",
	       "flag.")}
    $force = 0;
  }
if(scalar(@not_files) && $with eq 'rename_placeholder' && !$number_mode)
  {
    $with = shift(@not_files);
    @input_files = grep {$_ ne $with} @input_files;
    if($force)
      {warning("The force flag will not work without either an explicit ",
	       "-w(--with) flag or -n(--number-mode) flag.")}
    $force = 0;
  }

if($with ne 'rename_placeholder' && $number_mode)
  {
    error("You cannot supply -w and -n together.");
    usage() unless($quiet);
    exit(1);
  }

if($replace eq 'rename_placeholder' && $with eq 'rename_placeholder' &&
   !$number_mode)
  {
    error("You must supply either the -r, -w, or -n parameter.")
      unless($quiet);
    usage() unless($quiet);
    exit(2);
  }

if($replace eq 'rename_placeholder')
  {
    $replace = '';
    $append_flag = 1;
  }
$with = '' if($with eq 'rename_placeholder');

if(scalar(@input_files) == 0)
  {
    my $globstring = $replace;
    $globstring =~ s/(.*)(\/|\A)/$1$2*/;
    if(defined($replace) && !$pattern_mode)
      {@input_files = grep {-e $_} glob("$globstring*")}
    else
      {@input_files = glob('*')}
  }

#If they specified a file path in the pattern, remove it
$replace =~ s/.*\///;
$replace = quotemeta($replace) if(defined($replace) && !$pattern_mode);

debug("Pattern: /$replace/$with/");

my $renamed = 0;
my $number  = 1;
my $exist_check = {};

#For each input file of the same type
foreach my $input_file (@input_files)
  {
    next unless(-e $input_file);

    my($newname);

    do
      {
	$newname = $input_file;
	$with    = $number if($number_mode);

	if($append_flag)
	  {
	    debug("Appending");
	    $newname .= $with;
	  }
	else
	  {
	    debug("$newname =~ s/(?=[^\\/]*\\Z)$replace/$with/");
	    $newname =~ s/(?=[^\/]*\Z)$replace/$with/;
	    debug("Replaced: $newname");
	  }

	#If we're in "skip existing nums" mode and the file exists, increment
	if($input_file ne $newname && $number_mode && $increment &&
	   -e $newname)
	  {$number++}
      }
	#If we're in "skip existing nums" mode and the file exists, loop
	while($input_file ne $newname && $number_mode && $increment &&
	      -e $newname);

    debug("$input_file -> $newname");

    if($input_file eq $newname)
      {next}
    elsif(!$force && -e $newname)
      {
	$number++; #Advance the number anyway so they can force it later
	error("$newname already exists.  Use -f to override.") if(!$quiet);
      }
    else
      {
	warning("Replacing $newname") if(!$quiet && -e $newname);
	if($verbose)
	  {print("Renaming [$input_file] to [$newname].\n")}
	rename($input_file,$newname) unless($dry_run);
	if(!$? && !exists($exist_check->{$newname}))
	  {
	    $exist_check->{$newname} = 1;
	    $renamed++;
	  }
	else
	  {
	    error("Unable to rename [$input_file].  ",
		  ($dry_run && exists($exist_check->{$newname}) ?
		   "This rename operation will conflict with a " .
		   "previously renamed file." : $!),"\n");
	  }
	$number++; #Advance the number in any case so they can force it later
      }
  }

if($dry_run)
  {print("$renamed files will be renamed.\n") unless($quiet)}
else
  {print("$renamed files successfully renamed.\n") unless($quiet)}


##
## End Main
##






























##
## Subroutines
##

sub help
  {
    #Print a description of this program
    print << "end_print";

$0
Copyright 2004
Robert W. Leach
10/28/2004
Bioscience Division
Bioinformatics and Computational Biology Group, B5
Biodefense Informatics Team
MS M888
Los Alamos National Laboratory
Los Alamos, NM 87545
robleach\@lanl.gov

* WHAT IS THIS: This script takes a string to replace and/or a string to substitute/append and changes all supplied (or matching) files in the current (or supplied) directory (or directories).

end_print

    return(0);
  }



sub usage
  {
    print << "end_print";

USAGE: $0 -r|--replace replace_string -w|--with with_string input_files [-p] [-f|--force] [-h|--help] [--version] [-q|--quiet]

                          OPTIONAL [All files] Input file(s).
     -r|--replace         REQUIRED Replace string.  This is a string in a group
                                   of file names that you want to change.  Not
                                   required if -w is supplied.  If -w is not
                                   supplied, the string is removed from the
                                   name.  You may use globbed file names, but
                                   they cannot be interpolated by the shell, so
                                   you must use quotes around the replace
                                   string like this: "*/replace_string".
                                   This will find a file in every directory
                                   containing 'replace_string' in its name to
                                   make the replacement.
     -w|--with            REQUIRED With string.  This is the string you want to
                                   add to the file names.  If -r is supplied,
                                   the with string is substituted into its
                                   place.  If -r is not supplied, the file name
                                   is appended with the with string.
     -p|--pattern-mode    OPTIONAL [Off] Treat the -r string as a perl regular
                                   expression.
     -n|--number-mode     OPTIONAL [Off] Supplying this flag indicates that the
                                   replace string is to be replaced by an
                                   incrementing number (starting from 1).  The
                                   number is incremented for each file name
                                   successfully changed.  If -r is not
                                   supplied, the number is appended to the file
                                   name.  Cannot use with -w (--with).
     --skip-existing-nums OPTIONAL [Off] Increment the number (see -n) until
                                   the new file name is unique (i.e. avoids
                                   overwriting existing files).  Only used if
                                   -n is supplied.
     -f|--force           OPTIONAL [Off] Force file rename.  Use this if you
                                   want the rename operation to overwrite
                                   possible files that have the same name as
                                   the new names being generated.
     -q|--quiet           OPTIONAL [Off] Quiet mode.  Turns off warnings and
                                   errors.
     -h|--help            OPTIONAL [Off] Help.  Use this option to see sample
                                   input files and an explanation.
     --version            OPTIONAL [Off] Print software version and quit.

end_print

    return(0);
  }


##
## Subroutine that prints errors with a leading program identifier
##
sub error
  {
    #Gather and concatenate the error message and split on hard returns
    my @error_message = split("\n",join('',@_));
    pop(@error_message) if($error_message[-1] !~ /\S/);

    my $script = $0;
    $script =~ s/^\.\///;

    #Assign the values from the calling subroutine
    #but if called from main, assign the values from main
    my($junk1,$junk2,$line_num,$calling_sub);
    (($junk1,$junk2,$line_num,$calling_sub)) = caller(1) ||
      (($junk1,$junk2,$line_num) = caller());

    #Edit the calling subroutine string
    $calling_sub =~ s/^.*?::(.+)$/$1:/ if(defined($calling_sub));

    #Put location information at the beginning of each line of the message
    foreach my $line (@error_message)
      {
	print STDERR ("ERROR:$script:LINE$line_num:",
		      (defined($calling_sub) ? $calling_sub : ''),
		      ' ')
	  if($line =~ /\S/);
	print STDERR ($line,"\n");
      }

    #Return success
    return(0);
  }


##
## Subroutine that prints warnings with a leader string
##
sub warning
  {
    #Gather and concatenate the warning message and split on hard returns
    my @warning_message = split("\n",join('',@_));
    pop(@warning_message) if($warning_message[-1] !~ /\S/);

    #Put leader string at the beginning of each line of the message
    foreach my $line (@warning_message)
      {print STDERR (($line =~ /\S/ ? 'WARNING: ' : ''),$line,"\n")}

    #Return success
    return(0);
  }


##
## Subroutine that gets a line of input and accounts for carriage returns that
## many different platforms use instead of hard returns.  Note, it uses a
## global array reference variable ($infile_line_buffer).
##
sub getLine
  {
    my $file_handle = $_[0];

    #Set a global array variable if not already set
    $main::infile_line_buffer = {} if(!defined($main::infile_line_buffer));
    if(!exists($main::infile_line_buffer->{$file_handle}))
      {$main::infile_line_buffer->{$file_handle} = []}

    #If this sub was called in array context
    if(wantarray)
      {
	#Check to see if this file handle has anything remaining in its buffer
	#and if so return it with the rest
	if(scalar(@{$main::infile_line_buffer->{$file_handle}}) > 0)
	  {return(@{$main::infile_line_buffer->{$file_handle}},
		  map {split("\r",$_)} <$file_handle>)}

	#Otherwise return everything else
	return(map {split("\r",$_)} <$file_handle>);
      }

    #If the file handle's buffer is empty, put more on
    if(scalar(@{$main::infile_line_buffer->{$file_handle}}) == 0)
      {@{$main::infile_line_buffer->{$file_handle}} = split("\r",
							    <$file_handle>)}

    #Shift off and return the first thing in the buffer for this file handle
    return($_ = shift(@{$main::infile_line_buffer->{$file_handle}}));
  }


sub debug
  {
    return unless($DEBUG);

    #Gather and concatenate the error message and split on hard returns
    my @debug_message = split("\n",join('',@_));
    pop(@debug_message) if($debug_message[-1] !~ /\S/);

    #Assign the values from the calling subroutine
    #but if called from main, assign the values from main
    my($junk1,$junk2,$line_num,$calling_sub);
    (($junk1,$junk2,$line_num,$calling_sub)) = caller(1) ||
      (($junk1,$junk2,$line_num) = caller());

    #Edit the calling subroutine string
    $calling_sub =~ s/^.*?::(.+)$/$1:/ if(defined($calling_sub));

    #Put location information at the beginning of each line of the message
    foreach my $line (@debug_message)
      {
	print STDERR ("DEBUG:LINE$line_num:",
		      (defined($calling_sub) ? $calling_sub : ''),
		      ' ')
	  if($line =~ /\S/);
	print STDERR ($line,"\n");
      }

    #Return success
    return(0);
  }


#This sub marks the time (which it pushes onto an array) and in scalar context
#returns the time since the last mark by default or supplied mark (optional)
#In array context, the time between all marks is always returned regardless of
#a supplied mark index
#A mark is not made if a mark index is supplied
#Uses a global time_marks array reference
sub markTime
  {
    #Record the time
    my $time = time();

    #Set a global array variable if not already set
    $main::time_marks = [] if(!defined($main::time_marks));

    #Read in the time mark index or set the default value
    my $mark_index = (defined($_[0]) ? $_[0] : -1);  #Optional Default: -1

    #Error check the time mark index sent in
    if($mark_index > (scalar(@$main::time_marks) - 1))
      {
	error("Supplied time mark index is larger than the size of the ",
	      "time_marks array.\nThe last mark will be set.");
	$mark_index = -1;
      }

    #Calculate the time since the time recorded at the time mark index
    my $time_since_mark = (scalar(@$main::time_marks) ?
			   ($time - $main::time_marks->[$mark_index]) : 0);

    #Add the current time to the time marks array
    push(@$main::time_marks,$time)
      if(!defined($_[0]) || scalar(@$main::time_marks) == 0);

    #If called in array context, return time between all marks
    if(wantarray)
      {
	if(scalar(@$main::time_marks) > 1)
	  {return(map {$main::time_marks->[$_ - 1] - $main::time_marks->[$_]}
		  (1..(scalar(@$main::time_marks) - 1)))}
	else
	  {return(())}
      }

    #Return the time since the time recorded at the supplied time mark index
    return($time_since_mark);
  }
