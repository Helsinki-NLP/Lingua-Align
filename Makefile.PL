use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Lingua::Align',
    VERSION_FROM      => 'lib/Lingua/Align.pm',
    ABSTRACT_FROM  => 'lib/Lingua/Align.pm',
    AUTHOR         => 'Joerg Tiedemann <j.tiedemann@rug.nl>'
    PREREQ_PM     => {
        'XML::Parser' => 0,
    },
);
