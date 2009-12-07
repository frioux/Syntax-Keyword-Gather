
use ExtUtils::MakeMaker;
WriteMakefile(
		NAME	=> q[Perl6::Gather],
		VERSION => q[0.04],
        AUTHOR  => 'Damian Conway',
		PREREQ_PM => { Perl6::Export=>0.07 },

	     );
