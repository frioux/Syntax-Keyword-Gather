#!perl
use strict;
use warnings;

use Test::More;
use Test::Fatal;

use Syntax::Keyword::Gather;

sub does_compile {
    my ($code) = @_;
    my $canary = \42;
    return if eval '() = sub { ${code}; }; ${canary}' != $canary;
    return 1;
}

{
    my $code = q{
        gather {
            for my $x (qw(a b)) {
                sub { take @_ }->($x);
            }
        };
    };

    ok does_compile($code), 'take within the lexical scope of a gather is legal';

    TODO: {
        local $TODO = 'take must be called directly from gather currently';
        is_deeply [eval $code], [qw(a b)];
    }
}

TODO: {
    local $TODO = 'lexical scope for usage of take does not matter currently';

    my $code = q{
        my $take = sub { take @_ };

        gather {
            for my $x (qw(a b)) {
                $take->($x);
            }
        };
    };

    ok !does_compile($code), 'take outside the lexical scope of gather is illegal';
}

{
    my $code = q{
        sub {
            for my $x (qw(a b)) {
                take $x;
            }
        };
    };

    TODO: {
        local $TODO = 'lexical scope for usage of take does not matter currently';
        ok !does_compile($code);

        my $block = eval $code;
        ok exception { () = &gather($block) };
    }
}

done_testing;
