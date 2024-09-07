package SrvMngr::Controller::Wireguard;

#----------------------------------------------------------------------
# heading       : VPN
# description   : Wireguard
# navigation    : 6500 100
#
# name : wireguard,  method : get,  url : /wireguard,   ctlact : wireguard#main
# name : wireguardd, method : post, url : /wireguard,   ctlact : wireguard#do_display
# name : wireguardu, method : post, url : /wireguard2,  ctlact : wireguard#do_action
# name : wireguardr, method : get,  url : /wireguard2,  ctlact : wireguard#do_display
#
# routes : end
#----------------------------------------------------------------------
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';

use Locale::gettext;
use SrvMngr::I18N;
use SrvMngr qw( theme_list init_session is_normal_password );

use esmith::ConfigDB;
use Net::IP;

our $adb = esmith::AccountsDB->open() || die "Couldn't open accounts DB\ndb";
our $cdb = esmith::ConfigDB->open() || die "Couldn't open config DB\n";
our $wdb = esmith::ConfigDB->open('wireguard') || esmith::ConfigDB->create('wireguard');
our $ndb = esmith::NetworksDB->open_ro || die "Error opening networks DB\n";


sub main {

    my $c = shift;
    $c->app->log->info($c->log_req);

    my %wrg_datas = ();
    my $title = $c->l('wrg_FORM_TITLE');

    $wrg_datas{'trt'} = 'LST';

    $cdb = esmith::ConfigDB->open() || die "Couldn't open config DB\n";
    my $wg = $cdb->get('wg-quick@wg0');

    $wrg_datas{'wgpub'} 	= $wg->prop('public');
    $wrg_datas{'wgip'}		= $wg->prop('ip');
    $wrg_datas{'wgmask'}	= $wg->prop('mask');
    $wrg_datas{'wgport'}	= $wg->prop('UDPPort');
    $wrg_datas{'sstatus'}	= $wg->prop('status');

    my @wgstatus = `/usr/bin/wg show wg0 dump`;

    my $type = 'wg0';
    my @wgconf = $wdb->get_all_by_prop(type=>$type);

    $c->stash( title => $title, wrg_datas => \%wrg_datas,
	 wgstatus => \@wgstatus,  wgconf => \@wgconf );

    $c->render(template => 'wireguard');

};


sub do_display {

    my $c = shift;
    $c->app->log->info($c->log_req);

    my $rt = $c->current_route;
    my $trt = ($c->param('trt') || '');
    my $wgconf = $c->param('Wgconf') || '';

    my %wrg_datas = ();
    my $title = $c->l('wrg_FORM_TITLE');
    my $modul = '';

    $wrg_datas{'trt'} = $trt;

        if ( $trt eq 'QRC' ) {
	    $wrg_datas{'wgconf'} = $wgconf;
        }

        if ( $trt eq 'MOD' ) {
	    $wrg_datas{'wgconf'} = $wgconf;
	    my $rec = $wdb->get($wgconf);
	    if ( $rec ) {
		$wrg_datas{'info'} = $rec->prop('info') || '';
		$wrg_datas{'allowedips'} = $rec->prop('allowedips') || '';
		$wrg_datas{'private'} = $rec->prop('private') || '';
		$wrg_datas{'public'} = $rec->prop('public') || '';
		$wrg_datas{'account'} = $rec->prop('user') || '';
		$wrg_datas{'status'} = $rec->prop('status') || '';
		$wrg_datas{'dns'} = $rec->prop('dns') || '';
	    }
	}

        if ( $trt eq 'REM' ) {
	    $wrg_datas{'wgconf'} = $wgconf;
	    my $rec = $wdb->get($wgconf);
	    $wrg_datas{'wgcomment'} = $rec->prop('info') || '';
        }

        if ( $trt eq 'NEW' ) {
    	    # nothing for a new client
        }

        if ( $trt eq 'UPD' ) {
	    my $wg = $cdb->get('wg-quick@wg0');
	    $wrg_datas{'ip'}		= $wg->prop('ip');
	    $wrg_datas{'mask'}		= $wg->prop('mask');
	    $wrg_datas{'private'}	= $wg->prop('private');
	    $wrg_datas{'public'} 	= $wg->prop('public');
	    $wrg_datas{'status'}	= $wg->prop('status');
        }

        if ( $trt eq 'LST' ) {
	    my @wgss = $adb->wgss();
            $c->stash( wgss => \@wgss );
	}

    $c->stash( title => $title, modul => $modul, wrg_datas => \%wrg_datas );
    $c->render( template => 'wireguard' );

};


sub do_action {

    my $c = shift;
    $c->app->log->info($c->log_req);

    my $rt = $c->current_route;
    my $trt = ($c->param('trt') || '');

    my %wrg_datas = ();
    my $title = $c->l('wrg_FORM_TITLE');

    $wrg_datas{'trt'} = $trt;

    my $result = '';
    my $res = '';

    if ( $trt eq 'QRC' ) {
    #	NEVER
    }

    if ( $trt eq 'LST' ) {
    #	NEVER
    }

    if ( $trt eq 'MOD' ) {
	$wrg_datas{'wgconf'} = $c->param('Wgconf');
	# controls
	$res = 'OK';	# no controls here...
	$result .= $res unless $res eq 'OK';
	if ( ! $result ) {
	    $res = performModifyClient( $c ); 
	    $result .= $res unless $res eq 'OK';
	    if ( ! $result ) { 
		$result = $c->l('wrg_SUCCESSFULLY_MODIFIED_CONF');
	    }
	}
    }

    if ( $trt eq 'REM' ) {
	if ($c->param("cancel")) {
	    $c->stash( error => $c->l('wrg_CANCELLED') );
	    $c->redirect_to('/wireguard');
	}
	# controls
	$res = 'OK';	# no controls here...
	$result .= $res unless $res eq 'OK';
	if ( ! $result ) {
	    $res = performRemoveClient( $c ); 
	    $result .= $res unless $res eq 'OK';
	    if ( ! $result ) { 
		$result = $c->l('wrg_SUCCESSFULLY_REMOVED_CONF');
	    }
	}
    }

    if ( $trt eq 'NEW' ) {

	# controls
	$res = 'OK';	# no controls here...
	$result .= $res unless $res eq 'OK';
	if ( ! $result ) {
	    $res = performCreateClient( $c ); 
	    $result .= $res unless $res eq 'OK';
	    if ( ! $result ) { 
		$result = $c->l('wrg_SUCCESSFULLY_ADDED_CONF');
	    }
	}
    }

    if ( $trt eq 'UPD' ) {

	# controls
	$res = 'OK';	# no controls here...
	$result .= $res unless $res eq 'OK';
	if ( ! $result ) {
	    $res = performUpdateConfig( $c ); 
	    $result .= $res unless $res eq 'OK';
	    if ( ! $result ) { 
		$result = $c->l('wrg_SUCCESSFULLY_UPDATED_CONF');
	    }
	}
    }


    # common parts

    if ($res ne 'OK') {
	$c->stash( error => $result );
	$c->stash( title => $title, wrg_datas => \%wrg_datas );
	return $c->render('wireguard');
    }

    #force reload as successfull (for Main)
    $wdb = esmith::ConfigDB->open('wireguard');

    my $message = "'Wireguard' update ($trt) DONE";
    $c->app->log->info($message);
    $c->flash( success => $result );

    $c->redirect_to('/wireguard');
}


# action for 'MOD'
sub performModifyClient{

    my $c = shift;
    my $msg = "OK";

    my $wgacc = $c->param('Wgconf');
    my $account = $c->param('Account');
    my $private = $c->param('Private') || '';
    my $public = $c->param('Public') || ''; 
    my $info = $c->param('Info');
    my $status = $c->param('Status') || 'disabled';
    my $allowedips =  $c->param('Allowedips') || '';

    #todo validate fields

# Untaint info and account before use in system()
    ($info) = $info =~ /([A-Za-z0-9_\-. ]+)/;
#	trim both ends
    $info =~ s/^ +| +$//g;
    ($account) = $account =~ /([A-Za-z0-9_-]+)/;

    return $c->l('wrg_ERROR_FIELD_CONTENT') unless ($account and $info);

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

    return "$msg"

}


# action for 'NEW'
sub performCreateClient {

    my $c = shift;
    my $type = shift;

    my $username = $c->param('Account');
    my $info = $c->param('Info');

# Untaint info and account before use in system()
    ($info) = $info =~ /([A-Za-z0-9_\-. ]+)/;
#	trim both ends
    $info =~ s/^ +| +$//g;

    ($username) = $username =~ /([A-Za-z0-9_-]+)/;

    return $c->l('wrg_ERROR_FIELD_CONTENT') unless ($username and $info);

    #get username
    my $user = $adb->get($username) or return "$username does not exist";
    return $c->l('wrg_ERROR_WRONG_ACCT_TYPE') unless $user->prop("type") eq "user" or $user->key eq "admin";
    $username = $user->key;

    # execute the event wireguard-user-create username info
    unless ( system ("/sbin/e-smith/signal-event", "wireguard-user-create", "$username" , "$info") == 0 ){
        return $c->error('wrg_ERROR_OCCURED');
    }

    return 'OK';
}


# action for 'UPD'
sub performUpdateConfig {

    my $c = shift;
    my $msg = "OK";

    my $ip = $c->param('Ip');
    my $mask = $c->param('Mask');
    my $private = $c->param('Private');
    my $public = $c->param('Public');
    my $status = $c->param('Status');

    unless (defined $private) {
    	$private =`/usr/bin/wg genkey`;
	($private) = ($private =~ /(\w+)/);
	$public = `/usr/bin/echo $private | /usr/bin/wg pubkey`;
    }

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
		return $c->l('wrg_CLIENTS_ALREADY_CONFIGURED');
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
        #$fm->error($msg);return;
    }

    $cdb->get('wg-quick@wg0')->merge_props(%props)
        or $msg = "Error occurred while modifying server details.";


    if ($msg eq "OK"){
		# Untaint before use in system()
		($ip) = ($ip =~ /(\d+\.+\d+\.+\d+\.+\d+\.+\/\d+\.+)/);
		system( "/sbin/e-smith/signal-event", "wireguard-conf-modify", "$ip",)
			== 0 or $msg = "Error occurred while modifying wireguard conf.";
    }

    return "$msg";

}


# action for 'REM'
sub performRemoveClient{

    my ($c) = @_;

    my $conf = $c->param('Wgconf');
    if ($c->param("remove")){
        unless ($wdb->get($conf)->delete()){
    	    return $c->l('wrg_ERROR_OCCURED');
        }
        unless (system ("/sbin/e-smith/signal-event", "wireguard-user-delete") == 0 ){
    	    return $c->l('wrg_ERROR_OCCURED');
        }
    	return 'OK';
    }
    return $c->l('wrg_CANCELLED');

}


# called from templates
sub get_existing_accounts {

    my $c = shift;
    my @existingAccounts = ('Administrator');

    foreach my $account ($adb->get_all_by_prop(type=>'user')) {
            push @existingAccounts, $account->key;
    }
    return \@existingAccounts;

}


# called from templates
sub get_wgs_info {

    my ($c, $attr, $data) = @_;

    return undef if ( not defined $attr or not defined $data );

    my $value;
    $value = $wdb->get("$data")->prop('info') if ( $attr eq 'info' and $wdb->get("$data") );
    $value = $wdb->get("$data")->prop('user') if ( $attr eq 'user' and $wdb->get("$data") );

    return $value;

}


# called from templates
sub get_conf_info {

    my ( $c, $ipacc ) = @_;
    ##my $ipacc = $c->param('Wgconf');

    #untaint
    ($ipacc) = $ipacc  =~ /(\d+\.\d+\.\d+\.\d+\/\d+)/;
    #get from db

    # return if does not exist
    my $acc = $wdb->get($ipacc) or return undef;

    # return if current user is not admin or the user
    return undef unless $c->is_admin;

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
    my @fulltext = split( "\n", $fulltext);

    return \@fulltext;

}


# called from templates
sub get_conf_qr {

    my ( $c, $fulltext, $type) = @_;

    my $qr=`echo "$fulltext" |qrencode -t PNG -o - |base64`;

    return $qr;

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
     return ($iprange->first()->is_rfc1918() and $iprange->last()->is_rfc1918());

}


1

__END__
