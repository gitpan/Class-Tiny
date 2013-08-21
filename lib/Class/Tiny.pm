use 5.008001;
use strict;
use warnings;

package Class::Tiny;
# ABSTRACT: Minimalist class construction
our $VERSION = '0.004'; # VERSION

use Carp ();

if ( $] >= 5.010 ) {
    require "mro.pm"; ## no critic: hack to hide from min version & prereq scanners
}
else {
    require MRO::Compat;
}

my %CLASS_ATTRIBUTES;

sub import {
    my $class = shift;
    my $pkg   = caller;
    $class->prepare_class($pkg);
    $class->create_attributes( $pkg, @_ );
    return;
}

sub prepare_class {
    no strict 'refs';
    my ( $class, $pkg ) = @_;
    @{"${pkg}::ISA"} = "Class::Tiny::Object" unless @{"${pkg}::ISA"};
    return;
}

# adapted from Object::Tiny and Object::Tiny::RW
sub create_attributes {
    no strict 'refs';
    my ( $class, $pkg, @attr ) = @_;
    @attr = grep {
        defined and !ref and /^[^\W\d]\w*$/s
          or Carp::croak "Invalid accessor name '$_'"
    } @attr;
    $CLASS_ATTRIBUTES{$pkg}{$_} = undef for @attr;
    #<<< No perltidy
    eval join "\n", ## no critic: intentionally eval'ing subs here
      "package $pkg;",
      map {
        "sub $_ { return \@_ == 1 ? \$_[0]->{$_} : (\$_[0]->{$_} = \$_[1]) }\n"
      } grep { ! *{"$pkg\::$_"}{CODE} } @attr;
    #>>>
    Carp::croak("Failed to generate attributes for $pkg: @attr") if $@;
    return;
}

sub get_all_attributes_for {
    my ( $class, $pkg ) = @_;
    return map { keys %{ $CLASS_ATTRIBUTES{$_} || {} } } @{ mro::get_linear_isa($pkg) };
}

package Class::Tiny::Object;
# ABSTRACT: Base class for classes built with Class::Tiny
our $VERSION = '0.004'; # VERSION

sub new {
    my $class = shift;

    # handle hash ref or key/value arguments
    my $args;
    if ( @_ == 1 && ref $_[0] ) {
        my %copy = eval { %{ $_[0] } }; # try shallow copy
        if ($@) {
            Carp::croak("Argument to $class->new() could not be dereferenced as a hash");
        }
        $args = \%copy;
    }
    elsif ( @_ % 2 == 0 ) {
        $args = {@_};
    }
    else {
        Carp::croak("$class->new() got an odd number of elements");
    }

    # create object and invoke BUILD
    my $self = bless {%$args}, $class;
    my @search = @{ mro::get_linear_isa($class) };
    for my $s ( reverse @search ) {
        no strict 'refs';
        my $builder = *{ $s . "::BUILD" }{CODE};
        $self->$builder($args) if defined $builder;
    }

    # unknown attributes still in $args are fatal
    my @bad;
    for my $k ( keys %$args ) {
        push( @bad, $k ) unless $self->can($k); # a heuristic to catch typos
    }
    if (@bad) {
        Carp::croak("Invalid attributes for $class: @bad");
    }

    return $self;
}

# Adapted from Moo and its dependencies
require Devel::GlobalDestruction unless defined ${^GLOBAL_PHASE};

sub DESTROY {
    my $self = shift;
    my $in_global_destruction =
      defined ${^GLOBAL_PHASE}
      ? ${^GLOBAL_PHASE} eq 'DESTRUCT'
      : Devel::GlobalDestruction::in_global_destruction();
    for my $s ( @{ mro::get_linear_isa( ref $self ) } ) {
        no strict 'refs';
        my $demolisher = *{ $s . "::DEMOLISH" }{CODE};
        next unless $demolisher;
        my $e = do {
            local $?;
            local $@;
            eval { $self->$demolisher($in_global_destruction) };
            $@;
        };
        no warnings 'misc'; # avoid (in cleanup) warnings
        die $e if $e;       # rethrow
    }
}

1;


# vim: ts=4 sts=4 sw=4 et:

__END__

=pod

=encoding utf-8

=head1 NAME

Class::Tiny - Minimalist class construction

=head1 VERSION

version 0.004

=head1 SYNOPSIS

In F<Person.pm>:

  package Person;

  use Class::Tiny qw( name );

  1;

In F<Employee.pm>:

  package Employee;
  use parent 'Person';

  use Class::Tiny qw( ssn );

  1;

In F<example.pl>:

  use Employee;

  my $obj = Employee->new( name => "Larry", ssn => "111-22-3333" );

  # unknown attributes are fatal:
  eval { Employee->new( name => "Larry", OS => "Linux" ) };
  die "Error creating Employee: $@" if $@;

=head1 DESCRIPTION

This module offers a minimalist class construction kit in around 100 lines of
code.  Here is a list of features:

=over 4

=item *

defines attributes via import arguments

=item *

generates read-write accessors

=item *

supports custom accessors

=item *

superclass provides a standard C<new> constructor

=item *

C<new> takes a hash reference or list of key/value pairs

=item *

C<new> has heuristics to catch constructor attribute typos

=item *

C<new> calls C<BUILD> for each class from parent to child

=item *

superclass provides a C<DESTROY> method

=item *

C<DESTROY> calls C<DEMOLISH> for each class from child to parent

=back

It uses no non-core modules for any recent Perl. On Perls older than v5.10 it
requires L<MRO::Compat>. On Perls older than v5.14, it requires
L<Devel::GlobalDestruction>.

=head2 Why this instead of Object::Tiny or Class::Accessor or something else?

I wanted something so simple that it could potentially be used by core Perl
modules I help maintain (or hope to write), most of which either use
L<Class::Struct> or roll-their-own OO framework each time.

L<Object::Tiny> and L<Object::Tiny::RW> were close to what I wanted, but
lacking some features I deemed necessary, and their maintainers have an even
more strict philosophy against feature creep than I have.

Compared to everything else, this is smaller in implementation and simpler in
API.  (The only API is a list of attributes!)

I looked for something like it on CPAN, but after checking a dozen class
creators I realized I could implement it exactly how I wanted faster than I
could search CPAN for something merely sufficient.

=for Pod::Coverage new get_all_attributes_for prepare_class create_attributes

=head1 USAGE

=head2 Defining attributes

Define attributes as a list of import arguments:

    package Foo::Bar;

    use Class::Tiny qw(
        name
        id
        height
        weight
    );

For each item, a read-write accessor is created unless a subroutine of that
name already exists:

    $obj->name;               # getter
    $obj->name( "John Doe" ); # setter

Attribute names must be valid subroutine identifiers or an exception will
be thrown.

To make your own custom accessors, just pre-declare the method name before
loading Class::Tiny:

    package Foo::Bar;

    use subs 'id';

    use Class::Tiny qw( name id );

    sub id { ... }

By declaring C<id> also with Class::Tiny, you include it in the list
of allowed constructor parameters.

=head2 Class::Tiny::Object is your base class

If your class B<does not> already inherit from some class, then
Class::Tiny::Object will be added to your C<@ISA> to provide C<new> and
C<DESTROY>.

If your class B<does> inherit from something, then no additional inheritance is
set up.  If the parent subclasses Class::Tiny::Object, then all is well.  If
not, then you'll get accessors set up but no constructor or destructor. Don't
do that unless you really have a special need for it.

Define subclasses as normal.  It's best to define them with L<base>, L<parent>
or L<superclass> before defining attributes with Class::Tiny so the C<@ISA>
array is already populated at compile-time:

    package Foo::Bar::More;

    use parent 'Foo::Bar';

    use Class::Tiny qw( shoe_size );

=head2 Object construction

If your class inherits from Class::Tiny::Object (as it should if you followed
the advice above), it provides the C<new> constructor for you.

Objects can be created with attributes given as a hash reference or as a list
of key/value pairs:

    $obj = Foo::Bar->new( name => "David" );

    $obj = Foo::Bar->new( { name => "David" } );

If a reference is passed as a single argument, it must be able to be
dereferenced as a hash or an exception is thrown.  A shallow copy is made of
the reference provided.

In order to help catch typos in constructor arguments, any argument that it is
not also a valid method (e.g. an accessor or other method) will result in a
fatal exception.  This is not perfect, but should catch typical transposition
typos. Also see L</BUILD> for how to explicitly hide non-attribute, non-method
arguments if desired.

=head2 BUILD

If your class or any superclass defines a C<BUILD> method, it will be called
by the constructor from the furthest parent class down to the child class after
the object has been created.

It is passed the constructor arguments as a hash reference.  The return value
is ignored.  Use C<BUILD> for validation or setting default values.

    sub BUILD {
        my ($self, $args) = @_;
        $self->foo(42) unless defined $self->foo;
        croak "Foo must be non-negative" if $self->foo < 0;
    }

If you want to hide a non-attribute constructor argument from validation,
delete it from the passed-in argument hash reference.

    sub BUILD {
        my ($self, $args) = @_;

        if ( delete $args->{do_something_special} ) {
            ...
        }
    }

The argument reference is a copy, so deleting elements won't affect data in the
object. You have to delete it from both if that's what you want.

    sub BUILD {
        my ($self, $args) = @_;

        if ( delete $args->{do_something_special} ) {
            delete $self->{do_something_special};
            ...
        }
    }

=head2 DEMOLISH

Class::Tiny provides a C<DESTROY> method.  If your class or any superclass
defines a C<DEMOLISH> method, they will be called from the child class to the
furthest parent class during object destruction.  It is provided a single
boolean argument indicating whether Perl is in global destruction.  Return
values and errors are ignored.

    sub DEMOLISH {
        my ($self, $global_destruct) = @_;
        $self->cleanup();
    }

=head2 Introspection and internals

You can retrieve an unsorted list of valid attributes known to Class::Tiny
for a class and its superclasses with the C<get_all_attributes_for> class
method.

    my @attrs = Class::Tiny->get_all_attributes_for("Employee");
    # @attrs contains qw/name ssn/

The C<import> method uses two class methods, C<prepare_class> and
C<create_attributes> to set up the C<@ISA> array and attributes.  Anyone
attempting to extend Class::Tiny itself should use these instead of mocking up
a call to C<import>.

=for :stopwords cpan testmatrix url annocpan anno bugtracker rt cpants kwalitee diff irc mailto metadata placeholders metacpan

=head1 SUPPORT

=head2 Bugs / Feature Requests

Please report any bugs or feature requests through the issue tracker
at L<https://github.com/dagolden/class-tiny/issues>.
You will be notified automatically of any progress on your issue.

=head2 Source Code

This is open source software.  The code repository is available for
public review and contribution under the terms of the license.

L<https://github.com/dagolden/class-tiny>

  git clone git://github.com/dagolden/class-tiny.git

=head1 AUTHOR

David Golden <dagolden@cpan.org>

=head1 CONTRIBUTORS

=over 4

=item *

Karen Etheridge <ether@cpan.org>

=item *

Matt S Trout <mstrout@cpan.org>

=item *

Olivier Mengu� <dolmen@cpan.org>

=item *

Toby Inkster <inkster@cpan.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2013 by David Golden.

This is free software, licensed under:

  The Apache License, Version 2.0, January 2004

=cut
