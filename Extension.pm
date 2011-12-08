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
# The Original Code is the ProdzAndPlanz Bugzilla Extension.
#
# The Initial Developer of the Original Code is YOUR NAME
# Portions created by the Initial Developer are Copyright (C) 2011 the
# Initial Developer. All Rights Reserved.
#
# Contributor(s):
#   Francois Barriere <francois@barriere-smithson.net>

package Bugzilla::Extension::ProdzAndPlanz;
use strict;
use base qw(Bugzilla::Extension);

# This code for this is in ./extensions/ProdzAndPlanz/lib/Util.pm
use Bugzilla::Extension::ProdzAndPlanz::Util;

our $VERSION = '0.01';

# See the documentation of Bugzilla::Hook ("perldoc Bugzilla::Hook" 
# in the bugzilla directory) for a list of all available hooks.
sub install_update_db {
    my ($self, $args) = @_;

}

#
# Main logic to execute before the template:
#
#   As we add more than a single page, we select the
# function to execute based on the URL of the page
# requested.
#
sub page_before_template {
    my ($self, $args) = @_;

	my $pageid = Bugzilla->cgi->param('id');
	
	if("$pageid" eq "prodzandplanz/search_result.html") {
		product_search($self, $args);
	}
	elsif("$pageid" eq "prodzandplanz/product_planning.html") {
		product_planning($self, $args);
	}
}

#
# Product planning:
#
#   Given a product name, list milestones for this product and
# for each milestone list the bugs attached to the milestone.
# Sort the bugs into two lists: the closed bugs and the open bugs.
# Calculate the percentage done (closed / total), consider the
# special case where the total is 0.
# 
sub product_planning {
	my ($self, $args) = @_;
	
	my $user  = Bugzilla->login();
    my $vars  = $args->{vars};
    my $pname = Bugzilla->cgi->param('product');
    
    my $product = new Bugzilla::Product({ name => "$pname" });
    
    $vars->{'versions'} = [];
    $vars->{'product'}  = $product;
    
    foreach my $version (_filter_milestones($product, "---")) {
    	my $v = { 'version' => $version };
    	$v->{'bugs'} = Bugzilla::Bug->match({
    		'target_milestone' => $version->name,
    		'product'          => "$pname",
    	});
    	$v->{'opened'} = [];
    	$v->{'closed'} = [];
    	foreach my $bug (@{$v->{'bugs'}}) {
    		if($bug->isopened) {
    			push(@{$v->{'opened'}}, $bug);
    		}
    		else {
    			push(@{$v->{'closed'}}, $bug);
    		}
    	}
    	$v->{'num_opened'} = scalar(@{$v->{'opened'}});
    	$v->{'num_closed'} = scalar(@{$v->{'closed'}});
    	$v->{'num_total'}  = scalar(@{$v->{'opened'}}) + scalar(@{$v->{'closed'}});
    	if($v->{'num_total'} > 0) {
    		$v->{'pc_done'} = sprintf "%.0f", ($v->{'num_closed'} / $v->{'num_total'}) * 100;
    		$v->{'pc_done'} = sprintf "%.0f", $v->{'pc_done'};
    		
    	}
    	else {
    		$v->{'pc_done'} = 0;
    	}
    	push(@{$vars->{'versions'}}, $v);
    }    
}

#
# Product search:
#
#   given a string, list all the products that contain
# this string in their name or in their description (depending
# on the button pressed on the previous form, saved in psubmit).
# If the search string is empty, replace it with ".*" to match
# all the products.
# List the versions and milestones to complete the search page.
#
sub product_search {
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
    	
    	$product_filter = ($product_filter) ? qr/$product_filter/ : qr/.*/;
    	
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

#
# Version filter:
#
#   given a product and the string given to the default
# version ("unspecified" in fresh Bugzilla new install),
# just re-create a list of version strings without the
# default version name.
#
sub _filter_versions {
	my ($product, $default) = @_;
	
	my @versions = ();
	
	foreach my $version (@{$product->versions}) {
		next if $version->name eq $default;
		push(@versions, $version);
	}
	return @versions;
}

#
# Milestone filter:
#
#   given a product and the string given to the default
# milestone ("---" in fresh new install), re-create a list of
# the product milestones without the default milestone name,
# but also without the version names.
# Considering milestones are future versions, and once released
# they get added to the list of versions, so already released
# (or past) milestones are those that also appear in the version
# list.
#
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