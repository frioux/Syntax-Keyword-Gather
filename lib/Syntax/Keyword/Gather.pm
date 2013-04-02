package Syntax::Keyword::Gather;

use strict;
use warnings;

# VERSION

use Carp 'croak';

use Sub::Exporter::Progressive -setup => {
   exports => [qw{ break gather gathered take }],
   groups => {
      default => [qw{ break gather gathered take }],
   },
};

my %gatherers;

sub gather(&) {
   croak "Useless use of 'gather' in void context" unless defined wantarray;
   my ($code) = @_;
   my $caller = caller;
   local @_;
   push @{$gatherers{$caller}}, bless \@_, 'Syntax::Keyword::Gather::MagicArrayRef';
   die $@
      if !eval{ &$code } && $@ && !UNIVERSAL::isa($@, 'Syntax::Keyword::Gather::Break');
   return @{pop @{$gatherers{$caller}}} if wantarray;
   return   pop @{$gatherers{$caller}}  if defined wantarray;
}

sub gathered() {
   my $caller = caller;
   croak "Call to gathered not inside a gather" unless @{$gatherers{$caller}};
   return $gatherers{$caller}[-1];
}

sub take(@) {
   my $caller = caller;
   croak "Call to take not inside a gather block"
      unless ((caller 3)[3]||"") eq 'Syntax::Keyword::Gather::gather';
   push @{$gatherers{$caller}[-1]}, @_;
   return 0+@_;
}

my $breaker = bless [], 'Syntax::Keyword::Gather::Break';

sub break() {
   die $breaker;
}

package Syntax::Keyword::Gather::MagicArrayRef;

use overload
   'bool'   => sub { @{$_[0]} > 0      },
   '0+'     => sub { @{$_[0]} + 0      },
   '""'     => sub { join q{}, @{$_[0]} },
   fallback => 1;

1;

__END__

=head1 NAME

Syntax::Keyword::Gather - Implements the Perl 6 'gather/take' control structure in Perl 5

=head1 SYNOPSIS

 use Syntax::Keyword::Gather;

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

=head1 DESCRIPTION

Perl 6 provides a new control structure -- C<gather> -- that allows
lists to be constructed procedurally, without the need for a temporary
variable. Within the block/closure controlled by a C<gather> any call to
C<take> pushes that call's argument list to an implicitly created array.
C<take> returns the number of elements it took.  This module implements
that control structure.

At the end of the block's execution, the C<gather> returns the list of
values stored in the array (in a list context) or a reference to the array
(in a scalar context).

For example, instead of writing:

 print do {
    my @wanted;
    while (my $line = <>) {
       push @wanted, $line  if $line =~ /\D/;
       push @wanted, -$line if some_other_condition($line);
    }
    push @wanted, 'EOF';
    join q{, }, @wanted;
 };

instead we can write:

 print join q{, }, gather {
    while (my $line = <>) {
       take $line  if $line =~ /\D/;
       take -$line if some_other_condition($line);
    }
    take 'EOF';
 }

and instead of:

 my $text = do {
    my $string;
    while (<>) {
       next if /^#|^\s*$/;
       last if /^__[DATA|END]__\n$/;
       $string .= $_;
    }
    $string;
 };

we could write:

 my $text = join q{}, gather {
    while (<>) {
       next if /^#|^\s*$/;
       last if /^__[DATA|END]__\n$/;
       take $_;
    }
 };

There is also a third function -- C<gathered> -- which returns a
reference to the implicit array being gathered. This is useful for
handling defaults:

 my @odds = gather {
    for @data {
       take $_ if $_ % 2;
       take to_num($_) if /[one|three|five|nine]$/;
    }
    take (1,3,5,7,9) unless gathered;
 }

Note that -- as the example above implies -- the C<gathered> function
returns a special Perl 5 array reference that acts like a Perl 6 array
reference in boolean, numeric, and string contexts.


It's also handy for creating the implicit array by some process more
complex than by simple sequential pushing. For example, if we needed to
prepend a count of non-numeric items:

 my @odds = gather {
    for @data {
       take $_ if $_ %2;
       take to_num($_) if /[one|three|five|seven|nine]$/;
    }
    unshift gathered, +grep(/[a-z]/i, @data);
 }


Conceptually C<gather>/C<take> is the generalized form from which both
C<map> and C<grep> derive. That is, we could implement those two functions
as:

 sub map (&@) {
   my $coderef = shift;
   my @list = @{shift @_};

   return gather {
      take $coderef->($_) for (@list)
   };
 }

 sub grep (&@) {
   my $coderef = shift;
   my @list = @{shift @_};

   return gather {
      take $_ if $coderef->($_) for @list
   };
 }


A C<gather> is also a very handy way of short-circuiting the
construction of a list. For example, suppose we wanted to generate a
single sorted list of lines from two sorted files, but only up to the
first line they have in common. We could gather the lines like this:

 my @merged_diff = gather {
    my $a = <$fh_a>;
    my $b = <$fh_b>;
    while (1) {
       if ( defined $a && defined $b ) {
          if    ($a eq $b) { last }     # Duplicate means end of list
          elsif ($a lt $b) { take $a; $a = <$fh_a>; }
          else             { take $b; $b = <$fh_b>; }
       }
       elsif (defined $a)  { take $a; $a = <$fh_a>; }
       elsif (defined $b)  { take $b; $b = <$fh_b>; }
       else                { last }
    }
 }

=head1 HISTORY

This module was forked from Damian Conway's L<Perl6::Gather> for a few reasons.

=over 1

=item to avoid the slightly incendiary name

=item to avoid the use of the Perl6::Exporter

=item ~ doesn't overload to mean string context

=item to no longer takes the current topic ($_)

=back

The last item is actually due to an unintended side-effect of the fact that if
C<take> has an array of zero length it takes $_, which is suprising at the very
least.  I'll fix that issue if I can.

=head1 BUGS AND IRRITATIONS

It would be nice to be able to code the default case as:

 my @odds = gather {
    for (@data) {
       take if $_ % 2;
       take to_num($_) if /(?:one|three|five|nine)\z/;
    }
 } or (1,3,5,7,9);

but Perl 5's C<or> imposes a scalar context on its left argument.
This is arguably a bug and definitely an irritation.
