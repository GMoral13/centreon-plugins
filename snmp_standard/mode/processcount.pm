################################################################################
# Copyright 2005-2013 MERETHIS
# Centreon is developped by : Julien Mathis and Romain Le Merlus under
# GPL Licence 2.0.
# 
# This program is free software; you can redistribute it and/or modify it under 
# the terms of the GNU General Public License as published by the Free Software 
# Foundation ; either version 2 of the License.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A 
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License along with 
# this program; if not, see <http://www.gnu.org/licenses>.
# 
# Linking this program statically or dynamically with other modules is making a 
# combined work based on this program. Thus, the terms and conditions of the GNU 
# General Public License cover the whole combination.
# 
# As a special exception, the copyright holders of this program give MERETHIS 
# permission to link this program with independent modules to produce an executable, 
# regardless of the license terms of these independent modules, and to copy and 
# distribute the resulting executable under terms of MERETHIS choice, provided that 
# MERETHIS also meet, for each linked independent module, the terms  and conditions 
# of the license of that module. An independent module is a module which is not 
# derived from this program. If you modify this program, you may extend this 
# exception to your version of the program, but you are not obliged to do so. If you
# do not wish to do so, delete this exception statement from your version.
# 
# For more information : contact@centreon.com
# Authors : Quentin Garnier <qgarnier@merethis.com>
#
####################################################################################

package snmp_standard::mode::processcount;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $self->{version} = '1.0';
    $options{options}->add_options(arguments =>
                                { 
                                  "warning:s"               => { name => 'warning', },
                                  "critical:s"              => { name => 'critical', },
                                  "warning-mem-total:s"     => { name => 'warning_mem_total', },
                                  "critical-mem-total:s"    => { name => 'critical_mem_total', },
                                  "warning-mem-avg:s"       => { name => 'warning_mem_avg', },
                                  "critical-mem-avg:s"      => { name => 'critical_mem_avg', },
                                  "process-name:s"          => { name => 'process_name', },
                                  "regexp-name"             => { name => 'regexp_name', },
                                  "process-path:s"          => { name => 'process_path', },
                                  "regexp-path"             => { name => 'regexp_path', },
                                  "process-args:s"          => { name => 'process_args', },
                                  "regexp-args"             => { name => 'regexp_args', },
                                  "memory"                  => { name => 'memory', },
                                });
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);

    if (($self->{perfdata}->threshold_validate(label => 'warning', value => $self->{option_results}->{warning})) == 0) {
        $self->{output}->add_option_msg(short_msg => "Wrong warning threshold '" . $self->{option_results}->{warning} . "'.");
        $self->{output}->option_exit();
    }
    if (($self->{perfdata}->threshold_validate(label => 'critical', value => $self->{option_results}->{critical})) == 0) {
        $self->{output}->add_option_msg(short_msg => "Wrong critical threshold '" . $self->{option_results}->{critical} . "'.");
        $self->{output}->option_exit();
    }
    if (($self->{perfdata}->threshold_validate(label => 'warning-mem-total', value => $self->{option_results}->{warning_mem_total})) == 0) {
        $self->{output}->add_option_msg(short_msg => "Wrong warning-mem-total threshold '" . $self->{warning_mem_total} . "'.");
        $self->{output}->option_exit();
    }
    if (($self->{perfdata}->threshold_validate(label => 'critical-mem-total', value => $self->{option_results}->{critical_mem_total})) == 0) {
        $self->{output}->add_option_msg(short_msg => "Wrong critical-mem-total threshold '" . $self->{critical_mem_total} . "'.");
        $self->{output}->option_exit();
    }
    if (($self->{perfdata}->threshold_validate(label => 'warning-mem-avg', value => $self->{option_results}->{warning_mem_avg})) == 0) {
        $self->{output}->add_option_msg(short_msg => "Wrong warning-mem-avg threshold '" . $self->{warning_mem_avg} . "'.");
        $self->{output}->option_exit();
    }
    if (($self->{perfdata}->threshold_validate(label => 'critical-mem-avg', value => $self->{option_results}->{critical_mem_avg})) == 0) {
        $self->{output}->add_option_msg(short_msg => "Wrong critical-mem-avg threshold '" . $self->{critical_mem_avg} . "'.");
        $self->{output}->option_exit();
    }
    if (!defined($self->{option_results}->{process_name}) && 
        !defined($self->{option_results}->{process_path}) && 
        !defined($self->{option_results}->{process_args})
        ) {
        $self->{output}->add_option_msg(short_msg => "Need to specify at least one argument '--process-*'.");
        $self->{output}->option_exit();
    }
}

sub run {
    my ($self, %options) = @_;
    # $options{snmp} = snmp object
    $self->{snmp} = $options{snmp};
    
    my $oids = {
                name => '.1.3.6.1.2.1.25.4.2.1.2', # hrSWRunName
                path => '.1.3.6.1.2.1.25.4.2.1.4', # hrSWRunPath
                args => '.1.3.6.1.2.1.25.4.2.1.5', # hrSWRunParameters (Warning: it's truncated. (128 characters))
               };
    
    my $oid_hrSWRunStatus = '.1.3.6.1.2.1.25.4.2.1.7';
    my $oid_hrSWRunPerfMem = '.1.3.6.1.2.1.25.5.1.1.2';

    my $oid2check_filter;
    foreach (keys %$oids) {
        if (defined($self->{option_results}->{'process_' . $_})) {
            $oid2check_filter = $_;
            last;
        }
    }
    # Build other
    my $mores_filters = {};
    my $more_oids = [$oid_hrSWRunStatus];
    if (defined($self->{option_results}->{memory})) {
        push @{$more_oids}, $oid_hrSWRunPerfMem;
    }
    foreach (keys %$oids) {
        if ($_ ne $oid2check_filter && defined($self->{option_results}->{'process_' . $_})) {
            push @{$more_oids}, $oids->{$_};
            $mores_filters->{$_} = 1;
        }
    }

    my $result = $self->{snmp}->get_table(oid => $oids->{$oid2check_filter});
    my $instances_keep = {};
    foreach my $key ($self->{snmp}->oid_lex_sort(keys %$result)) {
        my $val = $self->{option_results}->{'process_' . $oid2check_filter};
        
        if ((defined($self->{option_results}->{'regexp_' . $oid2check_filter}) && $result->{$key} =~ /$val/)
            || (!defined($self->{option_results}->{'regexp_' . $oid2check_filter}) && $result->{$key} eq $val)) {
            $key =~ /\.([0-9]+)$/;
            $instances_keep->{$1} = 1;
        }
    }

    my $result2;
    if (scalar(keys %$instances_keep) > 0) {
        $self->{snmp}->load(oids => $more_oids, instances => [keys %$instances_keep ]);
        $result2 = $self->{snmp}->get_leef();
    
        foreach my $key (keys %$instances_keep) {
            # 1 = running, 2 = runnable, 3 = notRunnable, 4 => invalid
            if (!defined($result2->{$oid_hrSWRunStatus . "." . $key}) || $result2->{$oid_hrSWRunStatus . "." . $key} > 2) {
                delete $instances_keep->{$key};
                next;
            }
            
            my $long_value = '[ ' . $oid2check_filter . ' => ' . $result->{$oids->{$oid2check_filter} . '.' . $key} . ' ]';
            my $deleted = 0;
            foreach (keys %$mores_filters) {
                my $val = $self->{option_results}->{'process_' . $_};
                
                if ((defined($self->{option_results}->{'regexp_' . $_}) && $result2->{$oids->{$_} . '.' . $key} !~ /$val/)
                    || (!defined($self->{option_results}->{'regexp_' . $_}) && $result2->{$oids->{$_} . '.' . $key} ne $val)) {
                    delete $instances_keep->{$key};
                    $deleted = 1;
                    last;
                }
                
                $long_value .= ' [ ' . $_ . ' => ' . $result2->{$oids->{$_} . '.' . $key} . ' ]';
            }
            
            if ($deleted == 0) {
                $self->{output}->output_add(long_msg => 'Process: ' . $long_value);
            }
        }
    }
    
    my $num_processes_match = scalar(keys(%$instances_keep));
    my $exit = $self->{perfdata}->threshold_check(value => $num_processes_match, threshold => [ { label => 'critical', 'exit_litteral' => 'critical' }, { label => 'warning', exit_litteral => 'warning' } ]);
    $self->{output}->output_add(severity => $exit,
                                short_msg => "Number of current processes running: $num_processes_match");
    $self->{output}->perfdata_add(label => 'nbproc',
                                  value => $num_processes_match,
                                  warning => $self->{perfdata}->get_perfdata_for_output(label => 'warning'),
                                  critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical'),
                                  min => 0);
    # Check memory
    if (defined($self->{option_results}->{memory}) && $num_processes_match > 0) {
        my $total_memory = 0;
        foreach my $key (keys %$instances_keep) {
            $total_memory += ($result2->{$oid_hrSWRunPerfMem . "." . $key} * 1024);
        }
        
        $exit = $self->{perfdata}->threshold_check(value => $total_memory, threshold => [ { label => 'critical-mem-total', 'exit_litteral' => 'critical' }, { label => 'warning-mem-total', exit_litteral => 'warning' } ]);
        my ($total_mem_value, $total_mem_unit) = $self->{perfdata}->change_bytes(value => $total_memory);
        $self->{output}->output_add(severity => $exit,
                                    short_msg => sprintf("Total memory usage: %s", $total_mem_value . " " . $total_mem_unit));
        $self->{output}->perfdata_add(label => 'mem_total',
                                      value => $total_memory,
                                      warning => $self->{perfdata}->get_perfdata_for_output(label => 'warning_mem_total'),
                                      critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical_mem_total'),
                                      min => 0);
                                      
        $exit = $self->{perfdata}->threshold_check(value => $total_memory / $num_processes_match, threshold => [ { label => 'critical-mem-avg', 'exit_litteral' => 'critical' }, { label => 'warning-mem-avg', exit_litteral => 'warning' } ]);
        my ($avg_mem_value, $avg_mem_unit) = $self->{perfdata}->change_bytes(value => $total_memory / $num_processes_match);
        $self->{output}->output_add(severity => $exit,
                                    short_msg => sprintf("Average memory usage: %.2f %s", $avg_mem_value, $avg_mem_unit));
        $self->{output}->perfdata_add(label => 'mem_avg',
                                      value => sprintf("%.2f", $total_memory / $num_processes_match),
                                      warning => $self->{perfdata}->get_perfdata_for_output(label => 'warning_avg_total'),
                                      critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical_avg_total'),
                                      min => 0);
    }
    
    $self->{output}->display();
    $self->{output}->exit();
}

1;

__END__

=head1 MODE

Check system number of processes.
Can also check memory usage.

=over 8

=item B<--warning>

Threshold warning.

=item B<--critical>

Threshold critical.

=item B<--warning-mem-total>

Threshold warning in Bytes of total memory usage processes.

=item B<--critical-mem-total>

Threshold warning in Bytes of total memory usage processes.

=item B<--warning-mem-avg>

Threshold warning in Bytes of average memory usage processes.

=item B<--critical-mem-avg>

Threshold warning in Bytes of average memory usage processes.

=item B<--process-name>

Check process name.

=item B<--regexp-name>

Allows to use regexp to filter process name (with option --process-name).

=item B<--process-path>

Check process path.

=item B<--regexp-path>

Allows to use regexp to filter process path (with option --process-path).

=item B<--process-args>

Check process args.

=item B<--regexp-args>

Allows to use regexp to filter process args (with option --process-args).

=item B<--memory>

Check memory.

=back

=cut
