#
# Copyright 2015 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package centreon::common::powershell::exchange::2010::activesyncmailbox;

use strict;
use warnings;
use centreon::plugins::misc;
use centreon::common::powershell::exchange::2010::powershell;

sub get_powershell {
    my (%options) = @_;
    # options: no_ps
    my $no_ps = (defined($options{no_ps})) ? 1 : 0;
    my $no_trust_ssl = (defined($options{no_trust_ssl})) ? '' : '-TrustAnySSLCertificate';
    
    return '' if ($no_ps == 1);
    
    my $ps = centreon::common::powershell::exchange::2010::powershell::powershell_init(%options);
    
    $ps .= '
try {
    $ErrorActionPreference = "Stop"
    $username = "' . $options{mailbox}  . '"
    $password = "' . $options{password}  . '"
    $secstr = New-Object -TypeName System.Security.SecureString
    $password.ToCharArray() | ForEach-Object {$secstr.AppendChar($_)}
    $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $secstr
    
    $results = Test-ActiveSyncConnectivity -MailboxCredential $cred ' . $no_trust_ssl . '
} catch {
    Write-Host $Error[0].Exception
    exit 1
}

Foreach ($result in $results) {
    Write-Host "[scenario=" $result.Scenario "][result=" $result.Result "][latency=" $result.Latency.TotalMilliseconds "][[error=" $Result.Error "]]"
}
exit 0
';

    return centreon::plugins::misc::powershell_encoded($ps);
}

sub check {
    my ($self, %options) = @_;
    # options: stdout
    
    # Following output:
    #[scenario= Options ][result= Failure ][latency= 52,00 ][[error=...]]
    $self->{output}->output_add(severity => 'OK',
                                short_msg => "ActiveSync to '" . $options{mailbox} . "' is ok.");
   
    my $checked = 0;
    $self->{output}->output_add(long_msg => $options{stdout});
    while ($options{stdout} =~ /\[scenario=(.*?)\]\[result=(.*?)\]\[latency=(.*?)\]\[\[error=(.*?)\]\]/msg) {
        my ($scenario, $result, $latency, $error) = ($self->{output}->to_utf8($1), centreon::plugins::misc::trim($2), 
                                                    centreon::plugins::misc::trim($3), centreon::plugins::misc::trim($4));
        
        $checked++;
        foreach my $th (('critical', 'warning')) {
            next if (!defined($self->{thresholds}->{$th}));
        
            if ($self->{thresholds}->{$th}->{operator} eq '=' && 
                $result =~ /$self->{thresholds}->{$th}->{state}/) {
                $self->{output}->output_add(severity => $self->{thresholds}->{$th}->{out},
                                            short_msg => sprintf("ActiveSync scenario '%s' to '%s' is '%s'",
                                                                 $scenario, $options{mailbox}, $result));
            } elsif ($self->{thresholds}->{$th}->{operator} eq '!=' && 
                $result !~ /$self->{thresholds}->{$th}->{state}/) {
                $self->{output}->output_add(severity => $self->{thresholds}->{$th}->{out},
                                            short_msg => sprintf("ActiveSync scenario '%s' to '%s' is '%s'",
                                                                 $scenario, $options{mailbox}, $result));
            }
        }
        
        if ($latency =~ /^(\d+)/) {
            $self->{output}->perfdata_add(label => $scenario, unit => 's',
                                          value => sprintf("%.3f", $1 / 1000),
                                          min => 0);
        }
    }
    
    if ($checked == 0) {
        $self->{output}->output_add(severity => 'UNKNOWN',
                                    short_msg => 'Cannot find informations');
    }
}

1;

__END__

=head1 DESCRIPTION

Method to check Exchange 2010 activesync on a specific mailbox.

=cut