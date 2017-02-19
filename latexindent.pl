#!/usr/bin/env perl
#	This program is free software: you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation, either version 3 of the License, or
#	(at your option) any later version.
#
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#
#	See http://www.gnu.org/licenses/.
#
#	For details of how to use this file, please see readme.txt

# load packages/modules: assume strict and warnings are part of every perl distribution
use strict;
use warnings;

# list of modules
my @listOfModules = ('FindBin','YAML::Tiny','File::Copy','File::Basename','Getopt::Long','File::HomeDir');

# check the other modules are available
foreach my $moduleName (@listOfModules) {
    # references:
    #       http://stackoverflow.com/questions/251694/how-can-i-check-if-i-have-a-perl-module-before-using-it
    #       http://stackoverflow.com/questions/1917261/how-can-i-dynamically-include-perl-modules-without-using-eval
    eval {
        (my $file = $moduleName) =~ s|::|/|g;
        require $file . '.pm';
        $moduleName->import();
        1;
    } or die "$moduleName Perl Module not currently installed; please install the module, and then try running latexindent.pl again; exiting";
}

# now that we have confirmed the modules are available, load them
use FindBin;        # help find defaultSettings.yaml
use YAML::Tiny;     # interpret defaultSettings.yaml and other potential settings files
use File::Copy;     # to copy the original file to backup (if overwrite option set)
use File::Basename; # to get the filename and directory path
use Getopt::Long;   # to get the switches/options/flags
use File::HomeDir;  # to get users home directory, regardless of OS

# get the options
my $overwrite;
my $outputToFile;
my $silentMode;
my $tracingMode;
my $tracingModeVeryDetailed;
my $readLocalSettings=0;
my $onlyDefault;
my $showhelp;
my $cruftDirectory;

GetOptions (
 "overwrite|w"=>\$overwrite,
"outputfile|o"=>\$outputToFile,
"silent|s"=>\$silentMode,
"trace|t"=>\$tracingMode,
"ttrace|tt"=>\$tracingModeVeryDetailed,
"local|l:s"=>\$readLocalSettings,
"onlydefault|d"=>\$onlyDefault,
"help|h"=>\$showhelp,
"cruft|c=s"=>\$cruftDirectory,
);

# check local settings doesn't interfer with reading the file;
# this can happen if the script is called as follows:
#
#       latexindent.pl -l myfile.tex
#
# in which case, the GetOptions routine mistakes myfile.tex
# as the optional parameter to the l flag.
#
# In such circumstances, we correct the mistake by assuming that 
# the only argument is the file to be indented, and place it in @ARGV
if($readLocalSettings and scalar(@ARGV) < 1) {
    push(@ARGV,$readLocalSettings);
    $readLocalSettings = '';
}

# this can also happen if the script is called as
#
#       latexindent.pl -o -l myfile.tex outputfile.tex
#
# in which case, the GetOptions routine mistakes myfile.tex
# as the optional parameter to the l flag.
if($readLocalSettings and scalar(@ARGV) < 2 and $outputToFile) {
    unshift(@ARGV,$readLocalSettings);
    $readLocalSettings = '';
}

# default value of readLocalSettings
#
#       latexindent -l myfile.tex
#
# means that we wish to use localSettings.yaml
if(defined($readLocalSettings) and ($readLocalSettings eq '')){
    $readLocalSettings = 'localSettings.yaml';
}

# detailed tracing mode also implies regular tracing mode
$tracingMode = $tracingModeVeryDetailed ? 1 : $tracingMode;

# version number
my $versionNumber = "2.2";

# Check the number of input arguments- if it is 0 then simply
# display the list of options (like a manual)
if(scalar(@ARGV) < 1 or $showhelp) {
    print <<ENDQUOTE
latexindent.pl version $versionNumber
usage: latexindent.pl [options] [file][.tex]
      -h, --help
          help (see the documentation for detailed instructions and examples)
      -o, --outputfile
          output to another file; sample usage
                latexindent.pl -o myfile.tex outputfile.tex
      -w, --overwrite
          overwrite the current file- a backup will be made, but still be careful
      -s, --silent
          silent mode- no output will be given to the terminal
      -t, --trace
          tracing mode- verbose information given to the log file
      -l, --local[=myyaml.yaml]
          use localSettings.yaml (assuming it exists in the directory of your file);
          alternatively, use myyaml.yaml, if it exists
      -d, --onlydefault
          ONLY use defaultSettings.yaml, ignore ALL user files
      -c, --cruft=<cruft directory> 
          used to specify the location of backup files and indent.log
ENDQUOTE
    ;
    exit(2);
}

# set up default for cruftDirectory using the one from the input file,
# unless it has been specified using -c="/some/directory"
$cruftDirectory=dirname $ARGV[0] unless(defined($cruftDirectory));

die "Could not find directory $cruftDirectory\nExiting, no indentation done." if(!(-d $cruftDirectory));

# we'll be outputting to the logfile and to standard output
my $logfile;
my $out = *STDOUT;

# open the log file
open($logfile,">","$cruftDirectory/indent.log") or die "Can't open indent.log";

# output time to log file
my $time = localtime();
print $logfile $time;

# output version to log file
print $logfile <<ENDQUOTE

$FindBin::Script version $versionNumber, a script to indent .tex files
$FindBin::Script lives here: $FindBin::RealBin/

ENDQUOTE
;

# latexindent.exe is a standalone executable, and caches 
# the required perl modules onto the users system; they will
# only be displayed if the user specifies the trace option
if($FindBin::Script eq 'latexindent.exe' and !$tracingMode ) {
print $logfile <<ENDQUOTE
$FindBin::Script is a standalone script and caches the required perl modules
onto your system. If you'd like to see their location in your log file, indent.log, 
call the script with the tracing option, e.g latexindent.exe -t myfile.tex

ENDQUOTE
;
}

# output location of modules
if($FindBin::Script eq 'latexindent.pl' or ($FindBin::Script eq 'latexindent.exe' and $tracingMode )) {
    print $logfile "Modules are being loaded from the following directories:\n ";
    foreach my $moduleName (@listOfModules) {
            (my $file = $moduleName) =~ s|::|/|g;
            require $file . '.pm';
            print $logfile "\t",$INC{$file .'.pm'},"\n";
          }
}

# a quick options check
if($outputToFile and $overwrite) {
    print $logfile <<ENDQUOTE

WARNING:
\t You have called latexindent.pl with both -o and -w
\t -o (output to file) will take priority, and -w (over write) will be ignored

ENDQUOTE
;
    $overwrite = 0;
}

# can't call the script with MORE THAN 2 files
if(scalar(@ARGV)>2) {
    for my $fh ($out,$logfile) {print $fh <<ENDQUOTE

ERROR:
\t You're calling latexindent.pl with more than two file names
\t The script can take at MOST two file names, but you
\t need to call it with the -o switch; for example

\t latexindent.pl -o originalfile.tex outputfile.tex

No indentation done :(
Exiting...
ENDQUOTE
    };
    exit(2);
}

# don't call the script with 2 files unless the -o flag is active
if(!$outputToFile and scalar(@ARGV)==2)
{
for my $fh ($out,$logfile) {
print $fh <<ENDQUOTE

ERROR:
\t You're calling latexindent.pl with two file names, but not the -o flag.
\t Did you mean to use the -o flag ?

No indentation done :(
Exiting...
ENDQUOTE
};
    exit(2);
}

# if the script is called with the -o switch, then check that
# a second file is present in the call, e.g
#           latexindent.pl -o myfile.tex output.tex
if($outputToFile and scalar(@ARGV)==1) {
    for my $fh ($out,$logfile) {print $fh <<ENDQUOTE
ERROR: When using the -o flag you need to call latexindent.pl with 2 arguments

latexindent.pl -o "$ARGV[0]" [needs another name here]

No indentation done :(
Exiting...
ENDQUOTE
};
    exit(2);
}

# yaml work
print $logfile "YAML files:\n";

# Read in defaultSettings.YAML file
my $defaultSettings = YAML::Tiny->new;

# Open defaultSettings.yaml
$defaultSettings = YAML::Tiny->read( "$FindBin::RealBin/defaultSettings.yaml" );
print $logfile "\tReading defaultSettings.yaml from $FindBin::RealBin/defaultSettings.yaml\n\n" if($defaultSettings);

# if latexindent.exe is invoked from TeXLive, then defaultSettings.yaml won't be in 
# the same directory as it; we need to navigate to it
if(!$defaultSettings) {
    $defaultSettings = YAML::Tiny->read( "$FindBin::RealBin/../../texmf-dist/scripts/latexindent/defaultSettings.yaml");
    print $logfile "\tReading defaultSettings.yaml (2nd attempt, TeXLive, Windows) from $FindBin::RealBin/../../texmf-dist/scripts/latexindent/defaultSettings.yaml\n\n" if($defaultSettings);
}

# if both of the above attempts have failed, we need to exit
if(!$defaultSettings) {
  for my $fh ($out,$logfile) {
 print $fh <<ENDQUOTE
 ERROR  There seems to be a yaml formatting error in defaultSettings.yaml
        Please check it for mistakes- you can find a working version at https://github.com/cmhughes/latexindent.pl
        if you would like to overwrite your current version

        Exiting, no indendation done.
ENDQUOTE
};
 exit(2);
}

# the MASTER settings will initially be from defaultSettings.yaml
# and we update them with USER settings (if any) below
my %masterSettings = %{$defaultSettings->[0]};

# empty array to store the paths
my @absPaths;

# scalar to read user settings
my $userSettings;

# get information about user settings- first check if indentconfig.yaml exists
my $indentconfig = File::HomeDir->my_home . "/indentconfig.yaml";
# if indentconfig.yaml doesn't exist, check for the hidden file, .indentconfig.yaml
$indentconfig = File::HomeDir->my_home . "/.indentconfig.yaml" if(! -e $indentconfig);

if ( -e $indentconfig and !$onlyDefault ) {
      print $logfile "\tReading path information from $indentconfig\n";
      # if both indentconfig.yaml and .indentconfig.yaml exist
      if ( -e File::HomeDir->my_home . "/indentconfig.yaml" and  -e File::HomeDir->my_home . "/.indentconfig.yaml") {
            print $logfile File::HomeDir->my_home,"/.indentconfig.yaml has been found, but $indentconfig takes priority\n";
      } elsif ( -e File::HomeDir->my_home . "/indentconfig.yaml" ) {
            print $logfile "\tAlternatively, ",File::HomeDir->my_home,"/.indentconfig.yaml can be used\n";

      } elsif ( -e File::HomeDir->my_home . "/.indentconfig.yaml" ) {
            print $logfile "\tAlternatively, ",File::HomeDir->my_home,"/indentconfig.yaml can be used\n";
      }

      # read the absolute paths from indentconfig.yaml
      $userSettings = YAML::Tiny->read( "$indentconfig" );

      # integrity check
      if($userSettings) {
        print $logfile "\t",Dump \%{$userSettings->[0]};
        print $logfile "\n";
        @absPaths = @{$userSettings->[0]->{paths}};
      } else {
        print $logfile <<ENDQUOTE
WARNING:  $indentconfig
          contains some invalid .yaml formatting- unable to read from it.
          No user settings loaded.
ENDQUOTE
;
      }
} else {
      if($onlyDefault) {
        print $logfile "\tOnly default settings requested, not reading USER settings from $indentconfig\n";
        print $logfile "\tIgnoring $readLocalSettings\n" if($readLocalSettings);
        $readLocalSettings = 0;
      } else {
        # give the user instructions on where to put indentconfig.yaml or .indentconfig.yaml
        print $logfile "\tHome directory is ",File::HomeDir->my_home,"\n";
        print $logfile "\tTo specify user settings you would put indentconfig.yaml here: \n\t",File::HomeDir->my_home,"/indentconfig.yaml\n\n";
        print $logfile "\tAlternatively, you can use the hidden file .indentconfig.yaml as: \n\t",File::HomeDir->my_home,"/.indentconfig.yaml\n\n";
      }
}

# get information about LOCAL settings, assuming that $readLocalSettings exists
my $directoryName = dirname $ARGV[0];

# add local settings to the paths, if appropriate
if ( (-e "$directoryName/$readLocalSettings") and $readLocalSettings and !(-z "$directoryName/$readLocalSettings")) {
    print $logfile "\tAdding $directoryName/$readLocalSettings to paths\n\n";
    push(@absPaths,"$directoryName/$readLocalSettings");
} elsif ( !(-e "$directoryName/$readLocalSettings") and $readLocalSettings) {
      print $logfile "\tWARNING yaml file not found: \n\t$directoryName/$readLocalSettings not found\n";
      print $logfile "\t\tcarrying on without it.\n";
}

# read in the settings from each file
foreach my $settings (@absPaths) {
  # check that the settings file exists and that it isn't empty
  if (-e $settings and !(-z $settings)) {
      print $logfile "\tReading USER settings from $settings\n";
      $userSettings = YAML::Tiny->read( "$settings" );

      # if we can read userSettings
      if($userSettings) {
            # update the MASTER setttings to include updates from the userSettings
            while(my($userKey, $userValue) = each %{$userSettings->[0]}) {
                    # the update approach is slightly different for hashes vs scalars/arrays
                    if (ref($userValue) eq "HASH") {
                        while(my ($userKeyFromHash,$userValueFromHash) = each %{$userSettings->[0]{$userKey}}) {
                          $masterSettings{$userKey}{$userKeyFromHash} = $userValueFromHash;
                        }
                    } else {
                          $masterSettings{$userKey} = $userValue;
                    }
            }
            # output settings to $logfile
            if($masterSettings{logFilePreferences}{showEveryYamlRead}){
                print $logfile Dump \%{$userSettings->[0]};
                print $logfile "\n";
            } else {
                print $logfile "\t\tNot showing settings in the log file, see showEveryYamlRead.\n";
            }
       } else {
             # otherwise print a warning that we can not read userSettings.yaml
             print $logfile "WARNING\n\t$settings \n\t contains invalid yaml format- not reading from it\n";
       }
  } else {
      # otherwise keep going, but put a warning in the log file
      print $logfile "\nWARNING\n\t",File::HomeDir->my_home,"/indentconfig.yaml\n";
      if (-z $settings) {
          print $logfile "\tspecifies $settings \n\tbut this file is EMPTY- not reading from it\n\n"
      } else {
          print $logfile "\tspecifies $settings \n\tbut this file does not exist- unable to read settings from this file\n\n"
      }
  }
}

# some people may wish to see showAlmagamatedSettings
# which details the overall state of the settings modified
# from the default in various user files
if($masterSettings{logFilePreferences}{showAlmagamatedSettings}){
    print $logfile "Almagamated/overall settings to be used:\n";
    print $logfile Dump \%masterSettings ;
}

# scalar variables
my $defaultIndent = $masterSettings{defaultIndent};
my $alwaysLookforSplitBraces = $masterSettings{alwaysLookforSplitBraces};
my $alwaysLookforSplitBrackets = $masterSettings{alwaysLookforSplitBrackets};
my $backupExtension = $masterSettings{backupExtension};
my $indentPreamble = $masterSettings{indentPreamble};
my $onlyOneBackUp = $masterSettings{onlyOneBackUp};
my $maxNumberOfBackUps = $masterSettings{maxNumberOfBackUps};
my $removeTrailingWhitespace = $masterSettings{removeTrailingWhitespace};
my $cycleThroughBackUps = $masterSettings{cycleThroughBackUps};

# hash variables
my %lookForAlignDelims= %{$masterSettings{lookForAlignDelims}};
my %indentRules= %{$masterSettings{indentRules}};
my %verbatimEnvironments= %{$masterSettings{verbatimEnvironments}};
my %noIndentBlock= %{$masterSettings{noIndentBlock}};
my %checkunmatched= %{$masterSettings{checkunmatched}};
my %checkunmatchedELSE= %{$masterSettings{checkunmatchedELSE}};
my %checkunmatchedbracket= %{$masterSettings{checkunmatchedbracket}};
my %noAdditionalIndent= %{$masterSettings{noAdditionalIndent}};
my %indentAfterHeadings= %{$masterSettings{indentAfterHeadings}};
my %indentAfterItems= %{$masterSettings{indentAfterItems}};
my %itemNames= %{$masterSettings{itemNames}};
my %constructIfElseFi= %{$masterSettings{constructIfElseFi}};
my %fileExtensionPreference= %{$masterSettings{fileExtensionPreference}};
my %fileContentsEnvironments= %{$masterSettings{fileContentsEnvironments}};

# original name of file
my $fileName = $ARGV[0];

# sort the file extensions by preference 
my @fileExtensions = sort { $fileExtensionPreference{$a} <=> $fileExtensionPreference{$b} } keys(%fileExtensionPreference);

# get the base file name, allowing for different extensions (possibly no extension)
my ($dir, $name, $ext) = fileparse($fileName, @fileExtensions);

# quick check to make sure given file type is supported
if( -e $ARGV[0] and !$ext ){
for my $fh ($out,$logfile) {print $fh <<ENDQUOTE
The file $ARGV[0] exists , but the extension does not correspond to any given in fileExtensionPreference;
consinder updating fileExtensionPreference.

Exiting, no indentation done.
ENDQUOTE
};
exit(2);
}

# if no extension, search according to fileExtensionPreference
if (!$ext) {
    print $logfile "File extension work:\n";
    print $logfile "\tlatexindent called to act upon $fileName with an, as yet, unrecognised file extension;\n";
    print $logfile "\tsearching for file with an extension in the following order (see fileExtensionPreference):\n\t\t";
    print $logfile join("\n\t\t",@fileExtensions),"\n";
    my $fileFound = 0;
    # loop through the known file extensions (see @fileExtensions)
    foreach my $fileExt (@fileExtensions ){
        if ( -e $fileName.$fileExt ) {
           print $logfile "\t",$fileName,$fileExt," found!\n";
           $fileName .= $fileExt;
           print $logfile "\tUpdated $ARGV[0] to ",$fileName,"\n";
           $fileFound = 1;
           last;
        }
    }
    unless($fileFound){
      print $logfile "\tI couldn't find a match for $ARGV[0] in fileExtensionPreference (see defaultSettings.yaml)\n";
      foreach my $fileExt (@fileExtensions ){
        print $logfile "\t\tI searched for $ARGV[0]$fileExt\n";
      }
      print $logfile "\tbut couldn't find any of them.\n";
      print $logfile "\tConsider updating fileExtensionPreference. \nError: Exiting, no indendation done.";
      die "I couldn't find a match for $ARGV[0] in fileExtensionPreference.\nExiting, no indendation done.\n" 
    }
  } else {
    # if the file has a recognised extension, check that the file exists
    unless( -e $ARGV[0] ){
      print $logfile "Error: I couldn't find $ARGV[0], are you sure it exists?. No indentation done. \nExiting.\n";
      die "Error: I couldn't find $ARGV[0], are you sure it exists?. Exiting.\n" ;
    }
  }

# if we want to over write the current file create a backup first
if ($overwrite) {
    print $logfile "\nBackup procedure:\n";
    # cruft directory
    print $logfile "\tDirectory for backup files and indent.log: $cruftDirectory\n\n";

    my $backupFile; 

    # backup file name is the base name
    $backupFile = basename($fileName,@fileExtensions);

    # add the user's backup directory to the backup path
    $backupFile = "$cruftDirectory/$backupFile";

    # if both ($onlyOneBackUp and $maxNumberOfBackUps) then we have
    # a conflict- er on the side of caution and turn off onlyOneBackUp
    if($onlyOneBackUp and $maxNumberOfBackUps>1) {
        print $logfile "\t WARNING: onlyOneBackUp=$onlyOneBackUp and maxNumberOfBackUps: $maxNumberOfBackUps\n";
        print $logfile "\t\t setting onlyOneBackUp=0 which will allow you to reach $maxNumberOfBackUps back ups\n";
        $onlyOneBackUp = 0;
    }

    # if the user has specified that $maxNumberOfBackUps = 1 then
    # they only want one backup
    if($maxNumberOfBackUps==1) {
        $onlyOneBackUp=1 ;
        print $logfile "\t FYI: you set maxNumberOfBackUps=1, so I'm setting onlyOneBackUp: 1 \n";
    } elsif($maxNumberOfBackUps<=0 and !$onlyOneBackUp) {
        $onlyOneBackUp=0 ;
        $maxNumberOfBackUps=-1;
    }

    # if onlyOneBackUp is set, then the backup file will
    # be overwritten each time
    if($onlyOneBackUp) {
        $backupFile .= $backupExtension;
        print $logfile "\tcopying $fileName to $backupFile\n";
        print $logfile "\t$backupFile was overwritten\n\n" if (-e $backupFile);
    } else {
        # start with a backup file .bak0 (or whatever $backupExtension is present)
        my $backupCounter = 0;
        $backupFile .= $backupExtension.$backupCounter;

        # if it exists, then keep going: .bak0, .bak1, ...
        while (-e $backupFile or $maxNumberOfBackUps>1) {
            if($backupCounter==$maxNumberOfBackUps) {
                print $logfile "\t maxNumberOfBackUps reached ($maxNumberOfBackUps)\n";

                # some users may wish to cycle through back up files, e.g:
                #    copy myfile.bak1 to myfile.bak0
                #    copy myfile.bak2 to myfile.bak1
                #    copy myfile.bak3 to myfile.bak2
                #
                #    current back up is stored in myfile.bak4
                if($cycleThroughBackUps) {
                    print $logfile "\t cycleThroughBackUps detected (see cycleThroughBackUps) \n";
                    for(my $i=1;$i<=$maxNumberOfBackUps;$i++) {
                        # remove number from backUpFile
                        my $oldBackupFile = $backupFile;
                        $oldBackupFile =~ s/$backupExtension.*/$backupExtension/;
                        my $newBackupFile = $oldBackupFile;

                        # add numbers back on
                        $oldBackupFile .= $i;
                        $newBackupFile .= $i-1;

                        # check that the oldBackupFile exists
                        if(-e $oldBackupFile){
                        print $logfile "\t\t copying $oldBackupFile to $newBackupFile \n";
                            copy($oldBackupFile,$newBackupFile) or die "Could not write to backup file $backupFile. Please check permissions. Exiting.\n";
                        }
                    }
                }

                # rest maxNumberOfBackUps
                $maxNumberOfBackUps=1 ;
                last; # break out of the loop
            } elsif(!(-e $backupFile)) {
                $maxNumberOfBackUps=1 ;
                last; # break out of the loop
            }
            print $logfile "\t $backupFile already exists, incrementing by 1...\n";
            $backupCounter++;
            $backupFile =~ s/$backupExtension.*/$backupExtension$backupCounter/;
        }
        print $logfile "\n\t copying $fileName to $backupFile\n\n";
    }

    # output these lines to the log file
    print $logfile "\tBackup file: ",$backupFile,"\n";
    print $logfile "\tOverwriting file: ",$fileName,"\n\n";
    copy($fileName,$backupFile) or die "Could not write to backup file $backupFile. Please check permissions. Exiting.\n";
}

if(!($outputToFile or $overwrite)) {
    print $logfile "Just out put to the terminal :)\n\n" if !$silentMode  ;
}


# scalar variables
my $line;                   # $line: takes the $line of the file
my $inpreamble=!$indentPreamble;
                            # $inpreamble: switch to determine if in
                            #               preamble or not
my $inverbatim=0;           # $inverbatim: switch to determine if in
                            #               a verbatim environment or not
my $delimiters=0;           # $delimiters: switch that governs if
                            #              we need to check for & or not
my $trailingcomments;       # $trailingcomments stores the comments at the end of
                            #           a line
my $lineCounter=0;          # $lineCounter keeps track of the line number
my $inIndentBlock=0;        # $inindentblock: switch to determine if in
                            #               a inindentblock or not
my $inFileContents=0;       # $inFileContents: switch to determine if we're in a filecontents environment

# array variables
my @lines;                  # @lines: stores the newly indented lines
my @mainfile;               # @mainfile: stores input file; used to
                            #            grep for \documentclass

# array of hashes, containing details of commands & environments
my @masterIndentationArrayOfHashes;

# check to see if the current file has \documentclass, if so, then
# it's the main file, if not, then it doesn't have preamble
open(MAINFILE, $fileName) or die "Could not open input file, $fileName";
    @mainfile=<MAINFILE>;
close(MAINFILE);

# if the MAINFILE doesn't have a \documentclass statement, then
# it shouldn't have preamble
if(scalar(@{[grep(m/^\s*\\documentclass/, @mainfile)]})==0) {
    $inpreamble=0;

    print $logfile "Trace:\tNo documentclass detected, assuming no preamble\n" if($tracingMode);
} else {
    print $logfile "Trace:\t documentclass detected, assuming preamble\n" if($tracingMode);
}

# the previous OPEN command puts us at the END of the file
open(MAINFILE, $fileName) or die "Could not open input file, $fileName";

# loop through the lines in the INPUT file
while(<MAINFILE>) {
    # increment the line counter
    $lineCounter++;

    # very detailed output to logfile
    if($tracingModeVeryDetailed){
        if( @masterIndentationArrayOfHashes){
            print $logfile "\nLine $lineCounter\t (detailed trace) indentation hash: \n" if($tracingMode);
            for my $href ( @masterIndentationArrayOfHashes) {
                   print $logfile Dump \%{$href};
            }
        }
    }

    # tracing mode
    print $logfile $masterSettings{logFilePreferences}{traceModeBetweenLines} if($tracingMode and !($inpreamble or $inverbatim or $inIndentBlock));

    # check to see if we're still in the preamble
    # or in a verbatim environment or in IndentBlock
    if(!($inpreamble or $inverbatim or $inIndentBlock)) {
        # if not, remove all leading spaces and tabs
        # from the current line, assuming it isn't empty
        s/^\t*// if($_ !~ /^((\s*)|(\t*))*$/);
        s/^\s*// if($_ !~ /^((\s*)|(\t*))*$/);

        # tracing mode
        print $logfile "Line $lineCounter\t removing leading spaces\n" if($tracingMode);
    } else {
        # otherwise check to see if we've reached the main
        # part of the document
        if(m/^\s*\\begin\{document\}/ and !$inFileContents and !$inverbatim) {
            $inpreamble = 0;

            # tracing mode
            print $logfile "Line $lineCounter\t \\begin{document} found, switching indentation searches on. \n" if($tracingMode);
        } else {
            # tracing mode
            if($inpreamble) {
                print $logfile "Line $lineCounter\t still in PREAMBLE, leaving exisiting leading space (see indentPreamble)\n" if($tracingMode);
            } elsif($inverbatim) {
                print $logfile "Line $lineCounter\t in VERBATIM-LIKE environment, leaving exisiting leading space\n" if($tracingMode);
            } elsif($inIndentBlock) {
                print $logfile "Line $lineCounter\t in NO INDENT BLOCK, leaving exisiting leading space\n" if($tracingMode);
            }
        }
    }

    # \END{ENVIRONMENTS}, or CLOSING } or CLOSING ]
    # \END{ENVIRONMENTS}, or CLOSING } or CLOSING ]
    # \END{ENVIRONMENTS}, or CLOSING } or CLOSING ]

    # check to see if we're ending a filecontents environment
    if( $_ =~ m/^\s*\\end\{(.*?)\}/ and  $fileContentsEnvironments{$1} and $inFileContents){
        print $logfile "Line $lineCounter\t Found END of filecontents environment (see fileContentsEnvironments)\n" if($tracingMode);
        $inFileContents = 0;
    }

    # set the delimiters switch
    $delimiters = @masterIndentationArrayOfHashes?$masterIndentationArrayOfHashes[-1]{alignmentDelimiters}:0;

    if($inverbatim){
        print $logfile "Line $lineCounter\t $masterSettings{logFilePreferences}{traceModeDecreaseIndent} PHASE 1: in VERBATIM-LIKE environment, looking for $masterIndentationArrayOfHashes[-1]{end} \n" if($tracingMode);
    } elsif($inIndentBlock) {
        print $logfile "Line $lineCounter\t in NO INDENT BLOCK, doing nothing\n" if($tracingMode);
    } elsif($delimiters) {
        print $logfile "Line $lineCounter\t $masterSettings{logFilePreferences}{traceModeDecreaseIndent} PHASE 1: in ALIGNMENT BLOCK environment, looking for $masterIndentationArrayOfHashes[-1]{end}\n" if($tracingMode);
    } elsif($inpreamble and !$inFileContents) {
        print $logfile "Line $lineCounter\t In preamble, looking for \\begin{document}\n" if($tracingMode);
    } elsif($inpreamble and $inFileContents) {
        print $logfile "Line $lineCounter\t In preamble, in filecontents environment\n" if($tracingMode);
    } else {
        print $logfile "Line $lineCounter\t $masterSettings{logFilePreferences}{traceModeDecreaseIndent} PHASE 1: looking for reasons to DECREASE indentation of CURRENT line \n" if($tracingMode);
    }

    # check to see if we have \end{something} or \]
    &at_end_of_env_or_eq() unless ($inpreamble or $inIndentBlock);

    # check to see if we have %* \end{something} for alignment blocks
    # outside of environments
    &end_command_with_alignment();

    # check to see if we're at the end of a noindent
    # block %\end{noindent}
    &at_end_noindent();

    # only check for unmatched braces if we're not in
    # a verbatim-like environment or in the preamble or in a
    # noIndentBlock or in a delimiter block
    if(!($inverbatim or $inpreamble or $inIndentBlock or $delimiters)) {
        # The check for closing } and ] relies on counting, so
        # we have to remove trailing comments so that any {, }, [, ]
        # that are found after % are not counted
        #
        # note that these lines are NOT in @lines, so we
        # have to store the $trailingcomments to put
        # back on after the counting
        #
        # note the use of (?<!\\)% so that we don't match \%
        if ( $_=~ m/(?<!\\)%.*/) {
            s/((?<!\\)%.*)//;
            $trailingcomments=$1;

            # tracing mode
            print $logfile "Line $lineCounter\t Removed trailing comments to count braces and brackets: $1\n" if($tracingMode);
        }

        # check to see if we're at the end of a \parbox, \marginpar
        # or other split-across-lines command and check that
        # we're not starting another command that has split braces (nesting)
        &end_command_or_key_unmatched_braces();

        # check to see if we're at the end of a command that splits
        # [ ] across lines
        &end_command_or_key_unmatched_brackets();

        # check for a heading such as \chapter, \section, etc
        &indent_heading();

        # check for \item
        &indent_item();

        # check for \else or \fi
        &indent_if_else_fi();

        # add the trailing comments back to the end of the line
        if(scalar($trailingcomments)) {
            # some line break magic, http://stackoverflow.com/questions/881779/neatest-way-to-remove-linebreaks-in-perl
            s/\R//;
            $_ = $_ . $trailingcomments."\n" ;

            # tracing mode
            print $logfile "Line $lineCounter\t counting braces/brackets complete\n" if($tracingMode);
            print $logfile "Line $lineCounter\t Adding trailing comments back on: $trailingcomments\n" if($tracingMode);

            # empty the trailingcomments
            $trailingcomments='';

        }
        # remove trailing whitespace
        if ($removeTrailingWhitespace) {
            print $logfile "Line $lineCounter\t removing trailing whitespace (see removeTrailingWhitespace)\n" if ($tracingMode);
            s/\s+$/\n/;
        }
    }

    # ADD CURRENT LEVEL OF INDENTATION
    # ADD CURRENT LEVEL OF INDENTATION
    # ADD CURRENT LEVEL OF INDENTATION
    # (unless we're in a delimiter-aligned block)
    if(!$delimiters) {
        # make sure we're not in a verbatim block or in the preamble
        if($inverbatim or $inpreamble or $inIndentBlock) {
           # just push the current line as is
           push(@lines,$_);
        } else {
            # add current value of indentation to the current line
            # and output it
            # unless this would only create trailing whitespace and the
            # corresponding option is set
            unless ($_ =~ m/^$/ and $removeTrailingWhitespace){
                $_ = &current_indentation().$_;
            }
            push(@lines,$_);
            # tracing mode
            print $logfile "Line $lineCounter\t $masterSettings{logFilePreferences}{traceModeAddCurrentIndent} PHASE 2: Adding current level of indentation: ",&current_indentation_names(),"\n" if($tracingMode);
        }
    } else {
        # output to @block (within masterIndentationArrayOfHashes) if we're in a delimiter block
        push(@{$masterIndentationArrayOfHashes[-1]{block}},$_);

        # tracing mode
        print $logfile "Line $lineCounter\t In delimeter block ($masterIndentationArrayOfHashes[-1]{name}), waiting for block formatting\n" if($tracingMode);
    }

    # \BEGIN{ENVIRONMENT} or OPEN { or OPEN [
    # \BEGIN{ENVIRONMENT} or OPEN { or OPEN [
    # \BEGIN{ENVIRONMENT} or OPEN { or OPEN [

    # check to see if we're beginning a filecontents environment
    if( ($_ =~ m/^\s*\\begin\{(.*?)\}/ and  $fileContentsEnvironments{$1} and !$inverbatim)){
        print $logfile "Line $lineCounter\t Found filecontents environment (see fileContentsEnvironments)\n" if($tracingMode);
        $inFileContents = 1;
    }

    # only check for new environments or commands if we're
    # not in a verbatim-like environment or in the preamble
    # or in a noIndentBlock, or delimiter block
    if(!($inverbatim or $inpreamble or $inIndentBlock or $delimiters)) {

        print $logfile "Line $lineCounter\t $masterSettings{logFilePreferences}{traceModeIncreaseIndent} PHASE 3: looking for reasons to INCREASE indentation of SUBSEQUENT lines \n" if($tracingMode);

        # check if we are in a
        #   % \begin{noindent}
        # block; this is similar to a verbatim block, the user
        # may not want some blocks of code to be touched
        #
        # IMPORTANT: this needs to go before the trailing comments
        # are removed!
        &at_beg_noindent();

        # check for
        #   %* \begin{tabular}
        # which might be used to align blocks that contain delimeters that
        # are NOT contained in an alignment block in the usual way, e.g
        #   \matrix{
        #       %* \begin{tabular}
        #           1 & 2 \\
        #           3 & 4 \\
        #       %* \end{tabular}
        #           }
        &begin_command_with_alignment();
        if(@masterIndentationArrayOfHashes){
               $delimiters = $masterIndentationArrayOfHashes[-1]{alignmentDelimiters}||0;
             }

        # remove trailing comments so that any {, }, [, ]
        # that are found after % are not counted
        #
        # note that these lines are already in @lines, so we
        # can remove the trailing comments WITHOUT having
        # to put them back in
        #
        # Note that this won't match \%
        s/(?<!\\)%.*// if( $_=~ m/(?<!\\)%.*/);

        # tracing mode
        print $logfile "Line $lineCounter\t Removing trailing comments for brace count (line is already stored)\n" if($tracingMode);

        # check to see if we have \begin{something} or \[
        &at_beg_of_env_or_eq() if(!($inverbatim or $inpreamble or $inIndentBlock or $delimiters));
        if(@masterIndentationArrayOfHashes){
               $delimiters = $masterIndentationArrayOfHashes[-1]{alignmentDelimiters}||0;
             }

        # check to see if we have \parbox, \marginpar, or
        # something similar that might split braces {} across lines,
        # specified in %checkunmatched hash table
        &start_command_or_key_unmatched_braces() if(!($inverbatim or $inpreamble or $inIndentBlock or $delimiters));

        # check for an else statement (braces, not \else)
        &check_for_else() if(!($inverbatim or $inpreamble or $inIndentBlock or $delimiters));

        # check for a command that splits [] across lines
        &start_command_or_key_unmatched_brackets();

        # check for a heading
        &indent_after_heading() if(!($inverbatim or $inpreamble or $inIndentBlock or $delimiters));

        # check for \item
        &indent_after_item() if(!($inverbatim or $inpreamble or $inIndentBlock or $delimiters));

        # check for \if or \else command
        &indent_after_if_else_fi() if(!($inverbatim or $inpreamble or $inIndentBlock or $delimiters));

        # tracing mode
        if($tracingMode){
            if(scalar(@masterIndentationArrayOfHashes)){
                print $logfile "Line $lineCounter\t Indentation array: ",&current_indentation_names(),"\n";
              } else {
                print $logfile "Line $lineCounter\t Indentation array empty\n";
              }
        }
    }
}

# close the main file
close(MAINFILE);

# put line count information in the log file
print $logfile "Line Count of $fileName: ",scalar(@mainfile),"\n";
print $logfile "Line Count of indented $fileName: ",scalar(@lines);
if(scalar(@mainfile) != scalar(@lines))
{
  print $logfile <<ENDQUOTE
WARNING: \t line count of original file and indented file does
\t not match- consider reverting to a back up, see $backupExtension;
ENDQUOTE
;
} else {
    print $logfile "\n\nLine counts of original file and indented file match.\n";
}

# output the formatted lines to the terminal
print @lines if(!$silentMode);

# if -w is active then output to $ARGV[0]
if($overwrite) {
    open(OUTPUTFILE,">",$fileName);
    print OUTPUTFILE @lines;
    close(OUTPUTFILE);
}

# if -o is active then output to $ARGV[1]
if($outputToFile) {
    open(OUTPUTFILE,">",$ARGV[1]);
    print OUTPUTFILE @lines;
    close(OUTPUTFILE);
    print $logfile "Output from indentation written to $ARGV[1].\n";
}

# final line of the logfil
print $logfile "\n",$masterSettings{logFilePreferences}{endLogFileWith};

# close the log file
close($logfile);

exit(0);

sub indent_if_else_fi{
    # PURPOSE: set indentation of line that contains \else, \fi  command
    #
    #

    # @masterIndentationArrayOfHashes could be empty -- if so, exit
    return unless @masterIndentationArrayOfHashes;
    return unless $constructIfElseFi{$masterIndentationArrayOfHashes[-1]{name}};

    # look for \fi
    if( $_ =~ m/^\s*\\fi/) {
        # tracing mode
        print $logfile "Line $lineCounter\t \\fi command found, matching: \\",$masterIndentationArrayOfHashes[-1]{name}, "\n" if($tracingMode);
        &decrease_indent($masterIndentationArrayOfHashes[-1]{name});
    } 
    # look for \else or \or
    elsif( $_ =~ m/^\s*\\else/ or $_ =~ m/^\s*\\or/ ) {
        # tracing mode
        print $logfile "Line $lineCounter\t \\else command found, matching: \\",$masterIndentationArrayOfHashes[-1]{name}, "\n" if($tracingMode);
        print $logfile "Line $lineCounter\t decreasing indent, still looking for \\fi to match \\",&current_indentation_names(), "\n" if($tracingMode);

        # finding an \else or \or command removes the *indentation*, but not the entry from the master hash
        $masterIndentationArrayOfHashes[-1]{indent}="";
    }
}

sub indent_after_if_else_fi{
    # PURPOSE: set indentation *after* \if construct such as
    #
    #               \ifnum\x=2
    #                   <stuff>
    #                   <stuff>
    #               \else
    #                   <stuff>
    #                   <stuff>
    #               \fi
    #
    #   How to read /^\s*\\(if.*?)(\s|\\|\#)
    #
    #       ^\s*        begins with multiple spaces (possibly none)
    #       \\(if.*?)(\s|\\|\#)   matches \if... up to either a
    #                             space, a \, or a #
    #   Note: this won't match \if.*\fi
    if( $_ =~ m/^\s*\\(if.*?)(\s|\\|\#)/ and $_ !~ m/^\s*\\(if.*?\\fi)/ and $constructIfElseFi{$1}) {
        # tracing mode
        print $logfile "Line $lineCounter\t ifelsefi construct found: $1 \n" if($tracingMode);
        &increase_indent({name=>$1,type=>"ifelseif"});
    } elsif(@masterIndentationArrayOfHashes) {
        if( ($_ =~ m/^\s*\\else/ or $_ =~ m/^\s*\\or/ ) and $constructIfElseFi{$masterIndentationArrayOfHashes[-1]{name}}) {
            # tracing mode
            print $logfile "Line $lineCounter\t setting indent *after* \\else or \\or command found for $masterIndentationArrayOfHashes[-1]{name} \n" if($tracingMode);

            # recover the indentation to be implemented *after* the \else or \or
            $masterIndentationArrayOfHashes[-1]{indent}=$indentRules{$masterIndentationArrayOfHashes[-1]{name}}||$defaultIndent unless ($noAdditionalIndent{$masterIndentationArrayOfHashes[-1]{name}});
        }
  }
}

sub indent_item{
    # PURPOSE: when considering environments that can contain items, such 
    #          as enumerate, itemize, etc, this subroutine sets the indentation for the item *itself*

    return unless(scalar(@masterIndentationArrayOfHashes)>1);
    return unless $indentAfterItems{$masterIndentationArrayOfHashes[-2]{name}};

    if( $_ =~ m/^\s*\\(.*?)(\[|\s)/ and $itemNames{$1}){
        # tracing mode
        print $logfile "Line $lineCounter\t $1 found within ",$masterIndentationArrayOfHashes[-1]{name}," environment (see indentAfterItems and itemNames)\n" if($tracingMode);
        if($itemNames{$masterIndentationArrayOfHashes[-1]{name}}) {
            print $logfile "Line $lineCounter\t $1 found - neutralizing indentation from previous ",$masterIndentationArrayOfHashes[-1]{name},"\n" if($tracingMode);
            &decrease_indent($1);
        }
    }

}

sub indent_after_item{
    # PURPOSE: Set the indentation *after* the item
    #          This matches a line that begins with
    #
    #               \item
    #               \item[
    #               \myitem
    #               \myitem[
    #
    #           or anything else specified in itemNames
    #
    return unless @masterIndentationArrayOfHashes;
    return unless $indentAfterItems{$masterIndentationArrayOfHashes[-1]{name}};

    if( $_ =~ m/^\s*\\(.*?)(\[|\s)/
            and $itemNames{$1}) {
        # tracing mode
        print $logfile "Line $lineCounter\t $1 found within ",$masterIndentationArrayOfHashes[-1]{name}," environment (see indentAfterItems and itemNames)\n" if($tracingMode);
        &increase_indent({name=>$1,type=>"item"});
    }
}

sub begin_command_with_alignment{
    # PURPOSE: This matches
    #           %* \begin{tabular}
    #          with any number of spaces (possibly none) between
    #          the * and \begin{noindent}.
    #
    #          the comment symbol IS indended!
    #
    #          This is to align blocks that contain delimeters that
    #          are NOT contained in an alignment block in the usual way, e.g
    #             \matrix{
    #                 %* \begin{tabular}
    #                     1 & 2 \\
    #                     3 & 4 \\
    #                 %* \end{tabular}
    #                     }

    if( $_ =~ m/^\s*%\*\s*\\begin\{(.*?)\}/ and $lookForAlignDelims{$1}) {
           # increase the indentation
           &increase_indent({name=>$1,
                             alignmentDelimiters=>1,
                             type=>"environment",
                             begin=>"\\begin{$1}",
                             end=>"\\end{$1}"});
           # tracing mode
           print $logfile "Line $lineCounter\t Delimiter environment started: $1 (see lookForAlignDelims)\n" if($tracingMode);
    }
}

sub end_command_with_alignment{
    # PURPOSE: This matches
    #           %* \end{tabular}
    #          with any number of spaces (possibly none) between
    #          the * and \end{tabular} (or any other name used from
    #          lookFroAlignDelims)
    #
    #          Note: the comment symbol IS indended!
    #
    #          This is to align blocks that contain delimeters that
    #          are NOT contained in an alignment block in the usual way, e.g
    #             \matrix{
    #                 %* \begin{tabular}
    #                     1 & 2 \\
    #                     3 & 4 \\
    #                 %* \end{tabular}
    #                     }
    return unless @masterIndentationArrayOfHashes;
    return unless $masterIndentationArrayOfHashes[-1]{alignmentDelimiters};

    if( $_ =~ m/^\s*%\*\s*\\end\{(.*?)\}/ and $lookForAlignDelims{$1}) {
        # same subroutine used at the end of regular tabular, align, etc
        # environments
        if($delimiters) {
            &print_aligned_block();
            &decrease_indent($1);
        } else {
            # tracing mode
            print $logfile "Line $lineCounter\t FYI: did you mean to start a delimiter block on a previous line? \n" if($tracingMode);
            print $logfile "Line $lineCounter\t      perhaps using %* \\begin{$1}\n" if($tracingMode);
        }
    }
}

sub indent_heading{
    # PURPOSE: This matches
    #           \part
    #           \chapter
    #           \section
    #           \subsection
    #           \subsubsection
    #           \paragraph
    #           \subparagraph
    #
    #           and anything else listed in indentAfterHeadings
    #
    #           This subroutine specifies the indentation for the
    #           heading itself, i.e the line that has \chapter, \section etc
    if( $_ =~ m/^\s*\\(.*?)(\[|{)/ and $indentAfterHeadings{$1}){
       # tracing mode
       print $logfile "Line $lineCounter\t Heading found: $1 \n" if($tracingMode);

       # get the heading settings, it's a hash within a hash
       my %currentHeading = %{$indentAfterHeadings{$1}};

       # $previousHeadingLevel: scalar that stores which heading
       # we are under: \part, \chapter, etc
       my $previousHeadingLevel=0;         

       # form an array of the headings available
       my @headingStore=();
       foreach my $env (@masterIndentationArrayOfHashes){
           if($env->{type} eq 'heading'){
               push(@headingStore,$env->{name});
               # update heading level
               $previousHeadingLevel= $env->{headinglevel};
             }
         }

       # if current heading level < old heading level,
       if($currentHeading{level}<$previousHeadingLevel) {
            # decrease indentation, but only if
            # specified in indentHeadings. Note that this check
            # needs to be done here- decrease_indent won't
            # check a nested hash

            if(scalar(@headingStore)) {
               while($currentHeading{level}<$previousHeadingLevel and scalar(@headingStore)) {
                    my $higherHeadingName = pop(@headingStore);
                    my %higherLevelHeading = %{$indentAfterHeadings{$higherHeadingName}};

                    # tracing mode
                    print $logfile "Line $lineCounter\t stepping UP heading level from $higherHeadingName \n" if($tracingMode);

                    &decrease_indent($higherHeadingName) if($higherLevelHeading{indent});
                    $previousHeadingLevel=$higherLevelHeading{level};
               }
               # put the heading name back in to storage
               push(@headingStore,$1);
            }
       } elsif($currentHeading{level}==$previousHeadingLevel) {
            if(scalar(@headingStore)) {
                 my $higherHeadingName = pop(@headingStore);
                 my %higherLevelHeading = %{$indentAfterHeadings{$higherHeadingName}};
                 &decrease_indent($higherHeadingName) if($higherLevelHeading{indent});
            }
       } 
    }
}

sub indent_after_heading{
    # PURPOSE: This matches
    #           \part
    #           \chapter
    #           \section
    #           \subsection
    #           \subsubsection
    #           \paragraph
    #           \subparagraph
    #
    #           and anything else listed in indentAfterHeadings
    #
    #           This subroutine is specifies the indentation for
    #           the text AFTER the heading, i.e the body of conent
    #           in each \chapter, \section, etc
    if( $_ =~ m/^\s*\\(.*?)(\[|{)/ and $indentAfterHeadings{$1}) {
       # get the heading settings- it's a hash within a hash
       my %currentHeading = %{$indentAfterHeadings{$1}};

       &increase_indent({name=>$1,type=>"heading",headinglevel=>$currentHeading{level}}) if($currentHeading{indent});
    }
}

sub at_end_noindent{
    # PURPOSE: This matches
    #           % \end{noindent}
    #          with any number of spaces (possibly none) between
    #          the comment and \end{noindent}.
    #
    #          the comment symbol IS indended!
    #
    #          This is for blocks of code that the user wants
    #          to leave untouched- similar to verbatim blocks

    if( $_ =~ m/^%\s*\\end\{(.*?)\}/ and $noIndentBlock{$1}) {
            $inIndentBlock=0;
            # tracing mode
            print $logfile "Line $lineCounter\t % \\end{no indent block} found, switching inIndentBlock OFF \n" if($tracingMode);
    }
}

sub at_beg_noindent{
    # PURPOSE: This matches
    #           % \begin{noindent}
    #          with any number of spaces (possibly none) between
    #          the comment and \begin{noindent}.
    #
    #          the comment symbol IS indended!
    #
    #          This is for blocks of code that the user wants
    #          to leave untouched- similar to verbatim blocks

    if( $_ =~ m/^%\s*\\begin\{(.*?)\}/ and $noIndentBlock{$1}) {
           $inIndentBlock = 1;
           # tracing mode
           print $logfile "Line $lineCounter\t % \\begin{no indent block} found, switching inIndentBlock ON \n" if($tracingMode);
    }
}

sub start_command_or_key_unmatched_brackets{
    # PURPOSE: This matches
    #              \pgfplotstablecreatecol[...
    #
    #              or any other command/key that has brackets [ ]
    #              split across lines specified in the
    #              hash tables, %checkunmatchedbracket
    #
    # How to read: ^\s*(\\)?(.*?)(\[\s*)
    #
    #       ^       line begins with
    #       \s*     any (or no)spaces
    #       (\\)?   matches a \ backslash but not necessarily
    #       (.*?)   non-greedy character match and store the result
    #       ((?<!\\)\[\s*) match [ possibly leading with spaces
    #                      but it WON'T match \[

    if ($_ =~ m/^\s*(\\)?(.*?)(\s*(?<!\\)\[)/
        and ($checkunmatchedbracket{$2} or $alwaysLookforSplitBrackets)) {
            # store the command name, because $2
            # will not exist after the next match
            my $commandname = $2;
            my $matchedBRACKETS=0;

            # match [ but don't match \[
            $matchedBRACKETS++ while ($_ =~ /(?<!\\)\[/g);
            # match ] but don't match \]
            $matchedBRACKETS-- while ($_ =~ /(?<!\\)\]/g);

            # set the indentation
            if($matchedBRACKETS != 0 ) {
                  # tracing mode
                  print $logfile "Line $lineCounter\t Found opening BRACKET [ $commandname\n" if($tracingMode);

                  &increase_indent({name=>$commandname,matchedBRACKETS=>$matchedBRACKETS,type=>'splitBrackets'});
            }
        }
}

sub end_command_or_key_unmatched_brackets{
    # PURPOSE:  Check for the closing BRACKET of a command that
    #           splits its BRACKETS across lines, such as
    #
    #               \pgfplotstablecreatecol[ ...
    #
    #           It works by checking if we have any entries
    #           in the array @masterIndentationArrayOfHashes, and making
    #           sure that we're not starting another command/key
    #           that has split BRACKETS (nesting).
    #
    #           It also checks that the line is not commented.
    #
    #           We count the number of [ and ADD to the counter
    #                                  ] and SUBTRACT to the counter
    return unless @masterIndentationArrayOfHashes;
    return unless ($masterIndentationArrayOfHashes[-1]{type} eq 'splitBrackets');
    print $logfile "Line $lineCounter\t Searching for closing BRACKET ] $masterIndentationArrayOfHashes[-1]{name}\n" if($tracingMode);

    if(!($_ =~ m/^\s*(\\)?(.*?)(\s*\[)/
        and ($checkunmatchedbracket{$2} or $alwaysLookforSplitBrackets))
        and $_ !~ m/^\s*%/) {

       # get the details of the most recent command name
       my $commandname =  $masterIndentationArrayOfHashes[-1]{name};
       my $matchedBRACKETS = $masterIndentationArrayOfHashes[-1]{matchedBRACKETS};

       # match [ but don't match \[
       $matchedBRACKETS++ while ($_ =~ m/(?<!\\)\[/g);

       # match ] but don't match \]
       $matchedBRACKETS-- while ($_ =~ m/(?<!\\)\]/g);

       # if we've matched up the BRACKETS then
       # we can decrease the indent by 1 level
       if($matchedBRACKETS == 0){
            # tracing mode
            print $logfile "Line $lineCounter\t Found closing BRACKET ] $commandname\n" if($tracingMode);

            # decrease the indentation (if appropriate)
            &decrease_indent($commandname);
       } else {
           # otherwise we need to enter the new value
           # of $matchedBRACKETS and the value of $command
           # back into storage
           $masterIndentationArrayOfHashes[-1]{matchedBRACKETS} = $matchedBRACKETS;

           # tracing mode
           print $logfile "Line $lineCounter\t Searching for closing BRACKET ] $commandname\n" if($tracingMode);
       }
     }
}

sub start_command_or_key_unmatched_braces{
    # PURPOSE: This matches
    #              \parbox{...
    #              \parbox[..]..{
    #              empty header/.style={
    #              \foreach \something
    #              etc
    #
    #              or any other command/key that has BRACES
    #              split across lines specified in the
    #              hash tables, %checkunmatched, %checkunmatchedELSE
    #
    # How to read: ^\s*(\\)?(.*?)(\[|{|\s)
    #
    #       ^                  line begins with
    #       \s*                any (or no) spaces
    #       (\\)?              matches a \ backslash but not necessarily
    #       (.*?)              non-greedy character match and store the result
    #       (\[|}|=|(\s*\\))   either [ or { or = or space \

    if ($_ =~ m/^\s*(\\)?(.*?)(\[|{|=|(\s*\\))/
            and ($checkunmatched{$2} or $checkunmatchedELSE{$2}
                 or $alwaysLookforSplitBraces)
        ) {
            # store the command name, because $2
            # will not exist after the next match
            my $commandname = $2;
            my $matchedbraces=0;

            # by default, don't look for an else construct
            my $lookforelse=$checkunmatchedELSE{$2}||0;

            # match { but don't match \{
            $matchedbraces++ while ($_ =~ /(?<!\\){/g);

            # match } but don't match \}
            $matchedbraces-- while ($_ =~ /(?<!\\)}/g);

            # tracing mode
            print $logfile "Line $lineCounter\t matchedbraces = $matchedbraces\n" if($tracingMode);

            # set the indentation
            if($matchedbraces > 0 ) {
                  # tracing mode
                  print $logfile "Line $lineCounter\t Found opening BRACE { $commandname\n" if($tracingMode);

                  &increase_indent({name=>$commandname,
                                      matchedbraces=>$matchedbraces,
                                      lookforelse=>$lookforelse,
                                      countzeros=>0,
                                      type=>"splitbraces"});
            } elsif($matchedbraces<0) {
                # if $matchedbraces < 0 then we must be matching
                # braces from a previous split-braces command

                # keep matching { OR }, and don't match \{ or \}
                while ($_ =~ m/(((?<!\\){)|((?<!\\)}))/g) {

                     # store the match, either { or }
                     my $braceType = $1;

                     # exit the loop if @masterIndentationArrayOfHashes[-1] is empty
                     last if(!@masterIndentationArrayOfHashes);

                     # exit the loop if we're not looking for split braces
                     last if($masterIndentationArrayOfHashes[-1]{type} ne 'splitbraces');

                     # get the details of the most recent command name
                     $commandname =  $masterIndentationArrayOfHashes[-1]{name};
                     $matchedbraces = $masterIndentationArrayOfHashes[-1]{'matchedbraces'};
                     my $countzeros = $masterIndentationArrayOfHashes[-1]{'countzeros'};
                     $lookforelse= $masterIndentationArrayOfHashes[-1]{'lookforelse'};

                     $matchedbraces++ if($1 eq "{");
                     $matchedbraces-- if($1 eq "}");

                     # update the matched braces count
                     $masterIndentationArrayOfHashes[-1]{matchedbraces} = $matchedbraces;

                     # if we've matched up the braces then
                     # we can decrease the indent by 1 level
                     if($matchedbraces == 0) {
                          $countzeros++ if $lookforelse;

                          # tracing mode
                          print $logfile "Line $lineCounter\t Found closing BRACE } $1\n" if($tracingMode);

                          # decrease the indentation (if appropriate)
                          &decrease_indent($commandname);

                         if($countzeros==1) {
                              $masterIndentationArrayOfHashes[-1]{'matchedbraces'} = $matchedbraces;
                              $masterIndentationArrayOfHashes[-1]{'countzeros'} = $countzeros;
                              $masterIndentationArrayOfHashes[-1]{'lookforelse'} = $lookforelse;
                         }
                     } 
                }
            }
        }
}

sub end_command_or_key_unmatched_braces{
    # PURPOSE:  Check for the closing BRACE of a command that
    #           splits its BRACES across lines, such as
    #
    #               \parbox{ ...
    #
    #           or one of the tikz keys, such as
    #
    #              empty header/.style={
    #
    #           It works by checking if we have any entries
    #           in the array @masterIndentationArrayOfHashes, and making
    #           sure that we're not starting another command/key
    #           that has split BRACES (nesting).
    #
    #           It also checks that the line is not commented.
    #
    #           We count the number of { and ADD to the counter
    #                                  } and SUBTRACT to the counter
    return unless @masterIndentationArrayOfHashes;
    return unless ($masterIndentationArrayOfHashes[-1]{type} eq 'splitbraces');
    print $logfile "Line $lineCounter\t Searching for closing BRACE } $masterIndentationArrayOfHashes[-1]{name}\n" if($tracingMode);

    if(!($_ =~ m/^\s*(\\)?(.*?)(\[|{|=|(\s*\\))/
        and ($checkunmatched{$2} or $checkunmatchedELSE{$2} or $alwaysLookforSplitBraces))
        and $_ !~ m/^\s*%/
       ) {
       # keep matching { OR }, and don't match \{ or \}
       while ($_ =~ m/(((?<!\\){)|((?<!\\)}))/g) {
            # store the match, either { or }
            my $braceType = $1;

            # exit the loop if @masterIndentationArrayOfHashes[-1] is empty
            last if(!@masterIndentationArrayOfHashes);

            # exit the loop if we're not looking for split braces
            last if($masterIndentationArrayOfHashes[-1]{type} ne 'splitbraces');

            # get the details of the most recent command name
            my $commandname =  $masterIndentationArrayOfHashes[-1]{name};
            my $matchedbraces = $masterIndentationArrayOfHashes[-1]{matchedbraces};
            my $countzeros = $masterIndentationArrayOfHashes[-1]{countzeros};
            my $lookforelse= $masterIndentationArrayOfHashes[-1]{lookforelse};

            $matchedbraces++ if($1 eq "{");
            $matchedbraces-- if($1 eq "}");

            # update the matched braces count
            $masterIndentationArrayOfHashes[-1]{matchedbraces} = $matchedbraces;

            # if we've matched up the braces then
            # we can decrease the indent by 1 level
            if($matchedbraces == 0) {
                 $countzeros++ if $lookforelse;

                 # tracing mode
                 print $logfile "Line $lineCounter\t Found closing BRACE } $commandname\n" if($tracingMode);

                 # decrease the indentation (if appropriate)
                 &decrease_indent($commandname);

                if($countzeros==1){
                    $masterIndentationArrayOfHashes[-1]{'matchedbraces'} = $matchedbraces;
                    $masterIndentationArrayOfHashes[-1]{'countzeros'} = $countzeros;
                    $masterIndentationArrayOfHashes[-1]{'lookforelse'} = $lookforelse;
                }
            } 
            
            if(@masterIndentationArrayOfHashes){
                if($masterIndentationArrayOfHashes[-1]{'type'} eq 'splitbraces'){
                   # tracing mode
                   print $logfile "Line $lineCounter\t Searching for closing BRACE } $masterIndentationArrayOfHashes[-1]{name}\n" if($tracingMode);
                }
             }
        }
     }
}

sub check_for_else{
    # PURPOSE: Check for an else clause
    #
    #          Some commands have the form
    #
    #               \mycommand{
    #                   if this
    #               }
    #               {
    #                   else this
    #               }
    #
    #          so we need to look for the else bit, and set
    #          the indentation appropriately.
    #
    #          We only perform this check if there's something
    #          in the array @masterIndentationArrayOfHashes, and if
    #          the line itself is not a command, or comment,
    #          and if it begins with {

    if(scalar(@masterIndentationArrayOfHashes)
        and  !($_ =~ m/^\s*(\\)?(.*?)(\[|{|=)/
                    and ($checkunmatched{$2} or $checkunmatchedELSE{$2}
                         or $alwaysLookforSplitBraces))
        and $_ =~ m/^\s*{/
        and $_ !~ m/^\s*%/
       ) {
       # get the details of the most recent command name
       my $matchedbraces = $masterIndentationArrayOfHashes[-1]{'matchedbraces'};
       my $countzeros = $masterIndentationArrayOfHashes[-1]{'countzeros'};
       my $lookforelse= $masterIndentationArrayOfHashes[-1]{'lookforelse'};

       # increase indentation
       if($lookforelse and $countzeros==1) {
         #&increase_indent($commandname);
       }

       # put the array back together
       $masterIndentationArrayOfHashes[-1]{'matchedbraces'} = $matchedbraces;
       $masterIndentationArrayOfHashes[-1]{'countzeros'} = $countzeros;
       $masterIndentationArrayOfHashes[-1]{'lookforelse'} = $lookforelse;
    }
}

sub at_beg_of_env_or_eq{
    # PURPOSE: Check if we're at the BEGINning of an environment
    #          or at the BEGINning of a displayed equation \[
    #
    #          This subroutine checks for matches of the form
    #
    #               \begin{environmentname}
    #          or
    #               \[
    #
    #          It also checks to see if the current environment
    #          should have alignment delimiters; if so, we need to turn
    #          ON the $delimiter switch

    # How to read
    #  m/^\s*(\$)?\\begin{(.*?)}/
    #
    #   ^               beginning of a line
    #   \s*             any white spaces (possibly none)
    #   (\$)?           possibly a $ symbol, but not required
    #   \\begin{(.*)?}  \begin{environmentname}
    #
    # How to read
    #  m/^\s*()(\\\[)/
    #
    #  ^        beginning of a line
    #  \s*      any white spaces (possibly none)
    #  ()       empty just so that $1 and $2 are defined
    #  (\\\[)   \[  there are lots of \ because both \ and [ need escaping
    #  \\begin{\\?(.*?)}  \begin{something} where something could start
    #                     with a backslash, e.g \my@env@ which can happen
    #                     in a style or class file, for example

    if( (   ( $_ =~ m/^\s*(\$)?\\begin\{\\?(.*?)\}/ and $_ !~ m/\\end\{$2\}/)
         or ($_=~ m/^\s*()(\\\[)/ and $_ !~ m/\\\]/) )
        and $_ !~ m/^\s*%/ ) {
       # tracing mode
       print $logfile "Line $lineCounter\t \\begin{environment} found: $2 \n" if($tracingMode);

       # increase the indentation
       &increase_indent({name=>$2,
                         type=>"environment",
                         begin=>"\\begin{$2}",
                         end=>"\\end{$2}"});

       # check for verbatim-like environments
       if($verbatimEnvironments{$2}){
           $inverbatim = 1;
           # tracing mode
           print $logfile "Line $lineCounter\t \\begin{verbatim-like} found, $2, switching ON verbatim \n" if($tracingMode);

           # remove the key and value from %lookForAlignDelims hash
           # to avoid any further confusion
           if($lookForAlignDelims{$2}) {
                print $logfile "WARNING\n\t Line $lineCounter\t $2 is in *both* lookForAlignDelims and verbatimEnvironments\n";
                print $logfile "\t\t\t ignoring lookForAlignDelims and prioritizing verbatimEnvironments\n";
                print $logfile "\t\t\t Note that you only get this message once per environment\n";
                delete $lookForAlignDelims{$2};
           }
       }
    }
}

sub at_end_of_env_or_eq{
    # PURPOSE: Check if we're at the END of an environment
    #          or at the END of a displayed equation \]
    #
    #          This subroutine checks for matches of the form
    #
    #               \end{environmentname}
    #          or
    #               \]
    #
    #          Note: environmentname can begin with a backslash
    #                which might happen in a sty or cls file.
    #
    #          It also checks to see if the current environment
    #          had alignment delimiters; if so, we need to turn
    #          OFF the $delimiter switch

    return unless @masterIndentationArrayOfHashes;
    print $logfile "Line $lineCounter\t looking for \\end{$masterIndentationArrayOfHashes[-1]{name}} \n" if($tracingMode);

    if( ($_ =~ m/^\s*\\end\{\\?(.*?)\}/ or $_=~ m/^(\\\])/) and $_ !~ m/\s*^%/) {
       # check if we're at the end of a verbatim-like environment
       if($verbatimEnvironments{$1}) {
           $inverbatim = 0;
            # tracing mode

            print $logfile "Line $lineCounter\t \\end{verbatim-like} found: $1, switching off verbatim \n" if($tracingMode);
            print $logfile "Line $lineCounter\t removing leading spaces \n" if($tracingMode);
            #s/^\ *//;
            s/^\t+// if($_ ne "");
            s/^\s+// if($_ ne "");
       }

       # check if we're in an environment that is looking
       # to indent after each \item
       if(scalar(@masterIndentationArrayOfHashes) and $itemNames{$masterIndentationArrayOfHashes[-1]{name}}) {
            &decrease_indent($masterIndentationArrayOfHashes[-1]{name});
       }

       # if we're at the end of an environment that receives no additional indent, log it, and move on
       if($noAdditionalIndent{$1}){
            print $logfile "Line $lineCounter\t \\end{$1} finished a no-additional-indent environment (see noAdditionalIndent)\n" if($tracingMode);
       }

       # some commands contain \end{environmentname}, which
       # can cause a problem if \begin{environmentname} was not
       # started previously; if @masterIndentationArrayOfHashes is empty,
       # then we don't need to check for \end{environmentname}
       if(@masterIndentationArrayOfHashes) {
          # check to see if \end{environment} fits with most recent \begin{...}
          my %previousEnvironment = %{$masterIndentationArrayOfHashes[-1]};

          # check to see if we need to turn off alignment
          # delimiters and output the current block
          if($masterIndentationArrayOfHashes[-1]{alignmentDelimiters} and ($previousEnvironment{name} eq $1)) {
               &print_aligned_block();
          }

          # tracing mode
          print $logfile "Line $lineCounter\t \\end{environment} found: $1 \n" if($tracingMode and !$verbatimEnvironments{$1});

          # check to see if \end{environment} fits with most recent \begin{...}
          if($previousEnvironment{name} eq $1) {
               # decrease the indentation (if appropriate)
               print $logfile "Line $lineCounter\t removed $1 from Indentation array\n" if($tracingMode); 
               &decrease_indent($1);
          } else {
              # otherwise put the environment name back on the stack
              print $logfile "Line $lineCounter\t WARNING: \\end{$1} found on its own line, not matched to \\begin{$previousEnvironment{name}}\n" unless ($delimiters or $inverbatim or $inIndentBlock or $1 eq "\\\]");
          }

          # need a special check for \[ and \]
          if($1 eq "\\\]") {
               &decrease_indent($1);
          }
       }

       # if we're at the end of the document, we remove all current
       # indentation- this is especially prominent in examples that
       # have headings, and the user has chosen to indentAfterHeadings
       if($1 eq "document" and !$inFileContents and !$inpreamble and !$delimiters and !$inverbatim and !$inIndentBlock and @masterIndentationArrayOfHashes) {
            @masterIndentationArrayOfHashes=();

            # tracing mode
            if($tracingMode) {
                print $logfile "Line $lineCounter\t \\end{$1} found, emptying indentation array \n" unless ($delimiters or $inverbatim or $inIndentBlock or $1 eq "\\\]");
            }
       }
    }
}

sub print_aligned_block{
    # PURPOSE: this subroutine does a few things related
    #          to printing blocks of code that contain
    #          delimiters, such as align, tabular, etc
    #
    #          It does the following
    #           - turns off delimiters switch
    #           - processes the block
    #           - deletes the block
    $delimiters=0;

    # tracing mode
    print $logfile "Line $lineCounter\t Delimiter body FINISHED: $masterIndentationArrayOfHashes[-1]{name}\n" if($tracingMode);

    # print the current FORMATTED block
    my @block = &format_block(@{$masterIndentationArrayOfHashes[-1]{block}});
    foreach $line (@block) {
         # add the indentation and add the
         # each line of the formatted block
         # to the output
         # unless this would only create trailing whitespace and the
         # corresponding option is set
         unless ($line =~ m/^$/ and $removeTrailingWhitespace) {
             $line =&current_indentation().$line;
         }
         push(@lines,$line);
    }
}

sub format_block{
    #   PURPOSE: Format a delimited environment such as the
    #            tabular or align environment that contains &
    #
    #   INPUT: @block               array containing unformatted block
    #                               from, for example, align, or tabular
    #   OUTPUT: @formattedblock     array containing FORMATTED block

    # @block is the input
    my @block=@_;

    # tracing mode
    print $logfile "\t\tFormatting alignment block: $masterIndentationArrayOfHashes[-1]{name}\n" if($tracingMode);

    # step the line counter back to the beginning of the block-
    # it will be increased back to the end of the block in the
    # loop later on:  foreach $row (@tmpblock)
    $lineCounter -= scalar(@block);

    # local array variables
    my @formattedblock;
    my @tmprow=();
    my @tmpblock=();
    my @maxmstringsize=();
    my @ampersandCount=();

    # local scalar variables
    my $alignrowcounter=-1;
    my $aligncolcounter=-1;
    my $tmpstring;
    my $row;
    my $column;
    my $maxmcolstrlength;
    my $i;
    my $j;
    my $fmtstring;
    my $linebreak;
    my $maxNumberAmpersands = 0;
    my $currentNumberAmpersands;
    my $trailingcomments;

    # local hash table
    my %stringsize=();

    # loop through the block and count & per line- store the biggest
    # NOTE: this needs to be done in its own block so that
    # we can know what the maximum number of & in the block is
    foreach $row (@block) {
       # delete trailing comments
       $trailingcomments='';
       if($row =~ m/((?<!\\)%.*$)/) {
            $row =~ s/((?<!\\)%.*)/%TC/;
            $trailingcomments=$1;
       }

       # reset temporary counter
       $currentNumberAmpersands=0;

       # count & in current row (exclude \&)
       $currentNumberAmpersands++ while ($row =~ /(?<!\\)&/g);

       # store the ampersand count for future
       push(@ampersandCount,$currentNumberAmpersands);

       # overwrite maximum count if the temp count is higher
       $maxNumberAmpersands = $currentNumberAmpersands if($currentNumberAmpersands > $maxNumberAmpersands );

       # put trailing comments back on
       if($trailingcomments){
            $row =~ s/%TC/$trailingcomments/;
       }
    }

    # tracing mode
    print $logfile "\t\tmaximum number of & in any row: $maxNumberAmpersands\n" if($tracingMode);

    # loop through the lines in the @block
    foreach $row (@block){
        # get the ampersand count
        $currentNumberAmpersands = shift(@ampersandCount);

        # increment row counter
        $alignrowcounter++;

        # clear the $linebreak variable
        $linebreak='';

        # check for line break \\
        # and don't mess with a line that doesn't have the maximum
        # number of &
        if($row =~ m/\\\\/ and $currentNumberAmpersands==$maxNumberAmpersands ) {
          # remove \\ and all characters that follow
          # and put it back in later, once the measurement
          # has been done
          $row =~ s/(\\\\.*)//;
          $linebreak = $1;
        }

        if($currentNumberAmpersands==$maxNumberAmpersands) {

            # remove trailing comments
            $trailingcomments='';
            if($row =~ m/((?<!\\)%.*$)/) {
                 $row =~ s/((?<!\\)%.*)/%TC/;
                 $trailingcomments=$1;
            }

            # separate the row at each &, but not at \&
            @tmprow = split(/(?<!\\)&/,$row);

            # reset column counter
            $aligncolcounter=-1;

            # loop through each column element
            # removing leading and trailing space
            foreach $column (@tmprow) {
               # increment column counter
               $aligncolcounter++;

               # remove leading and trailing space from element
    	       $column =~ s/^\s+//;
               $column =~ s/\s+$//;

               # assign string size to the array
               $stringsize{$alignrowcounter.$aligncolcounter}=length($column);
               if(length($column)==0){
                 $column=" ";
               }

               # put the row back together
               if ($aligncolcounter ==0){
                 $tmpstring = $column;
               } else {
                 $tmpstring .= "&".$column;
               }
            }


            # put $linebreak back on the string, now that
            # the measurement has been done
            $tmpstring .= $linebreak;

            # put trailing comments back on
            if($trailingcomments) {
                 $tmpstring =~ s/%TC/$trailingcomments/;
            }

            push(@tmpblock,$tmpstring);
        } else {
               # if there are no & then use the
               # NOFORMATTING token
               # remove leading space
    	       s/^\s+//;
               push(@tmpblock,$row."NOFORMATTING");
        }
    }

    # calculate the maximum string size of each column
    for($j=0;$j<=$aligncolcounter;$j++) {
        $maxmcolstrlength=0;
        for($i=0; $i<=$alignrowcounter;$i++) {
            # make sure the stringsize is defined
            if(defined $stringsize{$i.$j}) {
                if ($stringsize{$i.$j}>$maxmcolstrlength) {
                    $maxmcolstrlength = $stringsize{$i.$j};
                }
            }
        }
        push(@maxmstringsize,$maxmcolstrlength);
    }

    # README: printf( formatting, expression)
    #
    #   formatting has the form %-50s & %-20s & %-19s
    #   (the numbers have been made up for example)
    #       the - symbols mean that each column should be left-aligned
    #       the numbers represent how wide each column is
    #       the s represents string
    #       the & needs to be inserted

    # join up the maximum string lengths using "s %-"
    $fmtstring = join("s & %-",@maxmstringsize);

    # add an s to the end, and a newline
    $fmtstring .= "s ";

    # add %- to the beginning
    $fmtstring = "%-".$fmtstring;

    # process the @tmpblock of aligned material
    foreach $row (@tmpblock) {
        $linebreak='';
        # check for line break \\
        if($row =~ m/\\\\/) {
          # remove \\ and all characters that follow
          # and put it back in later
          $row =~ s/(\\\\.*$)//;
          $linebreak = $1;
        }

        if($row =~ m/NOFORMATTING/) {
            $row =~ s/NOFORMATTING//;
            $tmpstring=$row;

            # tracing mode
            print $logfile "\t\tLine $lineCounter\t maximum number of & NOT found- not aligning delimiters \n" if($tracingMode);
        } else {
          # remove trailing comments
          $trailingcomments='';
          if($row =~ m/((?<!\\)%.*$)/) {
               $row =~ s/((?<!\\)%.*)/%TC/;
               $trailingcomments=$1;
          }

          $tmpstring = sprintf($fmtstring,split(/(?<!\\)&/,$row)).$linebreak."\n";

          # remove space before \\ if specified in alignDoubleBackSlash
          if($masterIndentationArrayOfHashes[-1]{alignDoubleBackSlash}==0){
                print $logfile "\t\tLine $lineCounter\t removing space before \\\\ (see $masterIndentationArrayOfHashes[-1]{name} alignDoubleBackSlash)\n" if($tracingMode);
                $tmpstring =~ s/\s*\\\\/\\\\/;
                # some users may like to put a number of spaces before \\
                if($masterIndentationArrayOfHashes[-1]{spacesBeforeDoubleBackSlash}){
                    my $spaceString;
                    for($j=1;$j<=$masterIndentationArrayOfHashes[-1]{spacesBeforeDoubleBackSlash};$j++) {
                        $spaceString .= ' ';
                    }
                    print $logfile "\t\tLine $lineCounter\t adding $masterIndentationArrayOfHashes[-1]{spacesBeforeDoubleBackSlash} ",$masterIndentationArrayOfHashes[-1]{spacesBeforeDoubleBackSlash}>1?"spaces":"space"," before \\\\ (see $masterIndentationArrayOfHashes[-1]{name} spacesBeforeDoubleBackSlash)\n" if($tracingMode);
                    $tmpstring =~ s/\\\\/$spaceString\\\\/;
                }
          }

          # put trailing comments back on
          if($trailingcomments) {
               $tmpstring =~ s/%TC/$trailingcomments/;
          }

          # tracing mode
          print $logfile "\t\tLine $lineCounter\t Found maximum number of & so aligning delimiters\n" if($tracingMode);
        }

        # remove trailing whitespace
        if ($removeTrailingWhitespace) {
            print $logfile "\t\tLine $lineCounter\t removing trailing whitespace from delimiter aligned line\n" if ($tracingMode);
            $tmpstring =~ s/\s+$/\n/;
        }

        push(@formattedblock,$tmpstring);

        # increase the line counter
        $lineCounter++;
    }

    # return the formatted block
	@formattedblock;
}

sub increase_indent{
       # PURPOSE: Adjust the indentation
       #          of the current environment, command, etc;
       #          check that it's not an environment
       #          that doesn't want indentation.

       my %infoHash = %{pop(@_)};
       my $command = $infoHash{name};

       # check for conflicting hash keys
       &check_conflicting_keys($command);

       # quick check for verbatim Environment
       if($inverbatim){
            print $logfile "Line $lineCounter\t currently inverbatim environment, not increasing indentation\n" if($tracingMode);
            return;
       }

       if($indentRules{$command}) {
          # tracing mode
          print $logfile "Line $lineCounter\t increasing indent using rule for $command (see indentRules)\n" if($tracingMode);
       } else {
          # default indentation
          if(!($noAdditionalIndent{$command} or $verbatimEnvironments{$command})) {
            # tracing mode
            print $logfile "Line $lineCounter\t increasing indent using defaultIndent\n" if($tracingMode);
          } elsif($noAdditionalIndent{$command})  {
            # tracing mode
            print $logfile "Line $lineCounter\t no additional indent added for $command (see noAdditionalIndent)\n" if($tracingMode);
          }
       }

       # add to the master array of hashes
       push(@masterIndentationArrayOfHashes,\%infoHash);

       # handle the keys slightly different when dealing with environments or commands
       if($infoHash{type} eq 'environment'){
            # environments
            if(!$noAdditionalIndent{$command}){
                 $masterIndentationArrayOfHashes[-1]{indent} = $indentRules{$command}||$defaultIndent;
               } 
            # check to see if we need to look for alignment delimiters
            if($lookForAlignDelims{$command}){ 
                # there are two ways to complete the lookForAlignDelims field, either as a scalar
                # or as a hash, so that we can check for alignDoubleBackSlash. 
                #
                # tabular: 
                #    delims: 1
                #    alignDoubleBackSlash: 1
                #
                # or, simply,
                #
                # tabular: 1
                #
                # We need to perform a check to see which has been done.
                if(ref($lookForAlignDelims{$command}) eq 'HASH'){
                      # tabular: 
                      #    delims: 1
                      #    alignDoubleBackSlash: 1
                      $masterIndentationArrayOfHashes[-1]{alignmentDelimiters}=defined $lookForAlignDelims{$command}{delims}?$lookForAlignDelims{$command}{delims}:1;
                      $masterIndentationArrayOfHashes[-1]{alignDoubleBackSlash}=defined $lookForAlignDelims{$command}{alignDoubleBackSlash}?$lookForAlignDelims{$command}{alignDoubleBackSlash}:1;
                      $masterIndentationArrayOfHashes[-1]{spacesBeforeDoubleBackSlash}=$lookForAlignDelims{$command}{spacesBeforeDoubleBackSlash}||0;
                } else {
                    # tabular: 1
                    $masterIndentationArrayOfHashes[-1]{alignmentDelimiters}=1;
                    $masterIndentationArrayOfHashes[-1]{alignDoubleBackSlash}=1;
                }
                if($masterIndentationArrayOfHashes[-1]{alignmentDelimiters}==1){
                    # tracing mode
                    print $logfile "Line $lineCounter\t Delimiter environment started: $command (see lookForAlignDelims)\n" if($tracingMode);
                }
            }
       } else {
            # commands, headings, etc
            if(!$noAdditionalIndent{$command}){
                $masterIndentationArrayOfHashes[-1]{indent} = $indentRules{$command}||$defaultIndent;
             } 
       }

       # details of noAdditionalIndent to the main hash
       if($noAdditionalIndent{$command}){
             $masterIndentationArrayOfHashes[-1]{noAdditionalIndent} = 'yes';
       }
}

sub decrease_indent{
       # PURPOSE: Adjust the indentation
       #          of the current environment;
       #          check that it's not an environment
       #          that doesn't want indentation.

       # if there is no evidence of indentation, then return
       return unless(scalar(@masterIndentationArrayOfHashes));

       # otherwise get details of the most recent command, environment, item, if, heading, etc
       my $command = pop(@_);

       if(!$inverbatim) {
            print $logfile "Line $lineCounter\t removing ", $masterIndentationArrayOfHashes[-1]{name}, " from masterIndentationArrayOfHashes\n" if($tracingMode);
            pop(@masterIndentationArrayOfHashes);
            # tracing mode
            if($tracingMode) {
                if(@masterIndentationArrayOfHashes) {
                    print $logfile "Line $lineCounter\t decreasing masterIndentationArrayOfHashes to: ",&current_indentation_names(),"\n";
                } else {
                    print $logfile "Line $lineCounter\t masterIndentationArrayOfHashes now empty \n";
              }
            }
       }
}

sub current_indentation{
    # PURPOSE: loop through masterIndentationArrayOfHashes and 
    #          pull out the indentation, and join it together

    # if the masterIndentationArrayOfHashes is empty, return an empty string
    return "" unless(@masterIndentationArrayOfHashes);

    my $indent;
    foreach my $env (@masterIndentationArrayOfHashes){
        $indent .= defined($env->{indent})?$env->{indent}:'';
      }
    return $indent;
}

sub current_indentation_names{
    # PURPOSE: loop through masterIndentationArrayOfHashes and 
    #          pull out the list of environment/command names
    return "masterIndentationArrayOfHashes empty" unless(@masterIndentationArrayOfHashes);

    my $listOfNames;
    foreach my $env (@masterIndentationArrayOfHashes){
        $listOfNames .= $env->{name};
        $listOfNames .= "," unless $env == $masterIndentationArrayOfHashes[-1];
      }
    return $listOfNames;
}

sub check_conflicting_keys{
  # PURPOSE: users may sometimes put an environment in two
  #          hash keys; for example, they might put lstlistings
  #          in both indentRules and in noAdditionalIndent;
  #          in which case, we need a hierachy.
  #
  #          This subroutine implements such a hierachy, 
  #          and deletes the redundant key.

  # if the user has specified $indentRules{$command} and
  # $noAdditionalIndent{$command} then they are a bit confused-
  # we remove the $indentRules{$command} and assume that they
  # want $noAdditionalIndent{$command}

  my $command = pop(@_);

  if(scalar($indentRules{$command}) and $noAdditionalIndent{$command}) {
       print $logfile "WARNING\n\t Line $lineCounter\t $command is in *both* indentRules and noAdditionalIndent\n";
       print $logfile "\t\t\t ignoring indentRules and prioritizing noAdditionalIndent\n";
       print $logfile "\t\t\t Note that you only get this message once per command/environment\n";

       # remove the key and value from %indentRules hash
       # to avoid any further confusion
       delete $indentRules{$command};
  }

  # if the command is in verbatimEnvironments and in indentRules then
  # remove it from %indentRules hash
  # to avoid any further confusion
  if($indentRules{$command} and $verbatimEnvironments{$command}) {
       # remove the key and value from %indentRules hash
       # to avoid any further confusion
       print $logfile "WARNING\n\t Line $lineCounter\t $command is in *both* indentRules and verbatimEnvironments\n";
       print $logfile "\t\t\t ignoring indentRules and prioritizing verbatimEnvironments\n";
       print $logfile "\t\t\t Note that you only get this message once per environment\n";
       delete $indentRules{$command};
  }

}
