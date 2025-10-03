%define release 28
%define version 1.0
%define debug_package %{nil}

Name: smeserver-wireguard		
Version: %{version}	
Release: %{release}%{?dist}
Summary: wireguard SME Server configuration package	

Group:	VPN	
License: GPL	
URL: https://wiki.koozali.org/Wireguard		
Source0: smeserver-wireguard-1.0.tar.xz	

BuildRequires:	smeserver-devtools
Requires: wireguard-tools
Requires: kmod-wireguard
Requires: smeserver-release >= 10
Requires: qrencode
Requires: perl-Net-Netmask
Requires: smeserver-base >= 5.8.1-2
Requires: smeserver-lib >= 2.6.0-15

AutoReqProv: no

%description
WireGuard is a novel VPN that runs inside the Linux Kernel and uses
state-of-the-art cryptography (the "Noise" protocol). It aims to be
faster, simpler, leaner, and more useful than IPSec, while avoiding
the massive headache. It intends to be considerably more performant
than OpenVPN. WireGuard is designed as a general purpose VPN for
running on embedded interfaces and super computers alike, fit for
many different circumstances. It runs over UDP.
This package provides the Koozali SME SERVER configuration for controlling WireGuard.

%prep
%setup -q

%build
perl createlinks


%install
rm -rf %{buildroot}
(cd root; find . -depth -print | cpio -dump %{buildroot})
/sbin/e-smith/genfilelist %{buildroot} \
 --ignoredir "/etc/wireguard" \
 > %{name}-%{version}-filelist

cat %{name}-%{version}-filelist

%files -f %{name}-%{version}-filelist
%defattr(-,root,root)
#%doc COPYING

%post


%changelog
* Fri Oct 03 2025 Brian Read <brianr@koozali.org> 1.0-28.sme
- Add in UTF8 to ConfigDB open [SME: 13209]

* Fri Oct 03 2025 Brian Read <brianr@koozali.org> 1.0-27.sme
- Remove smanager-refresh from spec file [SME: 13212]

* Fri Sep 26 2025 Brian Read <brianr@koozali.org> 1.0-26.sme
- Fix remove logic, add in user name to rem panel re-format templates,  add space to list panel [SME: 13168]

* Thu Sep 25 2025 Brian Read <brianr@koozali.org> 1.0-25.sme
- Sort outy Remove panel placement and operation of buttons [SME: 13168]

* Wed Sep 24 2025 Brian Read <brianr@koozali.org> 1.0-24.sme
- Sort out access to DB vis a vis caching [SME: 13168]

* Mon Sep 22 2025 Brian Read <brianr@koozali.org> 1.0-23.sme
- add debuginfo define to suppress it [SME: 13168]
- Fix config call in layout [SME: 13168]

* Sun Sep 08 2024 Brian Read <brianr@koozali.org> 1.0-22.sme
- Map e-smith package names to smeserver 

* Sat Sep 07 2024 cvs2git.sh aka Brian Read <brianr@koozali.org> 1.0-21.sme
- Roll up patches and move to git repo [SME: 12338]

* Sat Sep 07 2024 BogusDateBot
- Eliminated rpmbuild "bogus date" warnings due to inconsistent weekday,
  by assuming the date is correct and changing the weekday.

* Fri Sep 06 2024 Terry Fage <terry@fage.id.au> 1.0-20.sme
- apply locale 2024-09-06.patch

* Fri Mar 01 2024 Brian Read <brianr@koozali.org> 1.0-19.sme
- Edit SM2 Menu entry to conform to new arrangements [SME: 12493]

* Mon Dec 26 2022 Jean-Philippe Pialasse <tests@pialasse.com> 1.0-18.sme
- remove masquerade and forward directive on startup [SME: 12288]

* Fri Nov 11 2022 Jean-Philippe Pialasse <tests@pialasse.com> 1.0-17.sme
- apply locale 2022-11-11 patch

* Sun May 29 2022 Jean-Philippe Pialasse <tests@pialasse.com> 1.0-16.sme
- improve check and tidying for non local network type [SME: 11771]
  updated both legacy and new panel

* Tue Apr 19 2022 Michel Begue <mab974@misouk.com> 1.0-15.sme
- Fix typos in templates

* Fri Apr 15 2022 Michel Begue <mab974@misouk.com> 1.0-14.sme
- Integrate wireguard with smeserver-manager (manager2) [SME: 11819]
- Accept spaces in 'info' attribute [SME: 11742]

* Thu Nov 25 2021 Brian Read <brianr@bjsystems.co.uk> 1.0-13.sme
- Delete old networkdb records when server ip updated [SME: 11771]
- Validate Server Ip range to be private in SM panel

* Tue Nov 16 2021 Brian Read <brianr@bjsystems.co.uk> 1.0-12.sme
- Fix-allowedips-in-quick-conf-contents [SME: 11756]

* Wed Nov 03 2021 Jean-Philippe Pialasse <tests@pialasse.com> 1.0-11.sme
- fix tainted string from dns query [SME: 11721]

* Wed Nov 03 2021 Jean-Philippe Pialasse <tests@pialasse.com> 1.0-10.sme
- fix wrong delete event [SME: 11721]
  fix ip not shown if server only
  improved config display

* Mon Nov 01 2021 Jean-Philippe Pialasse <tests@pialasse.com> 1.0-9.sme
- fix  migrate fragment [SME: 11721]

* Sun Oct 31 2021 Jean-Philippe Pialasse <tests@pialasse.com> 1.0-8.sme
- set DNS if allowedips 0.0.0.0/0 [SME: 11721]
  allowedips displayed as it has been set.

* Wed Oct 27 2021 Jean-Philippe Pialasse <tests@pialasse.com> 1.0-7.sme
- fix wrong ip [SME: 11721]
- updated templates fragments
- fix panel link ; fix private/public key creation; fix preset path
- requires e-smith-base >= 5.8.1-2

* Tue Oct 26 2021 Jean-Philippe Pialasse <tests@pialasse.com> 1.0-1.sme
- first release for Koozali SME Server
