use 5.006;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Chemistry::File::MDLMol',
    'VERSION_FROM'	=> 'MDLMol.pm', # finds $VERSION
    'PREREQ_PM'		=> {
        'Chemistry::Mol' => "0.30" 
    }, # e.g., Module::Name => 1.1
);
