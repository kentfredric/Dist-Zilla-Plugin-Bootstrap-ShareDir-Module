use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package Dist::Zilla::Plugin::Bootstrap::ShareDir::Module;

our $VERSION = '1.000000';

# ABSTRACT: Use a share directory on your dist for a module during bootstrap

# AUTHORITY

use Moose qw( with has around );
use MooseX::AttributeShortcuts;

with 'Dist::Zilla::Role::Bootstrap';

=begin MetaPOD::JSON v1.1.0

{
    "namespace":"Dist::Zilla::Plugin::Bootstrap::ShareDir::Module",
    "interface":"class",
    "does":"Dist::Zilla::Role::Bootstrap",
    "inherits":"Moose::Object"
}

=end MetaPOD::JSON

=cut

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
  for my $attribute (qw( module_map )) {
    my $pred = 'has_' . $attribute;
    if ( $self->can($pred) ) {
      next unless $self->$pred();
    }
    if ( $self->can($attribute) ) {
      $localconf->{$attribute} = $self->$attribute();
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
  require Test::File::ShareDir::Object::Module;
  my $share_object = Test::File::ShareDir::Object::Module->new( modules => $resolved_map );
  for my $module ( $share_object->module_names ) {
    $self->log( [ 'Bootstrapped sharedir for %s -> %s', $module, $resolved_map->{$module}->relative(q[.])->stringify ] );
    $self->log_debug(
      [
        'Installing module %s sharedir ( %s => %s )',
        "$module",
        $share_object->module_share_source_dir($module) . q{},
        $share_object->module_share_target_dir($module) . q{},
      ],
    );
    $share_object->install_module($module);
  }
  $self->_add_inc( $share_object->inc->tempdir . q{} );
  $self->log_debug( [ 'Sharedir for %s installed to %s', $self->distname, $share_object->inc->module_tempdir . q{} ] );
  return;
}

__PACKAGE__->meta->make_immutable;
no Moose;
no MooseX::AttributeShortcuts;

1;
