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
# The Original Code is the Bugzilla Example Plugin.
#
# The Initial Developer of the Original Code is Canonical Ltd.
# Portions created by Canonical Ltd. are Copyright (C) 2008
# Canonical Ltd. All Rights Reserved.
#
# Contributor(s): 
#   Francois Barriere <francois@barriere-smithson.net>

package Bugzilla::Extension::ProdzAndPlanz::Config;
use strict;
use warnings;

use Bugzilla::Config::Common;

sub get_param_list {
    my ($class) = @_;

    my @param_list = (
    	{
        	name    => 'product_search_position',
        	type    => 's',
        	choices => ['off', 'header', 'footer'],
        	default => 'footer',
    	},
    	{
    		name    => 'max_milestones_in_plan',
    		type    => 't',
    		default => '0',
    		checker => \&check_numeric,
    	},
    	{
    		name    => 'milestones_sort',
    		type    => 's',
        	choices => ['sortkey', 'name'],
    		default => 'sortkey',
    	},
    );
    return @param_list;
}

1;
