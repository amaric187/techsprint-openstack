# OpenStack arhitektura

Svaki developer ima vlastiti Keystone projekt i privatnu Neutron mrežu. U projektu su dvije aplikacijske VM instance iza internog Octavia load balancera i jedna MariaDB VM. Sve instance imaju OS disk i dodatni Cinder data disk.

Swift container služi za Moodle objektne datoteke, a Manila CephFS share za backup. Pohrani pristupa zaseban servisni korisnik s ulogom `swiftoperator`.

Team Lead ima članstvo u svim developerskim projektima. Centralna Team Lead VM ujedno je jedini javno dostupan jump host. Ona ima upravljački port u svakoj developerskoj mreži, dok između developerskih mreža ne postoji router.

Nazivi koriste prefiks `techsprint-tst`, a resursi nose oznake `project=techsprint` i `environment=testing` gdje ih servis podržava.

## Red Hat Academy kompatibilnost

Academy overcloud ima ukupno 12 vCPU. Pet developerskih instanci koristi flavor od 2 vCPU i 4 GB, dok prvi redundantni `app2` i Team Lead jump-host koriste `flv-techsprint-lab-small` od 1 vCPU i 2 GB. Time svih sedam traženih instanci stane u laboratorijski kapacitet.

Octavia koristi OVN provider, TCP listener i `SOURCE_IP_PORT` algoritam, jer dostupni OVN driver ne podržava HTTP pool ni `ROUND_ROBIN`.

Manila CephFS share i CephX access rule uvijek se provisioniraju. Guest mount se izvodi samo kada je `mount.ceph` dostupan. Academy RHEL slike nemaju Ceph Tools repozitorij, a tenantske mreže nemaju put do storage mreže `172.24.3.0/24`, pa se u tom labu guest mount preskače. Swift objektna pohrana ostaje montirana rcloneom i služi Moodle objektima.
