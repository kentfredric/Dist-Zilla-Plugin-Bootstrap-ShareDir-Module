use strict;
use warnings;

package Dist::Zilla::Plugin::Bootstrap::ShareDir::Module;
BEGIN {
  $Dist::Zilla::Plugin::Bootstrap::ShareDir::Module::AUTHORITY = 'cpan:KENTNL';
}
{
  $Dist::Zilla::Plugin::Bootstrap::ShareDir::Module::VERSION = '0.1.2';
}

# ABSTRACT: Use a C<share> directory on your dist for a module during bootstrap

use Moose;
use MooseX::AttributeShortcuts;

with 'Dist::Zilla::Role::Bootstrap';


has module_map => (
  is      => 'ro',
  isa     => 'HashRef',
  lazy    => 1,
  builder => sub {
    {};
  },
);
around 'dump_config' => sub {
  my ( $orig, $self, @args ) = @_;
  my $config    = $self->$orig(@args);
  my $localconf = {};
  for my $var (qw( module_map )) {
    my $pred = 'has_' . $var;
    if ( $self->can($pred) ) {
      next unless $self->$pred();
    }
    if ( $self->can($var) ) {
      $localconf->{$var} = $self->$var();
    }
  }
  $config->{ q{} . __PACKAGE__ } = $localconf;
  return $config;
};
around 'plugin_from_config' => sub {
  my ( $orig, $self, $name, $payload, $section ) = @_;

  my $special_fields = [qw( try_built fallback )];
  my $module_map     = { %{$payload} };
  my $new            = {};

  for my $field ( @{$special_fields} ) {
    $new->{$field} = delete $module_map->{$field} if exists $module_map->{$field};
  }
  $new->{module_map} = $module_map;

  return $self->$orig( $name, $new, $section );
};

sub bootstrap {
  my $self = shift;
  my $root = $self->_bootstrap_root;

  if ( not defined $root ) {
    $self->log( ['Not bootstrapping'] );
    return;
  }
  my $resolved_map = {};

  for my $key ( keys %{ $self->module_map } ) {
    require Path::Tiny;
    $resolved_map->{$key} = Path::Tiny::path( $self->module_map->{$key} )->absolute($root);
  }
  require Test::File::ShareDir::TempDirObject;
  my $object = Test::File::ShareDir::TempDirObject->new( { -share => { -module => $resolved_map } } );
  for my $module ( $object->_module_names ) {
    $self->log( ['Bootstrapped sharedir for %s -> %s', $module, $resolved_map->{$module}->relative(q[.])->stringify ]);
    $self->log_debug(
      [
        'Installing module %s sharedir ( %s => %s )',
        "$module",
        $object->_module_share_source_dir($module) . q{},
        $object->_module_share_target_dir($module) . q{},
      ]
    );
    $object->_install_module($module);
  }
  $self->_add_inc( $object->_tempdir . q{} );
  $self->log_debug( [ 'Sharedir for %s installed to %s', $self->distname, $object->_tempdir . q{} ] );
  return;
}

__PACKAGE__->meta->make_immutable;
no Moose;
no MooseX::AttributeShortcuts;

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Dist::Zilla::Plugin::Bootstrap::ShareDir::Module - Use a C<share> directory on your dist for a module during bootstrap

=head1 VERSION

version 0.1.2

=begin MetaPOD::JSON v1.1.0

{
    "namespace":"Dist::Zilla::Plugin::Bootstrap::ShareDir::Module",
    "interface":"class",
    "does":"Dist::Zilla::Role::Bootstrap",
    "inherits":"Moose::Object"
}


=end MetaPOD::JSON

=head1 AUTHOR

Kent Fredric <kentfredric@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
