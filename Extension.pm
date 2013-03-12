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

use Bugzilla::Extension::ProdzAndPlanz::Groupmap;

use Bugzilla::Constants;

# This code for this is in ./extensions/ProdzAndPlanz/lib/Util.pm
use Bugzilla::Extension::ProdzAndPlanz::Util;

our $VERSION = '0.02';

# See the documentation of Bugzilla::Hook ("perldoc Bugzilla::Hook" 
# in the bugzilla directory) for a list of all available hooks.

sub db_schema_abstract_schema {
    my ($self, $args) = @_;
    
    $args->{'schema'}->{'pap_groupmap'} = {
        FIELDS => [
            group_id     => {TYPE => 'SMALLSERIAL', 
            	             NOTNULL => 1,
                             PRIMARYKEY => 1},
            leader_id    => {TYPE => 'INT3', 
            	             NOTNULL => 1,
                             REFERENCES  => {TABLE  =>  'bugs',
                                             COLUMN =>  'bug_id',
                                             DELETE => 'CASCADE'}},
            bug_id       => {TYPE => 'INT3', 
            	             NOTNULL => 1,
                             REFERENCES  => {TABLE  =>  'bugs',
                                             COLUMN =>  'bug_id',
                                             DELETE => 'CASCADE'}},
        ],
        INDEXES => [
            pap_groupmap_group_idx  => ['group_id'],
            pap_groupmap_leader_idx => ['leader_id'],
            pap_groupmap_bug_idx    => ['bug_id'],
        ],
    };
}



sub config_add_panels {
    my ($self, $args) = @_;
    
    my $modules = $args->{panel_modules};
    $modules->{ProdzAndPlanz} = "Bugzilla::Extension::ProdzAndPlanz::Config";
}

sub template_before_process {
    my ($self, $args) = @_;
    
    my ($vars, $file, $context) = @$args{qw(vars file context)};
	
	if($file eq "index.html.tmpl") {
		$self->product_list($args);
	}
	elsif($file eq "bug/show.html.tmpl") {
		$self->versions_map($args);
	}
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

	unless(Bugzilla->params->{'public_planning'}) {
		Bugzilla->login(LOGIN_REQUIRED);
	}

	my $pageid = Bugzilla->cgi->param('id');
	
	if("$pageid" eq "prodzandplanz/search_result.html") {
		product_search($self, $args);
	}
	elsif("$pageid" eq "prodzandplanz/product_page.html") {
		product_page($self, $args);
	}
	elsif("$pageid" eq "prodzandplanz/product_planning.html") {
		product_planning($self, $args);
	}
	elsif("$pageid" eq "prodzandplanz/product_versions.html") {
		product_versions($self, $args);
	}
	elsif("$pageid" eq "prodzandplanz/bug_versions.html") {
		versions_map($self, $args);
	}
}

#
# Product page:
#
#   A summary page with the product name, its description,
# the list of (past) versions with links to their bugs lists,
# the list of (future) milestones with links to their bugs/fixes
# lists, and links to the history (versions list)and planning 
# (milestones list) pages.
#
sub product_page {
	my ($self, $args) = @_;
	
    my $vars    = $args->{vars};
    my $pname   = Bugzilla->cgi->param('product');
    my $product = new Bugzilla::Product({ name => "$pname" });
    
    $vars->{'product'} = $product;
    $vars->{'versions'} = [
    	PAP_filter_list(
    		$product->versions, 
    		[ Bugzilla->params->{'default_version'} ]
    	)
    ];
    $vars->{'milestones'} = [
    	PAP_filter_list(
    		$product->milestones, 
    		[ Bugzilla->params->{'default_milestone'} ]
    	)
    ];
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
	
    my $vars  = $args->{vars};
    my $pname = Bugzilla->cgi->param('product');
    
    my $product = new Bugzilla::Product({ name => "$pname" });
    
    $vars->{'versions'} = [];
    $vars->{'product'}  = $product;
    
    my @milestones = PAP_filter_list(
		$product->milestones,
		[
			Bugzilla->params->{'default_milestone'},
			map {$_->name} @{$product->versions},
		],
	);
	@milestones = PAP_sort_milestones(@milestones);
	@milestones = PAP_limit_list(
		Bugzilla->params->{'max_milestones_in_plan'}, 
		@milestones
	);
    
    foreach my $version (@milestones) {
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
# Product versions:
#
#   Given a product name, list versions for this product and
# for each version list the bugs attached to the version.
# Sort the bugs into two lists: the closed bugs and the open bugs.
# 
sub product_versions {
	my ($self, $args) = @_;
	
    my $vars  = $args->{vars};
    my $pname = Bugzilla->cgi->param('product');
    
    my $product = new Bugzilla::Product({ name => "$pname" });
    
    $vars->{'versions'} = [];
    $vars->{'product'}  = $product;
    
    my @versions = PAP_filter_list(
		$product->versions,
		[
			Bugzilla->params->{'default_version'},
		],
	);
	@versions = PAP_limit_list(
		Bugzilla->params->{'max_versions_in_plan'}, 
		reverse @versions
	);
    
    foreach my $version (@versions) {
    	my $v = { 'version' => $version };
    	$v->{'bugs'} = Bugzilla::Bug->match({
    		'version' => $version->name,
    		'product' => "$pname",
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
    my ($tested, $products);
    
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
    	
	if(Bugzilla->params->{'public_planning'}) {
    	$products = PAP_get_all_products();
	}
	else {
		my $user = Bugzilla->login();
		$products = $user->get_selectable_products();
	}
    
    foreach my $product (@{$products}) {
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
    			'versions'   => [ 
    				reverse 
    				PAP_limit_list(
    					Bugzilla->params->{'max_versions_in_search'},
    					reverse PAP_filter_list(
    						$product->versions,
    						[ Bugzilla->params->{'default_version'} ],
    					)
    				)
				],
    			'milestones' => [ 
    				PAP_limit_list(
    					Bugzilla->params->{'max_milestones_in_search'},
    					PAP_sort_milestones(
    						PAP_filter_list(
    							$product->milestones,
    							[
									Bugzilla->params->{'default_milestone'},
									map {$_->name} @{$product->versions},
								],
    						)
						)
					)
    			],
    		};
    		push(@{$vars->{'products'}}, $p);
    	}
    }
}

#
# Home page products listing
#
#   List the products per classification and return a hash of hash
# used to build the drop down lists of the home page.
#
sub product_list {
    my ($self, $args) = @_;
    my $products;
	
	if(Bugzilla->params->{'product_search_position'} eq "off") {
		return;
	}
	
    my $vars     = $args->{vars};
    my $llimit   = Bugzilla->params->{'index_list_columns'};

	if(Bugzilla->params->{'public_planning'}) {
    	$products = PAP_get_all_products();
	}
	else {
		my $user = Bugzilla->login();
		$products = $user->get_selectable_products();
	}
    
    my $productlist = {};
    
    foreach my $product (@{$products}) {
    	my $classification = $product->classification();
    	if(exists $productlist->{$classification->name}) {
    		push(@{$productlist->{$classification->name}->{'products'}}, $product);
    	}
    	else {
    		$productlist->{$classification->name}->{'products'}       = [$product];
    		$productlist->{$classification->name}->{'classification'} = $classification;
    	}
    }
    
    $vars->{'products_table'} = PAP_tableize($llimit, values %{$productlist});
}

#
# Build a map of the product versions with the bug corresponding to
# the current bug, but for the given version.
#
sub versions_map {
    my ($self, $args) = @_;

    my $vars   = $args->{vars};
	my $cgi    = Bugzilla->cgi;
    my $bug_id = ($cgi->param('bug_id')) ? $cgi->param('bug_id') : $cgi->param('id');
    
    my $bug = new Bugzilla::Bug($bug_id) if $bug_id;
    
	if($bug) {
		my $product = new Bugzilla::Product({ name => $bug->product });

		$vars->{'PAP'}->{'bug'} = $bug;
		$vars->{'PAP'}->{'product'} = $product;
		
		$vars->{'product_versions'} = [ 
			map { $_->name } PAP_filter_list(
				$product->versions, [ Bugzilla->params->{'default_version'} ],
			)
		];


		


		my $groupmap = new Bugzilla::Extension::ProdzAndPlanz::Groupmap({ 'name' => $bug_id });
		unless($groupmap) {
			$groupmap = Bugzilla::Extension::ProdzAndPlanz::Groupmap->match({ 'leader_id' => $bug_id })->[0];
		}
		
		if($groupmap) {
			$vars->{'bug_leader_id'} = $groupmap->leader_id;
			
			foreach my $related_bug ( @{$groupmap->all_bugs_in_groupmap($groupmap->leader_id)} ) {
				$vars->{'versions_map'}->{$related_bug->version} = $related_bug->bug_id;
			}
			
			$vars->{'bugslist_as_string'} = $groupmap->all_bugs_in_groupmap_as_string($groupmap->leader_id);
		}
		$vars->{'versions_map'}->{$bug->version} = $bug->bug_id;
		
		#
		# If we have passed version params, we must duplicate the current
		# bug for each version.
		#
    	my @versions = $cgi->param('version');
    	foreach my $version (@versions) {
    		PAP_clone_bug($bug, $version);
    	}
	}
}

__PACKAGE__->NAME;