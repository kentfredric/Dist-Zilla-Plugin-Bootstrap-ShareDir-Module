
use strict;
use warnings;

package E;

# ABSTRACT: Fake dist stub

use Moose;
use File::ShareDir qw( module_file );
use Path::Tiny qw( path );

with 'Dist::Zilla::Role::Plugin';

our $content = path( module_file( 'E', 'placeholder.txt' ) )->slurp;

1;

