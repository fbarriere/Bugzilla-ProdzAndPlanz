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

package Bugzilla::Extension::ProdzAndPlanz::Util;
use strict;
use base qw(Exporter);
our @EXPORT = qw(
    PAP_filter_list
    PAP_sort_milestones
    PAP_limit_list
    PAP_tableize
    PAP_get_all_products
    PAP_clone_bug
);

# This file can be loaded by your extension via 
# "use Bugzilla::Extension::ProdzAndPlanz::Util". You can put functions
# used by your extension in here. (Make sure you also list them in
# @EXPORT.)

#
# Filter a list of object given a list of names
# to exclude. Used to filter the list of milestones
# or versions.
#
sub PAP_filter_list {
	my ($sourcelist, $excludes) = @_;
	
	my @excludes = @{$excludes};
	my @outlist = ();
	foreach my $elmt (@{$sourcelist}) {
		next if grep {$elmt->name eq $_} @excludes;
		push(@outlist, $elmt);
	}
	return @outlist;
}

#
# Sort a list of milestone objects. Depending on the
# configuration, sort on 'sortkey' or 'name' attribute.
#
sub PAP_sort_milestones {
	my $sortkey = Bugzilla->params->{'milestones_sort'};
	
	if($sortkey eq 'name') {
		return sort {$a->name cmp $b->name} @_;
	}
	else {
		return sort {$a->sortkey <=> $b->sortkey} @_;
	}
}

#
# Limit a list of values. The limit value is the
# first argument, the rest is the list.
# If the limit is null, return the complete list.
#
sub PAP_limit_list {
	my $max = shift;
	
	$max = ($max < scalar(@_)) ? $max : scalar(@_);
	
	return ($max) ? @_[0 .. $max -1] : @_;
}

#
# Given a line size and an array, return a reference
# to a table with the line size being the limit.
# Used to format lists into tables for easier manipulation
# in the templates.
#
sub PAP_tableize {
	my $limit = shift;
	
	my $table = [];
	my $line   = [];
	
	foreach my $elmt (@_) {
		if(scalar(@{$line}) == $limit) {
			push(@{$table}, $line);
			$line = [$elmt];
		}
		else {
			push(@{$line}, $elmt);
		}
	}
	push(@{$table}, $line);
	
	return $table;
}

sub PAP_get_all_products {
	my $class_id = shift;

	my $query = "SELECT id  FROM products ORDER BY name";

	my $prod_ids = Bugzilla->dbh->selectcol_arrayref($query);
	my $prodlist = Bugzilla::Product->new_from_list($prod_ids);

    # Restrict the list of products to those being in the classification, if any.
    if ($class_id) {
        return [grep {$_->classification_id == $class_id} @{$prodlist}];
    }
    # If we come here, then we want all selectable products.
    return $prodlist;
}

sub PAP_clone_bug {
	my ($bug, $version_string) = @_;
	
	warn "Clonning bug to version $version_string";
	
	my %bugvars;
	
	$bugvars{'product'}          = $bug->product;
	$bugvars{'component'}        = $bug->component;
	$bugvars{'priority'}         = $bug->priority;
	$bugvars{'bug_severity'}     = $bug->bug_severity;
	$bugvars{'rep_platform'}     = $bug->rep_platform;
	$bugvars{'op_sys'}           = $bug->op_sys;
	$bugvars{'target_milestone'} = $bug->target_milestone;

	$bugvars{'short_desc'}       = $bug->short_desc;
	$bugvars{'bug_file_loc'}     = $bug->bug_file_loc;
	$bugvars{'keywords'}         = $bug->keywords;
	$bugvars{'dependson'}        = join (", ", @{$bug->dependson});
	$bugvars{'blocked'}          = join (", ", @{$bug->blocked});
	$bugvars{'deadline'}         = $bug->deadline;
	$bugvars{'estimated_time'}   = $bug->estimated_time;

	if (defined $bug->cc) {
		$bugvars{'cc'}           = join (", ", @{$bug->cc});
	}
    
	my @enter_bug_fields = grep { $_->enter_bug } Bugzilla->active_custom_fields;
    
    foreach my $field (@enter_bug_fields) {
        my $field_name = $field->name;
        $bugvars{$field_name} = $bug->$field_name;
    }

	$bugvars{'version'} = $version_string;
	
	my $newbug = Bugzilla::Bug->create(\%bugvars);
	
	warn "New bug is: " . $newbug->bug_id;
	
	if($newbug) {
		warn "Adding new bug to group.";
		my $group = Bugzilla::Extension::ProdzAndPlanz::Groupmap->create({
			'bug_id'    => $newbug->bug_id,
			'leader_id' => $bug->bug_id,
		});
	}
}

1;