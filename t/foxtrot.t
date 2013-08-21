use 5.008001;
use strict;
use warnings;
use lib 't/lib';

use Test::More 0.96;
use TestUtils;

require_ok("Foxtrot");

subtest "attribute list" => sub {
    is_deeply(
        [ sort Class::Tiny->get_all_attributes_for("Foxtrot") ],
        [ sort qw/foo bar/ ],
        "attribute list correct",
    );
};

subtest "attribute set as list" => sub {
    my $obj = new_ok( "Foxtrot", [ foo => 42, bar => 23 ] );
    is( $obj->foo, 42, "foo is set" );
    is( $obj->bar, 23, "bar is set" );
};

done_testing;
#
# This file is part of Class-Tiny
#
# This software is Copyright (c) 2013 by David Golden.
#
# This is free software, licensed under:
#
#   The Apache License, Version 2.0, January 2004
#
# vim: ts=4 sts=4 sw=4 et:
