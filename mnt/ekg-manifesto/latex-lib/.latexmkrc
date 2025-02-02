#
# Configure latexmk
#
# Looks at the following environment variables:
#
# - latex_document_main: the root directory of the document or the full file name of its main doc
# - latex_customer_code: customer code such as "agnos" or "ekgf"
# - latex_document_mode: "editors-version" or "release-version"
# - latex_document_members_only: "yes" or "no"
#
use File::Basename;
use experimental 'smartmatch';
use warnings FATAL => "all";
no warnings 'experimental::smartmatch';
$pdf_mode = 4;              # generate PDF using lualatex
$bibtex_use = 2;
$postscript_mode = $dvi_mode = 0;
$max_repeat = 10;
$do_cd = 1;
$force_mode = 1 ;
$recorder = 1;              # turn recorder option on (.fls file generated)
$ENV{'SILENT'} //= 0;       # Run latexmk silently, not output to text
$silent = $ENV{'SILENT'};
$quiet  = $ENV{'SILENT'};
$ENV{'max_print_line'} = 2000;
$log_wrap = 2000;
$ENV{'error_line'} = 254;
$ENV{'half_error_line'} = 238;
$ENV{'openout_any'} = 'a';
$biber = "biber %O --bblencoding=utf8 -u -U --output_safechars %B";
$max_repeat = 10;
$do_cd = 1;
$force_mode = 1 ;           # If nonzero, continue processing past minor latex errors including
                            # unrecognized cross references. Equivalent to specifying the -f option.
$recorder = 1;              # turn recorder option on (.fls file generated)
$ENV{'SILENT'} //= 0;       # Run latexmk silently, not output to text
$silent = $ENV{'SILENT'};
$quiet  = $ENV{'SILENT'};
$ENV{'max_print_line'} = 2000;
$log_wrap = 2000;
$ENV{'error_line'} = 254;
$ENV{'half_error_line'} = 238;
$ENV{'openout_any'} = 'a';
$biber = "biber %O --bblencoding=utf8 -u -U --output_safechars %B";
#
# Specify which PDF viewer you want to use (Skim is the best one on a Mac)
#
$pdf_previewer = 'open -a Skim';
$texinputs = $ENV{'TEXINPUTS'} || '';
$ENV{'TEXINPUTS'} = "./etc/:../etc/:../../etc/:${texinputs}";
$bstinputs = $ENV{'BSTINPUTS'} || '';
$ENV{'BSTINPUTS'} = "./:../:../../:${bstinputs}";
$ENV{'TZ'} = 'Europe/London';

print "Tex Inputs: $ENV{'TEXINPUTS'}\n";
print "Bst Inputs: $ENV{'BSTINPUTS'}\n";
print "default_files=@default_files  $_[0]\n";
#foreach (@default_files) {
#  print "$_\n";
#}

#
# Find the main doc and derive some values from it.
# 
# NOTE: Can't use spaces or dots in the file names unfortunately,
# tools like makeglossaries do not support it
#
sub findMainDoc() {
    my $document_name = 'ekg-mm'; # just a default, could be anything
    my $document_file = "${document_name}/${document_name}.tex";

    if($ENV{'latex_document_main'}) {
        $document_file = $ENV{'latex_document_main'};
        # If the env var latex_document_main happens to be just the directory name of the
        # document's content root then assume that the main file in that root has the same name
        if (-d $document_file) {
            $document_name = $document_file;
            $document_file = $document_file . '/' . ${document_file} . '.tex';
        } elsif (-f $document_file) {
            my @array = split /\//, $document_file, 2;
            $document_name = $array[0];
        } elsif (-f "../${document_file}") {
            my @array = split /\//, $document_file, 2;
            $document_name = $array[0];
        }
    }

    if (-f "../${document_file}") {
        my @array = split /\//, $document_file, 2;
        $document_name = $array[0];
        $document_file = $array[1];
        $do_cd = 0;
    }
    if (! -e $document_file) {
        die "${document_file} does not exist"
    }
    $ENV{'latex_document_main'} = $document_file;
    @default_files = ($document_file);

    print "Main document file: ${document_file}\n";
    print "Main document name: ${document_name}\n";

    return ($document_file, $document_name);
}

sub getCustomerCode($) {

    my $document_name = $_[0];
    my $document_name_suffix = (split '-', $document_name)[-1];
    my $document_name_prefix = (split '-', $document_name)[0];
    my $defaultCustomerCode = 'ekgf';

    # If this runs in a Github Actions workflow then we can derive the best
    # default customer code from the repository name by taking the organization code.
    if ($ENV{'GITHUB_REPOSITORY'}) {
        $defaultCustomerCode = split /\//, $defaultCustomerCode, 2;
    } else {
        my $gitRemoteUrl = `git remote get-url origin`;
        if ( $? == -1 ) {
            print "git not in path\n";
        } else {
            my @array = split /[:,\/]+/, $gitRemoteUrl;
            $defaultCustomerCode = lc($array[-2]);
        }
    }

    if (-d "./customer-assets/${document_name_prefix}" || -d "../customer-assets/${document_name_prefix}") {
        $defaultCustomerCode = ${document_name_prefix};
        $ENV{'latex_customer_code'} = $defaultCustomerCode;
    }
    if (-d "./customer-assets/${document_name_suffix}" || -d "../customer-assets/${document_name_suffix}") {
        $defaultCustomerCode = ${document_name_suffix};
        $ENV{'latex_customer_code'} = $defaultCustomerCode;
    }
    if (! $ENV{'latex_customer_code'}) {
        $ENV{'latex_customer_code'} = $defaultCustomerCode;
    }
    if("$ENV{'latex_customer_code'}" eq 'agnos') {
        $ENV{'latex_customer_code'} = 'agnos-ai'
    }
    if("$ENV{'latex_customer_code'}" eq 'agnos-ai') {
        $document_customer = 'agnos-ai';
        $document_customer_code_short = 'agnos';
    } else {
        $document_customer = lc($ENV{'latex_customer_code'});
        $document_customer_code_short = ${document_customer};
    }
    print "Document Customer Code: ${document_customer}\n";
    print "Document Short Customer Code: ${document_customer_code_short}\n";

    return ($document_customer, $document_customer_code_short);
}

sub tchomp {
    my $text = shift;

    # Matching with the hex values for the various line separators
    $text =~ s/^(.*?)(?:\x0D\x0A|\x0A|\x0D|\x0C|\x{2028}|\x{2029})/$1/s;
    return $text;
}

#
# Process the VERSION file in the main content directory of the repo and if not found then check the root directory
# of the repo. It should be a one-line file with the major and minor version number separated by a dot.
# This code then adds the Github Actions run number to it (taken from the environment variable GITHUB_RUN_NUMBER) or
# if you run latexmk locally it uses your user-id.
#
sub readVersion {
    my $versionFileName;
    if (-f "./${document_name}/VERSION") {
        $versionFileName = "./${document_name}/VERSION";
    } elsif (-f "./VERSION") {
        $versionFileName = "./VERSION";
    } else {
        $versionFileName = "./${document_name}/VERSION";
        open(my $fh, '>', $versionFileName) or die "Could not open file ${$versionFileName} $!";
        print $fh "1.0\n";
        close $fh;
    }
    open my $versionFileHandle, '<', $versionFileName or die "Failed to open ${versionFileName}: $!\n";
    my ($version, @lines) = <$versionFileHandle>;
    close $versionFileHandle or die "Failed to close ${versionFileName}: $!\n";
    $version = tchomp($version);
    $version = tchomp($version);
    #
    # Replace the dots with dashes
    #
    $version =~ tr/./-/s;
    #
    # Replace the slashes with dashes
    #
    $version =~ tr@/@-@s;
    #
    # Just before passing the documentVersion to lualatex, we replace the dashes with dots
    #
    return $version;
}

sub getCurrentBranchName() {
    my $branchName = `git rev-parse --symbolic-full-name --abbrev-ref HEAD`;
    if ( $? == -1 ) {
        print "WARNING: git not in path, can't determine branch name\n";
        return '';
    }
    $branchName = tchomp($branchName);
    print "Git Branch: ${branchName}\n";
    return ${branchName};
}

sub starts_with {
    return substr($_[0], 0, length($_[1])) eq $_[1];
}

sub getVersionString() {
    my $prefix = '';
    my $suffix = '';
    my $gitref = $ENV{'GITHUB_REF'} || '';
    #
    # If we are running in a job that is being triggered by a push with a tag then
    # assume that the tag is the version number
    #
    if (starts_with($gitref, 'refs/tags/')) {
        my $tag = $gitref;
        $tag =~ s@refs/tags/@@;
        $suffix = "${tag}";
    } else {
        #
        # Else, read the version number from the VERSION file and add the
        # job run number at the end so that it looks like '0.1.123' or so.
        # If run locally, then use the userid instead: '0.1.youruserid'.
        #
        $suffix = readVersion();
        if (! $ENV{'GITHUB_RUN_NUMBER'}) {
            $suffix = "${suffix}.$ENV{'USER'}";
        } else {
            $suffix = "${suffix}.$ENV{'GITHUB_RUN_NUMBER'}";
        }
    }
    my $branchName = getCurrentBranchName();
    if ($branchName ~~ ['main', 'master', 'HEAD']) {
        print "Git Branch: No git branch name in the name of the generated PDF file because we're on ${branchName}\n";
    } elsif ($branchName eq '') {
        ;
    } else {
        $suffix = "${suffix}-${branchName}";
    }
    return "${prefix}${suffix}";
}

($document_file, $document_name) = findMainDoc();

sub makeGlossaries{
    my ($base_name, $path) = fileparse( $_[0] );
    print "makeGlossaries base_name=${base_name} path=${path}\n";
    pushd $path;
    my $return = system "makeglossaries $base_name";
    if (-z "${base_name}.glo" ) {
       open GLS, ">${base_name}.gls";
       close GLS;
    }
    popd;
#    return $return;
    return 0;
}


#
# Acronym Glossary "acronym" (./acronym.tex)
#
# 'alg', 'acr', 'acn'
#
add_cus_dep('acn', 'acr', 0, 'makeGlossaries');
$clean_ext .= " alg acr acn";
push @generated_exts, 'alg', 'acr', 'acn';

#
# Main Glossary "main" (./glossary-main.tex)
#
# 'glg', 'gls', 'glo'
#
add_cus_dep('glo', 'gls', 0, 'makeGlossaries');
$clean_ext .= " glg gls glo";
push @generated_exts, 'glg', 'gls', 'glo';

#
# Ontologies Glossary "ont" (./glossary-ontologies.tex)
#
# 'olg', 'old', 'odn'
#
# Also see statement: \newglossary[olg]{ont}{old}{odn}{Ontologies}
#
add_cus_dep('oln', 'old', 0, 'makeGlossaries');
$clean_ext .= " olg old odn";
push @generated_exts, 'olg', 'old', 'odn';

#
# Concepts Glossary "concept" (./glossary-concepts.tex)
#
# 'tlg', 'tld', 'tdn'
#
# Also see statement: \newglossary[tlg]{concept}{tld}{tdn}{Concepts}
#
add_cus_dep('tdn', 'tld', 0, 'makeGlossaries');
$clean_ext .= " tlg tld tdn";
push @generated_exts, 'tlg', 'tld', 'tdn';

$clean_ext .= " aux fls log glsdefs tdo ist run.xml xdy";

($document_customer_code, $document_customer_code_short) = getCustomerCode(${document_name});

$latex_document_mode = lc($ENV{'latex_document_mode'} || 'draft');
print "Document Mode: ${latex_document_mode}\n";
if("${latex_document_mode}" eq 'release-version') {
    $jobname = "$document_customer_code-${document_name}";
} else {
    $jobname = "$document_customer_code-${document_name}-${latex_document_mode}";
}
#
# Remove duplicate customer codes
#
#print "document_customer_code=${document_customer_code}\n";
$jobname =~ s/${document_customer_code}//g ;
$jobname =~ s/--/-/g ;
$jobname = "${document_customer_code}${jobname}" ;
$jobname =~ s/--/-/g ;

$latex_document_version = getVersionString();
$latex_document_version_dotted = $latex_document_version;
$latex_document_version_dotted =~ tr/-/./s;
$latex_document_version_dotted =~ tr/_/./s;
$latex_document_version_dotted =~ tr@/@.@s;
print "Document Version: $latex_document_version_dotted (dotted version)\n";
print "Document Version: $latex_document_version\n";

$pre_tex_code = "${pre_tex_code}\\def\\documentMode{${latex_document_mode}}";
$pre_tex_code = "${pre_tex_code}\\def\\documentName{$document_name}";
$pre_tex_code = "${pre_tex_code}\\def\\customerCode{$document_customer_code}";
$pre_tex_code = "${pre_tex_code}\\def\\documentVersion{$latex_document_version_dotted}";

if($ENV{'latex_document_members_only'} and "$ENV{'latex_document_members_only'}" eq 'yes') {
    $jobname = "${jobname}-members-only-${latex_document_version}";
    $pre_tex_code = "${pre_tex_code}\\def\\membersOnly{yes}"
} else {
    $jobname = "${jobname}-${latex_document_version}";
    $pre_tex_code = "${pre_tex_code}\\def\\membersOnly{no}"
}
#
# Remove all dots from the latex job name since utilities like makeindex cannot handle them
# well.
#
$jobname =~ tr/./-/s;
$jobname =~ s/--/-/g ;
$jobname =~ s@/@-@g ;

print "Job name: ${jobname}\n";

$lualatex_bin = "lualatex";
if (-f "/Library/TeX/texbin/lualatex") {
    $lualatex_bin = "/Library/TeX/texbin/lualatex";
}

$lualatex = "${lualatex_bin} --synctex=1 --output-format=pdf --shell-escape --halt-on-error -file-line-error --interaction=nonstopmode %O %P";

$kpsewhich = "kpsewhich %S";
if (-f "/Library/TeX/texbin/kpsewhich") {
    $kpsewhich = "/Library/TeX/texbin/kpsewhich %S";
    $ENV{'PATH'} = "$ENV{'PATH'}:/Library/TeX/texbin/";
}

push @generated_exts, 'synctex.gz';
push @generated_exts, 'synctex(busy)';
push @generated_exts, 'run.xml';
$clean_ext .= " synctex.gz synctex(busy) run.xml";

print "\n\n$lualatex\n\n";