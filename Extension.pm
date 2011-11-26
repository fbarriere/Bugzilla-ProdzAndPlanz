# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# The contents of this file are subject to the Mozilla Public
# License Version 1.1 (the "License"); you may not use this file
# except in compliance with the License. You may obtain a copy of
# the License at http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
# implied. See the License for the specific language governing
# rights and limitations under the License.
#
# The Original Code is the ManyProducts Bugzilla Extension.
#
# The Initial Developer of the Original Code is YOUR NAME
# Portions created by the Initial Developer are Copyright (C) 2011 the
# Initial Developer. All Rights Reserved.
#
# Contributor(s):
#   Francois Barriere <francois.barriere@atmel.com>

package Bugzilla::Extension::ManyProducts;
use strict;
use base qw(Bugzilla::Extension);

# This code for this is in ./extensions/ManyProducts/lib/Util.pm
use Bugzilla::Extension::ManyProducts::Util;

our $VERSION = '0.01';

# See the documentation of Bugzilla::Hook ("perldoc Bugzilla::Hook" 
# in the bugzilla directory) for a list of all available hooks.
sub install_update_db {
    my ($self, $args) = @_;

}

#
# Main logic to execute before the template:
#
sub page_before_template {
    my ($self, $args) = @_;
    my ($tested);
    
	my $user           = Bugzilla->login();
    my $vars           = $args->{vars};
    my $product_filter = Bugzilla->cgi->param('product_filter');
    my $filter_type    = Bugzilla->cgi->param('psubmit');
	
	$vars->{'product_filter'}  = "$product_filter";
	$vars->{'products'}        = [];
    if("$filter_type" eq "Search product name") {
 		$vars->{'filter_type'} = "name";
    }
    else {
 		$vars->{'filter_type'} = "description";
    }
    	
    my @products = @{$user->get_enterable_products};
    
    foreach my $product (@products) {
    	if("$filter_type" eq "Search product name") {
    		$tested = $product->name;
    	}
    	else {
    		$tested = $product->description;
    	}
    	$product_filter = qr/$product_filter/;
    	if("$tested" =~ $product_filter) {
    		my $p = {
    			'product'    => $product,
    			'versions'   => [ _filter_versions($product, "unspecified") ],
    			'milestones' => [ _filter_milestones($product, "---")],
    		};
    		push(@{$vars->{'products'}}, $p);
    	}
    }
}

sub _filter_versions {
	my ($product, $default) = @_;
	
	my @versions = ();
	
	foreach my $version (@{$product->versions}) {
		next if $version->name eq $default;
		push(@versions, $version);
	}
	return @versions;
}

sub _filter_milestones {
	my ($product, $default) = @_;
	
	my @versions   = @{$product->versions};
	my @milestones = ();
	
	foreach my $milestone (@{$product->milestones}) {
		next if $milestone->name eq $default;
		next if grep {$milestone->name eq $_->name} @versions;
		push(@milestones, $milestone);
	}
	
	return @milestones;
}

__PACKAGE__->NAME;