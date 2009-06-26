package Koha::Templates;

use strict;
use warnings;
use Carp;

# Copyright 2009 Chris Cormack and The Koha Dev Team
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA

=head1 NAME 

    Koha::Templates - Object for manipulating templates for use with Koha

=cut

use base qw(Class::Accessor);
use Template;
use Template::Constants qw( :debug );

use C4::Context;

__PACKAGE__->mk_accessors(qw( theme lang filename htdocs));

sub new {
    my $class     = shift;
    my $interface = shift;
    my $filename  = shift;
    my $htdocs;
    if ( $interface ne "intranet" ) {
        $htdocs = C4::Context->config('opachtdocs');
    }
    else {
        $htdocs = C4::Context->config('intrahtdocs');
    }

#    my ( $theme, $lang ) = themelanguage( $htdocs, $tmplbase, $interface, $query );
    my $theme = 'prog';
    my $lang = 'en';
    my $template = Template->new(
        {
            EVAL_PERL    => 1,
            ABSOLUTE     => 1,
            INCLUDE_PATH => "$htdocs/$theme/$lang/includes",
            FILTERS      => {},

        }
    ) or die Template->error();
    my $self = {
        TEMPLATE => $template,
    };
    bless $self, $class;
    $self->theme($theme);
    $self->lang($lang);
    $self->filename($filename);
    $self->htdocs($htdocs);
    return $self;

}

sub output {
    my $self = shift;
    my $vars = shift;
    my $file = $self->htdocs . '/' . $self->theme .'/'.$self->lang.'/'.$self->filename;
    my $template = $self->{TEMPLATE};
    $template->process( $file, $vars) || die "Template process failed: ", $template->error();; 
    return;
}

1;