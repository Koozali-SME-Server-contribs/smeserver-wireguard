#!/usr/bin/perl
package esmith::FormMagick::Panel::wireguard;

# Imports
use strict;
use warnings;
use esmith::AccountsDB;
use esmith::ConfigDB;
use esmith::NetworksDB;
use esmith::FormMagick;
use esmith::cgi;
use esmith::util;
use Net::IP;
use CGI::Carp qw ( fatalsToBrowser );
use File::Basename;

our @ISA = qw(esmith::FormMagick Exporter);

# TODO: update sub list
our @EXPORT = qw(
    print_custom_button
    print_section_bar
    write_db_conf
    update_ports
    print_conf_table
    print_conf_name_field
    remove_conf
    print_conf_to_remove
    read_file
    reload
);

our $accounts = esmith::AccountsDB::UTF8->open();
our $wdb = esmith::ConfigDB::UTF8->open('wireguard') || esmith::ConfigDB->create('wireguard');
our $cdb = esmith::ConfigDB->open || die "Error opening configuration DB\n";
our $ndb = esmith::NetworksDB->open_ro || die "Error opening netwoks DB\n";
our $base_url = "?page=0&page_stack=&Next=Next&wherenext=";

*wherenext = \&CGI::FormMagick::wherenext;

sub new {
    shift;
    my $fm = esmith::FormMagick->new();
    $fm->{calling_package} = (caller)[0];
    bless $fm;
    return $fm;
}

sub print_custom_button{
    my ($fm,$desc,$url) = @_;
    my $q = $fm->{cgi};
    $url="wireguard?page=0&page_stack=&Next=Next&wherenext=".$url;
    print "  <tr>\n    <td colspan='2'>\n";
    print $q->p($q->a({href => $url, -class => "button-like"},$fm->localise($desc)));
    print qq(</tr>\n);
    return undef;
}

sub print_section_bar{
    my ($fm) = @_;
    print "  <tr>\n    <td colspan='2'>\n";
    print "<hr class=\"sectionbar\"/>\n";
    return undef;
}

sub print_conf_table{
    my $fm = shift;
    my $type = shift;
    my $q = $fm->{cgi};
    my $conf_name = $fm->localise('CONF_NAME');
    my $modify = $fm->localise('MODIFY');
    $wdb = esmith::ConfigDB::UTF8->open('wireguard') || esmith::ConfigDB->create('wireguard');

    my @conf = $wdb->get_all_by_prop(type=>$type);

    unless ( scalar @conf ){
        print $q->Tr($q->td($fm->localise('NO_CONF')));
        return "";
    }
    print $q->start_table({-CLASS => "sme-border"}),"\n";
    print $q->Tr (
            esmith::cgi::genSmallCell($q, $fm->localise('CONF_NAME'),"header"),
            esmith::cgi::genSmallCell($q, $fm->localise('USER'),"header"),
            esmith::cgi::genSmallCell($q, $fm->localise('INFO'),"header"),
            esmith::cgi::genSmallCell($q, $fm->localise('LABEL_STATUS'),"header"),
            esmith::cgi::genSmallCell($q, $fm->localise('ACTION'),"header", 3),
        ),
            "\n";
    foreach my $config (@conf){
        my $key = $config->key;

        my $status = $config->prop('status') || 'enabled';
        if ($status eq 'enabled'){
            $status = $fm->localise('ENABLED');
        }
        elsif ($status eq 'disabled'){
            $status = $fm->localise('DISABLED');
        }
	my $user = $config->prop('user') || '';
        my $info = $config->prop('info') || '';

        print $q->Tr (esmith::cgi::genSmallCell($q,"$key"),
                      esmith::cgi::genSmallCell($q,"$user"),
                      esmith::cgi::genSmallCell($q,"$info"),
                      esmith::cgi::genSmallCell($q,"$status"),
                      esmith::cgi::genSmallCell ($q, $q->a ({href => $q->url (-absolute => 1).
                                $base_url."DISPLAY_QR_PAGE&action=reload&conf_name=".
                                $key}, $fm->localise('QRCODE'))),
                      esmith::cgi::genSmallCell ($q, $q->a ({href => $q->url (-absolute => 1).
                                $base_url."MODIFY_CLIENT_PAGE&action=modify&conf_name=".
                                $key}, $fm->localise('MODIFY'))),
                      esmith::cgi::genSmallCell ($q, $q->a ({href => $q->url (-absolute => 1).
                                $base_url."REMOVE_CLIENT_PAGE&conf_name=".
                                $key}, $fm->localise('REMOVE'))));

    }

### add table lines here
#
    print $q->end_table,"\n";
    return "";
}

sub print_config{
    my $fm = shift;
    my $type = shift;
    my $q = $fm->{cgi};
    my @wgstatus = `/usr/bin/wg show wg0 dump`;
    my $wg = $cdb->get('wg-quick@wg0');
    my $wgpub = $wg->prop('public');
    my $wgip = $wg->prop('ip');
    my $wgmask = $wg->prop('mask');
    my $wgport = $wg->prop('UDPPort');
    my $sstatus = $wg->prop('status');

    print $q->Tr (esmith::cgi::genSmallCell($q,$fm->localise('INTERFACE'),"header"),
                esmith::cgi::genSmallCell($q, "wg0"),);
    print $q->Tr (esmith::cgi::genSmallCell($q,$fm->localise('LABEL_STATUS'),"header"),
                esmith::cgi::genSmallCell($q, $sstatus),);
    print $q->Tr (esmith::cgi::genSmallCell($q,$fm->localise('PUBLIC_KEY'),"header"), 
		esmith::cgi::genSmallCell($q, $wgpub),);
    print $q->Tr (esmith::cgi::genSmallCell($q,$fm->localise('IP'),"header"), 
                esmith::cgi::genSmallCell($q, "$wgip/$wgmask"),);
    print $q->Tr (esmith::cgi::genSmallCell($q,$fm->localise('PORT'),"header"),          
                esmith::cgi::genSmallCell($q, $wgport),);


    print $q->start_table({-CLASS => "sme-border"}),"\n";
#public-key | private-key | listen-port |persistent-keepalive
    print $q->Tr (
            esmith::cgi::genSmallCell($q, $fm->localise('PUBLIC_KEY'),"header"),
            esmith::cgi::genSmallCell($q, $fm->localise('INFO'),"header"),
            esmith::cgi::genSmallCell($q, $fm->localise('ENDPOINT'),"header"),
            esmith::cgi::genSmallCell($q, $fm->localise('VPN_IP'),"header"),	   
            esmith::cgi::genSmallCell($q, $fm->localise('LATEST_HANDSHAKE'),"header"),
            esmith::cgi::genSmallCell($q, $fm->localise('RECEIVED'),"header"),
            esmith::cgi::genSmallCell($q, $fm->localise('SENT'),"header"),
            esmith::cgi::genSmallCell($q, $fm->localise('KEEPALIVE'),"header"),
        ),
            "\n";
    if (scalar @wgstatus >0) {
    foreach my $list (@wgstatus){
    my @line = split(' ',$list);
	next if $line[1] eq $wgpub;
	my ($ginfo ,$user);
	$ginfo = $wdb->get("$line[3]")->prop('info') if $wdb->get("$line[3]");
	$user = $wdb->get("$line[3]")->prop('user') if $wdb->get("$line[3]");
	use POSIX qw( strftime );
	my $dateR= ($line[4] ) ? strftime("%Y-%m-%d %H:%M:%S", localtime($line[4])) : " ";
        print $q->Tr (esmith::cgi::genSmallCell($q,$line[0]),
                      esmith::cgi::genSmallCell($q,"$user : $ginfo"),
                      esmith::cgi::genSmallCell($q,$line[2]),
                      esmith::cgi::genSmallCell($q,$line[3]),
                      esmith::cgi::genSmallCell($q,$dateR),
                      esmith::cgi::genSmallCell($q,$line[5]),
                      esmith::cgi::genSmallCell($q,$line[6]),
                      esmith::cgi::genSmallCell($q,$line[7]),
	);
    }
    }
    print $q->end_table,"\n";
    return "";

}

# this sub is to create a new client for an existing account
sub performCreateClient{
    my $fm = shift;
    my $type = shift;
    my $q = $fm->{cgi};
    my $username = $q->param('account');
    my $info = $q->param('info');
    ($info) = $info =~ /([A-Za-z0-9_\-. ]+)/;
#	trim both ends
    $info =~ s/^ +| +$//g;
    ($username) = $username =~ /([A-Za-z0-9_-]+)/;
    return $fm->error("ERROR_FIELD_CONTENT", 'FIRST_PAGE') unless ($username and $info);
    #get username
    my $user = $accounts->get($username) or return "$username does not exist";
    return $fm->error("ERROR_WRONG_ACCT_TYPE", 'FIRST_PAGE') unless $user->prop("type") eq "user" or $user->key eq "admin";
    $username = $user->key;
    # execute the event wireguard-user-create username info
    unless ( system ("/sbin/e-smith/signal-event", "wireguard-user-create", "$username" , "$info") == 0 ){
        return $fm->error("ERROR_OCCURED", 'FIRST_PAGE');
    }
    #force reload
    $wdb = esmith::ConfigDB::UTF8->open('wireguard') || esmith::ConfigDB->create('wireguard');
    # return
    $fm->success('SUCCESS','FIRST_PAGE');
    return undef;
}

sub print_qr{
    my $fm = shift;
    my $type = shift;
    my $q = $fm->{cgi};
    my $ipacc = $q->param('conf_name');
#untaint
($ipacc) = $ipacc  =~ /(\d+\.\d+\.\d+\.\d+\/\d+)/;
#get from db

# return if does not exist
my $acc = $wdb->get($ipacc) or return "not found";

# return if current user is not admin or the user
my $username = $ENV{REMOTE_USER};
return unless $username eq "admin";
my $key = $acc->key;
my $info = $acc->prop('info');
my $private = $acc->prop('private');
my $wg0 = $cdb->get('wg-quick@wg0');
my $ServPublic = $wg0->prop('public');
my $Port = $wg0->prop('UDPPort');
my $allowedips = $acc->prop('allowedips') || "0.0.0.0/0";

#here we guess wan IP
# are we server-gateway mode ? so external lan, should do 
# else we should guess from an external service
my $ExternalIP = $cdb->get('ExternalInterface')->prop('IPAddress');
$ExternalIP = get_internet_ip_address() unless defined $ExternalIP;

#DNS
my $IPAddress = $cdb->get('InternalInterface')->prop('IPAddress');
my $dns = ($allowedips =~ /0.0.0.0\/0/)? "DNS = $IPAddress" : "" ;


my $fulltext ="#configuration for $key $info
[Interface]
PrivateKey = $private
Address = $key
$dns

[Peer]
PublicKey = $ServPublic
AllowedIPs = $allowedips
Endpoint = $ExternalIP:$Port
";

print "<br><textarea cols='70' rows='10'>$fulltext </textarea>";

my $qr=`echo "$fulltext" |qrencode -t PNG -o - |base64`;
print "</br>";
print "<img src='data:image/png;base64,$qr' >";

return "";

}
=head2 existing_accounts

Return a hash of exisitng system accounts

=cut

sub existing_accounts {
    my $fm = shift;
    my %existingAccounts = ('admin' => "Administrator" );

    foreach my $account ($accounts->get_all_by_prop(type=>'user')) {
            $existingAccounts{$account->key} = $account->key;
    }
    return(\%existingAccounts);
}

=head2 get_cgi_param FM FIELD

Returns the named CGI parameter as a string

=cut

sub get_cgi_param {
    my $fm = shift;
    my $param = shift;

    return ($fm->{'cgi'}->param($param));
}

sub print_client_name_field{
    my $fm = shift;
    my $q = $fm->{cgi};
    my $name = $q->param('conf_name') || '';
    my $action = $q->param('action') || '';
    print qq(<tr><td colspan="2">) . $fm->localise('DESC_CONF_NAME').qq(</td></tr>);
    print qq(<tr><td class="sme-noborders-label">) .
    $fm->localise('CONF_NAME') . qq(</td>\n);
    if ($action eq 'modify' and $name) {
        print qq(
            <td class="sme-noborders-content">$name 
            <input type="hidden" name="name" value="$name">
            <input type="hidden" name="action" value="modify">
            </td>
        );
        # If action is modify, we need to read the DB
        # And set CGI parameters

        my $rec = $wdb->get($name);
        if ($rec){
            $q->param(-name=>'info',-value=>
                    $rec->prop('info'));
            $q->param(-name=>'allowedips',-value=>
                    $rec->prop('allowedips'));
            $q->param(-name=>'private',-value=>
                    $rec->prop('private'));
            $q->param(-name=>'public',-value=>
                    $rec->prop('public'));
            $q->param(-name=>'account',-value=>
                    $rec->prop('user'));
            $q->param(-name=>'status',-value=>
                    $rec->prop('status'));
            $q->param(-name=>'dns',-value=>
                    $rec->prop('dns'));

        }
    }
}

sub performModifyClient{
    my $fm = shift;
    my $q = $fm->{'cgi'};
    my $msg = "OK";

    my $wgacc = $q->param('conf_name');
    my $account = $q->param('account');
    my $private = $q->param('private') || '';
    my $public = $q->param('public') || ''; 
    my $info = $q->param('info');
    my $status = $q->param('status') || 'disabled';
    my $allowedips =  $q->param('allowedips') || '';

#todo validate fields
    ($info) = $info =~ /([A-Za-z0-9_\-. ]+)/;
#	trim both ends
    $info =~ s/^ +| +$//g;

    return $fm->error("ERROR_FIELD_CONTENT", 'FIRST_PAGE') unless $info;

    my %props = ('user' =>  $account
		,'private' => $private
		,'public' => $public
		,'info' => $info
		,'status' => $status
		,'allowedips' => $allowedips
		);

    $wdb->get($wgacc)->merge_props(%props)
        or $msg = "Error occurred while modifying pseudonym in database.";

    # Untaint before use in system()
    ($wgacc) = ($wgacc =~ /(\d+\.+\d+\.+\d+\.+\d+\.+\/\d+\.+)/);
    system( "/sbin/e-smith/signal-event", "wireguard-user-modify", "$wgacc",)
        == 0 or $msg = "Error occurred while modifying wirequard account.";

    if ($msg eq "OK")
    {
        $q->delete('conf_name');
        $q->delete('private');
        $q->delete('public');
	$q->delete('info');
	$q->delete('allowedips');
	$q->delete('status');
	$q->delete('account');
        $fm->success('MODIFY_SUCCEEDED');
    }
    else
    {
        $fm->error($msg);
    }

}

sub getConfig{
   my $fm = shift;
    my $q = $fm->{cgi};
        my $rec = $cdb->get('wg-quick@wg0');
        if ($rec){
            $q->param(-name=>'ip',-value=>
                    $rec->prop('ip'));
            $q->param(-name=>'mask',-value=>
                    $rec->prop('mask'));
            $q->param(-name=>'private',-value=>
                    $rec->prop('private'));
            $q->param(-name=>'public',-value=>
                    $rec->prop('public'));
            $q->param(-name=>'status',-value=>
                    $rec->prop('status'));
        }
return "";
}

sub performUpdateConfig{
    my $fm = shift;
    my $q = $fm->{'cgi'};
    my $msg = "OK";

    my $ip = $q->param('ip');
    my $mask = $q->param('mask');
    my $port = $q->param('port');
    my $private = $q->param('private');
    my $public = $q->param('public');
    unless (defined $private) {
    	$private =`/usr/bin/wg genkey`;
	($private) = ($private =~ /(\w+)/);
	$public = `/usr/bin/echo $private | /usr/bin/wg pubkey`;
    }
    my $status = $q->param('status') || 'disabled';

    # we get number of entries in wireguard db
    my @num=$wdb->get_all_by_prop(type=>"wg0"); 
    if ( scalar @num >0 ) {
	# we get current values
	my $pprivate=$cdb->get('wg-quick@wg0')->prop('private');
	my $ppublic=$cdb->get('wg-quick@wg0')->prop('public');
	my $pip=$cdb->get('wg-quick@wg0')->prop('ip');
        my $pmask=$cdb->get('wg-quick@wg0')->prop('mask');
	# if  # entries >0 and private  |public | ip is chnaged then we push an error and stop
	if ($pprivate ne $private || $ppublic ne $public || $pip ne $ip || $mask ne $pmask) {
		$fm->error('CLIENTS_ALREADY_CONFIGURED');
		return; 
		}	
	}

    #todo validate fields

    my %props = ('ip' =>  $ip
		,'mask' => $mask 
                ,'private' => $private
                ,'public' => $public
                ,'status' => $status
                );

        # Test Ip is inside CIDR
    if (!test_for_private_ip($ip,$mask)) {
	$msg = "IP must be in private range";
	$fm->error($msg);return;		
    }


    $cdb->get('wg-quick@wg0')->merge_props(%props)
        or $msg = "Error occurred while modifying server details.";

    
    if ($msg eq "OK"){
		# Untaint before use in system()
		($ip) = ($ip =~ /(\d+\.+\d+\.+\d+\.+\d+\.+\/\d+\.+)/);
		system( "/sbin/e-smith/signal-event", "wireguard-conf-modify", "$ip",)
			== 0 or $msg = "Error occurred while modifying wireguard conf.";
    }
    if ($msg eq "OK")
    {
        $q->delete('ip');
        $q->delete('private');
        $q->delete('public');
        $q->delete('info');
        $q->delete('status');
        $fm->success('MODIFY_SUCCEEDED');
    }
    else
    {
        $fm->error($msg);
    }





}

sub remove_client{
    my ($fm) = @_;
    my $q = $fm->{cgi};
    my $conf = $q->param('conf_name');
    unless($q->param("cancel")){
        unless ($wdb->get($conf)->delete()){
            $fm->error('ERROR_OCCURED','FIRST_PAGE');
            return undef;
        }
        unless (system ("/sbin/e-smith/signal-event", "wireguard-user-delete") == 0 ){
            $fm->error('ERROR_OCCURED','FIRST_PAGE');
            return undef;
        }
    	#force reload
    	$wdb = esmith::ConfigDB::UTF8->open('wireguard') || esmith::ConfigDB->create('wireguard');
        $fm->success('SUCCESS','FIRST_PAGE');
        return undef;
    }
    $fm->error('CANCELED','FIRST_PAGE');
    return undef;
}

sub print_client_to_remove{
    my ($fm) = @_;
    my $q = $fm->{cgi};
    my $conf = $q->param('conf_name');
    my $rec = $wdb->get($conf);
    my $comment = $rec->prop('info') || '';

    print $q->Tr(
            $q->td(
                { -class => 'sme-noborders-label' },
                $fm->localise('CONF_NAME')
            ),
            $q->td( { -class => 'sme-noborders-content' }, $conf )
          ),
          "\n";
    print $q->Tr(
            $q->td(
                { -class => 'sme-noborders-label' },
                $fm->localise('COMMENT')
            ),
            $q->td( { -class => 'sme-noborders-content' }, $comment )
          ),
          "\n";

    print $q->table(
        { -width => '100%' },
        $q->Tr(
            $q->th(
                { -class => 'sme-layout' },
                $q->submit(
                    -name  => 'cancel',
                    -value => $fm->localise('CANCEL')
                ),
                ' ',
                $q->submit(
                    -name  => 'remove',
                    -value => $fm->localise('REMOVE')
                )
            )
        )
      ),
      "\n";

    # Clear these values to prevent collisions when the page reloads.
    $q->delete("cancel");
    $q->delete("remove");
    return undef;
}



sub get_internet_ip_address {
  #we could use DNS to do this faster but some provider will block DNS
  #dig +short myip.opendns.com @resolver1.opendns.com
  #also resolver1.opendns.com resolver2.opendns.com resolver3.opendns.com
  #here a list of available site with https
  use Net::DNS;
  use LWP::Simple;
  my $timeout=1;

  my @httpslist=qw(
checkip.amazonaws.com
myexternalip.com/raw
ifconfig.me/
icanhazip.com/
ident.me/
tnx.nl/ip
ipecho.net/plain
wgetip.com/
ip.tyk.nu/
bot.whatismyipaddress.com/
ipof.in/txt
l2.io/ip
eth0.me/ );
  my @dns = (
        ['myip.opendns.com', 'resolver1.opendns.com', 'A'],
        ['myip.opendns.com', 'resolver2.opendns.com', 'A'],
        ['myip.opendns.com', 'resolver3.opendns.com', 'A'],
        ['myip.opendns.com', 'resolver4.opendns.com', 'A'],
        ['whoami.akamai.net', 'ns1-1.akamaitech.net', 'A'],
        ['o-o.myaddr.l.google.com', 'ns1.google.com', 'TXT']

  );
  my $ip;

  #foreach my $i ( 0 .. $#dns) {
  # dns calls; test only one random...
  my $i = rand(@httpslist);
  my $res   = Net::DNS::Resolver->new(
        nameservers => [ $dns[$i][1] ],
        udp_timeout => $timeout,
        tcp_timeout => $timeout
  );
  my $reply = $res->search($dns[$i][0], $dns[$i][2]);
  if ($reply) {
    foreach my $rr ($reply->answer) {
        $ip= $rr->txtdata if $rr->can("txtdata");
        $ip= $rr->address if $rr->can("address");
	# untaint, dns output is tainted
	($ip) = $ip =~ /(\d+\.\d+\.\d+\.\d+)/;
	return $ip if $ip =~ /(\d+\.\d+\.\d+\.\d+)/;
    }
  } else {
    warn "query failed: ", $res->errorstring, "\n";
  }
  #}

  # https calls
  my $ii=0;
  my $service;
  while ( $ii <5 ) { 
    $service=$httpslist[rand(@httpslist)];
    $ip = (get "https://$service" );
    chomp $ip;
    $ii++;
    last if $ip =~ /(\d+\.\d+\.\d+\.\d+)/;
  }
  # not needed but in case, untaint
  ($ip) = $ip =~ /(\d+\.\d+\.\d+\.\d+)/;
  return $ip;
}

sub test_for_private_ip {
     use NetAddr::IP;
     $_ = shift;
     my $mask = shift;
     return unless /(\d+\.\d+\.\d+\.\d+)/;
     my $iprange = NetAddr::IP->new($1,"$mask");
     return unless $iprange;    
     return ($iprange->first()->is_rfc1918() and  $iprange->last()->is_rfc1918());
}


1;
