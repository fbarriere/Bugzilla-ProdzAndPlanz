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
    PAP_filter_versions
    PAP_filter_milestones
);

# This file can be loaded by your extension via 
# "use Bugzilla::Extension::ProdzAndPlanz::Util". You can put functions
# used by your extension in here. (Make sure you also list them in
# @EXPORT.)

#
# Version filter:
#
#   given a product and the string given to the default
# version ("unspecified" in fresh Bugzilla new install),
# just re-create a list of version strings without the
# default version name.
#
sub PAP_filter_versions {
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
sub PAP_filter_milestones {
	my ($product, $default, $max) = @_;
	
	my @versions   = @{$product->versions};
	my @milestones = ();
	my $sortkey    = Bugzilla->params->{'milestones_sort'};
	
	foreach my $milestone (@{$product->milestones}) {
		next if $milestone->name eq $default;
		next if grep {$milestone->name eq $_->name} @versions;
		push(@milestones, $milestone);
	}
	
	if($sortkey eq 'name') {
		@milestones = sort {$a->name cmp $b->name} @milestones;
	}
	else {
		@milestones = sort {$a->sortkey cmp $b->sortkey} @milestones;
	}
	
	return ($max) ? @milestones[0 .. $max -1] : @milestones;
}

1;