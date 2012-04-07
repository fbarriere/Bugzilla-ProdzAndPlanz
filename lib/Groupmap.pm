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

use strict;

package Bugzilla::Extension::ProdzAndPlanz::Groupmap;

use base qw(Bugzilla::Object);

use constant DB_TABLE => 'pap_groupmap';

use constant DB_COLUMNS => qw(
    group_id
    leader_id
    bug_id
);

use constant ID_FIELD => 'group_id';
use constant NAME_FIELD => 'bug_id';
use constant LIST_ORDER => 'leader_id';

use constant UPDATE_COLUMNS => qw(
    leader_id
    bug_id
);

use constant VALIDATORS => {
    leader_id  => \&_check_dummy,
    bug_id     => \&_check_dummy,
};

###############################
#####     Accessors        ####
###############################

sub group_id { return $_[0]->{'group_id'}; }
sub leader_id { return $_[0]->{'leader_id'}; }
sub bug_id { return $_[0]->{'bug_id'}; }

sub all_bugs_in_groupmap {
	my ($self, $leader) = @_;
	
	unless($self and $leader) {
		return [];
	}
	
	my $related = $self->match({ 'leader_id' => $leader });
	
	my @related_ids = map { $_->bug_id } @{$related};
	
	my @related_bugs = ();
	foreach ( @related_ids, $leader ) {
		my $bug = new Bugzilla::Bug($_);
		if($bug) {
			push(@related_bugs, $bug);
		}
	}
	
	return @related_bugs;
}

###############################
#####     Validators       ####
###############################

sub _check_dummy {
	my ($invocant, $fieldvalue) = @_;

	#$fieldvalue || ThrowUserError('blank_field');
	return $fieldvalue;
}

1;
