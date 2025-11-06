BEGIN {
	FS="/"
	while ("for feed in $(./scripts/feeds list -n); do find -L feeds/${feed} -name Makefile.append | sort; done"  | getline APPEND) {
            nf=split(APPEND, parts)
            APPENDS[parts[nf-1]]="$(TOPDIR)/" APPEND "\n" APPENDS[parts[nf-1]]
        }
}
$1 ~ /^feeds/ { FEEDS[$NF]=$0 }
$1 !~ /^feeds/ { PKGS[$NF]=$0 }
END {
	# Filter-out OpenWrt packages which have a feeds equivalent
	for (pkg in PKGS)
		if (pkg in FEEDS) {
			print PKGS[pkg] > of
			delete PKGS[pkg]
		}
	n = asorti(PKGS, PKGKEYS)
	for (i=1; i <= n; i++) {
		print PKGS[PKGKEYS[i]]
                if (PKGKEYS[i] in APPENDS)
                    printf "%s", APPENDS[PKGKEYS[i]]
	}
	n = asorti(FEEDS, FEEDKEYS)
	for (i=1; i <= n; i++){
		print FEEDS[FEEDKEYS[i]]
                if (FEEDKEYS[i] in APPENDS)
                    printf "%s", APPENDS[FEEDKEYS[i]]
	}
}
