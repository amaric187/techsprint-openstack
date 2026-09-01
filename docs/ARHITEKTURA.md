# OpenStack arhitektura

Svaki developer ima vlastiti Keystone projekt i privatnu Neutron mrežu. U projektu su dvije aplikacijske VM instance iza internog Octavia load balancera i jedna MariaDB VM. Sve instance imaju OS disk i dodatni Cinder data disk.

Swift container služi za Moodle objektne datoteke, a Manila CephFS share za backup. Pohrani pristupa zaseban servisni korisnik s ulogom `swiftoperator`.

Team Lead ima članstvo u svim developerskim projektima. Centralna Team Lead VM ujedno je jedini javno dostupan jump host. Ona ima upravljački port u svakoj developerskoj mreži, dok između developerskih mreža ne postoji router.

Nazivi koriste prefiks `techsprint-tst`, a resursi nose oznake `project=techsprint` i `environment=testing` gdje ih servis podržava.

