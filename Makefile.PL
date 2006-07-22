use strict;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME         => 'Email::LocalDelivery',
    VERSION_FROM => 'LocalDelivery.pm',
    PREREQ_PM    => {
                     'Email::FolderType'  => '0.7',
                     'Email::Simple'      => '1.92',
                     'File::Path::Expand' => '1.01',
                     'Test::More'         => '0.47',
                    },
);
