
use strict;
use warnings;

use 5.008001;

use ExtUtils::MakeMaker 6.17;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Minimalist class construction",
  "AUTHOR" => "David Golden <dagolden\@cpan.org>",
  "BUILD_REQUIRES" => {},
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.17"
  },
  "DISTNAME" => "Class-Tiny",
  "EXE_FILES" => [],
  "LICENSE" => "apache",
  "NAME" => "Class::Tiny",
  "PREREQ_PM" => {
    "Carp" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "Exporter" => 0,
    "ExtUtils::MakeMaker" => 0,
    "File::Spec::Functions" => 0,
    "List::Util" => 0,
    "Test::More" => "0.96",
    "base" => 0,
    "lib" => 0,
    "subs" => 0
  },
  "VERSION" => "0.012",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "Exporter" => 0,
  "ExtUtils::MakeMaker" => 0,
  "File::Spec::Functions" => 0,
  "List::Util" => 0,
  "Test::More" => "0.96",
  "base" => 0,
  "lib" => 0,
  "strict" => 0,
  "subs" => 0,
  "warnings" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

if ($] < 5.010) {
    $WriteMakefileArgs{PREREQ_PM} = {
        %{ $WriteMakefileArgs{PREREQ_PM} },
        "MRO::Compat" => "0",
    };
}

if ($] < 5.014) {
    $WriteMakefileArgs{PREREQ_PM} = {
        %{ $WriteMakefileArgs{PREREQ_PM} },
        "Devel::GlobalDestruction" => "0",
    };
}

WriteMakefile(%WriteMakefileArgs);



