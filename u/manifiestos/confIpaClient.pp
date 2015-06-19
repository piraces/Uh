class { 'ipaclient':
	password => "administracionsistemas",
	principal => "admin",
	server => ["ipa1.1.2.ff.es.eu.org","ipa2.1.2.ff.es.eu.org"],
	domain => "1.2.ff.es.eu.org",
	realm => "1.2.FF.ES.EU.ORG",
	mkhomedir => true,
	automount => true,
	automount_location => "default",
	automount_server => "ipa1.1.2.ff.es.eu.org",
	ssh => true,
	options => "--enable-dns-updates",
	fixed_primary => "false",
	installer => "/usr/sbin/ipa-client-install"
}
