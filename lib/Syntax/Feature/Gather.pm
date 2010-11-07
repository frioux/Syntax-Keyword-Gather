package Syntax::Feature::Gather;

use strict;
use warnings;

# ABSTRACT: Provide a gather keyword

use Syntax::Keyword::Gather ();

sub install {
  my ($class, %args) = @_;

  my $target  = $args{into};
  my $options = $args{options} || {};

  Syntax::Keyword::Gather->import({ into => $target }, %$options );

  return 1;
}

1;

=head1 SYNOPSIS

 use syntax 'gather';

 my @list = gather {
    # Try to extract odd numbers and odd number names...
    for (@data) {
       if (/(one|three|five|seven|nine)$/) { take qq{'$_'} }
       elsif (/^\d+$/ && $_ %2)            { take $_ }
    }
    # But use the default set if there aren't any of either...
    take @defaults unless gathered;
 }

or to use the stuff that L<Sub::Exporter> gives us, try

 # this is a silly idea
 use syntax gather => {
   gather => { -as => 'bake' },
   take   => { -as => 'cake' },
 };

 my @vals = bake { cake (1...10) };

The full documentation for this module is in L<Syntax::Keyword::Gather>.  This
is just a way to use the sugar that L<syntax> gives us.

=cut

